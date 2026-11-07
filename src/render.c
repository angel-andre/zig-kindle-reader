/* MuPDF wrapper. Each zr_doc owns its own context and document, so one
 * zr_doc per thread gives lock-free parallel rendering. */
#include <mupdf/fitz.h>
#include <string.h>
#include <math.h>
#include <pthread.h>
#include <stdint.h>
#include <sys/stat.h>
#include <unistd.h>
#include <dirent.h>
#include <stdio.h>
#include <time.h>
#include "render.h"

/* One locked base context; every zr_doc and the UI use clones of it, as
 * MuPDF requires for use from several threads (fonts, store, harfbuzz). */
static pthread_mutex_t zr_mutexes[FZ_LOCK_MAX];
static fz_context *zr_base;
static pthread_once_t zr_once = PTHREAD_ONCE_INIT;

static void zr_lock(void *user, int lock) { pthread_mutex_lock(&zr_mutexes[lock]); }
static void zr_unlock(void *user, int lock) { pthread_mutex_unlock(&zr_mutexes[lock]); }

static void zr_init(void)
{
	static fz_locks_context locks = { NULL, zr_lock, zr_unlock };
	for (int i = 0; i < FZ_LOCK_MAX; i++) pthread_mutex_init(&zr_mutexes[i], NULL);
	zr_base = fz_new_context(NULL, &locks, 256 << 20);
	if (zr_base) {
		fz_try(zr_base) fz_register_document_handlers(zr_base);
		fz_catch(zr_base) fz_report_error(zr_base);
	}
}

static fz_context *zr_new_ctx(void)
{
	pthread_once(&zr_once, zr_init);
	return zr_base ? fz_clone_context(zr_base) : NULL;
}

#define NLISTS 24

struct zr_anchor_index;
static void drop_anchor_index(zr_doc *z);

struct zr_doc {
	fz_context *ctx;
	fz_document *doc;
	int pages, is_pdf, reflow, pending;
	float spacing;
 float lw, lh, font, margin;
	int styled;
	struct zr_anchor_index *anchor_index;
	struct { int page; fz_display_list *list; unsigned age; } lists[NLISTS];
	unsigned tick;
 fz_cookie cookie;
};

static void set_css(fz_context *ctx, fz_document *doc, float margin_pt, float font_pt, float spacing, int styled)
{
	char css[512];
	fz_snprintf(css, sizeof css, "@page{margin:%gpt %gpt !important}html,body{font-size:%gpt !important}body{margin:0 !important}*{line-height:%g !important}", margin_pt * 0.8f, margin_pt, font_pt, spacing);
	if (!styled) fz_snprintf(css, sizeof css, "@page{margin:%gpt %gpt !important}body{margin:0 !important}", margin_pt * .8f, margin_pt);
	fz_style_document(ctx, doc, 1, css);
}

/* MuPDF EPUB accelerators cache per-chapter pagination, keyed by file identity
 * AND all typography. Bounded, disposable user-data cache; never book changes. */
static char layout_dir[1200];
static _Thread_local int (*pagination_progress)(int);
void zr_layout_cache(const char *data) { snprintf(layout_dir,sizeof layout_dir,"%s/layout",data);mkdir(layout_dir,0700);struct stat st;if(lstat(layout_dir,&st)||!S_ISDIR(st.st_mode))layout_dir[0]=0; }
static uint64_t khash(uint64_t h,const void *data,size_t n){const unsigned char *p=data;while(n--)h=(h^*p++)*1099511628211ULL;return h;}
static void layout_path(char *out,size_t cap,const char *path,float w,float h,float em,float margin,float spacing,int styled){
 struct stat st;if(!*layout_dir||stat(path,&st)){*out=0;return;}
 uint64_t k=khash(14695981039346656037ULL,path,strlen(path));
 int64_t fields[]={st.st_size,st.st_mtim.tv_sec,st.st_mtim.tv_nsec,8,styled};float f[]={w,h,em,margin,spacing};
 k=khash(k,fields,sizeof fields);k=khash(k,f,sizeof f);snprintf(out,cap,"%s/%016llx.zra",layout_dir,(unsigned long long)k);
}
static void save_layout(zr_doc *z,const char *name){
 if(!*name||!z->reflow||!fz_document_supports_accelerator(z->ctx,z->doc))return;
 /* File size ceiling and bounded entry count (<=128 * 16 KiB = 2 MiB). */
 DIR *d=opendir(layout_dir);if(!d)return;struct dirent *e;int count=0;char victim[1400]="";time_t age=0;
 while((e=readdir(d))){size_t n=strlen(e->d_name);struct stat st;char p[1400];if(n!=20||strcmp(e->d_name+16,".zra"))continue;snprintf(p,sizeof p,"%s/%s",layout_dir,e->d_name);if(lstat(p,&st)||!S_ISREG(st.st_mode))continue;count++;if(!*victim||st.st_mtime<age){age=st.st_mtime;strcpy(victim,p);}}
 closedir(d);if(count>=128&&*victim)unlink(victim);
 char tmp[1400];snprintf(tmp,sizeof tmp,"%s/.layout-XXXXXX",layout_dir);int fd=mkstemp(tmp);if(fd<0)return;close(fd);
 fz_try(z->ctx){fz_save_accelerator(z->ctx,z->doc,tmp);struct stat st;if(!stat(tmp,&st)&&st.st_size<=16384)rename(tmp,name);}
 fz_catch(z->ctx){}unlink(tmp);
}
static zr_doc *open_style(const char *path,float lw,float lh,float font_pt,float margin_pt,float spacing,int styled,int cover)
{
	zr_doc *z = calloc(1, sizeof *z);
	if (!z) return NULL;
	z->spacing = spacing; z->styled=styled;
 z->lw=lw;z->lh=lh;z->font=font_pt;z->margin=margin_pt;
	z->ctx = zr_new_ctx();
	if (!z->ctx) { free(z); return NULL; }
	fz_try(z->ctx) {
		char ap[1400];layout_path(ap,sizeof ap,path,lw,lh,font_pt,margin_pt,spacing,styled);
        struct stat ast;const char *accel=(cover!=1&&*ap&&!lstat(ap,&ast)&&S_ISREG(ast.st_mode)&&ast.st_size<=16384)?ap:NULL;
        z->doc = fz_open_accelerated_document(z->ctx,path,accel);
		char fmt[64] = "";
		fz_lookup_metadata(z->ctx, z->doc, FZ_META_FORMAT, fmt, sizeof fmt);
		z->is_pdf = strncmp(fmt, "PDF", 3) == 0;
		z->reflow = fz_is_document_reflowable(z->ctx, z->doc);
		if (z->reflow) {
            set_css(z->ctx, z->doc, margin_pt, font_pt, z->spacing, z->styled);
            fz_layout_document(z->ctx, z->doc, lw, lh, font_pt);
        }
		z->pending = cover==2 && !accel && z->reflow;
        if(z->reflow && cover==0 && !accel && pagination_progress){
            z->pages=0;int chapters=fz_count_chapters(z->ctx,z->doc);
            for(int ch=0;ch<chapters;ch++){
                z->pages+=fz_count_chapter_pages(z->ctx,z->doc,ch);
                if(!pagination_progress(z->pages))fz_throw(z->ctx,FZ_ERROR_ABORT,"pagination cancelled");
            }
        } else z->pages = z->reflow && (cover==1 || z->pending) ? fz_count_chapter_pages(z->ctx,z->doc,0) : fz_count_pages(z->ctx,z->doc);
        if(cover!=1&&!z->pending&&z->reflow&&!accel)save_layout(z,ap);
	}
	fz_catch(z->ctx) {
		fz_report_error(z->ctx);
		if (z->doc) fz_drop_document(z->ctx, z->doc);
		fz_drop_context(z->ctx);
		free(z);
		return NULL;
	}
	return z;
}

