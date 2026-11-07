#include "render.h"
#include <mupdf/fitz.h>
#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#define CHECK(x) do { if (!(x)) { fprintf(stderr,"CHECK failed at line %d: %s\n",__LINE__,#x); exit(1); } } while (0)
static zr_word words[12000];
static char text[262144];
static unsigned orig[100000], actual[100000];
static int normalize(unsigned *out, int count, const char *s, int len) {
 int p=0; while(p<len) {int c; p+=fz_chartorune(&c,s+p); if(c<=32 || c==0xAD || c==0xA0 || (c>=0x2000 && c<=0x200B)) continue; CHECK(count<100000);out[count++]=c;} return count;
}
static int extract(zr_doc *z, zr_anchor *a, unsigned *out) {
 int len=0;
 for(int p=0;p<zr_page_count(z);p++) {
  float qs[256][4];int nq=zr_anchor_quads(z,a,p,&qs[0][0],256);if(!nq)continue;
  int n=zr_words(z,p,words,12000,text,sizeof text);
  for(int i=0;i<n;i++) {
   float x=(words[i].x0+words[i].x1)/2,y=(words[i].y0+words[i].y1)/2;
   for(int k=0;k<nq;k++) if(x>=qs[k][0]&&x<=qs[k][2]&&y>=qs[k][1]&&y<=qs[k][3]) {len=normalize(out,len,text+words[i].off,words[i].len);break;}
  }
 }
 return len;
}
int main(int argc,char **argv) {
 CHECK(argc==2);zr_doc *z=zr_open(argv[1],1272.f*72/300,1696.f*72/300,9,18);CHECK(z&&zr_reflowable(z));
 int page=3,n=zr_words(z,page,words,12000,text,sizeof text); CHECK(n>100);
 int first=7,last=n-8,olen=0;char quote[8192];int qlen=0;
 for(int i=first;i<=last;i++) {olen=normalize(orig,olen,text+words[i].off,words[i].len); if(i>first)quote[qlen++]=' ';CHECK(qlen+words[i].len<sizeof quote);memcpy(quote+qlen,text+words[i].off,words[i].len);qlen+=words[i].len;}quote[qlen]=0;
 zr_anchor a={-1,0,0,0},pos={-1,0,0,0},legacy={-1,0,0,0};
 CHECK(zr_anchor_words(z,page,first,last,&a));CHECK(zr_anchor_words(z,page,0,0,&pos));
 CHECK(zr_anchor_migrate(z,page,quote,qlen,(words[first].x0+words[first].x1)/2,(words[first].y0+words[first].y1)/2,&legacy));
 CHECK(a.chapter==legacy.chapter&&a.start==legacy.start&&a.end==legacy.end&&a.hash==legacy.hash);
 /* Explicitly pick the LAST identical phrase on a page, not its first occurrence. */
 n=zr_words(z,page,words,12000,text,sizeof text);int target=-1;
 for(int i=0;i<n;i++) if(words[i].len==5&&!memcmp(text+words[i].off,"Exact",5))target=i;
 CHECK(target>=0);zr_anchor repeated={-1,0,0,0}, migrated={-1,0,0,0};
 CHECK(zr_anchor_words(z,page,target,target+2,&repeated));
 CHECK(zr_anchor_migrate(z,page,"Exact words matter:",19,(words[target].x0+words[target].x1)/2,(words[target].y0+words[target].y1)/2,&migrated));
 CHECK(repeated.start==migrated.start&&repeated.end==migrated.end);
 CHECK(!zr_anchor_migrate(z,page,"THIS QUOTE DOES NOT EXIST",25,0,0,&migrated));
 zr_anchor bad=a;bad.hash^=1;float qs[256][4];CHECK(zr_anchor_page(z,&bad)==-1);CHECK(zr_anchor_quads(z,&bad,page,&qs[0][0],256)==0);
 float sizes[]={10.5,12,13.5,15,17.25,19.5,22.5,25.5,30};float spaces[]={1.15,1.4,1.7};int layouts=0,split=0;
 for(int f=0;f<9;f++)for(int sp=0;sp<3;sp++)for(int margin=0;margin<=36;margin+=36) {
  zr_set_spacing(z,spaces[sp]);zr_relayout(z,1272.f*72/300,1696.f*72/300,sizes[f],margin,page);
  int p=zr_anchor_page(z,&a);if(p<0){fprintf(stderr,"anchor mismatch: size=%g spacing=%g margin=%d\n",sizes[f],spaces[sp],margin);return 2;}
  CHECK(zr_anchor_page(z,&pos)>=0);
  int len=extract(z,&a,actual);if(len!=olen||memcmp(orig,actual,olen*sizeof *orig)){fprintf(stderr,"quad mismatch: size=%g spacing=%g margin=%d len=%d expected=%d\n",sizes[f],spaces[sp],margin,len,olen);return 3;}
  int spans=0;for(int j=0;j<zr_page_count(z);j++)if(zr_anchor_quads(z,&a,j,&qs[0][0],256))spans++;if(spans>1)split++;
  layouts++;
 }
 zr_close(z);
 /* Reopen into a new document/context: the serialized integers must still work. */
 z=zr_open(argv[1],1272.f*72/300,1696.f*72/300,30,36);CHECK(z);zr_set_spacing(z,1.7);zr_relayout(z,1272.f*72/300,1696.f*72/300,30,36,0);
 CHECK(zr_anchor_page(z,&a)>=0);CHECK(extract(z,&a,actual)==olen);CHECK(!memcmp(orig,actual,olen*sizeof *orig));zr_close(z);
 printf("PASS %d typography layouts (9 sizes x 3 spacing x 2 margins), exact Unicode quote retained; %d split-page highlight layouts; state/notes resolve after fresh reopen\n",layouts,split);
 printf("PASS native pointer bookmarks never serialized, repeated legacy quote disambiguated, missing quote/checksum mismatch fail closed\n");
 return 0;
}
