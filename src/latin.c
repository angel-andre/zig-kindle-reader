// Offline Latin dictionary (latin.zdict, ZRLA1001) built from William Whitaker's WORDS data.
// A word is folded (lowercase, macrons/accents dropped, j->i, v->u), then every ending in the
// inflection table that the word ends with is stripped and the remaining stem is looked up;
// declension/conjugation, gender, comparison and stem number must agree, as in WORDS itself.
#include <fcntl.h>
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <unistd.h>

static const unsigned char *db;
static size_t size;
static uint32_t nstems, nentries, ninfl, so, ko, ro, eo, io, dso, to;
static uint32_t u32(const unsigned char *p) { return (uint32_t)p[0] | (uint32_t)p[1]<<8 | (uint32_t)p[2]<<16 | (uint32_t)p[3]<<24; }
static unsigned u16(const unsigned char *p) { return p[0] | (unsigned)p[1]<<8; }
void zrl_close(void) { if (db) munmap((void*)db,size); db=NULL;size=0; }
int zrl_open(const char *path) {
 zrl_close();int fd=open(path,O_RDONLY);if(fd<0)return 0;struct stat st;
 if(fstat(fd,&st)||st.st_size<64||st.st_size>(off_t)(40u<<20)){close(fd);return 0;}
 size=st.st_size;void *m=mmap(NULL,size,PROT_READ,MAP_PRIVATE,fd,0);close(fd);if(m==MAP_FAILED){size=0;return 0;}db=m;
 if(memcmp(db,"ZRLA1001",8))goto bad;
 nstems=u32(db+8);nentries=u32(db+12);ninfl=u32(db+16);so=u32(db+20);ko=u32(db+24);ro=u32(db+28);eo=u32(db+32);io=u32(db+36);dso=u32(db+40);to=u32(db+44);
 if(u32(db+48)!=size||nstems>500000||nentries>200000||ninfl>10000)goto bad;
 if(so!=64||ko<so+(size_t)nstems*12||ro<ko||eo<ro||eo+(size_t)nentries*12>io||io+(size_t)ninfl*20>dso||dso>to||to>size)goto bad;
 return 1;
 bad:zrl_close();return 0;
}
static const unsigned char *find(const char *key,size_t len) {
 uint32_t lo=0,hi=nstems;
 while(lo<hi){uint32_t mid=lo+(hi-lo)/2;const unsigned char*r=db+so+(size_t)mid*12;size_t bn=u16(r+4);
  int c=memcmp(key,db+ko+u32(r),len<bn?len:bn);if(!c)c=len<bn?-1:len>bn;if(!c)return r;if(c<0)hi=mid;else lo=mid+1;}
 return NULL;
}
// U+00C0..U+017F -> base letter ('.' = not a letter we fold)
static const char latin1ext[]="aaaaaa.ceeeeiiii.nooooo..uuuuy..aaaaaa.ceeeeiiii.nooooo..uuuuy.yaaaaaaccccccccdd..eeeeeeeeeegggggggghh..iiiiiiiii...jjkk.llllll....nnnnnn...oooooo..rrrrrrsssssssstttt..uuuuuuuuuuuuwwyyyzzzzzzs";
static int fold(const char *s,int len,char *out,int cap) {
 int n=0,i=0;
 while(i<len){
  unsigned char c=s[i];unsigned cp=c;int step=1;
  if(c>=0xc0&&c<0xe0&&i+1<len){cp=(c&0x1f)<<6|(s[i+1]&0x3f);step=2;}
  else if(c>=0xe0&&c<0xf0&&i+2<len){cp=(c&0x0f)<<12|(s[i+1]&0x3f)<<6|(s[i+2]&0x3f);step=3;}
  else if(c>=0xf0){step=4;cp=0xfffd;}
  i+=step;
  const char *add=NULL;char one[2]={0,0};
  if(cp>='A'&&cp<='Z')one[0]=cp+32;else if(cp>='a'&&cp<='z')one[0]=cp;
  else if(cp==0xe6||cp==0xc6)add="ae";else if(cp==0x153||cp==0x152)add="oe";
  else if(cp>=0xc0&&cp<0x180&&latin1ext[cp-0xc0]!='.')one[0]=latin1ext[cp-0xc0];
  else if(cp>=0x300&&cp<0x370)continue; // combining marks (macron, breve, acute...)
  else if(cp=='\''||cp==0x2019||cp=='-'||cp==0xad)continue;
  else return 0;
  if(!add)add=one;
  for(;*add;add++){char k=*add;if(k=='j')k='i';else if(k=='v')k='u';if(n>=cap-1)return 0;out[n++]=k;}
 }
 out[n]=0;return n;
}
static int letter(unsigned char c){return (c>='a'&&c<='z')||(c>='A'&&c<='Z')||c>=0x80;}
typedef struct { uint32_t entry, rank; uint32_t desc[3]; int ndesc; } Hit;
enum { MAXHITS=12 };
static int addhit(Hit *h,int n,uint32_t entry,uint32_t rank,uint32_t desc) {
 for(int i=0;i<n;i++)if(h[i].entry==entry||u32(db+eo+(size_t)h[i].entry*12+8)==u32(db+eo+(size_t)entry*12+8)){
  if(rank<h[i].rank)h[i].rank=rank;
  for(int k=0;k<h[i].ndesc;k++)if(h[i].desc[k]==desc)return n;
  if(h[i].ndesc<3)h[i].desc[h[i].ndesc++]=desc;return n;}
 if(n>=MAXHITS)return n;h[n].entry=entry;h[n].rank=rank;h[n].desc[0]=desc;h[n].ndesc=desc==0xffffffffu?0:1;return n+1;
}
static int collect(const char *w,int n,Hit *h,int nh) {
 const unsigned char *u=find(w,n);
 if(u){unsigned c=u16(u+6);const unsigned char*rf=db+ro+u32(u+8);
  for(unsigned k=0;k<c;k++){uint32_t ref=u32(rf+k*4),e=ref>>2;if(e>=nentries)continue;const unsigned char*E=db+eo+(size_t)e*12;
   if(E[0]==10)nh=addhit(h,nh,e,E[5]*16,0xffffffffu);}}
 for(uint32_t i=0;i<ninfl;i++){
  const unsigned char *I=db+io+(size_t)i*20;int el=I[7];
  if(el>=n||el>8||memcmp(w+n-el,I+8,el))continue;
  int key=I[3];if(key<1||key>4)continue;
  const unsigned char *r=find(w,n-el);if(!r)continue;
  unsigned c=u16(r+6);const unsigned char*rf=db+ro+u32(r+8);
  for(unsigned k=0;k<c;k++){
   uint32_t ref=u32(rf+k*4),e=ref>>2;if(e>=nentries||(int)(ref&3)!=key-1)continue;
   const unsigned char *E=db+eo+(size_t)e*12;
   if(E[0]!=I[0])continue;
   if(I[1]&&I[1]!=E[1])continue;
   if(I[2]&&I[2]!=E[2])continue;
   int ig=I[4],eg=E[3];
   if(E[0]==1&&ig&&eg&&ig!=eg&&!(ig==4&&(eg==1||eg==2))&&!(eg==4&&(ig==1||ig==2)))continue;
   if((E[0]==3||E[0]==6)&&E[4]&&I[5]&&I[5]!=E[4])continue;
   nh=addhit(h,nh,e,E[5]*16+I[6],u32(I+16));
  }
 }
 return nh;
}
static int put(char *out,int cap,int used,const char *s,size_t len){
 if(used<0||(size_t)used+len+1>=(size_t)cap)return -1;memcpy(out+used,s,len);used+=len;out[used]=0;return used;}
