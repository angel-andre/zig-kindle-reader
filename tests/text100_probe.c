/* v0.10.0: lay out an EPUB with a text style and print per-page lines, so tests can count
 * hyphenated line ends, pages, fonts. usage: probe book.epub mode font [pages] */
#include "render.h"
#include <mupdf/fitz.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
static unsigned char *slurp(const char *p,int *n){FILE*f=fopen(p,"rb");if(!f){*n=0;return NULL;}fseek(f,0,SEEK_END);long l=ftell(f);fseek(f,0,SEEK_SET);unsigned char*b=malloc(l);if(fread(b,1,l,f)!=(size_t)l){}fclose(f);*n=(int)l;return b;}
int main(int argc,char**argv){
 if(argc<4)return 2;int ln,rn,bn,in,bin;
 unsigned char*la=slurp(SRC"/hyph/la",&ln),*r=slurp(SRC"/fonts/NotoSans-Regular.otf",&rn),*b=slurp(SRC"/fonts/NotoSans-Bold-Latin.ttf",&bn),*i=slurp(SRC"/fonts/NotoSans-Italic-Latin.ttf",&in),*bi=slurp(SRC"/fonts/NotoSans-BoldItalic-Latin.ttf",&bin);
 zr_set_text_resources(la,ln,r,rn,b,bn,i,in,bi,bin);zr_set_text_style(atoi(argv[2]),atoi(argv[3]));
 float lw=1272*72.0f/300,lh=1696*72.0f/300;zr_doc*z=zr_open_style(argv[1],lw,lh,10.5f,18,1.4f);if(!z)return 1;
 int n=zr_page_count(z),maxp=argc>4?atoi(argv[4]):n;printf("pages\t%d\n",n);
 static zr_word w[8000];static char t[200000];
 for(int p=0;p<n&&p<maxp;p++){int k=zr_words(z,p,w,8000,t,sizeof t);int line=-1;
  for(int j=0;j<k;j++){if(w[j].line!=line){if(line>=0)putchar('\n');printf("%d\t",p);line=w[j].line;}else putchar(' ');fwrite(t+w[j].off,1,w[j].len,stdout);}
  if(line>=0)putchar('\n');}
 return 0;}
