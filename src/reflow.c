/* Scanned-page reflow, port of the reflow prototype v14. See reflow.h. */
#include "reflow.h"
#include <stdlib.h>
#include <string.h>
#define _USE_MATH_DEFINES
#include <math.h>
#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif
#include <stdio.h>

typedef struct { int a, b; } span;
typedef struct { int fig, a, b, x0, x1, h, foot, nw; span *w; } item;

static int cmpd(const void *x, const void *y){ double a=*(const double*)x,b=*(const double*)y; return a<b?-1:a>b; }
static double pct(double *v, int n, double p){ if(n<=0) return 0; qsort(v,n,sizeof(double),cmpd);
  double r=(n-1)*p/100.0; int i=(int)r; double f=r-i; return i+1<n? v[i]*(1-f)+v[i+1]*f : v[i]; }
static double median(double *v,int n){ return pct(v,n,50); }
/* runs of true values; a gap > mingap blank cells splits runs */
static int runs(const uint8_t *m, int n, int mingap, span *out, int maxo){
  int k=0, s=-1, p=-1;
  for(int i=0;i<n;i++) if(m[i]){ if(s<0){s=p=i;continue;} if(i-p-1>mingap){ if(k<maxo) out[k++]=(span){s,p+1}; s=i;} p=i; }
  if(s>=0 && k<maxo) out[k++]=(span){s,p+1};
  return k;
}
typedef struct { int W,H; float *g; uint8_t *ink,*soft,*grey,*sg,*nf; } page;
#define AT(m,y,x) (m)[(size_t)(y)*P->W+(x)]

/* exact 90th percentile of an 8-bit image via histogram (numpy 'linear' interpolation) */
static double pct90_u8(const uint8_t *px, size_t n){
  size_t h[256]={0}; for(size_t i=0;i<n;i++) h[px[i]]++;
  double r=(n-1)*0.9; size_t lo=(size_t)r; double f=r-lo; size_t c=0; int vlo=-1,vhi=-1;
  for(int v=0;v<256;v++){ c+=h[v]; if(vlo<0 && c>lo) vlo=v; if(c>lo+1){ vhi=v; break; } }
  if(vhi<0) vhi=vlo; return vlo*(1-f)+vhi*f; }
static void norm_page(page *P, const rf_img *lo){
  int n=P->W*P->H; double bg=pct90_u8(lo->px,n); if(bg<120) bg=120;
  for(int i=0;i<n;i++){ float x=lo->px[i]*(255.0f/(float)bg); P->g[i]=x>255?255:x; }
}

typedef struct { item *it; int n; double lh, mp, xh, share; int left,right,nlines; } analysis;

