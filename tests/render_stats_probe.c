#include "render.h"
#include <stdio.h>
#include <stdlib.h>
#include <math.h>
static void save(const char *name,unsigned char *p) {
 FILE *f=fopen(name,"wb");fprintf(f,"P5 1272 1696 255\n");fwrite(p,1,1272*1696,f);fclose(f);
}
int main(int argc,char **argv) {
 if(argc!=4)return 2;
 zr_doc *z=zr_open(argv[1],305.28,407.04,9,18);if(!z)return 3;
 float r[4],m[6];if(zr_page_bounds(z,0,r))return 4;
 float s=fminf(1272/(r[2]-r[0]),1696/(r[3]-r[1]));
 m[0]=m[3]=s;m[1]=m[2]=0;m[4]=(1272-(r[2]-r[0])*s)/2-r[0]*s;m[5]=(1696-(r[3]-r[1])*s)/2-r[1]*s;
 unsigned char *p=malloc(1272*1696);zr_render_stats st;
 if(zr_render_with_stats(z,0,m,p,1272,1696,1272,0,0,&st))return 5;save(argv[2],p);
 printf("image_coverage=%g image_count=%d\n",st.image_coverage,st.image_count);
 if(zr_render_with_stats(z,0,m,p,1272,1696,1272,0,1,&st))return 6;save(argv[3],p);
 free(p);zr_close(z);return 0;
}
