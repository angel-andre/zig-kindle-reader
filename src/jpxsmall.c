/* v0.9.3: decode a JPEG 2000 image at reduced resolution (OpenJPEG resolution
 * factor) into an 8-bit luminance buffer. MuPDF always decodes JPX at full size;
 * the MRC scan checks only need a tiny preview. Uses MuPDF's OpenJPEG build and
 * its allocator lock. Returns NULL on any unsupported layout or error. */
#include "mupdf/fitz.h"
#ifndef OPJ_STATIC
#define OPJ_STATIC
#endif
#define OPJ_HAVE_INTTYPES_H
#define OPJ_HAVE_STDINT_H
#if __has_include(<openjpeg.h>)
#include <openjpeg.h>
#else /* default source layout: MuPDF next to this project */
#include "../../mupdf-1.28.6-source/thirdparty/openjpeg/src/lib/openjp2/openjpeg.h"
#endif
#include <stdlib.h>
#include <string.h>
void fz_opj_lock(fz_context *ctx);
void fz_opj_unlock(fz_context *ctx);
typedef struct { const unsigned char *data; size_t size, pos; } jsb;
static OPJ_SIZE_T rd(void *b, OPJ_SIZE_T n, void *u){ jsb *s=u; size_t l=s->size-s->pos; if(!l) return (OPJ_SIZE_T)-1; if(l>n) l=n; memcpy(b,s->data+s->pos,l); s->pos+=l; return l; }
static OPJ_OFF_T sk(OPJ_OFF_T n, void *u){ jsb *s=u; if(n>(OPJ_OFF_T)(s->size-s->pos)) n=s->size-s->pos; s->pos+=n; return s->pos; }
static OPJ_BOOL se(OPJ_OFF_T p, void *u){ jsb *s=u; if(p>(OPJ_OFF_T)s->size) return OPJ_FALSE; s->pos=p; return OPJ_TRUE; }
static void quiet(const char *m, void *u){ (void)m; (void)u; }
unsigned char *zr_jpx_small_lum2(fz_context *ctx, const unsigned char *data, size_t size, int tw, int th, int *ow, int *oh);
unsigned char *zr_jpx_small_lum(fz_context *ctx, const unsigned char *data, size_t size, int target, int *ow, int *oh)
{ return zr_jpx_small_lum2(ctx,data,size,target,target,ow,oh); }
/* Largest reduction keeping at least tw x th pixels. */
unsigned char *zr_jpx_small_lum2(fz_context *ctx, const unsigned char *data, size_t size, int tw, int th, int *ow, int *oh)
{
    if (size < 2) return NULL;
    unsigned char *out=NULL;
    opj_dparameters_t par; opj_codec_t *codec; opj_stream_t *st; opj_image_t *im=NULL; jsb sb={data,size,0};
    fz_opj_lock(ctx);
    codec=opj_create_decompress(data[0]==0xFF&&data[1]==0x4F?OPJ_CODEC_J2K:OPJ_CODEC_JP2);
    opj_set_info_handler(codec,quiet,NULL); opj_set_warning_handler(codec,quiet,NULL); opj_set_error_handler(codec,quiet,NULL);
    opj_set_default_decoder_parameters(&par);
    st=opj_stream_default_create(OPJ_TRUE);
    opj_stream_set_read_function(st,rd); opj_stream_set_skip_function(st,sk); opj_stream_set_seek_function(st,se);
    opj_stream_set_user_data(st,&sb,NULL); opj_stream_set_user_data_length(st,size);
    if (opj_setup_decoder(codec,&par) && opj_read_header(st,codec,&im) && im && im->numcomps >= 1) {
        int w=im->x1-im->x0, h=im->y1-im->y0, k=0;
        while (k < 6 && (w>>(k+1)) >= tw && (h>>(k+1)) >= th) k++;
        int ok=1;
        if (k && !opj_set_decoded_resolution_factor(codec,k)) { k=0; }
        if (!opj_decode(codec,st,im) || !opj_end_decompress(codec,st)) ok=0;
        int nc=im->numcomps>=3?3:1;
        for (int i=0; ok && i<nc; i++) if (!im->comps[i].data || im->comps[i].w != im->comps[0].w || im->comps[i].h != im->comps[0].h || im->comps[i].prec > 16) ok=0;
        if (ok) {
            int cw=im->comps[0].w, ch=im->comps[0].h; out=malloc((size_t)cw*ch);
            if (out) {
                int ycc = im->color_space == OPJ_CLRSPC_SYCC || nc == 1;
                for (int i=0;i<cw*ch;i++) {
                    int v[3];
                    for (int c=0;c<nc;c++) { int p=im->comps[c].prec, x=im->comps[c].data[i]+(im->comps[c].sgnd?(1<<(p-1)):0); v[c]= p>8 ? x>>(p-8) : x<<(8-p); }
                    int l = ycc ? v[0] : (v[0]*77+v[1]*150+v[2]*29)>>8;
                    out[i]=(unsigned char)(l<0?0:l>255?255:l);
                }
                *ow=cw; *oh=ch;
            }
        }
    }
    if (im) opj_image_destroy(im);
    opj_stream_destroy(st); opj_destroy_codec(codec);
    fz_opj_unlock(ctx);
    return out;
}