static int analyse(page *P, analysis *A){
  int W=P->W,H=P->H; uint8_t *ink=P->ink;
  for(int i=0;i<W*H;i++){ float x=P->g[i]; ink[i]=x<150; P->grey[i]=x>60&&x<200; P->soft[i]=x<200; }
  /* drop mostly-ink columns/rows (edge shadows) */
  for(int x=0;x<W;x++){ int c=0; for(int y=0;y<H;y++) c+=AT(ink,y,x); if(c>0.5*H && (x<(int)(0.08*W) || x>=W-(int)(0.08*W))) for(int y=0;y<H;y++) AT(ink,y,x)=0; }
  int *prof=calloc(H,sizeof(int));
  for(int y=0;y<H;y++){ int c=0; for(int x=0;x<W;x++) c+=AT(ink,y,x); if(c>0.5*W && (y<(int)(0.08*H) || y>=H-(int)(0.08*H))){ for(int x=0;x<W;x++) AT(ink,y,x)=0; c=0;} prof[y]=c; }
  uint8_t *pm=malloc(H); for(int y=0;y<H;y++) pm[y]=prof[y]>=2;
  int MAXR=H+1; span *rows=malloc(sizeof(span)*MAXR); int nr0=runs(pm,H,0,rows,MAXR), nr=0;
  for(int i=0;i<nr0;i++) if(rows[i].b-rows[i].a>=3) rows[nr++]=rows[i];
  if(!nr){ free(prof);free(pm);free(rows); return 0; }
  double *dv=malloc(sizeof(double)*(MAXR+W+H+16)); 
  for(int i=0;i<nr;i++) dv[i]=rows[i].b-rows[i].a; double lh=median(dv,nr);
  /* split touching lines */
  span *rr=malloc(sizeof(span)*MAXR); int nrr=0;
  for(int i=0;i<nr;i++){ int a=rows[i].a,b=rows[i].b; long gs=0,is=0; 
    for(int y=a;y<b;y++) for(int x=0;x<W;x++){ gs+=AT(P->grey,y,x); is+=AT(ink,y,x);} 
    double gm=(double)gs/((b-a)*W), im=(double)is/((b-a)*W);
    if(b-a>1.8*lh && gm<0.3 && im<0.4){
      for(int y=a;y<b;y++) dv[y-a]=prof[y]; double p90=pct(dv,b-a,90); double th=fmax(2,0.12*p90);
      for(int y=a;y<b;y++) pm[y-a]=prof[y]>=th; span *sub=malloc(sizeof(span)*(b-a+1)); int ns0=runs(pm,b-a,0,sub,b-a+1),ns=0,mx=0;
      for(int j=0;j<ns0;j++) if(sub[j].b-sub[j].a>=3){ sub[ns++]=sub[j]; if(sub[j].b-sub[j].a>mx) mx=sub[j].b-sub[j].a; }
      if(ns>1 && mx<1.8*lh){ for(int j=0;j<ns&&nrr<MAXR;j++) rr[nrr++]=(span){a+sub[j].a,a+sub[j].b}; free(sub); continue; }
      free(sub);
    }
    if(nrr<MAXR) rr[nrr++]=(span){a,b};
  }
  for(int i=0;i<nrr;i++) dv[i]=rr[i].b-rr[i].a; double lh0=median(dv,nrr);
  /* merge tiny fragment rows into the nearest line */
  uint8_t *skip=calloc(MAXR,1); int changed=1;
  while(changed && nrr>1){ changed=0;
    for(int i=0;i<nrr;i++){ int a=rr[i].a,b=rr[i].b; if(!(b-a<0.5*lh0) || skip[i]) continue;
      int cx0=-1,cx1=-1; for(int x=0;x<W;x++){ int any=0; for(int y=a;y<b;y++) if(AT(ink,y,x)){any=1;break;} if(any){ if(cx0<0)cx0=x; cx1=x; } }
      if(cx0>=0 && cx1-cx0>2.5*lh0){ skip[i]=1; continue; }
      double gp=i>0? a-rr[i-1].b:1e9, gn=i+1<nrr? rr[i+1].a-b:1e9;
      if(fmin(gp,gn)>1.2*lh0){ skip[i]=1; continue; }
      int j=gp<=gn? i-1:i+1; int na=rr[j].a<a?rr[j].a:a, nb=rr[j].b>b?rr[j].b:b;
      if(nb-na>1.6*lh0){ skip[i]=1; continue; }
      rr[j]=(span){na,nb}; memmove(&rr[i],&rr[i+1],sizeof(span)*(nrr-i-1)); memmove(&skip[i],&skip[i+1],nrr-i-1); nrr--; changed=1; break; }
  }
  for(int i=0;i<nrr;i++) dv[i]=rr[i].b-rr[i].a; lh=median(dv,nrr);
  item *its=calloc(nrr,sizeof(item)); int ni=0;
  uint8_t *cm=malloc(W), *sm=malloc(W); span *xr=malloc(sizeof(span)*W), *sx=malloc(sizeof(span)*W);
  for(int i=0;i<nrr;i++){ int a=rr[i].a,b=rr[i].b,h=b-a;
    for(int x=0;x<W;x++){ cm[x]=0; sm[x]=0; for(int y=a;y<b;y++){ if(AT(ink,y,x)) cm[x]=1; if(AT(P->soft,y,x)) sm[x]=1; } }
    int nx=runs(cm,W,0,xr,W); if(!nx) continue;
    int ns=runs(sm,W,0,sx,W), k=0;
    for(int j=0;j<ns;j++) if(sx[j].b>xr[0].a-3*lh && sx[j].a<xr[nx-1].b+3*lh) sx[k++]=sx[j];
    if(!k){ memcpy(sx,xr,sizeof(span)*nx); k=nx; } ns=k;
    int x0=xr[0].a<sx[0].a?xr[0].a:sx[0].a, x1=xr[nx-1].b>sx[ns-1].b?xr[nx-1].b:sx[ns-1].b;
    long di=0,dg=0; for(int y=a;y<b;y++) for(int x=x0;x<x1;x++){ di+=AT(ink,y,x); dg+=AT(P->grey,y,x);} 
    double dens=(double)di/(h*(x1-x0)), gfr=(double)dg/(h*(x1-x0));
    double thr=lh; if(ns>1){ for(int j=0;j+1<ns;j++) dv[j]=sx[j+1].a-sx[j].b; double md=median(dv,ns-1); thr=fmin(fmax(2.5*md,0.4*lh),0.65*lh); }
    int *cuts=malloc(sizeof(int)*(ns+2)), nc=0; cuts[nc++]=x0; for(int j=0;j+1<ns;j++) if(sx[j+1].a-sx[j].b>thr) cuts[nc++]=(sx[j].b+sx[j+1].a)/2; cuts[nc++]=x1;
    span *w=malloc(sizeof(span)*nc); int nw=0;
    for(int j=0;j+1<nc;j++){ int u=cuts[j],v=cuts[j+1],f=-1,l=-1; for(int x=u;x<v;x++){ int any=0; for(int y=a;y<b;y++) if(AT(P->soft,y,x)){any=1;break;} if(any){ if(f<0)f=x; l=x; } } if(f>=0) w[nw++]=(span){f,l+1}; }
    for(int j=0;j<nw;j++) dv[j]=w[j].b-w[j].a; double mw=nw?median(dv,nw):0;
    int symbol= nw<=6 && h>1.6*lh && mw>1.5*h;
    free(cuts);
    int fig= h>2.2*lh || (dens>0.4&&h>1.6*lh) || (gfr>0.3&&h>1.6*lh) || symbol || (h>1.6*lh && nw<=4);
    its[ni++]=(item){fig,a,b,x0,x1,h,0,nw,w};
  }
  free(cm);free(sm);free(xr);free(sx);free(skip);free(rr);free(rows);free(pm);free(prof);
  /* group figure rows (+ label lines sandwiched between figure rows) */
  item *out=calloc(ni,sizeof(item)); int no=0;
  for(int i=0;i<ni;){ item it=its[i]; if(!it.fig){ out[no++]=it; i++; continue; }
    item g0=it; int j=i+1;
    while(j<ni){ item nx=its[j]; if(nx.a-g0.b>3*lh) break;
      if(!nx.fig){ int ok=0; for(int m=j+1;m<j+3&&m<ni;m++) if(its[m].fig && its[m].a-nx.b<3*lh){ok=1;break;} if(!ok) break; }
      if(nx.b>g0.b) g0.b=nx.b; if(nx.x0<g0.x0) g0.x0=nx.x0; if(nx.x1>g0.x1) g0.x1=nx.x1; j++; }
    g0.h=g0.b-g0.a; out[no++]=g0; i=j; }
  free(its);
  int nl=0; for(int i=0;i<no;i++) if(!out[i].fig) dv[nl++]=out[i].x0; int left= nl? (int)pct(dv,nl,10):0;
  nl=0; for(int i=0;i<no;i++) if(!out[i].fig) dv[nl++]=out[i].x1; int right= nl? (int)pct(dv,nl,90):W;
  int tw=right-left>1?right-left:1;
  int np=0, pl=-1; for(int i=0;i<no;i++) if(!out[i].fig){ if(pl>=0 && out[i].a-out[pl].a<3*lh) dv[np++]=out[i].a-out[pl].a; pl=i; }
  double mp= np? median(dv,np):1.5*lh;
  int start=0, end=no;
  if(no>1){ item f=out[0]; if(!f.fig && (f.nw<=5 || f.h>1.25*lh)) start=1; else if(f.fig && f.h<2.5*lh && f.x1-f.x0>0.8*tw) start=1; }
  if(end-start>1 && !out[end-1].fig){ item l=out[end-1]; if(l.x1-l.x0<0.15*tw && l.nw<=2) end--; }
  item *o2=out+start; int n2=end-start;
  int nlines=0; for(int i=0;i<no;i++) if(!out[i].fig) nlines++;   /* python counts lines before head removal */
  /* footnotes */
  int bh=0; for(int i=0;i<n2;i++) if(!o2[i].fig) dv[bh++]=o2[i].h; double body_h= bh? median(dv,bh):lh;
  int ng=0; for(int i=0;i+1<n2;i++) if(!o2[i].fig&&!o2[i+1].fig&&o2[i+1].a-o2[i].b<2*lh) dv[ng++]=o2[i+1].a-o2[i].b;
  double mg= ng? median(dv,ng): mp-lh;
  for(int i=n2-1;i>0;i--){ if(o2[i].a<0.55*H) break;
    if(o2[i].a-o2[i-1].b>fmax(1.6*mg,mg+4)){ int allline=1; for(int j=i;j<n2;j++) if(o2[j].fig) allline=0;
      if(allline){ int npt=0; for(int j=i;j+1<n2;j++) dv[npt++]=o2[j+1].a-o2[j].a; double mpt=npt?median(dv,npt):1e9;
        int nh=0; double *hv=malloc(sizeof(double)*(n2-i)); for(int j=i;j<n2;j++) hv[nh++]=o2[j].h; double mh=median(hv,nh); free(hv);
        if((npt && mpt<0.92*mp) || mh<0.88*body_h) for(int j=i;j<n2;j++) o2[j].foot=1; }
      break; } }
  double at=0,af=0; for(int i=0;i<n2;i++){ double ar=(double)(o2[i].b-o2[i].a)*(o2[i].x1-o2[i].x0); if(o2[i].fig) af+=ar; else at+=ar; }
  int nx=0; for(int i=0;i<no;i++) if(!out[i].fig){ item *o=&out[i]; int bd0=-1,bd1=-1,mx=0; int hh=o->b-o->a; int *pr=malloc(sizeof(int)*hh);
      for(int y=0;y<hh;y++){ int c=0; for(int x=o->x0;x<o->x1;x++) c+=AT(ink,o->a+y,x); pr[y]=c; if(c>mx)mx=c; }
      if(mx) for(int y=0;y<hh;y++) if(pr[y]>0.35*mx){ if(bd0<0)bd0=y; bd1=y; }
      if(bd0>=0 && bd1>bd0) dv[nx++]=bd1-bd0+1; free(pr); }
  A->xh= nx? median(dv,nx):0.5*lh;
  A->it=malloc(sizeof(item)*(n2>0?n2:1)); memcpy(A->it,o2,sizeof(item)*n2); A->n=n2;
  A->lh=lh; A->mp=mp; A->share=at/fmax(1,at+af); A->left=left; A->right=right; A->nlines=nlines;
  free(out); free(dv); return 1;
}