zr_doc *zr_open(const char *path,float w,float h,float em,float margin){return open_style(path,w,h,em,margin,1.4f,0,0);}
zr_doc *zr_open_style(const char *path,float w,float h,float em,float margin,float spacing){return open_style(path,w,h,em,margin,spacing,1,0);}
zr_doc *zr_open_initial(const char *path,float w,float h,float em,float margin,float spacing){return open_style(path,w,h,em,margin,spacing,1,2);}
/* Main-thread hint from the full-pagination worker, no document sharing. */
void zr_page_count_hint(zr_doc *z,int pages){if(pages>=z->pages){z->pages=pages;z->pending=0;}}
zr_doc *zr_open_cover(const char *path){return open_style(path,306,407,10.5,18,1.4f,0,1);}

static void drop_lists(zr_doc *z)
{
	for (int i = 0; i < NLISTS; i++) {
		if (z->lists[i].list) fz_drop_display_list(z->ctx, z->lists[i].list);
		z->lists[i].list = NULL;
		z->lists[i].page = -1;
	}
}

void zr_close(zr_doc *z)
{
	if (!z) return;
	drop_lists(z);
	drop_anchor_index(z);
	fz_drop_document(z->ctx, z->doc);
	fz_drop_context(z->ctx);
	free(z);
}

int zr_page_count(zr_doc *z) { return z->pages; }
int zr_is_pdf(zr_doc *z) { return z->is_pdf; }
int zr_reflowable(zr_doc *z) { return z->reflow; }

int zr_relayout(zr_doc *z, float lw, float lh, float font_pt, float margin_pt, int page)
{
	int out = page;
	if (!z->reflow) return page;
 if(z->styled && z->lw==lw && z->lh==lh && z->font==font_pt && z->margin==margin_pt)return page;
	fz_try(z->ctx) {
		fz_bookmark mark = fz_make_bookmark(z->ctx, z->doc, fz_location_from_page_number(z->ctx, z->doc, page));
		drop_lists(z);
		drop_anchor_index(z);
		set_css(z->ctx, z->doc, margin_pt, font_pt, z->spacing, z->styled);
		fz_layout_document(z->ctx, z->doc, lw, lh, font_pt);
        z->lw=lw;z->lh=lh;z->font=font_pt;z->margin=margin_pt;
		z->pages = fz_count_pages(z->ctx, z->doc);
		out = fz_page_number_from_location(z->ctx, z->doc, fz_lookup_bookmark(z->ctx, z->doc, mark));
	}
	fz_catch(z->ctx) {
		fz_report_error(z->ctx);
		out = 0;
	}
	if (out < 0) out = 0;
	if (out >= z->pages) out = z->pages - 1;
	return out;
}

/* Returns a borrowed display list for the page (cached, LRU). */
static fz_display_list *get_list(zr_doc *z, int page)
{
	int oldest = 0;
	z->tick++;
	for (int i = 0; i < NLISTS; i++) {
		if (z->lists[i].list && z->lists[i].page == page) {
			z->lists[i].age = z->tick;
			return z->lists[i].list;
		}
		if (!z->lists[i].list || z->lists[i].age < z->lists[oldest].age) oldest = i;
	}
	fz_display_list *l = fz_new_display_list_from_page_number(z->ctx, z->doc, page);
	if (z->lists[oldest].list) fz_drop_display_list(z->ctx, z->lists[oldest].list);
	z->lists[oldest].list = l;
	z->lists[oldest].page = page;
	z->lists[oldest].age = z->tick;
	return l;
}

int zr_page_bounds(zr_doc *z, int page, float *r)
{
	int rc = 0;
	fz_try(z->ctx) {
		fz_rect b = fz_bound_display_list(z->ctx, get_list(z, page));
		r[0] = b.x0; r[1] = b.y0; r[2] = b.x1; r[3] = b.y1;
	}
	fz_catch(z->ctx) {
		fz_report_error(z->ctx);
		r[0] = r[1] = 0; r[2] = 612; r[3] = 792;
		rc = -1;
	}
	return rc;
}

static void skip_image(fz_context *ctx, fz_device *dev, fz_image *img, fz_matrix ctm, float alpha, fz_color_params cp) {}
static void skip_image_mask(fz_context *ctx, fz_device *dev, fz_image *img, fz_matrix ctm, fz_colorspace *cs, const float *color, float alpha, fz_color_params cp) {}

static void maybe_skip_images(fz_device *dev, int no_images)
{
	if (no_images) {
		dev->fill_image = skip_image;
		dev->fill_image_mask = skip_image_mask;
	}
}

static int mrc_fast(fz_context *ctx, fz_display_list *l, fz_matrix m, fz_device *dev, unsigned char *out, int stride, int w, int h, double page_area, fz_rect *bbox);
int zr_ink_bbox_flags(zr_doc *z, int page, float *r, int no_images, int flags);
int zr_ink_bbox(zr_doc *z, int page, float *r, int no_images) { return zr_ink_bbox_flags(z,page,r,no_images,0); }
/* flags bit1 (clean scans): MRC scan pages take the bounding box of their 1-bit text mask, without decoding the JPEG 2000 layers. */
int zr_ink_bbox_flags(zr_doc *z, int page, float *r, int no_images, int flags)
{
	fz_context *ctx = z->ctx;
	fz_pixmap *pix = NULL;
	fz_device *dev = NULL;
	int rc = 0;
	fz_var(pix);
	fz_var(dev);
	fz_try(ctx) {
		fz_display_list *l = get_list(z, page);
		fz_rect bounds = fz_bound_display_list(ctx, l);
		fz_rect mb;
		if ((flags & 2) && !no_images && !fz_is_empty_rect(bounds) &&
		    mrc_fast(ctx,l,fz_identity,NULL,NULL,0,(int)ceilf(bounds.x1),(int)ceilf(bounds.y1),(double)(bounds.x1-bounds.x0)*(bounds.y1-bounds.y0),&mb)) {
			if (!fz_is_empty_rect(mb)) { mb.x0-=6; mb.y0-=6; mb.x1+=6; mb.y1+=6; }
			fz_rect out = fz_is_empty_rect(mb) ? bounds : fz_intersect_rect(mb, bounds);
			r[0]=out.x0; r[1]=out.y0; r[2]=out.x1; r[3]=out.y1;
			break;
		}
		const float s = 0.5f;
		fz_matrix m = fz_scale(s, s);
		fz_irect ib = fz_round_rect(fz_transform_rect(bounds, m));
		pix = fz_new_pixmap_with_bbox(ctx, fz_device_gray(ctx), ib, NULL, 0);
		fz_clear_pixmap_with_value(ctx, pix, 255);
		dev = fz_new_draw_device(ctx, fz_identity, pix);
		maybe_skip_images(dev, no_images);
		fz_run_display_list(ctx, l, dev, m, fz_infinite_rect, &z->cookie);
		fz_close_device(ctx, dev);
		int w = pix->w, h = pix->h, x0 = w, y0 = h, x1 = -1, y1 = -1;
		for (int y = 0; y < h; y++) {
			const unsigned char *row = pix->samples + (size_t)y * pix->stride;
			for (int x = 0; x < w; x++) {
				if (row[x] < 200) {
					if (x < x0) x0 = x;
					if (x > x1) x1 = x;
					if (y < y0) y0 = y;
					if (y > y1) y1 = y;
				}
			}
		}
		fz_rect out = bounds;
		if (x1 > x0 && y1 > y0) {
			const float pad = 6.0f;
			out.x0 = (ib.x0 + x0) / s - pad;
			out.y0 = (ib.y0 + y0) / s - pad;
			out.x1 = (ib.x0 + x1 + 1) / s + pad;
			out.y1 = (ib.y0 + y1 + 1) / s + pad;
			out = fz_intersect_rect(out, bounds);
		}
		r[0] = out.x0; r[1] = out.y0; r[2] = out.x1; r[3] = out.y1;
	}
	fz_always(ctx) {
		fz_drop_device(ctx, dev);
		fz_drop_pixmap(ctx, pix);
	}
	fz_catch(ctx) {
		fz_report_error(ctx);
		rc = -1;
	}
	return rc;
}

#define IMAGE_CELL 32
#define IMAGE_GRID_MAX 128
/* Only this pass-through layer observes image draw operations. Text remains
 * MuPDF's 8-bit antialiasing and is never quantized by a whole-page filter. */
