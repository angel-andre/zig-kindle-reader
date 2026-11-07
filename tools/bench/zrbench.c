/* zrbench: headless on-device benchmark for zreader (no display, no input, no user state).
 * Uses the reader's own render.c / dictionary.c / latin.c with the reader's defaults:
 * 1272x1696 screen, PDF fit-page with trim, image dither + clean scans; EPUB/other reflow
 * at 10.5 pt, margin 18, spacing 1.4, justify + hyphenation, book fonts.
 *   zrbench book PATH TMPDIR [N]   open cold/warm, N page renders, prerender model, peak RSS
 *   (bench105 adds: the reader's first visible page as of 0.10.4, i.e. the draft when
 *   the first page is a large JPEG 2000 picture page, and EPUB reopen-at-position
 *   without a cached layout)
 *   zrbench dict WORDNET LATIN     English and Latin lookup times
 * Output: one "key=value" line per measurement. */
#include <pthread.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <time.h>
#include <unistd.h>
#include "render.h"
#include "hyph_la.h"
#define W 1272
#define H 1696
static const float LW=W*72.0f/300.0f,LH=H*72.0f/300.0f;
int zrd_open(const char*);int zrd_define(const char*,int,char*,int,char*,int);
int zrl_open(const char*);int zrl_define(const char*,int,char*,int,char*,int);
static double now_ms(void){struct timespec t;clock_gettime(CLOCK_MONOTONIC,&t);return t.tv_sec*1e3+t.tv_nsec/1e6;}
static int cmpd(const void*a,const void*b){double x=*(const double*)a,y=*(const double*)b;return x<y?-1:x>y;}
static void stats(const char*name,double*v,int n){
 if(n<=0){printf("%s_n=0\n",name);return;}double*s=malloc(n*sizeof*s);memcpy(s,v,n*sizeof*s);qsort(s,n,sizeof*s,cmpd);double sum=0;for(int i=0;i<n;i++)sum+=s[i];
 int p95=(int)(0.95*(n-1)+0.5);printf("%s_n=%d %s_p50_ms=%.3f %s_p95_ms=%.3f %s_max_ms=%.3f %s_mean_ms=%.3f\n",name,n,name,s[n/2],name,s[p95],name,s[n-1],name,sum/n);free(s);}
static long vm(const char*key){FILE*f=fopen("/proc/self/status","r");char l[256];long v=-1;size_t k=strlen(key);if(!f)return -1;while(fgets(l,sizeof l,f))if(!strncmp(l,key,k)){v=atol(l+k+1);break;}fclose(f);return v;}
static zr_doc *open_book(const char*p){return zr_open_style(p,LW,LH,10.5f,18,1.4f);}
static zr_doc *open_upto(const char*p,int ch){return zr_open_upto(p,LW,LH,10.5f,18,1.4f,ch);}
static int render_page(zr_doc*z,unsigned char*buf,int p){
 float r[4];int pdf=zr_is_pdf(z);int rc=pdf?zr_ink_bbox_flags(z,p,r,0,3):zr_page_bounds(z,p,r);if(rc)rc=zr_page_bounds(z,p,r);if(rc)return rc;
 float rw=r[2]-r[0],rh=r[3]-r[1];if(rw<1)rw=1;if(rh<1)rh=1;float s=W/rw<H/rh?W/rw:H/rh;
 float m[6]={s,0,0,s,(W-rw*s)/2-r[0]*s,(H-rh*s)/2-r[1]*s};zr_render_stats st;memset(buf,255,W*H);
 return zr_render_with_stats(z,p,m,buf,W,H,W,0,3,&st);}
/* 0.10.4 reader first page: a draft (half resolution, untrimmed, big JPEG 2000 images
 * decoded reduced) when zr_draft_wanted says the page is heavy, else the normal render.
 * Returns 1 when a draft was drawn. Same code path as the reader's renderDraftRaster. */