static const char *safety(page *P, analysis *A, double scale, int sw){
  int W=P->W,H=P->H,T=24; double lh=A->lh; int bad=0;
  for(int ty=0;ty+T<H;ty+=T) for(int tx=0;tx+T<W;tx+=T){
    double s=0,s2=0; int mid=0,wh=0; for(int y=ty;y<ty+T;y++) for(int x=tx;x<tx+T;x++){ float v=AT(P->g,y,x); s+=v; s2+=v*v; mid+=v>50&&v<205; wh+=v>230; }
    double n=T*T, sd=sqrt(fmax(0,s2/n-(s/n)*(s/n)));
    if(sd>35 && mid/n>0.45 && wh/n<0.2){ int cy=ty+T/2,cx=tx+T/2,in=0;
      for(int i=0;i<A->n;i++){ item *f=&A->it[i]; if(f->fig && f->a-lh<=cy && cy<=f->b+lh && f->x0-lh<=cx && cx<=f->x1+lh){in=1;break;} }
      /* v0.12.3: a tile inside an ordinary text line (one line high, several words) is dense small
       * print such as a bold caption, not a photo */
      if(!in) for(int i=0;i<A->n;i++){ item *f=&A->it[i]; if(!f->fig && f->h<=1.6*lh && f->nw>=4 && f->a<=cy && cy<f->b && f->x0<=cx && cx<f->x1){in=1;break;} }
      if(!in && getenv("RFDBG")) fprintf(stderr,"bad %d %d %.1f\n",ty,tx,sd);
      if(!in && ++bad>=3) return "photo-outside-figure"; } }
  double *hs=malloc(sizeof(double)*(A->n+1)); int nh=0; for(int i=0;i<A->n;i++) if(!A->it[i].fig && !A->it[i].foot) hs[nh++]=A->it[i].h;
  if(nh>5){ double m=0,v=0; for(int i=0;i<nh;i++) m+=hs[i]; m/=nh; for(int i=0;i<nh;i++) v+=(hs[i]-m)*(hs[i]-m); if(sqrt(v/nh)/m>0.35){ free(hs); return "mixed-sizes"; } }
  free(hs);
  { int tw=A->right-A->left, nwl=0, nbig=0; for(int i=0;i<A->n;i++){ item *o=&A->it[i]; if(o->fig||o->foot||o->x1-o->x0<=0.5*tw) continue; nwl++; int mx=0; for(int j=0;j<o->nw;j++) if(o->w[j].b-o->w[j].a>mx) mx=o->w[j].b-o->w[j].a; if(mx>0.6*tw) nbig++; }
    if(nwl>=5 && nbig>=0.9*nwl) return "no-word-gaps"; }   /* tight digital type beside photos: wraps raggedly */
  /* table: wide gaps aligned in the same column bin across >= max(4, 25%) lines */
  int nb=W/(int)fmax(1,lh)+2; int *cnt=calloc(nb,sizeof(int)); int *last=malloc(sizeof(int)*nb); for(int i=0;i<nb;i++) last[i]=-1;
  for(int i=0;i<A->n;i++){ item *o=&A->it[i]; if(o->fig||o->foot) continue;
    for(int j=0;j+1<o->nw;j++) if(o->w[j+1].a-o->w[j].b>1.5*lh){ int bi=(int)(((o->w[j].b+o->w[j+1].a)/2.0)/lh); if(bi<nb && last[bi]!=o->a){ cnt[bi]++; last[bi]=o->a; } } }
  for(int i=0;i<nb;i++) if(cnt[i]>=fmax(4,0.25*nh)){ free(cnt);free(last); return "table"; }
  free(cnt); free(last);
  double maxw=0.95*(sw-2*48)/(scale*15.0/A->xh);
  for(int i=0;i<A->n;i++){ item *o=&A->it[i]; if(o->fig||o->foot) continue;
    int cap=o->nw*4+16; span *nw=malloc(sizeof(span)*cap), *st=malloc(sizeof(span)*cap); int k=0; int ns;
    uint8_t *m=malloc(W+1); span *cr=malloc(sizeof(span)*(W+1));
    for(int j=0;j<o->nw;j++){ ns=0; st[ns++]=o->w[j];
      while(ns){ span s=st[0]; memmove(st,st+1,sizeof(span)*(--ns));
        if(s.b-s.a<=maxw){ if(k>=cap){ cap*=2; nw=realloc(nw,sizeof(span)*cap); st=realloc(st,sizeof(span)*cap);} nw[k++]=s; continue; }
        int L=s.b-s.a; for(int x=0;x<L;x++){ m[x]=0; for(int y=o->a;y<o->b;y++) if(AT(P->soft,y,s.a+x)){m[x]=1;break;} }
        int nc=runs(m,L,0,cr,W+1); if(nc<2){ free(nw);free(st);free(m);free(cr); return "word-too-wide"; }
        int gi=0; for(int q=0;q+1<nc;q++) if(cr[q+1].a-cr[q].b>cr[gi+1].a-cr[gi].b) gi=q;
        if(ns+2>=cap){ cap*=2; nw=realloc(nw,sizeof(span)*cap); st=realloc(st,sizeof(span)*cap);} memmove(st+2,st,sizeof(span)*ns); st[0]=(span){s.a+cr[0].a,s.a+cr[gi].b}; st[1]=(span){s.a+cr[gi+1].a,s.a+cr[nc-1].b}; ns+=2; } }
    /* sort and store */
    for(int x=1;x<k;x++){ span t=nw[x]; int y=x-1; while(y>=0&&nw[y].a>t.a){nw[y+1]=nw[y];y--;} nw[y+1]=t; }
    free(o->w); o->w=nw; o->nw=k; free(st); free(m); free(cr); }
  return "";
}