/* v0.9.2 "Clean up scanned pages". A page counts as scanned only when ALL hold:
 *  - its FIRST drawing operation is an opaque, axis-aligned raster image,
 *  - that image covers >= 85% of the page area on screen,
 *  - everything else drawn on the page is raster too: further images or image
 *    masks (separated text/background scans); any visible text, vector path,
 *    shading, soft mask, group or tile disqualifies it (invisible OCR text is fine),
 *  - the image is paper-dominant: >= 35% of its pixels lie within +-14 levels of
 *    the most common level, and that level is light (>= 96).
 * The image is held back (not yet dithered) while it is a candidate. Any later
 * drawing operation first finishes it exactly as the cleanup-off path would, so
 * every non-scanned page is byte-identical with the setting on or off.
 * For a scanned page: levels stretch (92nd percentile -> white, 1st percentile
 * -> black, gamma 1.25 to keep stroke weight), then the normal 16-level ordered
 * dithering of image pixels. */
typedef struct {
    fz_device super;
    unsigned char *out;
    int w, h, stride, dither, clean, cleaned, image_count, ops, layered, rerender;
    int depth, nonraster, gseen, gcand; fz_irect grect;
    double page_area;
    unsigned char *pend_before; fz_irect pend_r;
    unsigned char cells[IMAGE_GRID_MAX * IMAGE_GRID_MAX];
} zr_image_device;

