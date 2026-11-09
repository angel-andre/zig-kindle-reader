/* Host probe for the v0.12.0 reflow hook: probe PDF PAGE(1-based) L|R|F SCALE10 OUT.pgm. Prints the outcome
 * and writes what the reader would show: the reflow screen, or today's fitted page/half. */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include "render.h"
int zr_reflow_screen(zr_doc *z, int page, const float *r, int scale10, const char *cache, unsigned char *out, int w, int h, int stride, int screen, int *count, int *index);
int main(int c, char **v){
  if(c<6) return 2; const int W=1264,H=1680; zr_doc *z=zr_open(v[1],W,H,10.5f,18); if(!z) return 3;
  int p=atoi(v[2])-1; float r[4]; zr_page_bounds(z,p,r);
  if(v[3][0]!='F'){ float xs=(r[0]+r[2])/2; if(v[3][0]=='L') r[2]=xs; else r[0]=xs; }
  unsigned char *buf=malloc((size_t)W*H); memset(buf,255,(size_t)W*H);
  int cnt=0,idx=0; int rc=zr_reflow_screen(z,p,r,atoi(v[4]),"/tmp/probe.rf",buf,W,H,W,c>6?atoi(v[6]):0,&cnt,&idx); remove("/tmp/probe.rf");
  if(rc!=1){ float s=W/(r[2]-r[0]); if(H/(r[3]-r[1])<s) s=H/(r[3]-r[1]); float m[6]={s,0,0,s,-r[0]*s+(W-(r[2]-r[0])*s)/2,-r[1]*s+(H-(r[3]-r[1])*s)/2};
    zr_render_stats st; zr_render_with_stats(z,p,m,buf,W,H,W,0,0,&st); }
  printf("page %s%s screen %d/%d: %s\n",v[2],v[3],idx+1,cnt,rc==1?"reflow screen 1":rc==0?"today's view (page view / spread)":"error -> today's view");
  FILE *f=fopen(v[5],"wb"); fprintf(f,"P5\n%d %d\n255\n",W,H); fwrite(buf,1,(size_t)W*H,f); fclose(f); return 0; }