/* ---- drawing helpers ---- */
/* Lanczos-3 resize into a temp buffer, then darken-composite (min) onto the screen with an optional tone LUT */
static double lzk(double x){ if(x<0)x=-x; if(x<1e-9) return 1; if(x>=3) return 0; double px=M_PI*x; return 3*sin(px)*sin(px/3)/(px*px); }
/* Lanczos-3 weight table for one axis: for each output index, a clamped start and taps in 1.14 fixed point.
 * Taps that fall outside the source are folded onto the edge pixel (same as clamping). */
static float LZT[3*1024+2]; static int lzt_ready=0;   /* lzk sampled at 1/1024 steps (linear interp.) */
static double lzf(double x){ if(x<0)x=-x; if(x>=3) return 0; if(!lzt_ready){ for(int i=0;i<=3*1024+1;i++) LZT[i]=(float)lzk(i/1024.0); lzt_ready=1; }
  double f=x*1024; int i=(int)f; f-=i; return LZT[i]*(1-f)+LZT[i+1]*f; }
typedef struct { int n, taps; int *start; int16_t *w; } lzt;
static void lz_table(lzt *t, int sn, int dn){
  double sc=(double)sn/dn, fs=sc>1?sc:1; int taps=(int)ceil(3*fs)*2+1; if(taps>sn) taps=sn;
  t->n=dn; t->taps=taps; t->start=malloc(sizeof(int)*dn); t->w=calloc((size_t)dn*taps,sizeof(int16_t));
  double *wd=malloc(sizeof(double)*(taps+64));
  for(int o=0;o<dn;o++){ double c=(o+0.5)*sc-0.5; int lo=(int)floor(c-3*fs)+1, hi=(int)floor(c+3*fs);
    int st=lo<0?0:lo; if(st+taps>sn) st=sn-taps; t->start[o]=st;
    for(int q=0;q<taps;q++) wd[q]=0; double ws=0;
    for(int i=lo;i<=hi;i++){ double w=lzf((i-c)/fs); ws+=w; int ii=i<0?0:i>=sn?sn-1:i; int q=ii-st; if(q<0)q=0; if(q>=taps)q=taps-1; wd[q]+=w; }
    int sum=0, big=0; for(int q=0;q<taps;q++){ int v=(int)lround(wd[q]/ws*16384); t->w[(size_t)o*taps+q]=(int16_t)v; sum+=v; if(abs(v)>abs(t->w[(size_t)o*taps+big])) big=q; }
    t->w[(size_t)o*taps+big]+=16384-sum; }   /* weights sum to exactly 1.0 */
  free(wd); }
