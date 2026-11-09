/* Host harness: rfhost LO.pgm HI.pgm K SCALE OUTPREFIX -> mode/reason, screens as OUTPREFIX_NN.pgm */
#include "../reflow.h"
#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#ifndef CLOCK_MONOTONIC
#define CLOCK_MONOTONIC 1
#endif
static int rd(const char*f, rf_img*m){ FILE*p=fopen(f,"rb"); if(!p) return -1; int mx; if(fscanf(p,"P5 %d %d %d",&m->w,&m->h,&mx)!=3) return -1; fgetc(p); m->px=malloc((size_t)m->w*m->h); fread(m->px,1,(size_t)m->w*m->h,p); fclose(p); return 0; }
int main(int c,char**v){ rf_img lo,hi; if(c<6||rd(v[1],&lo)||rd(v[2],&hi)) return 2;
  struct timespec t0,t1; clock_gettime(CLOCK_MONOTONIC,&t0); rf_result r; rf_reflow(&lo,&hi,atoi(v[3]),atof(v[4]),1264,1680,&r); clock_gettime(CLOCK_MONOTONIC,&t1);
  static const char *mn[]={"reflow","page","spread"};
  printf("%s %s %d %.1f\n", mn[r.mode], r.reason, r.nscreens, (t1.tv_sec-t0.tv_sec)*1e3+(t1.tv_nsec-t0.tv_nsec)/1e6);
  for(int i=0;i<r.nscreens;i++){ char fn[512]; snprintf(fn,sizeof fn,"%s_%02d.pgm",v[5],i+1); FILE*o=fopen(fn,"wb"); fprintf(o,"P5\n%d %d\n255\n",r.screens[i].w,r.screens[i].h); fwrite(r.screens[i].px,1,(size_t)r.screens[i].w*r.screens[i].h,o); fclose(o); }
  rf_free(&r); return 0; }