static int first_visible(zr_doc*z,unsigned char*buf,int p){
 if(!zr_is_pdf(z)||!zr_draft_wanted(z,p,3,W,H)){render_page(z,buf,p);return 0;}
 static unsigned char half[(W/2)*(H/2)];float r[4];if(zr_page_bounds(z,p,r)){render_page(z,buf,p);return 0;}
 float rw=r[2]-r[0],rh=r[3]-r[1];if(rw<1)rw=1;if(rh<1)rh=1;float s=W/rw<H/rh?W/rw:H/rh;
 float m[6]={s/2,0,0,s/2,((W-rw*s)/2-r[0]*s)/2,((H-rh*s)/2-r[1]*s)/2};zr_render_stats st;
 if(zr_render_with_stats(z,p,m,half,W/2,H/2,W/2,0,7,&st)||!st.drafted){render_page(z,buf,p);return 0;}
 for(int y=0;y<H;y++)for(int x=0;x<W;x++)buf[y*W+x]=half[(y/2)*(W/2)+x/2]; /* upscale cost stand-in */
 return 1;}
/* prerender model: like the reader, two workers (one document each) render the next pages
 * ahead of the current one while the reader turns every INTERVAL ms; a turn is a hit when
 * its page is already rendered. */
#define AHEAD 2
static struct{pthread_mutex_t m;pthread_cond_t c;int cur,stop,last,state[100000];double done_at[100000];}pm={PTHREAD_MUTEX_INITIALIZER,PTHREAD_COND_INITIALIZER};
static const char *bookpath;
static void *worker(void*arg){
 zr_doc*z=(zr_doc*)arg;unsigned char*buf=malloc(W*H);
 pthread_mutex_lock(&pm.m);
 while(!pm.stop){int job=-1;for(int p=pm.cur;p<=pm.cur+AHEAD&&p<=pm.last;p++)if(!pm.state[p]){job=p;break;}
  if(job<0){pthread_cond_wait(&pm.c,&pm.m);continue;}
  pm.state[job]=1;pthread_mutex_unlock(&pm.m);render_page(z,buf,job);pthread_mutex_lock(&pm.m);pm.state[job]=2;pm.done_at[job]=now_ms();pthread_cond_broadcast(&pm.c);}
 pthread_mutex_unlock(&pm.m);free(buf);return 0;}
static void model(zr_doc*a,zr_doc*b,int start,int n,int interval){
 memset(pm.state,0,sizeof pm.state);pm.stop=0;pm.cur=start;pm.last=start+n;
 pthread_t t[2];pthread_create(&t[0],0,worker,a);pthread_create(&t[1],0,worker,b);
 double *wait=malloc(n*sizeof*wait);int hits=0;
 pthread_mutex_lock(&pm.m);while(pm.state[start]!=2)pthread_cond_wait(&pm.c,&pm.m);pthread_mutex_unlock(&pm.m);
 for(int i=0;i<n;i++){
  usleep(interval*1000);double t0=now_ms();pthread_mutex_lock(&pm.m);int p=start+i+1;pm.cur=p;int hit=pm.state[p]==2;pthread_cond_broadcast(&pm.c);
  while(pm.state[p]!=2)pthread_cond_wait(&pm.c,&pm.m);pthread_mutex_unlock(&pm.m);double w=now_ms()-t0;wait[i]=w;if(hit)hits++;}
 pthread_mutex_lock(&pm.m);pm.stop=1;pthread_cond_broadcast(&pm.c);pthread_mutex_unlock(&pm.m);pthread_join(t[0],0);pthread_join(t[1],0);
 char name[64];snprintf(name,sizeof name,"model%d_turn_wait",interval);stats(name,wait,n);
 printf("model%d_prerender_hit_pct=%.0f\n",interval,100.0*hits/n);free(wait);}