static void lz_free(lzt *t){ free(t->start); free(t->w); }
/* Lanczos-3 resize (separable, fixed point), then darken-composite (min) onto the screen with an optional tone LUT */
static void resize_paste(rf_img *dst, const uint8_t *src, int sstride, int sw, int sh, int dw, int dh, int dx, int dy, const uint8_t *lut){
  if(dw<1||dh<1||sw<1||sh<1) return;
  lzt tx, ty; lz_table(&tx,sw,dw); lz_table(&ty,sh,dh);
  int16_t *tmp=malloc(sizeof(int16_t)*(size_t)sh*dw);   /* horizontal pass, value*16 (range -2040..6120) */
  for(int y=0;y<sh;y++){ const uint8_t *row=src+(size_t)y*sstride; int16_t *o=tmp+(size_t)y*dw;
    for(int x=0;x<dw;x++){ const uint8_t *p=row+tx.start[x]; const int16_t *w=tx.w+(size_t)x*tx.taps; int acc=0;
      for(int q=0;q<tx.taps;q++) acc+=p[q]*w[q];
      acc=(acc+512)>>10; if(acc<-4096)acc=-4096; if(acc>8191)acc=8191; o[x]=(int16_t)acc; } }
  for(int y=0;y<dh;y++){ int py=dy+y; if(py<0||py>=dst->h) continue; const int16_t *w=ty.w+(size_t)y*ty.taps; const int16_t *base=tmp+(size_t)ty.start[y]*dw;
    uint8_t *drow=&dst->px[(size_t)py*dst->w];
    for(int x=0;x<dw;x++){ int px=dx+x; if(px<0||px>=dst->w) continue; const int16_t *p=base+x; int acc=0;
      for(int q=0;q<ty.taps;q++) acc+=p[(size_t)q*dw]*w[q];
      int iv=(acc+(1<<17))>>18; if(iv<0)iv=0; if(iv>255)iv=255; uint8_t o=lut?lut[iv]:(uint8_t)iv; if(o<drow[px]) drow[px]=o; } }
  free(tmp); lz_free(&tx); lz_free(&ty); }
static rf_img newscreen(int w,int h){ rf_img s={w,h,malloc((size_t)w*h)}; memset(s.px,255,(size_t)w*h); return s; }
static void page_view(rf_result *out){ (void)out; }