static void image_footprint(zr_image_device *d, fz_matrix m, float alpha)
{
    if (alpha <= 0) return;
    fz_rect r = fz_intersect_rect(fz_transform_rect(fz_unit_rect, m), fz_make_rect(0,0,d->w,d->h));
    if (fz_is_empty_rect(r)) return;
    d->image_count++;
    int x0 = (int)r.x0 / IMAGE_CELL, y0 = (int)r.y0 / IMAGE_CELL;
    int x1 = ((int)ceilf(r.x1) + IMAGE_CELL - 1) / IMAGE_CELL;
    int y1 = ((int)ceilf(r.y1) + IMAGE_CELL - 1) / IMAGE_CELL;
    for (int y=y0; y<y1 && y<IMAGE_GRID_MAX; y++)
        for (int x=x0; x<x1 && x<IMAGE_GRID_MAX; x++) d->cells[y*IMAGE_GRID_MAX+x] = 1;
}
static void dither_rect(zr_image_device *d, fz_irect r, const unsigned char *before)
{
    static const unsigned char bayer[4][4]={{0,8,2,10},{12,4,14,6},{3,11,1,9},{15,7,13,5}};
    int rw=r.x1-r.x0;
    for (int y=r.y0; y<r.y1; y++) {
        unsigned char *row = d->out + (size_t)y*d->stride;
        for (int x=r.x0; x<r.x1; x++) {
            unsigned v=row[x];
            if (v==before[(size_t)(y-r.y0)*rw+x-r.x0]) continue;
            unsigned q=v/17, rem=v%17;
            if (q<15 && rem*16 > bayer[y&3][x&3]*17+8) q++;
            row[x]=(unsigned char)(q*17);
        }
    }
}
static int scan_cleanup(unsigned char *out, int stride, fz_irect r, const unsigned char *before)
{
    int rw=r.x1-r.x0;
    unsigned hist[256]={0}; size_t n=0;
    for (int y=r.y0; y<r.y1; y+=2) {
        const unsigned char *row=out+(size_t)y*stride;
        for (int x=r.x0; x<r.x1; x+=2) {
            if (row[x]==before[(size_t)(y-r.y0)*rw+x-r.x0] && row[x]==255) continue;
            hist[row[x]]++; n++;
        }
    }
    if (n < 1000) return 0;
    size_t acc=0; int ink=0, paper=255, mode=0;
    for (int v=0; v<256; v++) { acc+=hist[v]; if (acc*1000 < n*2) ink=v; if (acc*100 < n*92) paper=v; }
    for (int v=1; v<256; v++) if (hist[v]>hist[mode]) mode=v;
    size_t near=0; for (int v=mode-14; v<=mode+14; v++) if (v>=0 && v<256) near+=hist[v];
    if (near*100 < n*35 || mode < 96) return 0;
    if (paper < mode) paper = mode;
    if (ink > mode - 100) ink = mode - 100;  /* sparse text: never treat light grays as ink */
    if (ink > paper - 64) ink = paper - 64;
    if (ink < 0) ink = 0;
    if (paper >= 251 && ink <= 4) return 0; /* already clean black on white */
    /* Local paper level: 90th percentile per 64x64 tile, bilinear between tile
     * centres, so uneven yellowing, vignettes and stains all map to white. */
    enum { TS = 64 };
    int rh=r.y1-r.y0, gw=(rw+TS-1)/TS, gh=(rh+TS-1)/TS;
    int floor_bg = mode - 60 > ink + 48 ? mode - 60 : ink + 48;
    if (gw < 2 || gh < 2) return 0;
    short *bg=malloc(sizeof(short)*(size_t)gw*gh); int *gx0=malloc(sizeof(int)*(size_t)rw); short *wx=malloc(sizeof(short)*(size_t)rw);
    if (!bg || !gx0 || !wx) { free(bg); free(gx0); free(wx); return 0; }
    for (int ty=0; ty<gh; ty++) for (int tx=0; tx<gw; tx++) {
        unsigned th[256]={0}; unsigned tn=0;
        int y1=r.y0+(ty+1)*TS < r.y1 ? r.y0+(ty+1)*TS : r.y1, x1=r.x0+(tx+1)*TS < r.x1 ? r.x0+(tx+1)*TS : r.x1;
        for (int y=r.y0+ty*TS; y<y1; y+=2) { const unsigned char *row=out+(size_t)y*stride; for (int x=r.x0+tx*TS; x<x1; x+=2) { th[row[x]]++; tn++; } }
        unsigned c=0; int v90=255; for (int v=0; v<256; v++) { c+=th[v]; if (c*10 >= tn*9) { v90=v; break; } }
        if (v90 < floor_bg) v90 = floor_bg;
        bg[ty*gw+tx]=(short)(v90-8);       /* headroom: paper grain clips to white */
    }
    for (int x=0; x<rw; x++) { int f=(x-TS/2)*256/TS; int g=f<0?0:f>>8; if (g>gw-2) g=gw-2; gx0[x]=g; wx[x]=(short)(f-(g<<8)); }
    unsigned char lut[1025];
    for (int i=0; i<=1024; i++) lut[i]=(unsigned char)(powf(i/1024.f,1.25f)*255.f+0.5f);
    for (int y=r.y0; y<r.y1; y++) {
        int f=(y-r.y0-TS/2)*256/TS; int g=f<0?0:f>>8; if (g>gh-2) g=gh-2; int wy=f-(g<<8); int g1=g+1;
        const short *b0=bg+g*gw, *b1=bg+g1*gw;
        unsigned char *row=out+(size_t)y*stride;
        const unsigned char *bf = before+(size_t)(y-r.y0)*rw;
        for (int x=0; x<rw; x++) {
            unsigned char v=row[r.x0+x];
            if (v==bf[x]) continue;
            int c0=gx0[x], c1=c0+1, w=wx[x];
            int top=b0[c0]*(256-w)+b0[c1]*w, bot=b1[c0]*(256-w)+b1[c1]*w;
            int pb=(top*(256-wy)+bot*wy)/65536; if (pb>247) pb=247; if (pb<floor_bg-8) pb=floor_bg-8;
            int den=pb-ink; if (den<16) den=16;
            int t=(v-ink)*1024/den; if (t<0) t=0; if (t>1024) t=1024;
            row[r.x0+x]=lut[t];
        }
    }
    free(bg); free(gx0); free(wx);
    return 1;
}
/* Finishes a held-back candidate exactly like the cleanup-off path. */
static void flush_pending(zr_image_device *d)
{
    if (!d->pend_before) return;
    if (d->dither) dither_rect(d,d->pend_r,d->pend_before);
    free(d->pend_before); d->pend_before=NULL;
}
static void drop_pending(zr_image_device *d){ free(d->pend_before); d->pend_before=NULL; }
static void finish_page(zr_image_device *d)
{
    if (!d->pend_before && d->gcand && !d->nonraster && d->depth == 0) {
        fz_irect r=d->grect; size_t n=(size_t)(r.x1-r.x0)*(r.y1-r.y0);
        unsigned char *white=malloc(n);
        if (white) {
            memset(white,255,n);
            if (scan_cleanup(d->out,d->stride,r,white)) { d->cleaned=1; if (d->dither) dither_rect(d,r,white); }
            free(white);
        }
        return;
    }
    if (!d->pend_before) return;
    if (scan_cleanup(d->out,d->stride,d->pend_r,d->pend_before)) { d->cleaned=1; flush_pending(d); return; }
    if (d->layered) { d->rerender=1; drop_pending(d); return; } /* layers were drawn over an undithered base */
    flush_pending(d);
}
/* A non-raster drawing operation: the page is not a scan. */
static void note_op(zr_image_device *d)
{
    d->nonraster=1;
    if (d->pend_before && d->layered) { d->rerender=1; drop_pending(d); }
    else flush_pending(d);
    d->ops++;
}
static void image_fill(fz_context *ctx, fz_device *dev, fz_image *img, fz_matrix m, float alpha, fz_color_params cp)
{
    zr_image_device *d = (zr_image_device *)dev;
    if (d->depth > 0) {
        /* Inside a transparency group the draw device renders into a group
         * buffer, so nothing is held back here; a raster-only page is finished
         * after the group has been composited (see finish_page). */
        d->ops++; image_footprint(d,m,alpha);
        fz_irect gr = fz_round_rect(fz_intersect_rect(fz_transform_rect(fz_unit_rect,m),fz_make_rect(0,0,d->w,d->h)));
        if (!d->gseen && d->clean && alpha == 1 && !img->mask && m.b == 0 && m.c == 0 && d->page_area > 0 &&
            (double)(gr.x1-gr.x0)*(gr.y1-gr.y0) >= 0.85*d->page_area) { d->gcand=1; d->grect=gr; }
        d->gseen=1;
        fz_fill_image(ctx,dev->passthrough,img,m,alpha,cp);
        return;
    }
    if (d->pend_before) {
        /* Further raster layer on a scan candidate (e.g. separated text/background
         * scans): drawn as-is; the whole page is finished at the end. */
        d->layered=1; d->ops++; image_footprint(d,m,alpha);
        fz_fill_image(ctx,dev->passthrough,img,m,alpha,cp);
        return;
    }
    int first = d->ops == 0;
    d->ops++;
    image_footprint(d,m,alpha);
    fz_irect r = fz_round_rect(fz_intersect_rect(fz_transform_rect(fz_unit_rect,m),fz_make_rect(0,0,d->w,d->h)));
    int rw=r.x1-r.x0, rh=r.y1-r.y0;
    int simple = alpha == 1 && !img->mask && m.b == 0 && m.c == 0 && rw>0 && rh>0;
    int candidate = d->clean && simple && first && d->page_area > 0 && (double)rw*rh >= 0.85*d->page_area;
    unsigned char *before=NULL;
    fz_var(before);
    /* Retain the rectangle before this draw. Pixels untouched by this image
     * (including anything excluded by PDF clips) MUST stay unchanged. */
    if ((d->dither || candidate) && simple) {
        before=malloc((size_t)rw*rh);
        if (before) for (int y=0; y<rh; y++) memcpy(before+(size_t)y*rw,d->out+(size_t)(r.y0+y)*d->stride+r.x0,rw);
    }
    fz_try(ctx) {
        fz_fill_image(ctx,dev->passthrough,img,m,alpha,cp);
        if (before && candidate) { d->pend_before=before; d->pend_r=r; before=NULL; }
        else if (before && d->dither) dither_rect(d,r,before);
    }
    fz_always(ctx) free(before);
    fz_catch(ctx) fz_rethrow(ctx);
}
static void image_mask_fill(fz_context *ctx, fz_device *dev, fz_image *img, fz_matrix m,
    fz_colorspace *cs, const float *color, float alpha, fz_color_params cp)
{
    zr_image_device *d = (zr_image_device *)dev;
    if (d->pend_before) { d->layered=1; d->ops++; }
    else if (d->depth > 0) d->ops++;
    else note_op(d);
    image_footprint(d,m,alpha);
    fz_fill_image_mask(ctx,dev->passthrough,img,m,cs,color,alpha,cp);
}
static void op_fill_path(fz_context *ctx, fz_device *dev, const fz_path *p, int eo, fz_matrix m, fz_colorspace *cs, const float *c, float a, fz_color_params cp)
{ note_op((zr_image_device *)dev); fz_fill_path(ctx,dev->passthrough,p,eo,m,cs,c,a,cp); }
static void op_stroke_path(fz_context *ctx, fz_device *dev, const fz_path *p, const fz_stroke_state *st, fz_matrix m, fz_colorspace *cs, const float *c, float a, fz_color_params cp)
{ note_op((zr_image_device *)dev); fz_stroke_path(ctx,dev->passthrough,p,st,m,cs,c,a,cp); }
static void op_fill_text(fz_context *ctx, fz_device *dev, const fz_text *t, fz_matrix m, fz_colorspace *cs, const float *c, float a, fz_color_params cp)
{ note_op((zr_image_device *)dev); fz_fill_text(ctx,dev->passthrough,t,m,cs,c,a,cp); }
static void op_stroke_text(fz_context *ctx, fz_device *dev, const fz_text *t, const fz_stroke_state *st, fz_matrix m, fz_colorspace *cs, const float *c, float a, fz_color_params cp)
{ note_op((zr_image_device *)dev); fz_stroke_text(ctx,dev->passthrough,t,st,m,cs,c,a,cp); }
static void op_fill_shade(fz_context *ctx, fz_device *dev, fz_shade *sh, fz_matrix m, float a, fz_color_params cp)
{ note_op((zr_image_device *)dev); fz_fill_shade(ctx,dev->passthrough,sh,m,a,cp); }
static void op_begin_mask(fz_context *ctx, fz_device *dev, fz_rect area, int lum, fz_colorspace *cs, const float *bc, fz_color_params cp)
{ note_op((zr_image_device *)dev); fz_begin_mask(ctx,dev->passthrough,area,lum,cs,bc,cp); }
/* A plain group (normal blend, opaque) is neutral; anything else disqualifies the page. */
static void op_begin_group(fz_context *ctx, fz_device *dev, fz_rect area, fz_colorspace *cs, int iso, int ko, int bm, float a)
{
    zr_image_device *d=(zr_image_device *)dev;
    if (d->pend_before || bm != 0 || a != 1 || d->ops > 0) note_op(d);
    d->depth++;
    fz_begin_group(ctx,dev->passthrough,area,cs,iso,ko,bm,a);
}
static void op_end_group(fz_context *ctx, fz_device *dev)
{
    zr_image_device *d=(zr_image_device *)dev;
    if (d->depth > 0) d->depth--;
    fz_end_group(ctx,dev->passthrough);
}
static int op_begin_tile(fz_context *ctx, fz_device *dev, fz_rect area, fz_rect view, float xs, float ys, fz_matrix m, int id, int doc_id)
{ note_op((zr_image_device *)dev); return fz_begin_tile_tid(ctx,dev->passthrough,area,view,xs,ys,m,id,doc_id); }

/* ---- v0.9.3 fast path for MRC scans (e.g. Internet Archive PDFs) ----
 * Such a page is exactly two images: a low-resolution background (paper) and a
 * full-page foreground whose soft mask is a 1-bit (JBIG2/bitonal) image holding
 * the printed text. With "Clean up scanned pages" on, and only when the
 * background is plain paper and the foreground colour is near-uniform dark, the
 * page is drawn as white paper plus the 1-bit mask in solid black. Neither JPEG
 * 2000 layer is decoded at full size (only tiny reduced-resolution previews for
 * the checks). Anything else on the page (visible text, vectors, shadings, soft
 * masks, other images, blended groups) means it is not such a page. */