static int cmd_book(const char*path,const char*tmp,int n){
 bookpath=path;
 { /* 0.10.4 first page, measured first on a cold process (no store, no display list) */
  zr_doc*z=open_book(path);if(z){unsigned char*b=malloc(W*H);double a=now_ms();int d=first_visible(z,b,0);double v=now_ms()-a;
  double e0=now_ms();render_page(z,b,0);double e=now_ms()-e0;
  printf("first_visible_cold_ms=%.1f first_page_draft=%d exact_after_ms=%.1f\n",v,d,e);free(b);zr_close(z);}}zr_set_text_resources(hyph_la,(int)sizeof hyph_la,0,0,0,0,0,0,0,0);zr_set_text_style(2,0);
 char lay[1400];snprintf(lay,sizeof lay,"%s/layout",tmp);mkdir(tmp,0700);zr_layout_cache(tmp);
 struct stat st;if(stat(path,&st)){printf("error=cannot stat\n");return 1;}
 printf("book_bytes=%lld\n",(long long)st.st_size);
 double t0=now_ms();zr_doc*z=open_book(path);double t1=now_ms();if(!z){printf("error=cannot open\n");return 1;}
 int pages=zr_page_count(z);unsigned char*buf=malloc(W*H);
 double t2=now_ms();render_page(z,buf,0);double t3=now_ms();
 printf("pages=%d pdf=%d reflow=%d\nopen_cold_ms=%.1f first_render_cold_ms=%.1f open_to_first_page_cold_ms=%.1f\n",pages,zr_is_pdf(z),zr_reflowable(z),t1-t0,t3-t2,t3-t0);
 long rss_one=vm("VmHWM");
 if(zr_reflowable(z)&&pages>4){ /* 0.10.4: reopen at the middle of the book, no cached layout */
  zr_anchor a={0};int mid=pages/2;
  if(zr_anchor_words(z,mid,0,0,&a)&&a.chapter>=0){
   char t2[1400];snprintf(t2,sizeof t2,"%s/nolayout",tmp);mkdir(t2,0700);zr_layout_cache(t2);
   double r0=now_ms();zr_doc*zu=open_upto(path,a.chapter);double r1=now_ms();
   if(zu){int ap=zr_anchor_page(zu,&a);double r2=now_ms();render_page(zu,buf,ap<0?0:ap);double r3=now_ms();
    printf("resume_cold_chapter=%d resume_cold_page=%d resume_open_cold_ms=%.1f resume_open_to_page_cold_ms=%.1f full_open_cold_ms=%.1f\n",a.chapter,ap+1,r1-r0,r3-r0,t1-t0);zr_close(zu);}
   zr_layout_cache(tmp);}}
 zr_close(z);
 t0=now_ms();z=open_book(path);t1=now_ms();render_page(z,buf,0);t3=now_ms();
 printf("open_warm_ms=%.1f open_to_first_page_warm_ms=%.1f\n",t1-t0,t3-t0);
 int start=pages>40?10:1;if(start+n>=pages)n=pages-start-1;if(n<1)n=1;
 double*v=malloc(n*sizeof*v);for(int i=0;i<n;i++){double a=now_ms();render_page(z,buf,start+i);v[i]=now_ms()-a;}
 printf("render_pages=%d..%d\n",start+1,start+n);stats("render",v,n);
 for(int i=0;i<n;i++){double a=now_ms();render_page(z,buf,start+i);v[i]=now_ms()-a;}
 stats("rerender",v,n);
 long rss_render=vm("VmHWM");
 zr_doc*z2=open_book(path);
 int mstart=start+n<pages-62?start+n:1;int mn=pages-mstart-2<30?pages-mstart-2:30;
 if(z2&&mn>2){model(z,z2,mstart,mn,700);model(z,z2,mstart+mn>pages-mn-2?1:mstart,mn,250);}
 printf("rss_peak_one_doc_kb=%ld rss_peak_after_renders_kb=%ld rss_peak_two_workers_kb=%ld\n",rss_one,rss_render,vm("VmHWM"));
 if(z2)zr_close(z2);zr_close(z);free(buf);free(v);return 0;}