int rf_analyse(const rf_img *lo, double scale, int SW, rf_analysis *out){
  memset(out,0,sizeof *out); out->reason=""; out->scale=scale; out->w=lo->w; out->h=lo->h; int SH=0; (void)SH;
  page Pv={lo->w,lo->h}, *P=&Pv; size_t n=(size_t)lo->w*lo->h;
  P->g=malloc(n*sizeof(float)); P->ink=malloc(n); P->soft=malloc(n); P->grey=malloc(n); P->sg=malloc(n); P->nf=malloc(n);
  int nfig=0; span *fa=NULL,*fx=NULL;
  norm_page(P,lo); analysis A; memset(&A,0,sizeof A);
  int ok=analyse(P,&A); int W=P->W,H=P->H;
#define DONE(m,r) do{ out->mode=(m); out->reason=(r); goto fin; }while(0)
  if(!ok || A.nlines<6 || (A.share<0.4 && A.nlines<8)) DONE(RF_PAGE_VIEW,"page");
  { const char *why=safety(P,&A,scale,SW); if(*why) DONE(RF_PAGE_VIEW,why); }
  /* shading-free mask: dark AND smooth columns/rows are shading; photos are textured and stay */
  for(size_t i=0;i<n;i++){ P->sg[i]=P->g[i]<170; P->soft[i]=P->g[i]<200; P->ink[i]=P->g[i]<150; }
  { double *vt=calloc(W,sizeof(double)), *ht=calloc(H,sizeof(double)); int *cs=calloc(W,sizeof(int)), *rs=calloc(H,sizeof(int));
    for(int y=0;y<H;y++) for(int x=0;x<W;x++){ if(y+1<H) vt[x]+=fabs(AT(P->g,y+1,x)-AT(P->g,y,x)); if(x+1<W) ht[y]+=fabs(AT(P->g,y,x+1)-AT(P->g,y,x)); cs[x]+=AT(P->sg,y,x); rs[y]+=AT(P->sg,y,x); }
    for(int x=0;x<W;x++) if(cs[x]>0.3*H && vt[x]/(H-1)<8) for(int y=0;y<H;y++) AT(P->sg,y,x)=0;
    for(int y=0;y<H;y++){ rs[y]=0; for(int x=0;x<W;x++) rs[y]+=AT(P->sg,y,x); }  /* row test sees the column-cleared mask, as in Python */
    for(int y=0;y<H;y++) if(rs[y]>0.3*W && ht[y]/(W-1)<8) for(int x=0;x<W;x++) AT(P->sg,y,x)=0;
    free(vt);free(ht);free(cs);free(rs); }
  memcpy(P->nf,P->sg,n);
  int fr=(int)fmax(4,(int)(0.02*W)); for(int y=0;y<H;y++) for(int x=0;x<W;x++) if(x<fr||x>=W-fr||y<fr||y>=H-fr) AT(P->sg,y,x)=0;
  for(int y=0;y<H;y++){ int c=0; for(int x=0;x<W;x++) c+=AT(P->sg,y,x); if(c>0.5*W) for(int x=0;x<W;x++) AT(P->sg,y,x)=0; }
  int F=fr; double lh=A.lh;
  /* picture boxes: grow to all connected ink; edge -> spread view; unsure -> page view */
  nfig=0; fa=malloc(sizeof(span)*(A.n+1)); fx=malloc(sizeof(span)*(A.n+1));
  for(int i=0;i<A.n;i++){ item *it=&A.it[i]; if(!it->fig) continue;
    int pad=(int)(0.5*lh), a=it->a-pad, b=it->b+pad, x0=it->x0-pad, x1=it->x1+pad;
    if(a<F)a=F; if(b>H-F)b=H-F; if(x0<F)x0=F; if(x1>W-F)x1=W-F;
    long c=0; if(b>a&&x1>x0) for(int y=a;y<b;y++) for(int x=x0;x<x1;x++) c+=AT(P->sg,y,x);
    if(b<=a||x1<=x0|| c<0.01*(double)(b-a)*(x1-x0)){
      if(it->x0<=F||it->x1>=W-F||it->a<=F||it->b>=H-F){ if(getenv("RFDBG")) fprintf(stderr,"SHADE %d %d %d %d\n",it->a,it->b,it->x0,it->x1); it->fig=2; continue; }  /* shading: ignored */
      DONE(RF_PAGE_VIEW,"fig-unsure"); }
    for(int g=0;g<200;g++){ int grew=0;
      if(a>0){ for(int x=x0;x<x1;x++) if(AT(P->sg,a,x)){a--;grew=1;break;} }
      if(b<H){ for(int x=x0;x<x1;x++) if(AT(P->sg,b-1,x)){b++;grew=1;break;} }
      if(x0>0){ for(int y=a;y<b;y++) if(AT(P->sg,y,x0)){x0--;grew=1;break;} }
      if(x1<W){ for(int y=a;y<b;y++) if(AT(P->sg,y,x1-1)){x1++;grew=1;break;} }
      if(!grew) break; }
    if(b>H)b=H; if(x1>W)x1=W;
    int le=0,re=0; for(int y=a;y<b;y++){ le+=AT(P->nf,y,F); re+=AT(P->nf,y,W-F-1); }
    if((x0<=F && le>=2)||(x1>=W-F && re>=2)) DONE(RF_SPREAD_VIEW,"spread-picture");
    int v=0; for(int y=a;y<b&&!v;y++){ if(x0>0&&AT(P->sg,y,x0)) v=1; if(x1<W&&AT(P->sg,y,x1-1)) v=1; }
    for(int x=x0;x<x1&&!v;x++){ if(a>0&&AT(P->sg,a,x)) v=1; if(b<H&&AT(P->sg,b-1,x)) v=1; }
    if(v) DONE(RF_PAGE_VIEW,"fig-border");
    if(getenv("RFDBG")) fprintf(stderr,"FIG %d %d %d %d\n",a,b,x0,x1);
    fa[nfig]=(span){a,b}; fx[nfig]=(span){x0,x1}; nfig++; }
  /* ---- per-unit data for layout (everything the layout needs, so it can be cached) ---- */
  { int fi=0, nu=0; rf_unit *U=calloc(A.n+1,sizeof(rf_unit)); item *prev=NULL;
    for(int i=0;i<A.n;i++){ item *it=&A.it[i];
      if(it->fig==2) continue;
      if(it->fig){ U[nu++]=(rf_unit){.fig=1,.a=fa[fi].a,.b=fa[fi].b,.x0=fx[fi].a,.x1=fx[fi].b}; fi++; prev=NULL; continue; }
      int a=it->a,b=it->b,x0=it->x0,x1=it->x1;
      /* v0.12.3: a text line that lies inside a kept picture box (e.g. the first lines beside a
       * drop cap in a chapter banner) is already shown in the picture: not reflowed again */
      { int inpic=0; for(int f=0;f<nfig;f++){ int oy=(b<fa[f].b?b:fa[f].b)-(a>fa[f].a?a:fa[f].a), ox=(x1<fx[f].b?x1:fx[f].b)-(x0>fx[f].a?x0:fx[f].a);
          if(oy>0.5*(b-a) && ox>0.5*(x1-x0)){ inpic=1; break; } }
        if(inpic){ if(getenv("RFDBG")) fprintf(stderr,"IN-PICTURE line %d %d\n",a,b); continue; } }
      int para= !prev || a-prev->b>A.mp-lh+0.9*lh || prev->x1<A.right-4*lh || (x0-A.left>1.2*lh && prev->x1<A.right-1.5*lh);
      int indent= x0-A.left>1.2*lh;
      { int cov=0,tot=x1-x0; double *hv=malloc(sizeof(double)*(tot+1)); int nh=0; for(int xx=x0;xx<x1;xx++){ int c=0; for(int yy=a;yy<b;yy++) c+=AT(P->soft,yy,xx); if(c){cov++; hv[nh++]=c;} }
        int rule= tot>5*lh && cov>0.85*tot && nh && pct(hv,nh,90)<=fmax(3,0.25*lh); free(hv); if(rule) continue; }
      int a2=a-2<0?0:a-2, b2=b+2>H?H:b+2;
      int bl=b2-a2; { int mx=0, *pr=malloc(sizeof(int)*(b2-a2+1)); for(int yy=a2;yy<b2;yy++){ int c=0; for(int xx=0;xx<W;xx++) c+=AT(P->soft,yy,xx); pr[yy-a2]=c; if(c>mx)mx=c; }
        for(int yy=b2-1;yy>=a2;yy--) if(pr[yy-a2]>0.35*mx){ bl=yy-a2+1; break; } free(pr); }
      int cut=0; if(it->nw && x1>=A.right-0.15*(A.right-A.left)){ int wa=it->w[it->nw-1].a, wb=it->w[it->nw-1].b, hh=b-a, mx=0, xb0=-1,xb1=-1, *pr=malloc(sizeof(int)*(hh+1));
        for(int yy=0;yy<hh;yy++){ int c=0; for(int xx=wa;xx<wb;xx++) c+=AT(P->soft,a+yy,xx); pr[yy]=c; if(c>mx)mx=c; }
        for(int yy=0;yy<hh;yy++) if(pr[yy]>0.35*mx){ if(xb0<0)xb0=yy; xb1=yy; }
        if(xb1>xb0){ int xh=xb1-xb0+1, nn=0, c; for(c=wb-wa-1;c>=0;c--){ int r0=-1,r1=-1; for(int yy=0;yy<hh;yy++) if(AT(P->soft,a+yy,wa+c)){ if(r0<0)r0=yy; r1=yy; }
            if(r0<0){ if(!nn) continue; break; }
            if(r1-r0+1<=fmax(2,0.3*xh) && (r0+r1)/2.0>=xb0+0.2*xh && (r0+r1)/2.0<=xb0+0.85*xh) nn++; else break; }
          if(nn>=0.2*lh && nn<=0.7*lh && c>2) cut=nn+((wb-wa-1)-(c+nn))+1; } free(pr); }
      rf_unit u={.fig=0,.a=a,.b=b,.x0=x0,.x1=x1,.a2=a2,.b2=b2,.cut=cut,.bl=bl,.foot=it->foot,.para=para,.indent=indent};
      u.w=malloc(sizeof(rf_span)*(it->nw+1));
      for(int wi=0;wi<it->nw;wi++){ int wa=it->w[wi].a, wb=it->w[wi].b;
        { int r0=-1,r1=-1,cc=0,tot=0; long gs=0; for(int xx=wa;xx<wb;xx++){ int any=0; for(int yy=a2;yy<b2;yy++) if(AT(P->soft,yy,xx)){ any=1; tot++; gs+=(long)AT(P->g,yy,xx); if(r0<0||yy<r0)r0=yy; if(yy>r1)r1=yy; } cc+=any; }
          double covr=(wb-wa)? (double)cc/(wb-wa):0, fill=(double)tot/((wb-wa)*(b2-a2));
          if(tot && (r1-r0+1)<0.45*lh && covr<0.6 && (wb-wa)>0.6*lh) continue;
          if(tot && (wb-wa)<=1.2*lh && fill>0.6 && gs/(double)tot>90 && gs/(double)tot<200) continue;
          if(tot<=0.6*lh*lh && (tot==0 || (r1-r0+1)<0.3*lh || fill<0.04)) continue; }
        u.w[u.nw++]=(rf_span){wa,wb, wi==it->nw-1}; }
      U[nu++]=u; prev=it; }
    out->u=U; out->nu=nu; out->lh=lh; out->mp=A.mp; out->xh=A.xh; out->mode=RF_REFLOW; }
fin:
  free(fa); free(fx);
  for(int i=0;i<A.n;i++) free(A.it[i].w); free(A.it);
  free(P->g);free(P->ink);free(P->soft);free(P->grey);free(P->sg);free(P->nf);
  (void)page_view; return 0;
}