int zr_mrc_debug;
typedef struct { fz_device super; int n, other, nclip; fz_image *clip; fz_image *img[2]; fz_matrix m[2]; float a[2]; } mrc_dev;
static void mrc_other_(mrc_dev *d, const char *w){ if (zr_mrc_debug && !d->other) fprintf(stderr,"mrc: other=%s\n",w); d->other=1; }
#define mrc_other(d) mrc_other_(d,__func__)
static void mrc_fill_path(fz_context *c, fz_device *d, const fz_path *p, int eo, fz_matrix m, fz_colorspace *cs, const float *col, float a, fz_color_params cp){ mrc_other((mrc_dev*)d); }
static void mrc_stroke_path(fz_context *c, fz_device *d, const fz_path *p, const fz_stroke_state *st, fz_matrix m, fz_colorspace *cs, const float *col, float a, fz_color_params cp){ mrc_other((mrc_dev*)d); }
static void mrc_fill_text(fz_context *c, fz_device *d, const fz_text *t, fz_matrix m, fz_colorspace *cs, const float *col, float a, fz_color_params cp){ mrc_other((mrc_dev*)d); }
static void mrc_stroke_text(fz_context *c, fz_device *d, const fz_text *t, const fz_stroke_state *st, fz_matrix m, fz_colorspace *cs, const float *col, float a, fz_color_params cp){ mrc_other((mrc_dev*)d); }
static void mrc_fill_shade(fz_context *c, fz_device *d, fz_shade *sh, fz_matrix m, float a, fz_color_params cp){ mrc_other((mrc_dev*)d); }
static void mrc_fill_image_mask(fz_context *c, fz_device *d, fz_image *img, fz_matrix m, fz_colorspace *cs, const float *col, float a, fz_color_params cp){ mrc_other((mrc_dev*)d); }
/* MuPDF may draw a soft-masked image as a clip by its 1-bit mask; recorded, then checked against the foreground's mask. */
static void mrc_clip_image_mask(fz_context *c, fz_device *dev, fz_image *img, fz_matrix m, fz_rect sc)
{ mrc_dev *d=(mrc_dev*)dev; if (d->nclip++ || d->n != 1) { mrc_other(d); return; } d->clip=fz_keep_image(c,img); }
static void mrc_begin_mask(fz_context *c, fz_device *d, fz_rect area, int lum, fz_colorspace *cs, const float *bc, fz_color_params cp){ mrc_other((mrc_dev*)d); }
static void mrc_begin_group(fz_context *c, fz_device *d, fz_rect area, fz_colorspace *cs, int iso, int ko, int bm, float a){ if (bm != 0 || a != 1) mrc_other((mrc_dev*)d); }
static int mrc_begin_tile(fz_context *c, fz_device *d, fz_rect area, fz_rect view, float xs, float ys, fz_matrix m, int id, int doc_id){ mrc_other((mrc_dev*)d); return 1; }
static void mrc_fill_image(fz_context *c, fz_device *dev, fz_image *img, fz_matrix m, float a, fz_color_params cp)
{
    mrc_dev *d=(mrc_dev*)dev;
    if (d->n >= 2) { d->other=1; return; }
    d->img[d->n]=fz_keep_image(c,img); d->m[d->n]=m; d->a[d->n]=a; d->n++;
}
static int covers(fz_matrix m, int w, int h, double page_area)
{
    if (m.b != 0 || m.c != 0 || page_area <= 0) return 0;
    fz_rect r=fz_intersect_rect(fz_transform_rect(fz_unit_rect,m),fz_make_rect(0,0,w,h));
    return !fz_is_empty_rect(r) && (double)(r.x1-r.x0)*(r.y1-r.y0) >= 0.85*page_area;
}
static int lum_at(const fz_pixmap *p, int x, int y)
{
    const unsigned char *s=p->samples+(size_t)y*p->stride+(size_t)x*p->n;
    int nc=p->n-p->alpha;
    return nc>=3 ? (s[0]*77+s[1]*150+s[2]*29)>>8 : s[0];
}
/* Reduced-resolution luminance preview (caller frees). JPEG 2000 goes through
 * OpenJPEG's resolution factor; other formats through MuPDF's subsampling. */
