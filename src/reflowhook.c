/* v0.12.0: reader glue for scanned-page reflow (src/reflow.c). Renders the page (or split half) region at
 * 150 dpi for analysis and 300 dpi for drawing, loads or builds the cached analysis, and lays out screen 1.
 * Returns 1 when out holds a reflow screen, 0 when the page should be shown as today (page view / spread),
 * <0 on error (caller keeps today's render). */
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>
#include "render.h"
#include "reflow.h"
#include <pthread.h>
/* Laid-out screens of the last few reflowed pages (keyed by cache path = book, page, half, scale), so a
 * screen step or a return to a prepared page only copies a screen. Shared by the render threads. */
#define MEMN 4
static struct { char key[512]; int w, h, n; rf_img *s; unsigned long used; } mem[MEMN];
static unsigned long mem_tick; static pthread_mutex_t mem_mtx=PTHREAD_MUTEX_INITIALIZER;
static int mem_get(const char *key, int w, int h, int screen, unsigned char *out, int stride, int *count, int *index){
  int hit=0; pthread_mutex_lock(&mem_mtx);
  for(int i=0;i<MEMN;i++) if(mem[i].n && mem[i].w==w && mem[i].h==h && !strcmp(mem[i].key,key)){
    int si= screen<0||screen>=mem[i].n ? mem[i].n-1 : screen;
    for(int y=0;y<h;y++) memcpy(out+(size_t)y*stride, mem[i].s[si].px+(size_t)y*w, w);
    *count=mem[i].n; *index=si; mem[i].used=++mem_tick; hit=1; break; }
  pthread_mutex_unlock(&mem_mtx); return hit; }
static void mem_put(const char *key, int w, int h, rf_result *r){   /* takes ownership of r's screens */
  pthread_mutex_lock(&mem_mtx); int v=0;
  for(int i=0;i<MEMN;i++){ if(!strcmp(mem[i].key,key)){ v=i; break; } if(mem[i].used<mem[v].used) v=i; }
  for(int i=0;i<mem[v].n;i++) free(mem[v].s[i].px); free(mem[v].s);
  snprintf(mem[v].key,sizeof mem[v].key,"%s",key); mem[v].w=w; mem[v].h=h; mem[v].n=r->nscreens; mem[v].s=r->screens; mem[v].used=++mem_tick;
  r->screens=0; r->nscreens=0; pthread_mutex_unlock(&mem_mtx); }
#include <stdio.h>
static int region(zr_doc *z, int page, const float *r, double dpi, rf_img *im){
  double s=dpi/72.0; im->w=(int)floor((r[2]-r[0])*s); im->h=(int)floor((r[3]-r[1])*s);
  if(im->w<16||im->h<16) return -1; im->px=malloc((size_t)im->w*im->h); if(!im->px) return -1;
  float m[6]={(float)s,0,0,(float)s,(float)(-r[0]*s),(float)(-r[1]*s)}; zr_render_stats st; memset(&st,0,sizeof st);
  if(zr_render_with_stats(z,page,m,im->px,im->w,im->h,im->w,0,0,&st)!=0){ free(im->px); im->px=0; return -1; }
  return 0; }
int zr_reflow_screen(zr_doc *z, int page, const float *r, int scale10, const char *cache, unsigned char *out, int w, int h, int stride, int screen, int *count, int *index){
  *count=0; *index=0;
  if(cache && mem_get(cache,w,h,screen,out,stride,count,index)) return 1;
  rf_analysis an; int have = cache && rf_load(&an,cache)==0 && fabs(an.scale-scale10/10.0)<1e-6;
  rf_img lo={0}, hi={0};
  if(!have){ if(have==0 && cache) {} if(region(z,page,r,150,&lo)) return -1;
    rf_analyse(&lo,scale10/10.0,w,&an); free(lo.px); if(cache) rf_save(&an,cache); }
  if(an.mode!=RF_REFLOW){ rf_analysis_free(&an); return 0; }
  if(region(z,page,r,300,&hi)){ rf_analysis_free(&an); return -1; }
  if(hi.w<an.w*2||hi.h<an.h*2){ free(hi.px); rf_analysis_free(&an); return -1; }
  rf_result res; rf_layout(&an,&hi,2,w,h,&res); free(hi.px); rf_analysis_free(&an);
  int ok= res.mode==RF_REFLOW && res.nscreens>0;
  int si= screen<0 || screen>=res.nscreens ? res.nscreens-1 : screen;   /* -1: last screen (coming back) */
  if(ok){ for(int y=0;y<h;y++) memcpy(out+(size_t)y*stride, res.screens[si].px+(size_t)y*w, w); *count=res.nscreens; *index=si; if(cache) mem_put(cache,w,h,&res); }
  rf_free(&res); return ok?1:0; }
int zr_reflow_mem(const char *cache, unsigned char *out, int w, int h, int stride, int screen, int *count, int *index){
  *count=0; *index=0; return mem_get(cache,w,h,screen,out,stride,count,index); }