#define PUTS(s) do{int t_=put(out,cap,used,(s),strlen(s));if(t_<0)goto full;used=t_;}while(0)
#define PUTN(s,l) do{int t_=put(out,cap,used,(s),(l));if(t_<0)goto full;used=t_;}while(0)
int zrl_define(const char*word,int len,char*lemma,int lemma_cap,char*out,int cap) {
 if(!lemma||lemma_cap<1||!out||cap<1)return -1;lemma[0]=out[0]=0;
 if(!db)return -1;if(!word||len<=0||len>4096)return 0;
 int first=0,last=len;while(first<last&&!letter((unsigned char)word[first]))first++;
 while(last>first&&!letter((unsigned char)word[last-1]))last--;
 char w[64];int n=fold(word+first,last-first,w,sizeof w);if(n<=0)return 0;
 Hit h[MAXHITS];int nh=collect(w,n,h,0);const char *enclitic=NULL;
 if(!nh){static const char *tk[][2]={{"que","-que = and (enclitic)"},{"ne","-ne = question / or (enclitic)"},{"ue","-ve = or (enclitic)"}};
  for(unsigned t=0;t<3&&!nh;t++){int l=strlen(tk[t][0]);if(n>l+1&&!memcmp(w+n-l,tk[t][0],l)){nh=collect(w,n-l,h,0);if(nh)enclitic=tk[t][1];}}}
 if(!nh){snprintf(lemma,lemma_cap,"%s",w);return 0;}
 for(int i=1;i<nh;i++){Hit t=h[i];int j=i;while(j>0&&h[j-1].rank>t.rank){h[j]=h[j-1];j--;}h[j]=t;}
 if(nh>6)nh=6;
 int used=0;
 for(int i=0;i<nh;i++){
  const unsigned char *E=db+eo+(size_t)h[i].entry*12;const char *hw=(const char*)db+to+u32(E+8);
  size_t avail=size-(size_t)((const unsigned char*)hw-db);
  const char *z1=memchr(hw,0,avail);if(!z1)continue;const char *tag=z1+1;const char *z2=memchr(tag,0,avail-(tag-hw));if(!z2)continue;
  const char *mean=z2+1;const char *z3=memchr(mean,0,avail-(mean-hw));if(!z3)continue;
  if(i==0){size_t l=strcspn(hw,",");if(l>=(size_t)lemma_cap)l=lemma_cap-1;memcpy(lemma,hw,l);lemma[l]=0;}
  const char *dash=strstr(tag,"\xe2\x80\x94");size_t tl=dash?(size_t)(dash-tag):(size_t)(z2-tag);while(tl&&tag[tl-1]==' ')tl--;
  if(used)PUTS("\n\n");
  PUTN(hw,z1-hw);PUTS("  (");PUTN(tag,tl);PUTS(")\n");
  PUTN(mean,z3-mean);
  int any=0;
  if(dash){const char *d=dash+3;while(*d==' ')d++;PUTS("\n");PUTN(w,n);PUTS(": ");PUTS(d);any=1;}
  for(int k=0;k<h[i].ndesc;k++){const char *d=(const char*)db+dso+h[i].desc[k];if(!*d)continue;PUTS(any?"; ":"\n");if(!any){PUTS("form: ");}PUTS(d);any=1;}
 }
 if(enclitic){PUTS("\n\n+ ");PUTS(enclitic);}
 return used;
 full:{const char*t="\n\n[Additional senses omitted.]";if(used+(int)strlen(t)<cap){strcpy(out+used,t);used+=strlen(t);}}
 return used;
}
#ifdef ZRL_PROBE
#include <stdlib.h>
#include <time.h>
int cmp(const void*x,const void*y){double a=*(const double*)x,b=*(const double*)y;return a<b?-1:a>b;}
int main(int argc,char**argv){
 if(argc<3||!zrl_open(argv[1])){fprintf(stderr,"usage: probe latin.zdict word... (or -t file for timing)\n");return 2;}
 static char out[32768],lemma[128];
 if(!strcmp(argv[2],"-t")){
  FILE*f=fopen(argv[3],"r");if(!f)return 2;static char words[200000][32];int nw=0;char b[256];
  while(nw<200000&&fscanf(f,"%255s",b)==1){if(strlen(b)<32)strcpy(words[nw++],b);}fclose(f);
  struct timespec a,z;static double t[200000];double total=0,first=0;int hits=0;
  for(int i=0;i<nw;i++){clock_gettime(CLOCK_MONOTONIC,&a);int r=zrl_define(words[i],strlen(words[i]),lemma,128,out,sizeof out);clock_gettime(CLOCK_MONOTONIC,&z);
   double ms=(z.tv_sec-a.tv_sec)*1e3+(z.tv_nsec-a.tv_nsec)/1e6;t[i]=ms;total+=ms;if(!i)first=ms;if(r>0)hits++;}
  int cmp(const void*x,const void*y);qsort(t,nw,sizeof*t,cmp);
  printf("words=%d found=%d first_ms=%.4f mean_ms=%.4f p50_ms=%.4f p99_ms=%.4f p999_ms=%.4f max_ms=%.4f\n",nw,hits,first,total/nw,t[nw/2],t[nw*99/100],t[nw*999/1000],t[nw-1]);return 0;}
 for(int i=2;i<argc;i++){int r=zrl_define(argv[i],strlen(argv[i]),lemma,128,out,sizeof out);printf("== %s -> [%s] (%d)\n%s\n",argv[i],lemma,r,out);}
 return 0;
}
#endif