unsigned char *zr_jpx_small_lum(fz_context *ctx, const unsigned char *data, size_t size, int target, int *ow, int *oh);
unsigned char *zr_jpx_small_lum2(fz_context *ctx, const unsigned char *data, size_t size, int tw, int th, int *ow, int *oh);
static unsigned char *small_lum(fz_context *ctx, fz_image *img, int target, int *ow, int *oh)
{
    fz_compressed_buffer *cb=fz_compressed_image_buffer(ctx,img);
    if (cb && cb->params.type == FZ_IMAGE_JPX) {
        if (!cb->buffer) return NULL;
        return zr_jpx_small_lum(ctx,cb->buffer->data,cb->buffer->len,target,ow,oh);
    }
    int w=img->w, h=img->h;
    while (w > target*2 && h > target*2) { w/=2; h/=2; }
    fz_pixmap *p=fz_get_pixmap_from_image(ctx,img,NULL,NULL,&w,&h);
    unsigned char *out=malloc((size_t)p->w*p->h);
    if (out) { for (int y=0;y<p->h;y++) for (int x=0;x<p->w;x++) out[(size_t)y*p->w+x]=(unsigned char)lum_at(p,x,y); *ow=p->w; *oh=p->h; }
    fz_drop_pixmap(ctx,p);
    return out;
}
/* Returns 1 when the page was drawn by the fast path. */
static int mrc_fast(fz_context *ctx, fz_display_list *l, fz_matrix m, fz_device *dev, unsigned char *out, int stride, int w, int h, double page_area, fz_rect *bbox)
{
    mrc_dev *d=NULL; unsigned char *bg=NULL, *fg=NULL; fz_pixmap *mk=NULL; int done=0, bw=0, bh=0, fw=0, fh=0;
    fz_var(d); fz_var(bg); fz_var(fg); fz_var(mk);
    fz_try(ctx) {
        d=fz_new_derived_device(ctx,mrc_dev);
        d->super.fill_path=mrc_fill_path; d->super.stroke_path=mrc_stroke_path;
        d->super.fill_text=mrc_fill_text; d->super.stroke_text=mrc_stroke_text;
        d->super.fill_shade=mrc_fill_shade; d->super.fill_image=mrc_fill_image;
        d->super.fill_image_mask=mrc_fill_image_mask; d->super.clip_image_mask=mrc_clip_image_mask;
        d->super.begin_mask=mrc_begin_mask; d->super.begin_group=mrc_begin_group; d->super.begin_tile=mrc_begin_tile;
        fz_run_display_list(ctx,l,&d->super,m,fz_make_rect(0,0,w,h),NULL);
        fz_close_device(ctx,&d->super);
        fz_image *b=d->n==2?d->img[0]:NULL, *f=d->n==2?d->img[1]:NULL;
        if (zr_mrc_debug) { fprintf(stderr,"mrc: n=%d other=%d",d->n,d->other); for(int i=0;i<d->n;i++) fprintf(stderr," [%dx%d mask=%p bpc=%d n=%d im=%d a=%g cov=%d]",d->img[i]->w,d->img[i]->h,(void*)d->img[i]->mask,d->img[i]->mask?d->img[i]->mask->bpc:0,d->img[i]->mask?d->img[i]->mask->n:0,d->img[i]->imagemask,d->a[i],covers(d->m[i],w,h,page_area)); fprintf(stderr,"\n"); }
        if (zr_mrc_debug && d->clip) fprintf(stderr,"mrc: clip %dx%d bpc=%d same=%d\n",d->clip->w,d->clip->h,d->clip->bpc,f&&d->clip==f->mask);
        if (!d->other && b && f && (!d->clip || d->clip == f->mask) && !b->mask && !b->imagemask && !f->imagemask && f->mask && f->mask->bpc == 1 && f->mask->n == 1 &&
            d->a[0] == 1 && d->a[1] == 1 && covers(d->m[0],w,h,page_area) && covers(d->m[1],w,h,page_area)) {
            /* background must be plain paper: tight luminance spread */
            bg=small_lum(ctx,b,96,&bw,&bh);
            int hist[256]={0}, n=0;
            if (bg) for (int i=0;i<bw*bh;i++) { hist[bg[i]]++; n++; }
            int mode=0; for (int v=1;v<256;v++) if (hist[v]>hist[mode]) mode=v;
            int lo=0,acc=0; while (lo<255 && (acc+=hist[lo])<n*2/100) lo++;
            int hi=255; acc=0; while (hi>0 && (acc+=hist[hi])<n*2/100) hi--;
            int near=0; for (int v=mode-20; v<=mode+20; v++) if (v>=0&&v<256) near+=hist[v];
            int paper = n > 0 && mode >= 48 && near >= n*80/100 && hi-lo <= 90;
            int dark=0, inkn=0, p90=0, p50=0;
            if (paper) {
                /* foreground colour where the mask has ink: must be near-uniform dark */
                mk=fz_get_pixmap_from_image(ctx,f->mask,NULL,NULL,NULL,NULL);
                fg=small_lum(ctx,f,160,&fw,&fh);
                int lh[256]={0};
                if (fg) for (int y=0;y<fh;y++) for (int x=0;x<fw;x++) {
                    int mx=(int)((x+0.5)*mk->w/fw), my=(int)((y+0.5)*mk->h/fh);
                    if (mk->samples[(size_t)my*mk->stride+(size_t)mx*mk->n] > 127) { lh[fg[(size_t)y*fw+x]]++; inkn++; }
                }
                p50=0; acc=0; while (p50<255 && (acc+=lh[p50])<inkn/2) p50++;
                p90=0; acc=0; while (p90<255 && (acc+=lh[p90])<inkn*90/100) p90++;
                dark = inkn == 0 || p50 <= 110;  /* mostly dark print; otherwise (e.g. a colour picture in the foreground) render normally */
                if (zr_mrc_debug) fprintf(stderr,"mrc: ink_p90=%d inkn=%d\n",p90,inkn);
            }
            if (zr_mrc_debug) fprintf(stderr,"mrc: bg %dx%d fg %dx%d mode=%d near=%.2f spread=%d paper=%d dark=%d\n",bw,bh,fw,fh,mode,(double)near/n,hi-lo,paper,dark);
            if (paper && dark && bbox) {
                /* ink bounding box from the 1-bit mask (for trimmed views), without drawing */
                int x0=mk->w, y0=mk->h, x1=-1, y1=-1;
                for (int y=0;y<mk->h;y++) { const unsigned char *row=mk->samples+(size_t)y*mk->stride;
                    for (int x=0;x<mk->w;x++) if (row[(size_t)x*mk->n] > 127) { if (x<x0) x0=x; if (x>x1) x1=x; if (y<y0) y0=y; if (y>y1) y1=y; } }
                if (x1 >= x0 && y1 >= y0) *bbox=fz_transform_rect(fz_make_rect((float)x0/mk->w,(float)y0/mk->h,(float)(x1+1)/mk->w,(float)(y1+1)/mk->h),d->m[1]);
                else *bbox=fz_empty_rect;
                done=1;
            } else if (paper && dark) {
                float black=0;
                fz_fill_image_mask(ctx,dev,f->mask,d->m[1],fz_device_gray(ctx),&black,1,fz_default_color_params);
                fz_close_device(ctx,dev);
                /* Keep light foreground areas light (e.g. a pale box behind dark words):
                 * ink is scaled by the foreground darkness, from a smoothed preview.
                 * Mapped between the page's ink level and its paper level. */
                int lo_t=p50+(mode-p50)*50/100, hi_t=p50+(mode-p50)*85/100;
                if (fg && inkn && mode > p50+16 && p90 > lo_t-4) {
                    fz_rect r=fz_intersect_rect(fz_transform_rect(fz_unit_rect,d->m[1]),fz_make_rect(0,0,w,h));
                    fz_irect ir=fz_round_rect(r); fz_rect fr=fz_transform_rect(fz_unit_rect,d->m[1]);
                    unsigned char lut[256];
                    for (int v=0;v<256;v++) lut[v]= v<=lo_t ? 0 : v>=hi_t ? 255 : (unsigned char)((v-lo_t)*255/(hi_t-lo_t));
                    for (int y=ir.y0;y<ir.y1;y++) {
                        unsigned char *row=out+(size_t)y*stride;
                        double fy=((y+0.5)-fr.y0)/(fr.y1-fr.y0)*fh-0.5; if (fy<0) fy=0; if (fy>fh-1) fy=fh-1;
                        int y0=(int)fy, y1=y0+1<fh?y0+1:y0; int wy=(int)((fy-y0)*256);
                        for (int x=ir.x0;x<ir.x1;x++) {
                            if (row[x]==255) continue;
                            double fx=((x+0.5)-fr.x0)/(fr.x1-fr.x0)*fw-0.5; if (fx<0) fx=0; if (fx>fw-1) fx=fw-1;
                            int x0=(int)fx, x1=x0+1<fw?x0+1:x0; int wx=(int)((fx-x0)*256);
                            const unsigned char *a=fg+(size_t)y0*fw, *b2=fg+(size_t)y1*fw;
                            int top=a[x0]*(256-wx)+a[x1]*wx, bot2=b2[x0]*(256-wx)+b2[x1]*wx;
                            int t=lut[(top*(256-wy)+bot2*wy)>>16];
                            row[x]=(unsigned char)(255-(255-row[x])*(255-t)/255);
                        }
                    }
                }
                done=1;
            }
        }
    }
    fz_always(ctx) {
        if (d) { for (int i=0;i<d->n;i++) fz_drop_image(ctx,d->img[i]); fz_drop_image(ctx,d->clip); fz_drop_device(ctx,&d->super); }
        free(bg); free(fg); fz_drop_pixmap(ctx,mk);
    }
    fz_catch(ctx) { fz_report_error(ctx); done=0; }
    return done;
}

/* ---- v0.9.4: single full-page JPEG 2000 scans ----
 * A page that is exactly one opaque full-page JPEG 2000 image (no mask, nothing
 * else visible) whose resolution is at least twice the screen footprint is
 * decoded at a reduced resolution that still covers the footprint (OpenJPEG
 * resolution factor), instead of MuPDF's full-size decode followed by
 * downscaling. Only with "Clean up scanned pages" on, and only when the reduced
 * image is paper-dominant (the same test the cleanup uses), so covers, photos
 * and digital pages are never affected. The reduced image then goes through the
 * normal scan cleanup. */