/* Layout: cached analysis + the hi-res page -> screens. No access to the analysis masks. */
int rf_layout(const rf_analysis *an, const rf_img *hi, int k, int SW, int SH, rf_result *out){
  memset(out,0,sizeof *out); out->mode=an->mode; out->reason=an->reason;
  if(an->mode!=RF_REFLOW) return 0;
  int M=48; double lh=an->lh, s=an->scale*15.0/an->xh; int space=(int)fmax(6,0.45*lh*s), lead=(int)(an->mp*s), TB=(int)(lh*s);
  int hw=hi->w, W=an->w;
  double pbg=fmax(120,pct90_u8(hi->px,(size_t)hi->w*hi->h)); uint8_t lut[256];
  for(int v=0;v<256;v++){ double a=fmin(255,v*255.0/pbg); a=fmin(1,fmax(0,(a-95)/130.0)); lut[v]=(uint8_t)(pow(a,1.15)*255); }
  int cap=8; out->screens=malloc(sizeof(rf_img)*cap); out->nscreens=0;
  rf_img cur=newscreen(SW,SH); int y=M, x=M, infoot=0, glue=0;
  typedef struct { int sx0,sx1,a2,b2,dx,off,w,h; } pend; int pcap=64; pend *pd=malloc(sizeof(pend)*pcap); int npd=0;
#define NEWSCR() do{ if(out->nscreens>=cap){ cap*=2; out->screens=realloc(out->screens,sizeof(rf_img)*cap);} out->screens[out->nscreens++]=cur; cur=newscreen(SW,SH); y=M; }while(0)
#define FLUSH(gap) do{ if(npd){ if(y+lead+(int)(0.4*lh*s)>SH-M) NEWSCR(); \
      for(int q=0;q<npd;q++) resize_paste(&cur,&hi->px[(size_t)pd[q].a2*k*hw+pd[q].sx0*k],hw,(pd[q].sx1-pd[q].sx0)*k,(pd[q].b2-pd[q].a2)*k,pd[q].w,pd[q].h,pd[q].dx,y+pd[q].off,lut); \
      y+=lead; } y+=(gap); npd=0; x=M; }while(0)
  for(int i=0;i<an->nu;i++){ const rf_unit *u=&an->u[i];
    if(u->fig){ FLUSH((int)(0.3*lead)); glue=0; int a=u->a,b=u->b,x0=u->x0,x1=u->x1;
      double fs=fmin(s,fmin((SW-2.0*M)/(x1-x0),(SH-2.0*M)/(b-a))); int dw=(int)((x1-x0)*fs), dh=(int)((b-a)*fs);
      if(y+dh>SH-M && y>M) NEWSCR();
      resize_paste(&cur,&hi->px[(size_t)a*k*hw+x0*k],hw,(x1-x0)*k,(b-a)*k,dw,dh,(SW-dw)/2,y,NULL); y+=dh+(int)(0.3*lead); continue; }
    int a2=u->a2,b2=u->b2,cut=u->cut,para=u->para;
    if(u->foot && !infoot){ FLUSH((int)(0.3*lead)); infoot=1; if(y+6>SH-M) NEWSCR(); for(int yy=y;yy<y+2;yy++) memset(&cur.px[yy*SW+M],0,(SW-2*M)/3); y+=(int)(0.4*lead); para=1; }
    int off=TB-(int)(u->bl*s);
    if(para){ FLUSH((int)(0.35*lead)); glue=0; x=M+(u->indent?(int)(1.5*lh*s):0); }
    int h=(int)fmax(1,(b2-a2)*s);
    for(int wi=0;wi<u->nw;wi++){ int wa=u->w[wi].a, wb=u->w[wi].b;
      int last=u->w[wi].last; int wa2=wa-1<0?0:wa-1, wb2=wb+1>W?W:wb+1; if(last&&cut) wb2=wb-cut+1;
      int w=(int)fmax(1,(wb2-wa2)*s);
      if(glue && npd){ pend *pp=&pd[npd-1]; if(pp->dx+pp->w+w>SW-M){ pend keep=*pp; npd--; FLUSH(0); keep.dx=x; pd[npd++]=keep; x=keep.dx+keep.w; }
        if(x+w<=SW-M){ if(npd>=pcap){ pcap*=2; pd=realloc(pd,sizeof(pend)*pcap);} pd[npd++]=(pend){wa2,wb2,a2,b2,x,off,w,h}; x+=w+space; glue=0; continue; } }
      glue=0; if(x+w>SW-M && npd) FLUSH(0);
      int hh2=h; if(x+w>SW-M){ double f=(double)(SW-M-x)/w; w=(int)fmax(1,w*f); hh2=(int)fmax(1,h*f); }
      if(npd>=pcap){ pcap*=2; pd=realloc(pd,sizeof(pend)*pcap);} pd[npd++]=(pend){wa2,wb2,a2,b2,x,off,w,hh2}; x+=w+space; }
    if(cut && u->nw && u->w[u->nw-1].last){ glue=1; x-=space; } }
  FLUSH(0); NEWSCR(); free(cur.px); free(pd);
  return 0;
}

