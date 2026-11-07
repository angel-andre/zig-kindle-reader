/* Compact read-only WordNet lookup, sorted on-disk keys + shared gloss offsets.
 * UI thread only; mmap is lazy, bounded to 40 MiB, never loaded by workers. */
#include "dictionary.h"
#include <stdint.h>
#include <stddef.h>
#include <string.h>
#include <stdio.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <fcntl.h>
#include <unistd.h>
static const unsigned char *db;
static size_t size;
static uint32_t count, io, ko, ro, go;
static uint32_t u32(const unsigned char *p) { return (uint32_t)p[0] | (uint32_t)p[1]<<8 | (uint32_t)p[2]<<16 | (uint32_t)p[3]<<24; }
static unsigned u16(const unsigned char *p) { return p[0] | (unsigned)p[1]<<8; }
void zrd_close(void) { if (db) munmap((void*)db,size); db=NULL;size=0;count=0; }
static int compare(const char *a,size_t an,const unsigned char *b,size_t bn) {
 size_t n=an<bn?an:bn;int c=memcmp(a,b,n);return c?c:an<bn?-1:an>bn?1:0;
}
int zrd_open(const char *path) {
 zrd_close();int fd=open(path,O_RDONLY);if(fd<0)return 0;struct stat st;
 if(fstat(fd,&st)||!S_ISREG(st.st_mode)||st.st_size<32||st.st_size>40*1024*1024){close(fd);return 0;}
 size=st.st_size;void *m=mmap(NULL,size,PROT_READ,MAP_PRIVATE,fd,0);close(fd);if(m==MAP_FAILED){size=0;return 0;}db=m;
 if(memcmp(db,"ZRWN3001",8))goto bad;
 count=u32(db+8);io=u32(db+12);ko=u32(db+16);ro=u32(db+20);go=u32(db+24);
 if(!count||count>500000||io!=32||(size_t)count*16+io!=ko||ko>ro||ro>go||go>=size||u32(db+28)!=size)goto bad;
 const unsigned char *prev=NULL;unsigned prevn=0;
 for(uint32_t i=0;i<count;i++) {
  const unsigned char *r=db+io+(size_t)i*16;uint32_t k=u32(r),ref=u32(r+8);unsigned n=u16(r+4),nr=u16(r+6);
  if(!n||n>=256||!nr||u32(r+12)||k>ro-ko||n>ro-ko-k||ref>go-ro||(size_t)nr*4>go-ro-ref)goto bad;
  const unsigned char *key=db+ko+k;if(prev&&compare((const char*)prev,prevn,key,n)>=0)goto bad;prev=key;prevn=n;
  for(unsigned j=0;j<nr;j++)if(u32(db+ro+ref+j*4)>=size-go)goto bad;
 }
 return 1;
 bad:zrd_close();return 0;
}
static const unsigned char *find(const char *key) {
 size_t len=strlen(key);uint32_t lo=0,hi=count;
 while(lo<hi){uint32_t mid=lo+(hi-lo)/2;const unsigned char*r=db+io+(size_t)mid*16;
 int c=compare(key,len,db+ko+u32(r),u16(r+4));if(!c)return r;if(c<0)hi=mid;else lo=mid+1;}
 return NULL;
}
static int letters(int c) { return (c>='a'&&c<='z')||(c>='A'&&c<='Z')||(c>='0'&&c<='9'); }
static int norm(const char*s,int len,char*out) {
 int first=0,last=len;while(first<last&&!letters((unsigned char)s[first]))first++;
 while(last>first&&!letters((unsigned char)s[last-1])&&(unsigned char)s[last-1]<128)last--;
 int n=0;for(int i=first;i<last;i++){
  unsigned char c=s[i];if(c==0xe2&&i+2<last&&(unsigned char)s[i+1]==0x80&&((unsigned char)s[i+2]==0x99||(unsigned char)s[i+2]==0x98)){c='\'';i+=2;}
  if(c==0xc3&&i+1<last){unsigned char t=s[i+1];if(t>=0x80&&t<=0x9e)t+=0x20;unsigned char mapped=0;if(t>=0xa0&&t<=0xa5)mapped='a';else if(t==0xa7)mapped='c';else if(t>=0xa8&&t<=0xab)mapped='e';else if(t>=0xac&&t<=0xaf)mapped='i';else if(t==0xb1)mapped='n';else if((t>=0xb2&&t<=0xb6)||t==0xb8)mapped='o';else if(t>=0xb9&&t<=0xbc)mapped='u';else if(t==0xbd||t==0xbf)mapped='y';if(mapped){c=mapped;i++;}}
  if(c>='A'&&c<='Z')c+=32;if(n>=127)return 0;out[n++]=c;
 }
 while(n&&!letters((unsigned char)out[n-1]))n--;
 out[n]=0;if(n>2&&out[n-2]=='\''&&out[n-1]=='s'){n-=2;out[n]=0;}return n;
}
static const unsigned char *candidate(char *key,const char *base,int keep,const char *suffix) {
 if(keep<1||(size_t)keep+strlen(suffix)>=128)return NULL;memcpy(key,base,keep);strcpy(key+keep,suffix);return find(key);
}
int zrd_define(const char*word,int len,char*lemma,int lemma_cap,char*out,int cap) {
 if(!lemma||lemma_cap<1||!out||cap<1)return -1;lemma[0]=out[0]=0;
 if(!db)return -1;if(!word||len<=0||len>4096)return 0;
 char key[128],base[128];int n=norm(word,len,key);if(!n)return 0;strcpy(base,key);
 const unsigned char *r=find(key);
 if(!r) {
  static const char *exceptions[][2]={{"children","child"},{"mice","mouse"},{"men","man"},{"women","woman"},{"teeth","tooth"},{"feet","foot"},{"geese","goose"},{"went","go"},{"gone","go"},{"was","be"},{"were","be"},{"is","be"},{"are","be"},{"has","have"},{"had","have"},{"did","do"},{"done","do"}};
  for(unsigned i=0;i<sizeof exceptions/sizeof*exceptions&&!r;i++)if(!strcmp(base,exceptions[i][0])){strcpy(key,exceptions[i][1]);r=find(key);}
 }
 #define TRY(keep,suffix) do { if(!r)r=candidate(key,base,(keep),(suffix)); } while(0)
 if(!r&&n>4&&!strcmp(base+n-3,"ies"))TRY(n-3,"y");
 if(!r&&n>4&&!strcmp(base+n-3,"ves")){TRY(n-3,"f");TRY(n-3,"fe");}
 if(!r&&n>3&&!strcmp(base+n-2,"es")){TRY(n-2,"");TRY(n-1,"");}
 if(!r&&n>2&&base[n-1]=='s'&&base[n-2]!='s')TRY(n-1,"");
 if(!r&&n>4&&!strcmp(base+n-3,"ied"))TRY(n-3,"y");
 if(!r&&n>3&&!strcmp(base+n-2,"ed")){TRY(n-1,"");TRY(n-2,"");if(n>4&&base[n-3]==base[n-4])TRY(n-3,"");}
 if(!r&&n>4&&!strcmp(base+n-3,"ing")){TRY(n-3,"");TRY(n-3,"e");if(n>5&&base[n-4]==base[n-5])TRY(n-4,"");}
 #undef TRY
 if(!r){snprintf(lemma,lemma_cap,"%s",base);return 0;}
 snprintf(lemma,lemma_cap,"%s",key);unsigned nr=u16(r+6);uint32_t ref=u32(r+8);int used=0;
 for(unsigned i=0;i<nr;i++) {
  const unsigned char *p=db+go+u32(db+ro+ref+i*4);size_t remain=size-(size_t)(p-db);if(remain>8192)remain=8192;
  const unsigned char *end=memchr(p,0,remain);if(!end)continue;size_t length=end-p;
  if(length+(used?2:0)+(size_t)used>=(size_t)cap){const char*t="\n\n[Additional senses omitted.]";if(used+(int)strlen(t)<cap){strcpy(out+used,t);used+=strlen(t);}break;}
  if(used){out[used++]='\n';out[used++]='\n';}memcpy(out+used,p,length);used+=length;out[used]=0;
 }
 return used;
}