static int jpx_single(fz_context *ctx, fz_display_list *l, fz_matrix m, zr_image_device *images, int w, int h)
{
    mrc_dev *d=NULL; unsigned char *lum=NULL; fz_pixmap *pix=NULL; fz_image *im=NULL; int done=0, bw=0, bh=0;
    fz_var(d); fz_var(lum); fz_var(pix); fz_var(im);
    fz_try(ctx) {
        d=fz_new_derived_device(ctx,mrc_dev);
        d->super.fill_path=mrc_fill_path; d->super.stroke_path=mrc_stroke_path;
        d->super.fill_text=mrc_fill_text; d->super.stroke_text=mrc_stroke_text;
        d->super.fill_shade=mrc_fill_shade; d->super.fill_image=mrc_fill_image;
        d->super.fill_image_mask=mrc_fill_image_mask; d->super.clip_image_mask=mrc_clip_image_mask;
        d->super.begin_mask=mrc_begin_mask; d->super.begin_group=mrc_begin_group; d->super.begin_tile=mrc_begin_tile;
        fz_run_display_list(ctx,l,&d->super,m,fz_make_rect(0,0,w,h),NULL);
        fz_close_device(ctx,&d->super);
        fz_image *b = d->n==1 ? d->img[0] : NULL;
        fz_compressed_buffer *cb = b ? fz_compressed_image_buffer(ctx,b) : NULL;
        if (!d->other && !d->clip && b && !b->mask && !b->imagemask && d->a[0] == 1 && cb && cb->buffer &&
            cb->params.type == FZ_IMAGE_JPX && covers(d->m[0],w,h,images->page_area)) {
            fz_rect r=fz_intersect_rect(fz_transform_rect(fz_unit_rect,d->m[0]),fz_make_rect(0,0,w,h));
            int tw=(int)ceilf(r.x1-r.x0), th=(int)ceilf(r.y1-r.y0);
            if (tw > 0 && th > 0 && b->w >= 2*tw && b->h >= 2*th) {
                lum=zr_jpx_small_lum2(ctx,cb->buffer->data,cb->buffer->len,tw,th,&bw,&bh);
                if (lum && bw < b->w) {
                    int hist[256]={0}, n=bw*bh;
                    for (int i=0;i<n;i++) hist[lum[i]]++;
                    int mode=0; for (int v=1;v<256;v++) if (hist[v]>hist[mode]) mode=v;
                    int near=0; for (int v=mode-14; v<=mode+14; v++) if (v>=0&&v<256) near+=hist[v];
                    if (mode >= 96 && near*100 >= n*35) {
                        pix=fz_new_pixmap(ctx,fz_device_gray(ctx),bw,bh,NULL,0);
                        for (int y=0;y<bh;y++) memcpy(pix->samples+(size_t)y*pix->stride,lum+(size_t)y*bw,bw);
                        im=fz_new_image_from_pixmap(ctx,pix,NULL);
                        images->super.fill_image(ctx,&images->super,im,d->m[0],1,fz_default_color_params);
                        done=1;
                    }
                }
            }
        }
    }
    fz_always(ctx) {
        if (d) { for (int i=0;i<d->n;i++) fz_drop_image(ctx,d->img[i]); fz_drop_image(ctx,d->clip); fz_drop_device(ctx,&d->super); }
        free(lum); fz_drop_image(ctx,im); fz_drop_pixmap(ctx,pix);
    }
    fz_catch(ctx) { fz_report_error(ctx); done=0; }
    return done;
}

int zr_render_with_stats(zr_doc *z, int page, const float *m6, unsigned char *out, int w, int h, int stride,
    int no_images, int image_dither, zr_render_stats *stats)
{
	fz_context *ctx = z->ctx;
	fz_pixmap *pix = NULL;
	fz_device *dev = NULL;
    zr_image_device *images = NULL;
    if (stats) memset(stats,0,sizeof *stats);
	int rc = 0, rerender = 0, mrc = 0;
	fz_var(mrc);
	fz_var(pix);
	fz_var(dev);
    fz_var(images);
	for (int y = 0; y < h; y++) memset(out + (size_t)y * stride, 0xFF, w);
	fz_try(ctx) {
		fz_display_list *l = get_list(z, page);
		fz_matrix m = fz_make_matrix(m6[0], m6[1], m6[2], m6[3], m6[4], m6[5]);
		pix = fz_new_pixmap_with_data(ctx, fz_device_gray(ctx), w, h, NULL, 0, stride, out);
		dev = fz_new_draw_device(ctx, fz_identity, pix);
        if (!no_images && (stats || image_dither)) {
            images = fz_new_derived_passthrough_device(ctx,dev,zr_image_device);
            images->out=out; images->w=w; images->h=h; images->stride=stride; images->dither=image_dither&1; images->clean=(image_dither>>1)&1;
            if (images->clean) {
                fz_rect pr=fz_intersect_rect(fz_transform_rect(fz_bound_display_list(ctx,l),m),fz_make_rect(0,0,w,h));
                images->page_area=fz_is_empty_rect(pr)?0:(double)(pr.x1-pr.x0)*(pr.y1-pr.y0);
                images->super.fill_path=op_fill_path; images->super.stroke_path=op_stroke_path;
                images->super.fill_text=op_fill_text; images->super.stroke_text=op_stroke_text;
                images->super.fill_shade=op_fill_shade; images->super.begin_mask=op_begin_mask;
                images->super.begin_group=op_begin_group; images->super.end_group=op_end_group; images->super.begin_tile=op_begin_tile;
            }
            images->super.fill_image=image_fill;
            images->super.fill_image_mask=image_mask_fill;
        }
        maybe_skip_images(dev, no_images);
        fz_device *draw = images ? &images->super : dev;
        if (images && images->clean && mrc_fast(ctx,l,m,dev,out,stride,w,h,images->page_area,NULL)) {
            images->cleaned=1; images->image_count=2; mrc=1; /* drawn as text ink: no image area */
        } else if (!(images && images->clean && jpx_single(ctx,l,m,images,w,h)))
        fz_run_display_list(ctx, l, draw, m, fz_make_rect(0, 0, w, h), &z->cookie);
        if (images && !mrc) { finish_page(images); rerender = images->rerender; }
        fz_close_device(ctx, draw);
        if (stats && images) {
            size_t area=0;
            for (int y=0; y<IMAGE_GRID_MAX && y*IMAGE_CELL<h; y++)
                for (int x=0; x<IMAGE_GRID_MAX && x*IMAGE_CELL<w; x++)
                    if (images->cells[y*IMAGE_GRID_MAX+x]) {
                        int cw=w-x*IMAGE_CELL, ch=h-y*IMAGE_CELL;
                        area+=(size_t)(cw<IMAGE_CELL?cw:IMAGE_CELL)*(ch<IMAGE_CELL?ch:IMAGE_CELL);
                    }
            stats->image_coverage=(float)area/((float)w*h);
            stats->image_count=images->image_count;
            stats->cleaned=images->cleaned;
        }
	}
	fz_always(ctx) {
        if (images) { free(images->pend_before); images->pend_before=NULL; }
        fz_drop_device(ctx, images ? &images->super : NULL);
		fz_drop_device(ctx, dev);
		fz_drop_pixmap(ctx, pix);
	}
	fz_catch(ctx) {
		fz_report_error(ctx);
		rc = -1;
	}
    if (rc == 0 && rerender) {
        /* Rare: a layered candidate turned out not to be a scan. Render again
         * exactly as with the setting off so digital pages never change. */
        return zr_render_with_stats(z,page,m6,out,w,h,stride,no_images,image_dither&1,stats);
    }
	return rc;
}

/* Stable no-dither entry point retained for reference pixel comparisons. */
int zr_render(zr_doc *z, int page, const float *m6, unsigned char *out, int w, int h, int stride, int no_images)
{
    return zr_render_with_stats(z,page,m6,out,w,h,stride,no_images,0,NULL);
}

static void put_text(char *text, int cap, int *tl, int c)
{
	char tmp[8];
	int n = fz_runetochar(tmp, c);
	if (*tl + n < cap) {
		memcpy(text + *tl, tmp, n);
		*tl += n;
	}
}

static void words_block(fz_stext_block *b, zr_word *out, int max, char *text, int cap, int *n, int *tl, int *line)
{
	for (; b; b = b->next) {
		if (b->type == FZ_STEXT_BLOCK_STRUCT && b->u.s.down) {
			words_block(b->u.s.down->first_block, out, max, text, cap, n, tl, line);
			continue;
		}
		if (b->type != FZ_STEXT_BLOCK_TEXT) continue;
		for (fz_stext_line *ln = b->u.t.first_line; ln; ln = ln->next) {
			int in_word = 0;
			for (fz_stext_char *ch = ln->first_char; ch; ch = ch->next) {
				int space = ch->c == ' ' || ch->c == '\t' || ch->c == 0xA0;
				if (space) { in_word = 0; continue; }
				fz_rect r = fz_rect_from_quad(ch->quad);
				if (!in_word) {
					if (*n >= max) return;
					zr_word *w = &out[(*n)++];
					w->x0 = r.x0; w->y0 = r.y0; w->x1 = r.x1; w->y1 = r.y1;
					w->line = *line; w->off = *tl; w->len = 0;
					in_word = 1;
				} else {
					zr_word *w = &out[*n - 1];
					if (r.x0 < w->x0) w->x0 = r.x0;
					if (r.y0 < w->y0) w->y0 = r.y0;
					if (r.x1 > w->x1) w->x1 = r.x1;
					if (r.y1 > w->y1) w->y1 = r.y1;
				}
				int before = *tl;
				put_text(text, cap, tl, ch->c);
				out[*n - 1].len += *tl - before;
			}
			(*line)++;
		}
	}
}

