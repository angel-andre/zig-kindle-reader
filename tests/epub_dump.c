#include "render.h"
#include <stdio.h>
#include <stdlib.h>
static zr_word words[12000]; static char text[262144];
int main(int argc,char**argv){
 if(argc!=7)return 1;float f=atof(argv[2]),space=atof(argv[3]),margin=atof(argv[4]);int styled=atoi(argv[5]),page=atoi(argv[6]);
 zr_doc*z=zr_open(argv[1],1272.f*72/300,1696.f*72/300,f,margin);if(!z)return 2;
 if(styled){zr_set_spacing(z,space);zr_relayout(z,1272.f*72/300,1696.f*72/300,f,margin,0);}
 float r[4];zr_page_bounds(z,page,r);printf("META\t%d\t%g\t%g\t%g\t%g\n",zr_page_count(z),r[0],r[1],r[2],r[3]);
 int n=zr_words(z,page,words,12000,text,sizeof text);
 for(int i=0;i<n;i++){zr_anchor a={-1,0,0,0};zr_anchor_words(z,page,i,i,&a);zr_word*w=words+i;printf("%d\t%g\t%g\t%g\t%g\t%d\t%d\t%u\t%u\t%016llx\t%.*s\n",i,w->x0,w->y0,w->x1,w->y1,w->line,a.chapter,a.start,a.end,(unsigned long long)a.hash,w->len,text+w->off);}
 zr_close(z);return 0;
}
