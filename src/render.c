/* MuPDF wrapper. Each zr_doc owns its own context and document, so one
 * zr_doc per thread gives lock-free parallel rendering. */
#include <mupdf/fitz.h>
#include <string.h>
#include <math.h>
#include <pthread.h>
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
	int pages, is_pdf, reflow;
	float spacing;
	int styled;
	struct zr_anchor_index *anchor_index;
	struct { int page; fz_display_list *list; unsigned age; } lists[NLISTS];
	unsigned tick;
};

static void set_css(fz_context *ctx, fz_document *doc, float margin_pt, float font_pt, float spacing, int styled)
{
	char css[512];
	fz_snprintf(css, sizeof css, "@page{margin:%gpt %gpt !important}html,body{font-size:%gpt !important}body{margin:0 !important}*{line-height:%g !important}", margin_pt * 0.8f, margin_pt, font_pt, spacing);
	if (!styled) fz_snprintf(css, sizeof css, "@page{margin:%gpt %gpt !important}body{margin:0 !important}", margin_pt * .8f, margin_pt);
	fz_style_document(ctx, doc, 1, css);
}

zr_doc *zr_open(const char *path, float lw, float lh, float font_pt, float margin_pt)
{
	zr_doc *z = calloc(1, sizeof *z);
	if (!z) return NULL;
	z->spacing = 1.4f;
	z->ctx = zr_new_ctx();
	if (!z->ctx) { free(z); return NULL; }
	fz_try(z->ctx) {
		z->doc = fz_open_document(z->ctx, path);
		char fmt[64] = "";
		fz_lookup_metadata(z->ctx, z->doc, FZ_META_FORMAT, fmt, sizeof fmt);
		z->is_pdf = strncmp(fmt, "PDF", 3) == 0;
		z->reflow = fz_is_document_reflowable(z->ctx, z->doc);
		if (z->reflow) {
            set_css(z->ctx, z->doc, margin_pt, font_pt, z->spacing, z->styled);
            fz_layout_document(z->ctx, z->doc, lw, lh, font_pt);
        }
		z->pages = fz_count_pages(z->ctx, z->doc);
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
	fz_try(z->ctx) {
		fz_bookmark mark = fz_make_bookmark(z->ctx, z->doc, fz_location_from_page_number(z->ctx, z->doc, page));
		drop_lists(z);
		drop_anchor_index(z);
		set_css(z->ctx, z->doc, margin_pt, font_pt, z->spacing, z->styled);
		fz_layout_document(z->ctx, z->doc, lw, lh, font_pt);
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

int zr_ink_bbox(zr_doc *z, int page, float *r, int no_images)
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
		const float s = 0.5f;
		fz_matrix m = fz_scale(s, s);
		fz_irect ib = fz_round_rect(fz_transform_rect(bounds, m));
		pix = fz_new_pixmap_with_bbox(ctx, fz_device_gray(ctx), ib, NULL, 0);
		fz_clear_pixmap_with_value(ctx, pix, 255);
		dev = fz_new_draw_device(ctx, fz_identity, pix);
		maybe_skip_images(dev, no_images);
		fz_run_display_list(ctx, l, dev, m, fz_infinite_rect, NULL);
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
typedef struct {
    fz_device super;
    unsigned char *out;
    int w, h, stride, dither, image_count;
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
static void image_fill(fz_context *ctx, fz_device *dev, fz_image *img, fz_matrix m, float alpha, fz_color_params cp)
{
    zr_image_device *d = (zr_image_device *)dev;
    image_footprint(d,m,alpha);
    fz_irect r = fz_round_rect(fz_intersect_rect(fz_transform_rect(fz_unit_rect,m),fz_make_rect(0,0,d->w,d->h)));
    int rw=r.x1-r.x0, rh=r.y1-r.y0;
    unsigned char *before=NULL;
    fz_var(before);
    /* Retain the rectangle before this draw. Pixels untouched by this image
     * (including anything excluded by PDF clips) MUST stay unchanged. */
    if (d->dither && alpha == 1 && !img->mask && m.b == 0 && m.c == 0 && rw>0 && rh>0) {
        before=malloc((size_t)rw*rh);
        if (before) for (int y=0; y<rh; y++) memcpy(before+(size_t)y*rw,d->out+(size_t)(r.y0+y)*d->stride+r.x0,rw);
    }
    fz_try(ctx) {
        fz_fill_image(ctx,dev->passthrough,img,m,alpha,cp);
        if (before) {
            static const unsigned char bayer[4][4]={{0,8,2,10},{12,4,14,6},{3,11,1,9},{15,7,13,5}};
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
    }
    fz_always(ctx) free(before);
    fz_catch(ctx) fz_rethrow(ctx);
}
static void image_mask_fill(fz_context *ctx, fz_device *dev, fz_image *img, fz_matrix m,
    fz_colorspace *cs, const float *color, float alpha, fz_color_params cp)
{
    image_footprint((zr_image_device *)dev,m,alpha);
    fz_fill_image_mask(ctx,dev->passthrough,img,m,cs,color,alpha,cp);
}

int zr_render_with_stats(zr_doc *z, int page, const float *m6, unsigned char *out, int w, int h, int stride,
    int no_images, int image_dither, zr_render_stats *stats)
{
	fz_context *ctx = z->ctx;
	fz_pixmap *pix = NULL;
	fz_device *dev = NULL;
    zr_image_device *images = NULL;
    if (stats) memset(stats,0,sizeof *stats);
	int rc = 0;
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
            images->out=out; images->w=w; images->h=h; images->stride=stride; images->dither=image_dither;
            images->super.fill_image=image_fill;
            images->super.fill_image_mask=image_mask_fill;
        }
        maybe_skip_images(dev, no_images);
        fz_device *draw = images ? &images->super : dev;
        fz_run_display_list(ctx, l, draw, m, fz_make_rect(0, 0, w, h), NULL);
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
        }
	}
	fz_always(ctx) {
        fz_drop_device(ctx, images ? &images->super : NULL);
		fz_drop_device(ctx, dev);
		fz_drop_pixmap(ctx, pix);
	}
	fz_catch(ctx) {
		fz_report_error(ctx);
		rc = -1;
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