static const char*EN[]={"walk","walked","running","children","memory","memories","houses","went","better","quickly","frontier","settlers","wilderness","rifles","cabin","journey","rivers","mountains","forgotten","carried","Indians","hunting","territory","beautiful","studies","theatre","images","places","rhetoric","architecture","remembering","astrology","philosophers","cathedral","treatise","renaissance","hermetic","system","wheel","seals"};
static const char*LA[]={"amavit","rosarum","memoria","memoriae","locis","imaginibus","agentes","artificiosa","constat","igitur","utendum","multis","illustribus","quae","est","enim","rerum","verborum","inventio","virumque","Gallia","divisa","partes","tres","quarum","incolunt","Belgae","Aquitani","lingua","institutis","legibus","inter","differunt","fortissimi","propterea","cultu","humanitate","provinciae","longissime","absunt"};
static void dict(const char*name,int(*def)(const char*,int,char*,int,char*,int),const char**w,int nw){
 static char out[32768],lemma[128];int rounds=25,n=0,found=0;double*v=malloc(nw*rounds*sizeof*v);
 double a=now_ms();int r=def(w[0],strlen(w[0]),lemma,128,out,sizeof out);printf("%s_first_lookup_ms=%.3f\n",name,now_ms()-a);(void)r;
 for(int k=0;k<rounds;k++)for(int i=0;i<nw;i++){a=now_ms();int rc=def(w[i],strlen(w[i]),lemma,128,out,sizeof out);v[n++]=now_ms()-a;if(k==0&&rc>0)found++;}
 printf("%s_found=%d/%d\n",name,found,nw);stats(name,v,n);free(v);}
static int cmd_dict(const char*en,const char*la){
 double a=now_ms();int ok=zrd_open(en);printf("en_open_ms=%.2f en_ok=%d\n",now_ms()-a,ok);if(ok)dict("en_lookup",zrd_define,EN,40);
 a=now_ms();ok=zrl_open(la);printf("la_open_ms=%.2f la_ok=%d\n",now_ms()-a,ok);if(ok)dict("la_lookup",zrl_define,LA,40);
 printf("rss_peak_kb=%ld\n",vm("VmHWM"));return 0;}
/* bench105: render pages 0..N-1 (reader settings) and hash all pixels (FNV-1a 64), so
 * two builds can be checked for identical output on the device. */
static int cmd_hash(const char*path,int n){
 zr_set_text_resources(hyph_la,(int)sizeof hyph_la,0,0,0,0,0,0,0,0);zr_set_text_style(2,0);
 zr_doc*z=open_book(path);if(!z){printf("error=cannot open\n");return 1;}
 int pages=zr_page_count(z);if(n>pages)n=pages;unsigned char*buf=malloc(W*H);uint64_t h=1469598103934665603ULL;double sum=0;
 for(int p=0;p<n;p++){double a=now_ms();render_page(z,buf,p);sum+=now_ms()-a;for(int i=0;i<W*H;i++)h=(h^buf[i])*1099511628211ULL;}
 printf("pages=%d hash=%016llx render_mean_ms=%.1f\n",n,(unsigned long long)h,n?sum/n:0);free(buf);zr_close(z);return 0;}
int main(int argc,char**argv){
 setvbuf(stdout,0,_IOLBF,0);
 if(argc>=4&&!strcmp(argv[1],"book"))return cmd_book(argv[2],argv[3],argc>4?atoi(argv[4]):30);
 if(argc>=4&&!strcmp(argv[1],"dict"))return cmd_dict(argv[2],argv[3]);
 if(argc>=3&&!strcmp(argv[1],"hash"))return cmd_hash(argv[2],argc>3?atoi(argv[3]):40);
 fprintf(stderr,"usage: zrbench book PATH TMPDIR [N] | zrbench dict WORDNET.zdict LATIN.zdict | zrbench hash PATH [N]\n");return 2;}
