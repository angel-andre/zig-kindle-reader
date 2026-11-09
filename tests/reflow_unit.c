/* Unit tests for src/reflow.c: analysis/layout split and the cache file. Usage: reflow_unit LO.pgm HI.pgm */
#include "../src/reflow.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
static int rd(const char*f, rf_img*m){ FILE*p=fopen(f,"rb"); if(!p) return -1; int mx; if(fscanf(p,"P5 %d %d %d",&m->w,&m->h,&mx)!=3) return -1; fgetc(p); m->px=malloc((size_t)m->w*m->h); if(fread(m->px,1,(size_t)m->w*m->h,p)!=(size_t)m->w*m->h) return -1; fclose(p); return 0; }
static int fails=0, n=0;
#define CHECK(c,msg) do{ n++; if(!(c)){ fails++; printf("FAIL %s\n",msg);} else printf("ok   %s\n",msg); }while(0)
int main(int c,char**v){
  rf_img lo,hi; if(c<3||rd(v[1],&lo)||rd(v[2],&hi)) { printf("usage\n"); return 2; }
  for(int si=0;si<2;si++){ double sc=si?2.0:1.5;
    rf_result a,b; rf_reflow(&lo,&hi,2,sc,1264,1680,&a);
    rf_analysis an; rf_analyse(&lo,sc,1264,&an);
    CHECK(rf_save(&an,"/tmp/rf_unit.rf")==0,"save cache");
    rf_analysis ld; CHECK(rf_load(&ld,"/tmp/rf_unit.rf")==0,"load cache");
    CHECK(ld.mode==an.mode && ld.nu==an.nu && !strcmp(ld.reason,an.reason),"cache header round-trip");
    int same=1; for(int i=0;i<an.nu&&same;i++){ rf_unit *x=&an.u[i],*y=&ld.u[i]; same= x->fig==y->fig&&x->a==y->a&&x->b==y->b&&x->x0==y->x0&&x->x1==y->x1&&x->cut==y->cut&&x->bl==y->bl&&x->nw==y->nw&&x->para==y->para&&x->indent==y->indent&&x->foot==y->foot; for(int j=0;same&&j<x->nw;j++) same= x->w[j].a==y->w[j].a&&x->w[j].b==y->w[j].b&&x->w[j].last==y->w[j].last; }
    CHECK(same,"cache units round-trip");
    rf_layout(&ld,&hi,2,1264,1680,&b);
    int eq= a.mode==b.mode && a.nscreens==b.nscreens; for(int i=0;eq&&i<a.nscreens;i++) eq=!memcmp(a.screens[i].px,b.screens[i].px,1264*1680);
    CHECK(eq,"layout from cache == direct reflow (pixel-identical)");
    printf("     scale %.1f: mode %d %s, %d screens\n",sc,a.mode,a.reason,a.nscreens);
    rf_free(&a); rf_free(&b); rf_analysis_free(&an); rf_analysis_free(&ld); }
  FILE *f=fopen("/tmp/rf_bad.rf","wb"); fwrite("ZRF1\x07\0\0\0",1,8,f); fclose(f);
  rf_analysis bad; CHECK(rf_load(&bad,"/tmp/rf_bad.rf")==-1,"corrupt cache rejected");
  CHECK(rf_load(&bad,"/tmp/does-not-exist.rf")==-1,"missing cache rejected");
  printf("%d/%d passed\n",n-fails,n); return fails?1:0; }