int rf_reflow(const rf_img *lo, const rf_img *hi, int k, double scale, int SW, int SH, rf_result *out){
  rf_analysis an; rf_analyse(lo,scale,SW,&an); int r=rf_layout(&an,hi,k,SW,SH,out); rf_analysis_free(&an); return r; }
void rf_analysis_free(rf_analysis *a){ for(int i=0;i<a->nu;i++) free(a->u[i].w); free(a->u); a->u=0; a->nu=0; }
void rf_free(rf_result *r){ for(int i=0;i<r->nscreens;i++) free(r->screens[i].px); free(r->screens); r->screens=0; r->nscreens=0; }

/* ---- cache file: DATA/cache/reflow/<key>.rf ----
 * "ZRF1" | i32 version=2 (v0.12.3: in-picture lines and caption tiles; older files are re-analysed) | i32 mode | i32 reason code | i32 scale*100 | i32 w,h | f32 lh,mp,xh | i32 nu |
 * nu x { i32 fig,a,b,x0,x1,a2,b2,cut,bl,foot,para,indent,nw | nw x { i32 a,b,last } }   (little-endian host order) */
static const char *REASONS[]={"","page","photo-outside-figure","mixed-sizes","no-word-gaps","table","word-too-wide","fig-unsure","fig-border","spread-picture"};
static int reason_code(const char *r){ for(int i=0;i<(int)(sizeof REASONS/sizeof *REASONS);i++) if(!strcmp(REASONS[i],r)) return i; return 1; }
int rf_save(const rf_analysis *a, const char *path){
  FILE *f=fopen(path,"wb"); if(!f) return -1;
  int32_t hd[7]={2,a->mode,reason_code(a->reason),(int32_t)lround(a->scale*100),a->w,a->h,a->nu}; float fl[3]={(float)a->lh,(float)a->mp,(float)a->xh};
  int ok= fwrite("ZRF1",1,4,f)==4 && fwrite(hd,4,6,f)==6 && fwrite(fl,4,3,f)==3 && fwrite(&hd[6],4,1,f)==1;
  for(int i=0;ok&&i<a->nu;i++){ const rf_unit *u=&a->u[i]; int32_t v[13]={u->fig,u->a,u->b,u->x0,u->x1,u->a2,u->b2,u->cut,u->bl,u->foot,u->para,u->indent,u->nw};
    ok= fwrite(v,4,13,f)==13; for(int j=0;ok&&j<u->nw;j++){ int32_t w[3]={u->w[j].a,u->w[j].b,u->w[j].last}; ok= fwrite(w,4,3,f)==3; } }
  if(fclose(f)!=0) ok=0; return ok?0:-1; }
int rf_load(rf_analysis *a, const char *path){
  memset(a,0,sizeof *a); FILE *f=fopen(path,"rb"); if(!f) return -1; char m[4]; int32_t hd[7]; float fl[3];
  if(fread(m,1,4,f)!=4 || memcmp(m,"ZRF1",4) || fread(hd,4,6,f)!=6 || hd[0]!=2 || fread(fl,4,3,f)!=3 || fread(&hd[6],4,1,f)!=1 || hd[6]<0 || hd[6]>1000000){ fclose(f); return -1; }
  a->mode=hd[1]; a->reason= hd[2]>=0&&hd[2]<(int)(sizeof REASONS/sizeof *REASONS)? REASONS[hd[2]]:"page"; a->scale=hd[3]/100.0; a->w=hd[4]; a->h=hd[5]; a->lh=fl[0]; a->mp=fl[1]; a->xh=fl[2];
  a->u=calloc(hd[6]+1,sizeof(rf_unit));
  for(int i=0;i<hd[6];i++){ int32_t v[13]; if(fread(v,4,13,f)!=13 || v[12]<0 || v[12]>100000){ a->nu=i; rf_analysis_free(a); fclose(f); return -1; }
    rf_unit *u=&a->u[i]; *u=(rf_unit){v[0],v[1],v[2],v[3],v[4],v[5],v[6],v[7],v[8],v[9],v[10],v[11],0,NULL}; u->w=malloc(sizeof(rf_span)*(v[12]+1)); a->nu=i+1;
    for(int j=0;j<v[12];j++){ int32_t w[3]; if(fread(w,4,3,f)!=3){ rf_analysis_free(a); fclose(f); return -1; } u->w[u->nw++]=(rf_span){w[0],w[1],w[2]}; } }
  fclose(f); return 0; }
