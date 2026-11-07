#include "render.h"
#include <stdio.h>
#include <stdlib.h>
#include <math.h>
int main(int argc,char **argv) {
 if(argc<4) return 2;
 zr_doc *z=zr_open(argv[1],432,576,9,18); if(!z)return 3;
 int page=atoi(argv[2])-1; float r[4],m[6];
 if(argc>4)zr_page_bounds(z,page,r);else zr_ink_bbox(z,page,r,0);
 float s=fminf(1272/(r[2]-r[0]),1696/(r[3]-r[1]));
 m[0]=s;m[1]=m[2]=0;m[3]=s;m[4]=(1272-(r[2]-r[0])*s)/2-r[0]*s;m[5]=(1696-(r[3]-r[1])*s)/2-r[1]*s;
 printf("bounds %g %g %g %g\nmatrix %g %g %g %g %g %g\n",r[0],r[1],r[2],r[3],m[0],m[1],m[2],m[3],m[4],m[5]);
 unsigned char *pixels=malloc(1272*1696);zr_render(z,page,m,pixels,1272,1696,1272,0);
 FILE *f=fopen(argv[3],"wb");fprintf(f,"P5 1272 1696 255\n");fwrite(pixels,1,1272*1696,f);fclose(f);free(pixels);
 zr_word words[8192];char text[262144];int n=zr_words(z,page,words,8192,text,sizeof text);
 for(int i=0;i<n;i++){zr_word *w=words+i;printf("%d\t%d\t%.3f\t%.3f\t%.3f\t%.3f\t%d\t%d\t%.*s\n",i,w->line,w->x0,w->y0,w->x1,w->y1,(int)roundf((w->x0+w->x1)*s/2+m[4]),(int)roundf((w->y0+w->y1)*s/2+m[5]),w->len,text+w->off);}
 zr_close(z);return 0;
}
