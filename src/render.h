#ifndef ZR_RENDER_H
#define ZR_RENDER_H
#include <stdint.h>
typedef struct zr_doc zr_doc;
typedef struct zr_ui zr_ui;
typedef struct { float x0, y0, x1, y1; int line, off, len; } zr_word;
typedef struct { int page, level, off, len; } zr_toc;

zr_doc *zr_open(const char *path, float lw, float lh, float font_pt, float margin_pt);
void zr_close(zr_doc *z);
int zr_page_count(zr_doc *z);
int zr_is_pdf(zr_doc *z);
int zr_reflowable(zr_doc *z);
/* Re-lays out a reflowable book and returns the page that now holds the old page's start. */
int zr_relayout(zr_doc *z, float lw, float lh, float font_pt, float margin_pt, int page);
int zr_page_bounds(zr_doc *z, int page, float *r4);
int zr_ink_bbox(zr_doc *z, int page, float *r4, int no_images);
int zr_ink_bbox_flags(zr_doc *z, int page, float *r, int no_images, int flags);
/* m6 is a page-to-screen matrix (a b c d e f). Uses a cached display list. */
int zr_render(zr_doc *z, int page, const float *m6, unsigned char *out, int w, int h, int stride, int no_images);
int zr_words(zr_doc *z, int page, zr_word *out, int max, char *text, int cap);
/* Portable EPUB locations: Unicode scalar offsets in chapter text, excluding
 * whitespace/optional hyphens; chapter checksum detects changed/reordered text.
 * Native MuPDF bookmarks contain pointers and must never be serialized. */
typedef struct { int chapter; uint32_t start, end; uint64_t hash; } zr_anchor;
void zr_set_spacing(zr_doc *z, float spacing);
void zr_set_text_resources(const unsigned char *la,int la_len,const unsigned char *r,int rl,const unsigned char *b,int bl,const unsigned char *i,int il,const unsigned char *bi,int bil);
void zr_set_text_style(int mode,int font);
int zr_text_mode(void);
int zr_book_font(void);
int zr_anchor_words(zr_doc *z, int page, int first, int last, zr_anchor *out);
int zr_anchor_page(zr_doc *z, const zr_anchor *a);
int zr_anchor_quads(zr_doc *z, const zr_anchor *a, int page, float *quads, int max);
int zr_anchor_migrate(zr_doc *z, int page, const char *quote, int len, float x, float y, zr_anchor *out);
typedef struct { float q[8][4]; int nq, off, len; } zr_hit;
int zr_search_page(zr_doc *z, int page, const char *needle, zr_hit *hits, int max, char *snippets, int cap);
int zr_outline(zr_doc *z, zr_toc *out, int max, char *text, int cap);

zr_ui *zr_ui_new(const unsigned char *sans, int sans_len);
/* font: 0 sans, 1 serif, 2 serif bold */
float zr_ui_measure(zr_ui *u, int font, float size, const char *s, int len);
void zr_ui_text(zr_ui *u, int font, float size, unsigned char *buf, int w, int h, int stride,
	float x, float baseline, const char *s, int len, int gray);

/* Conservative screen-space union of raster image footprints, collected during
 * the existing draw pass. Image dithering affects opaque, axis-aligned images
 * as they are drawn, not later text/vector operations. */
typedef struct { float image_coverage; int image_count; int cleaned; } zr_render_stats;
int zr_render_with_stats(zr_doc *z, int page, const float *m6, unsigned char *out,
    int w, int h, int stride, int no_images, int image_dither, zr_render_stats *stats);

#endif

void zr_layout_cache(const char *data);
zr_doc *zr_open_style(const char *,float,float,float,float,float);
zr_doc *zr_open_cover(const char *);

zr_doc *zr_open_initial(const char *,float,float,float,float,float);
void zr_page_count_hint(zr_doc *,int);
