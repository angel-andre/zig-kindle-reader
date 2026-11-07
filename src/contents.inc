/* v0.10.1 Contents fallback: when a book has no outline, find chapter
 * headings in the text layer (including OCR text) on a low-priority thread.
 * Only headings at the top of a page, with a keyword (CHAPTER/PART/BOOK or a
 * named section), and numbered chapters must form an increasing sequence;
 * anything else is dropped rather than shown. Output: "zrcontents\t1" then
 * "page\tlevel\tlabel" lines, written atomically. */
#include <sys/resource.h>
#include <sys/syscall.h>
#include <ctype.h>

#define CT_MAXE 400
typedef struct { int page, kind, ncand, cand[3], roman, val, keep; char title[96], name[40]; } ct_ent; /* kind 1 chapter, 2 part, 3 named */
typedef struct { char t[160]; float y, size; } ct_line;

static pthread_t ct_thread; static int ct_started;
static volatile int ct_state, ct_done, ct_total, ct_cancel, ct_found; /* state 0 idle 1 running 2 done 3 failed */
static char ct_path[1200], ct_out[1300]; static float ct_lw, ct_lh, ct_font, ct_margin, ct_spacing; static int ct_reflow;
__attribute__((weak)) void zr_ui_kick(void){}
static double ct_ms;

static int ct_roman(const char *s){int v=0,prev=0,n=0;for(int i=(int)strlen(s)-1;i>=0;i--){int c=toupper((unsigned char)s[i]),d=c=='I'?1:c=='V'?5:c=='X'?10:c=='L'?50:c=='C'?100:0;if(!d)return 0;if(d<prev)v-=d;else{v+=d;prev=d;}n++;}return n&&v>0&&v<200?v:0;}
static const char *ct_words[]={"ONE","TWO","THREE","FOUR","FIVE","SIX","SEVEN","EIGHT","NINE","TEN","ELEVEN","TWELVE","THIRTEEN","FOURTEEN","FIFTEEN","SIXTEEN","SEVENTEEN","EIGHTEEN","NINETEEN","TWENTY"};
/* Candidates for a chapter number token: digits, roman, OCR digits (I/l/|->1, O->0), English words. */
static int ct_number(const char *tok,int *cand,int *roman){
 int n=0;*roman=0;size_t L=strlen(tok);if(!L||L>6)return 0;
 int dig=1;for(size_t i=0;i<L;i++)if(!isdigit((unsigned char)tok[i]))dig=0;
 if(dig){cand[n++]=atoi(tok);return n;}
 int r=ct_roman(tok);if(r){cand[n++]=r;*roman=1;}
 char o[8];int ok=1;for(size_t i=0;i<L;i++){char c=tok[i];o[i]=c=='I'||c=='l'||c=='|'||c=='i'?'1':c=='O'||c=='o'?'0':c;if(!isdigit((unsigned char)o[i]))ok=0;}o[L]=0;
 if(ok){int v=atoi(o);if(v>0&&(n==0||v!=cand[0]))cand[n++]=v;}
 for(int w=0;w<20&&n<3;w++)if(!strcasecmp(tok,ct_words[w]))cand[n++]=w+1;
 return n;}
static const char *ct_named[]={"PROLOGUE","EPILOGUE","PREFACE","FOREWORD","INTRODUCTION","AUTHOR'S NOTE","AUTHORS NOTE","AFTERWORD","ACKNOWLEDGMENTS","ACKNOWLEDGEMENTS","APPENDIX","NOTES","CHAPTER NOTES","BIBLIOGRAPHY","INDEX","GLOSSARY","ILLUSTRATIONS","CONCLUSION","POSTSCRIPT","CONTENTS",0};
static void ct_clean(char *s){ /* trim junk, normalise quotes/spaces */
 char o[160];int n=0;for(unsigned char *p=(unsigned char*)s;*p&&n<158;p++){
  if(p[0]==0xE2&&p[1]==0x80&&(p[2]==0x98||p[2]==0x99)){o[n++]='\'';p+=2;continue;}
  if(*p=='\t'||*p=='\n')o[n++]=' ';else o[n++]=*p;}
 o[n]=0;char *a=o;while(*a&&!isalnum((unsigned char)*a))a++;int L=(int)strlen(a);while(L>0&&(a[L-1]==' '||a[L-1]=='.'||a[L-1]==':'||a[L-1]=='-'||a[L-1]=='_'))a[--L]=0;
 memmove(s,a,L+1);}