/* Some calibre PDFs paint the initial before even the page heading. In stream
 * order a drag from that initial then selected the heading, chapter number and
 * location as well. Join an isolated, overlapping initial with its body word;
 * do not change any PDF drawing operations or publisher geometry. The selectable
 * rectangle is the body line, not the huge cap bbox covering several lines. */
static void join_colliding_initials(zr_word *out, int *count, char *text, int cap, int *tl)
{
    for (int i = 0; i < *count; i++) {
        zr_word initial = out[i];
        if (initial.len != 1 || text[initial.off] < 'A' || text[initial.off] > 'Z' ||
            initial.y1 - initial.y0 < 30) continue;
        int target = -1;
        float first_y = 1e30f;
        for (int j = 0; j < *count; j++) {
            zr_word *w = &out[j];
            if (j == i || w->y1 - w->y0 > (initial.y1 - initial.y0) * 0.55f ||
                w->y0 < initial.y0 || w->y0 >= initial.y1 ||
                w->x0 < initial.x0 - 2 || w->x0 > initial.x0 + 4 ||
                w->x0 >= initial.x1 || text[w->off] < 'A' || text[w->off] > 'Z') continue;
            if (w->y0 < first_y) { target = j; first_y = w->y0; }
        }
        if (target < 0 || *tl + 1 + out[target].len >= cap) continue;
        zr_word *w = &out[target];
        text[*tl] = text[initial.off];
        memcpy(text + *tl + 1, text + w->off, w->len);
        w->off = *tl;
        w->len++;
        *tl += w->len;
        memmove(out + i, out + i + 1, (*count - i - 1) * sizeof *out);
        (*count)--;
        i--;
    }
}

int zr_words(zr_doc *z, int page, zr_word *out, int max, char *text, int cap)
{
	fz_context *ctx = z->ctx;
	fz_stext_page *st = NULL;
	int n = 0, tl = 0, line = 0;
	fz_var(st);
	fz_try(ctx) {
		fz_stext_options opts = { 0 };
		fz_display_list *l = get_list(z, page);
		st = fz_new_stext_page_from_display_list(ctx, l, &opts);
		words_block(st->first_block, out, max, text, cap, &n, &tl, &line);
        if (z->is_pdf) join_colliding_initials(out, &n, text, cap, &tl);
	}
	fz_always(ctx) fz_drop_stext_page(ctx, st);
	fz_catch(ctx) {
		fz_report_error(ctx);
		return 0;
	}
	return n;
}

#include "epub-anchor.inc"

#include "search.inc"

static void walk_outline(zr_doc *z, fz_outline *o, int level, zr_toc *out, int max, char *text, int cap, int *n, int *tl)
{
	for (; o && *n < max; o = o->next) {
		const char *t = o->title ? o->title : "";
		int len = (int)strlen(t);
		if (len > 200) len = 200;
		if (*tl + len >= cap) return;
		zr_toc *e = &out[(*n)++];
		e->page = fz_page_number_from_location(z->ctx, z->doc, o->page);
		e->level = level;
		e->off = *tl;
		e->len = len;
		memcpy(text + *tl, t, len);
		*tl += len;
		if (o->down) walk_outline(z, o->down, level + 1, out, max, text, cap, n, tl);
	}
}

int zr_outline(zr_doc *z, zr_toc *out, int max, char *text, int cap)
{
	fz_outline *o = NULL;
	int n = 0, tl = 0;
	fz_var(o);
	fz_try(z->ctx) {
		o = fz_load_outline(z->ctx, z->doc);
		walk_outline(z, o, 0, out, max, text, cap, &n, &tl);
	}
	fz_always(z->ctx) fz_drop_outline(z->ctx, o);
	fz_catch(z->ctx) {
		fz_report_error(z->ctx);
	}
	return n;
}

/* ---------- UI text ---------- */
struct zr_ui {
	fz_context *ctx;
	fz_font *font[3];
};

zr_ui *zr_ui_new(const unsigned char *sans, int sans_len)
{
	zr_ui *u = calloc(1, sizeof *u);
	if (!u) return NULL;
	u->ctx = zr_new_ctx();
	if (!u->ctx) { free(u); return NULL; }
	fz_try(u->ctx) {
		int len = 0;
		const unsigned char *d;
		u->font[0] = fz_new_font_from_memory(u->ctx, "Noto Sans", sans, sans_len, 0, 0);
		d = fz_lookup_builtin_font(u->ctx, "Charis SIL", 0, 0, &len);
		u->font[1] = d ? fz_new_font_from_memory(u->ctx, "Charis SIL", d, len, 0, 0) : fz_keep_font(u->ctx, u->font[0]);
		d = fz_lookup_builtin_font(u->ctx, "Charis SIL", 1, 0, &len);
		u->font[2] = d ? fz_new_font_from_memory(u->ctx, "Charis SIL Bold", d, len, 0, 0) : fz_keep_font(u->ctx, u->font[1]);
	}
	fz_catch(u->ctx) {
		fz_report_error(u->ctx);
		return NULL;
	}
	return u;
}

float zr_ui_measure(zr_ui *u, int font, float size, const char *s, int len)
{
	fz_font *f = u->font[font];
	float w = 0;
	int i = 0;
	while (i < len) {
		int c;
		i += fz_chartorune(&c, s + i);
		w += fz_advance_glyph(u->ctx, f, fz_encode_character(u->ctx, f, c), 0);
	}
	return w * size;
}

void zr_ui_text(zr_ui *u, int font, float size, unsigned char *buf, int w, int h, int stride,
	float x, float baseline, const char *s, int len, int gray)
{
	fz_context *ctx = u->ctx;
	fz_font *f = u->font[font];
	fz_text *text = NULL;
	fz_pixmap *pix = NULL;
	fz_device *dev = NULL;
	fz_var(text);
	fz_var(pix);
	fz_var(dev);
	fz_try(ctx) {
		text = fz_new_text(ctx);
		int i = 0;
		float pen = x;
		while (i < len) {
			int c;
			i += fz_chartorune(&c, s + i);
			int g = fz_encode_character(ctx, f, c);
			fz_matrix trm = fz_make_matrix(size, 0, 0, -size, pen, baseline);
			fz_show_glyph(ctx, text, f, trm, g, c, 0, 0, FZ_BIDI_LTR, FZ_LANG_UNSET);
			pen += fz_advance_glyph(ctx, f, g, 0) * size;
		}
		pix = fz_new_pixmap_with_data(ctx, fz_device_gray(ctx), w, h, NULL, 0, stride, buf);
		dev = fz_new_draw_device(ctx, fz_identity, pix);
		float col = gray / 255.0f;
		fz_fill_text(ctx, dev, text, fz_identity, fz_device_gray(ctx), &col, 1, fz_default_color_params);
		fz_close_device(ctx, dev);
	}
	fz_always(ctx) {
		fz_drop_device(ctx, dev);
		fz_drop_pixmap(ctx, pix);
		fz_drop_text(ctx, text);
	}
	fz_catch(ctx) fz_report_error(ctx);
}

void zr_cancel(zr_doc *z){z->cookie.abort=1;}
void zr_reset_cancel(zr_doc *z){z->cookie.abort=0;}

int zr_pagination_pending(zr_doc *z){return z->pending;}

zr_doc *zr_open_worker(const char *path,float w,float h,float em,float margin,float spacing,int (*progress)(int)){
 pagination_progress=progress;zr_doc *z=open_style(path,w,h,em,margin,spacing,1,0);pagination_progress=NULL;return z;
}

/* v0.9.3 reduced-resolution JPEG 2000 previews (needs MuPDF's OpenJPEG headers on the include path) */
#include "jpxsmall.c"
