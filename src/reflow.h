/* Scanned-page reflow (port of the reflow prototype v14).
 * Rule: pictures are always shown whole. Any doubt -> RF_PAGE_VIEW (show the page as today). */
#ifndef ZR_REFLOW_H
#define ZR_REFLOW_H
#include <stdint.h>
typedef struct { int w, h; uint8_t *px; } rf_img;           /* 8-bit grey */
typedef enum { RF_REFLOW = 0, RF_PAGE_VIEW = 1, RF_SPREAD_VIEW = 2 } rf_mode;
typedef struct {
    rf_mode mode;
    const char *reason;          /* page-view reason, "" when reflowed */
    int nscreens; rf_img *screens; /* owned; free with rf_free */
} rf_result;
/* lo: page at 150 dpi (analysis). hi: same page at 150*k dpi (drawing). scale: 1.5 or 2.0.
 * sw, sh: screen size. Screens are produced only for RF_REFLOW. */
typedef struct { int a, b, last; } rf_span;
typedef struct { int fig, a, b, x0, x1, a2, b2, cut, bl, foot, para, indent, nw; rf_span *w; } rf_unit;
/* Analysis of one page (or split half) at one scale: verdict plus everything layout needs. Cacheable. */
typedef struct { rf_mode mode; const char *reason; double scale, lh, mp, xh; int w, h, nu; rf_unit *u; } rf_analysis;
int rf_analyse(const rf_img *lo, double scale, int sw, rf_analysis *out);
int rf_layout(const rf_analysis *an, const rf_img *hi, int k, int sw, int sh, rf_result *out);
void rf_analysis_free(rf_analysis *a);
int rf_save(const rf_analysis *a, const char *path);   /* 0 ok */
int rf_load(rf_analysis *a, const char *path);         /* 0 ok, -1 missing/corrupt */
/* analyse + layout in one call */
int rf_reflow(const rf_img *lo, const rf_img *hi, int k, double scale, int sw, int sh, rf_result *out);
void rf_free(rf_result *r);
#endif