static int ct_letters(const char *s,int *upper){int l=0,u=0;for(;*s;s++)if(isalpha((unsigned char)*s)){l++;if(isupper((unsigned char)*s))u++;}*upper=u;return l;}
static int ct_is_title(const char *s){int u,l=ct_letters(s,&u);size_t L=strlen(s);return s[0]!='['&&l>=3&&L<=48&&u*10>=l*7&&l*10>=(int)L*6;}
static void ct_titlecase(char *s){
 static const char *small[]={"of","in","the","and","a","an","as","at","on","to","for","by","or","with","from",0};
 int start=1,first=1;char *w=s;
 for(char *p=s;;p++){
  if(!*p||*p==' '){ /* finish word [w,p) */
   size_t L=(size_t)(p-w);int sm=0;if(!first)for(int i=0;small[i];i++)if(strlen(small[i])==L&&!strncasecmp(w,small[i],L))sm=1;
   if(sm&&L)w[0]=tolower((unsigned char)w[0]);if(L)first=0;if(!*p)break;w=p+1;start=1;continue;}
  if(isalpha((unsigned char)*p)){*p=start?toupper((unsigned char)*p):tolower((unsigned char)*p);start=0;}else start=*p=='-'||*p=='(';}
 int L=(int)strlen(s);while(L>0&&!isalnum((unsigned char)s[L-1])&&s[L-1]!=')'&&s[L-1]!='?')s[--L]=0;}
static int ct_top_lines(fz_stext_page *st,ct_line *out,int max,float ph){
 int n=0;
 for(fz_stext_block *b=st->first_block;b;b=b->next){if(b->type!=FZ_STEXT_BLOCK_TEXT)continue;
  for(fz_stext_line *ln=b->u.t.first_line;ln;ln=ln->next){if(ln->bbox.y0>ph*0.45f)continue;
   ct_line L;int m=0;float sz=0;for(fz_stext_char *c=ln->first_char;c&&m<150;c=c->next){m+=fz_runetochar(L.t+m,c->c);if(c->size>sz)sz=c->size;}
   L.t[m]=0;ct_clean(L.t);int u;if(!L.t[0])continue;
   {int c3[3],r3;int dig=1;for(char *q=L.t;*q;q++)if(!isdigit((unsigned char)*q))dig=0;
    if(ct_letters(L.t,&u)<3&&!dig&&!ct_number(L.t,c3,&r3))continue;} /* OCR specks don't push headings down */
   L.y=ln->bbox.y0;L.size=sz;
   int at=n;while(at>0&&out[at-1].y>L.y){if(at<max)out[at]=out[at-1];at--;}if(at<max){out[at]=L;if(n<max)n++;}}}
 return n;}
static void ct_page(int page,ct_line *ls,int n,ct_ent *e,int *ne){
 int skip=0; /* ignore a leading page number line */
 if(n>1){int dig=1;for(char *p=ls[0].t;*p;p++)if(!isdigit((unsigned char)*p))dig=0;if(dig)skip=1;}
 for(int i=skip;i<n&&i<skip+3&&*ne<CT_MAXE;i++){
  char *t=ls[i].t;int kind=0;const char *rest=0;
  if(!strncmp(t,"CHAPTER",7)&&(t[7]==0||t[7]==' '))kind=1,rest=t+7;
  else if(!strncmp(t,"Chapter ",8))kind=1,rest=t+7;
  else if(!strncmp(t,"CHAP. ",6))kind=1,rest=t+5;
  else if(!strncmp(t,"PART ",5)||!strncmp(t,"Part ",5))kind=2,rest=t+4;
  else if(!strncmp(t,"BOOK ",5)&&strlen(t)<=20)kind=2,rest=t+4;
  if(kind){
   while(*rest==' ')rest++;
   char tok[16]={0};int k=0;while(rest[k]&&rest[k]!=' '&&k<15){tok[k]=rest[k];k++;}const char *after=rest+k;while(*after==' ')after++;
   {int tl=(int)strlen(tok);while(tl>1&&(tok[tl-1]=='.'||tok[tl-1]==':'))tok[--tl]=0;} /* "CHAPTER I." */
   if(strstr(after,"CHAPTER ")||strstr(after,"Chapter "))continue; /* a printed contents line */
   ct_ent x;memset(&x,0,sizeof x);x.page=page;x.kind=kind;
   if(kind==1&&(!strcasecmp(tok,"NOTES"))){ x.kind=3;snprintf(x.name,sizeof x.name,"Chapter Notes"); e[(*ne)++]=x;return; }
   int next=i+1;
   if(!tok[0]&&next<n&&strlen(ls[next].t)<=6){snprintf(tok,sizeof tok,"%s",ls[next].t);next++;}
   if(tok[0]){x.ncand=ct_number(tok,x.cand,&x.roman);if(!x.ncand&&(strlen(tok)>3||*after))continue;} /* "CHAPTER" + an unreadable short token is kept as unknown */
   else if(kind==2)continue;
   if(*after&&(ct_is_title(after)||(ct_reflow&&strlen(after)<=48)))snprintf(x.title,sizeof x.title,"%s",after); /* reflowed books: "CHAPTER I. Down the Rabbit-Hole" */
   for(int j=next;j<n&&j<next+2;j++){if(!ct_is_title(ls[j].t))break;size_t L=strlen(x.title);if(L+strlen(ls[j].t)+2>=sizeof x.title)break;if(L)strcat(x.title," ");strcat(x.title,ls[j].t);}
   if(strlen(x.title)>=3)ct_titlecase(x.title);else x.title[0]=0;
   e[(*ne)++]=x;return;}
  if(i<skip+2&&strlen(t)<=30){char up[40];int k=0;for(;t[k]&&k<39;k++)up[k]=toupper((unsigned char)t[k]);up[k]=0;
   for(int w=0;ct_named[w];w++)if(!strcmp(up,ct_named[w])){int u;if(ct_letters(t,&u)!=u&&!(isupper((unsigned char)t[0])))break;
    ct_ent x;memset(&x,0,sizeof x);x.page=page;x.kind=3;snprintf(x.name,sizeof x.name,"%s",t);ct_titlecase(x.name);e[(*ne)++]=x;return;}}
 }}
