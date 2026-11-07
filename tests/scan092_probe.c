/* v0.9.2 probe: render one page fit-to-screen with image flags; write PGM; report cleanup + time. */
#include "render.h"
#include <stdio.h>
#include <stdlib.h>
#include <math.h>
#include <time.h>
static double now(void){struct timespec t;clock_gettime(CLOCK_MONOTONIC,&t);return t.tv_sec*1e3+t.tv_nsec/1e6;}
extern int zr_mrc_debug;
int main(int argc,char **argv){
 zr_mrc_debug=getenv("ZRMRC")!=NULL;double first=0;
 if(argc<5)return 2;int page=atoi(argv[2]),flags=atoi(argv[3]),reps=argc>5?atoi(argv[5]):1;
 zr_doc *z=zr_open(argv[1],305.28,407.04,10.5,18);if(!z)return 3;
 float r[4],m[6];if(zr_page_bounds(z,page,r))return 4;
 float s=fminf(1272/(r[2]-r[0]),1696/(r[3]-r[1]));
 m[0]=m[3]=s;m[1]=m[2]=0;m[4]=(1272-(r[2]-r[0])*s)/2-r[0]*s;m[5]=(1696-(r[3]-r[1])*s)/2-r[1]*s;
 unsigned char *p=malloc(1272*1696);zr_render_stats st;double best=1e9;
 for(int i=0;i<reps;i++){double t=now();if(zr_render_with_stats(z,page,m,p,1272,1696,1272,0,flags,&st))return 5;t=now()-t;if(!i)first=t;if(t<best)best=t;}
 FILE *f=fopen(argv[4],"wb");fprintf(f,"P5 1272 1696 255\n");fwrite(p,1,1272*1696,f);fclose(f);
 printf("cleaned=%d image_count=%d coverage=%.3f best_ms=%.2f first_ms=%.2f\n",st.cleaned,st.image_count,st.image_coverage,best,first);
 free(p);zr_close(z);return 0;}