/* Longest increasing chain of numbered entries of one kind (choosing one candidate each). */
static int ct_chain(ct_ent *e,int ne,int kind){
 int idx[CT_MAXE],m=0;for(int i=0;i<ne;i++)if(e[i].kind==kind&&e[i].ncand)idx[m++]=i;
 static int score[CT_MAXE][3],from[CT_MAXE][3],fromc[CT_MAXE][3];int best=-1,bi=0,bc=0;
 for(int a=0;a<m;a++)for(int c=0;c<e[idx[a]].ncand;c++){int v=e[idx[a]].cand[c];score[a][c]=4+(v==1?1:0);from[a][c]=-1;
  for(int b=0;b<a;b++)for(int d=0;d<e[idx[b]].ncand;d++){int w=e[idx[b]].cand[d];if(w>=v||v-w>12)continue;int s=score[b][d]+4+(v-w==1?1:0)-(v-w>3?2:0);if(s>score[a][c]){score[a][c]=s;from[a][c]=b;fromc[a][c]=d;}}
  if(score[a][c]>best){best=score[a][c];bi=a;bc=c;}}
 int kept=0;if(best<0)return 0;
 for(int a=bi,c=bc;a>=0;){ct_ent *x=&e[idx[a]];x->keep=1;x->val=x->cand[c];x->roman=x->roman&&c==0;kept++;int na=from[a][c],nc=fromc[a][c];a=na;c=nc;}
 /* unknown-number entries sitting in a gap of the chain get the missing number */
 int prev=-1;for(int i=0;i<ne;i++){if(e[i].kind!=kind||!e[i].keep)continue;
  if(prev>=0){int unk[16],u=0;for(int j=prev+1;j<i&&u<16;j++)if(e[j].kind==kind&&!e[j].ncand)unk[u++]=j;
   if(u&&e[i].val-e[prev].val-1>=u&&e[i].val-e[prev].val-1==u)for(int q=0;q<u;q++){e[unk[q]].keep=1;e[unk[q]].val=e[prev].val+1+q;e[unk[q]].roman=e[prev].roman;kept++;}}
  prev=i;}
 return kept;}
static void ct_toroman(int v,char *o){static const int vals[]={100,90,50,40,10,9,5,4,1};static const char *sy[]={"C","XC","L","XL","X","IX","V","IV","I"};o[0]=0;for(int i=0;i<9;i++)while(v>=vals[i]){strcat(o,sy[i]);v-=vals[i];}}
static void *ct_worker(void *arg){
 (void)arg;setpriority(PRIO_PROCESS,(id_t)syscall(SYS_gettid),19);
 struct timespec t0,t1;clock_gettime(CLOCK_MONOTONIC,&t0);
 zr_doc *z=ct_reflow?zr_open_style(ct_path,ct_lw,ct_lh,ct_font,ct_margin,ct_spacing):zr_open(ct_path,ct_lw,ct_lh,ct_font,ct_margin);
 if(!z){ct_state=3;zr_ui_kick();return 0;}
 static ct_ent e[CT_MAXE];int ne=0;ct_line ls[12];int n=z->pages;ct_total=n;int failed=0;
 for(int p=0;p<n&&!ct_cancel;p++){
  fz_stext_page *st=NULL;fz_page *pg=NULL;fz_var(st);fz_var(pg);
  fz_try(z->ctx){pg=fz_load_page(z->ctx,z->doc,p);fz_rect bb=fz_bound_page(z->ctx,pg);st=fz_new_stext_page_from_page(z->ctx,pg,NULL);
   int k=ct_top_lines(st,ls,12,bb.y1-bb.y0);ct_page(p,ls,k,e,&ne);}
  fz_always(z->ctx){fz_drop_stext_page(z->ctx,st);fz_drop_page(z->ctx,pg);}
  fz_catch(z->ctx){failed++;}
  ct_done=p+1;if(p%25==0)zr_ui_kick();}
 int cancelled=ct_cancel;
 int ch=ct_chain(e,ne,1),parts=ct_chain(e,ne,2);if(ch<3){for(int i=0;i<ne;i++)if(e[i].kind==1)e[i].keep=0;ch=0;}
 if(parts<2||(parts<3&&!ch))for(int i=0;i<ne;i++)if(e[i].kind==2)e[i].keep=0,parts=0;
 int named=0;for(int i=0;i<ne;i++)if(e[i].kind==3){int dup=0;for(int j=0;j<i;j++)if(e[j].kind==3&&e[j].keep){size_t a=strlen(e[j].name),b=strlen(e[i].name);
   if(!strcasecmp(e[j].name,e[i].name))dup=1; /* running headers */
   else if(a>b&&!strcasecmp(e[j].name+a-b,e[i].name)&&e[i].page-e[j].page<=10)dup=1;} /* "Notes" right after "Chapter Notes" */
  e[i].keep=!dup;named+=!dup;}
 for(int kind=1;kind<=2;kind++){int r=0,d=0;for(int i=0;i<ne;i++)if(e[i].kind==kind&&e[i].keep){if(e[i].roman)r++;else d++;}
  for(int i=0;i<ne;i++)if(e[i].kind==kind&&e[i].keep)e[i].roman=r>d;} /* one numbering style per book */
 if(!ch&&!parts&&named<3)for(int i=0;i<ne;i++)e[i].keep=0,named=0;
 if(!cancelled){char tmp[1400];snprintf(tmp,sizeof tmp,"%s.tmp",ct_out);FILE *f=fopen(tmp,"w");int count=0;
  if(f){fprintf(f,"zrcontents\t1\n");for(int i=0;i<ne;i++){if(!e[i].keep)continue;char lab[160],num[16];
    if(e[i].kind==3)snprintf(lab,sizeof lab,"%s",e[i].name);
    else{if(e[i].roman)ct_toroman(e[i].val,num);else snprintf(num,sizeof num,"%d",e[i].val);
     snprintf(lab,sizeof lab,"%s %s%s%s",e[i].kind==1?"Chapter":"Part",num,e[i].title[0]?" \xc2\xb7 ":"",e[i].title);}
    fprintf(f,"%d\t%d\t%s\n",e[i].page,e[i].kind==1&&parts?1:0,lab);count++;}
   if(fclose(f)==0)rename(tmp,ct_out);else unlink(tmp);}
  ct_found=count;}
 fz_drop_document(z->ctx,z->doc);fz_drop_context(z->ctx);free(z);
 clock_gettime(CLOCK_MONOTONIC,&t1);ct_ms=(t1.tv_sec-t0.tv_sec)*1000.0+(t1.tv_nsec-t0.tv_nsec)/1e6;
 ct_state=cancelled?0:2;zr_ui_kick();return 0;}
int zr_contents_start(const char *path,const char *out,int reflow,float lw,float lh,float font,float margin,float spacing){
 if(ct_state==1)return -1;if(ct_started){pthread_join(ct_thread,0);ct_started=0;}
 snprintf(ct_path,sizeof ct_path,"%s",path);snprintf(ct_out,sizeof ct_out,"%s",out);ct_reflow=reflow;ct_lw=lw;ct_lh=lh;ct_font=font;ct_margin=margin;ct_spacing=spacing;
 ct_cancel=0;ct_done=0;ct_total=0;ct_found=0;ct_state=1;
 if(pthread_create(&ct_thread,0,ct_worker,0)){ct_state=3;return -1;}ct_started=1;return 0;}
int zr_contents_poll(int *done,int *total,int *found,int *ms){*done=ct_done;*total=ct_total;*found=ct_found;*ms=(int)ct_ms;return ct_state;}
void zr_contents_stop(void){if(!ct_started)return;ct_cancel=1;pthread_join(ct_thread,0);ct_started=0;ct_state=0;}
