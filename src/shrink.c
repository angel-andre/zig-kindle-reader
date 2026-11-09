/* "Shrink for Kindle": rewrites a PDF's images for the 1272x1696 screen (greyscale,
 * downsampled to about 1.25x the screen's resolution for the image's placed size,
 * JPEG quality 80); text, fonts, links, pages and page sizes are kept. */
#include <mupdf/fitz.h>
#include <mupdf/pdf.h>
#include <string.h>
#include <stdio.h>
#include <unistd.h>
#include <math.h>

extern int zr_rw_gray;
extern volatile int zr_rw_done, zr_rw_total, zr_rw_cancel;
static volatile int phase; /* 0 idle, 1 images, 2 saving, 3 done, 4 preparing (v0.12.2) */

void zr_shrink_cancel(void) { zr_rw_cancel = 1; }
int zr_shrink_progress(int *done, int *total) { *done = zr_rw_done; *total = zr_rw_total; return phase; }

/* v0.12.3: the colour layer is kept at half resolution, so a JPEG 2000 layer is decoded with
 * OpenJPEG's reduce factor 1 (the finest wavelet level is never decoded): about 4x less work
 * than a full decode followed by halving. Returns NULL when the stream is not a plain 1- or
 * 3-component image; the caller then takes the general path. */
#define OPJ_STATIC
#include <openjpeg.h>
typedef struct { const unsigned char *d; size_t n, pos; } zr_jmem;
static OPJ_SIZE_T zj_read(void *b, OPJ_SIZE_T n, void *u) { zr_jmem *m = u; if (m->pos >= m->n) return (OPJ_SIZE_T)-1; if (n > m->n - m->pos) n = m->n - m->pos; memcpy(b, m->d + m->pos, n); m->pos += n; return n; }
static OPJ_OFF_T zj_skip(OPJ_OFF_T n, void *u) { zr_jmem *m = u; if (n < 0 || (size_t)n > m->n - m->pos) n = (OPJ_OFF_T)(m->n - m->pos); m->pos += (size_t)n; return n; }
static OPJ_BOOL zj_seek(OPJ_OFF_T n, void *u) { zr_jmem *m = u; if (n < 0 || (size_t)n > m->n) return OPJ_FALSE; m->pos = (size_t)n; return OPJ_TRUE; }
static fz_pixmap *jpx_gray_half(fz_context *ctx, const unsigned char *data, size_t len, int w, int h)
{
	zr_jmem m = { data, len, 0 };
	opj_dparameters_t par;
	opj_codec_t *c;
	opj_stream_t *st;
	opj_image_t *img = NULL;
	fz_pixmap *pix = NULL;
	int ok, nc, k;
	if (len < 12) return NULL;
	c = opj_create_decompress((data[0] == 0xFF && data[1] == 0x4F) ? OPJ_CODEC_J2K : OPJ_CODEC_JP2);
	if (!c) return NULL;
	opj_set_default_decoder_parameters(&par);
	par.cp_reduce = 1;
	st = opj_stream_create(1 << 16, OPJ_TRUE);
	if (!st) { opj_destroy_codec(c); return NULL; }
	opj_stream_set_user_data(st, &m, NULL);
	opj_stream_set_user_data_length(st, len);
	opj_stream_set_read_function(st, zj_read);
	opj_stream_set_skip_function(st, zj_skip);
	opj_stream_set_seek_function(st, zj_seek);
	ok = opj_setup_decoder(c, &par);
	if (ok && opj_has_thread_support()) opj_codec_set_threads(c, 2);
	ok = ok && opj_read_header(st, c, &img) && opj_decode(c, st, img) && opj_end_decompress(c, st);
	opj_stream_destroy(st);
	opj_destroy_codec(c);
	if (!ok || !img) { if (img) opj_image_destroy(img); return NULL; }
	nc = (int)img->numcomps;
	if ((nc != 1 && nc != 3) || img->color_space == OPJ_CLRSPC_SYCC || img->color_space == OPJ_CLRSPC_EYCC || img->color_space == OPJ_CLRSPC_CMYK)
		goto fail;
	for (k = 0; k < nc; k++)
		if (img->comps[k].w != img->comps[0].w || img->comps[k].h != img->comps[0].h || img->comps[k].prec < 1 || img->comps[k].prec > 16 || img->comps[k].sgnd || !img->comps[k].data) goto fail;
	{
		int ow = (int)img->comps[0].w, oh = (int)img->comps[0].h, x, y, sh = (int)img->comps[0].prec - 8;
		/* reduce 1 gives ceil(w/2) x ceil(h/2), the size fz_subsample_pixmap(.., 1) gives */
		if (ow != (w + 1) / 2 || oh != (h + 1) / 2) goto fail;
		fz_try(ctx)
			pix = fz_new_pixmap(ctx, fz_device_gray(ctx), ow, oh, NULL, 0);
		fz_catch(ctx)
		{
			fz_ignore_error(ctx);
			goto fail;
		}
		for (y = 0; y < oh; y++)
		{
			unsigned char *o = pix->samples + (size_t)y * pix->stride;
			for (x = 0; x < ow; x++)
			{
				size_t i = (size_t)y * ow + x;
				int v;
				if (nc == 1) v = img->comps[0].data[i];
				else v = (77 * img->comps[0].data[i] + 150 * img->comps[1].data[i] + 29 * img->comps[2].data[i] + 128) >> 8;
				v = sh > 0 ? v >> sh : v << -sh;
				o[x] = (unsigned char)(v < 0 ? 0 : v > 255 ? 255 : v);
			}
		}
	}
	opj_image_destroy(img);
	return pix;
fail:
	opj_image_destroy(img);
	return NULL;
}

/* v0.12.1: scanned books stored as "mixed raster" pages (a picture layer, plus a colour layer
 * seen only through a sharp 1-bit text mask at 2x or more its resolution) keep their pictures
 * below screen resolution, so the pass above leaves them alone. The colour layer under such a
 * mask only tints the print, so it is stored as greyscale JPEG at half its resolution; the mask
 * (the shape of every letter) and the picture layer are not touched. Replaced only if smaller. */
static int mrc_pass(fz_context *ctx, pdf_document *doc, int quality)
{
	int n = pdf_count_objects(ctx, doc), num, changed = 0;
	phase = 4; zr_rw_total = n; zr_rw_done = 0;
	for (num = 1; num < n; num++)
	{
		zr_rw_done = num;
		pdf_obj *obj = NULL, *ref = NULL, *sm;
		fz_image *img = NULL;
		fz_pixmap *pix = NULL, *g = NULL;
		fz_buffer *buf = NULL;
		if (zr_rw_cancel) fz_throw(ctx, FZ_ERROR_GENERIC, "cancelled");
		fz_var(obj); fz_var(ref); fz_var(img); fz_var(pix); fz_var(g); fz_var(buf);
		fz_try(ctx)
		{
			int w, h, mw, mh;
			obj = pdf_new_indirect(ctx, doc, num, 0); /* pdf_is_stream needs the reference */
			if (!pdf_is_stream(ctx, obj) || !pdf_name_eq(ctx, pdf_dict_get(ctx, obj, PDF_NAME(Subtype)), PDF_NAME(Image)))
				break;
			sm = pdf_dict_get(ctx, obj, PDF_NAME(SMask));
			if (!pdf_is_stream(ctx, sm) || pdf_dict_get_int(ctx, sm, PDF_NAME(BitsPerComponent)) != 1)
				break;
			w = pdf_dict_get_int(ctx, obj, PDF_NAME(Width)); h = pdf_dict_get_int(ctx, obj, PDF_NAME(Height));
			mw = pdf_dict_get_int(ctx, sm, PDF_NAME(Width)); mh = pdf_dict_get_int(ctx, sm, PDF_NAME(Height));
			if (w < 64 || h < 64 || mw < 2 * w || mh < 2 * h || pdf_dict_get(ctx, obj, PDF_NAME(Decode)))
				break;
			if (pdf_name_eq(ctx, pdf_dict_get(ctx, obj, PDF_NAME(Filter)), PDF_NAME(JPXDecode))
				&& (pdf_dict_get(ctx, obj, PDF_NAME(ColorSpace)) == NULL || pdf_name_eq(ctx, pdf_dict_get(ctx, obj, PDF_NAME(ColorSpace)), PDF_NAME(DeviceRGB)) || pdf_name_eq(ctx, pdf_dict_get(ctx, obj, PDF_NAME(ColorSpace)), PDF_NAME(DeviceGray))))
			{
				buf = pdf_load_raw_stream(ctx, obj);
				pix = jpx_gray_half(ctx, buf->data, buf->len, w, h);
				fz_drop_buffer(ctx, buf); buf = NULL;
			}
			if (!pix)
			{
				img = pdf_load_image(ctx, doc, obj);
				if (img->imagemask || img->use_colorkey || img->bpc != 8) break;
				pix = fz_get_pixmap_from_image(ctx, img, NULL, NULL, NULL, NULL);
				if (pix->alpha) break;
				if (pix->n != 1) { g = fz_convert_pixmap(ctx, pix, fz_device_gray(ctx), NULL, NULL, fz_default_color_params, 0); fz_drop_pixmap(ctx, pix); pix = g; g = NULL; }
				fz_subsample_pixmap(ctx, pix, 1);
			}
			buf = fz_new_buffer_from_pixmap_as_jpeg(ctx, pix, fz_default_color_params, quality, 0);
			if (buf->len >= (size_t)pdf_dict_get_int64(ctx, obj, PDF_NAME(Length))) break;
			ref = pdf_keep_obj(ctx, obj);
			pdf_dict_del(ctx, obj, PDF_NAME(DecodeParms));
			pdf_dict_del(ctx, obj, PDF_NAME(SMaskInData));
			pdf_dict_put(ctx, obj, PDF_NAME(Filter), PDF_NAME(DCTDecode));
			pdf_dict_put(ctx, obj, PDF_NAME(ColorSpace), PDF_NAME(DeviceGray));
			pdf_dict_put_int(ctx, obj, PDF_NAME(BitsPerComponent), 8);
			pdf_dict_put_int(ctx, obj, PDF_NAME(Width), pix->w);
			pdf_dict_put_int(ctx, obj, PDF_NAME(Height), pix->h);
			pdf_update_stream(ctx, doc, ref, buf, 1);
			changed++;
		}
		fz_always(ctx)
		{
			fz_drop_buffer(ctx, buf); fz_drop_pixmap(ctx, g); fz_drop_pixmap(ctx, pix);
			fz_drop_image(ctx, img); pdf_drop_obj(ctx, ref); pdf_drop_obj(ctx, obj);
		}
		fz_catch(ctx)
		{
			if (zr_rw_cancel) fz_rethrow(ctx);
			/* an image that cannot be loaded is left exactly as it is; the error is cleared so a
			 * later throw is not reported as an UNHANDLED EXCEPTION */
			fz_ignore_error(ctx);
		}
	}
	phase = 1; zr_rw_total = 0; zr_rw_done = 0;
	return changed;
}

/* 0 = written, 1 = cancelled, -1 = error. `out` is removed on failure. */
int zr_shrink_pdf(const char *in, const char *out, int quality)
{
	int rc = 0;
	char q[8];
	fz_context *ctx = fz_new_context(NULL, NULL, 64 << 20);
	pdf_document *doc = NULL;
	if (!ctx) return -1;
	snprintf(q, sizeof q, "%d", quality > 0 ? quality : 80);
	zr_rw_cancel = 0; zr_rw_done = 0; zr_rw_total = 0; phase = 1;
	fz_var(doc);
	fz_try(ctx)
	{
		pdf_image_rewriter_options o;
		pdf_write_options w;
		fz_rect b;
		float s, dpi;
		doc = pdf_open_document(ctx, in);
		if (pdf_needs_password(ctx, doc)) fz_throw(ctx, FZ_ERROR_GENERIC, "encrypted");
		{
			pdf_page *pg = pdf_load_page(ctx, doc, 0);
			b = pdf_bound_page(ctx, pg, FZ_CROP_BOX);
			fz_drop_page(ctx, &pg->super);
		}
		/* fit the first page's size; images are judged at their placed size */
		s = fminf(1272.0f / fmaxf(b.x1 - b.x0, 1), 1696.0f / fmaxf(b.y1 - b.y0, 1));
		dpi = 72.0f * s * 1.25f;
		if (dpi < 96) dpi = 96;
		memset(&o, 0, sizeof o);
		o.color_lossless_image_subsample_method = o.color_lossy_image_subsample_method = FZ_SUBSAMPLE_BICUBIC; /* exact target size; AVERAGE only halves */
		o.gray_lossless_image_subsample_method = o.gray_lossy_image_subsample_method = FZ_SUBSAMPLE_BICUBIC;
		o.color_lossless_image_subsample_threshold = o.color_lossy_image_subsample_threshold = (int)(dpi * 1.2f);
		o.gray_lossless_image_subsample_threshold = o.gray_lossy_image_subsample_threshold = (int)(dpi * 1.2f);
		o.color_lossless_image_subsample_to = o.color_lossy_image_subsample_to = (int)dpi;
		o.gray_lossless_image_subsample_to = o.gray_lossy_image_subsample_to = (int)dpi;
		o.color_lossless_image_recompress_method = o.color_lossy_image_recompress_method = FZ_RECOMPRESS_JPEG;
		o.gray_lossless_image_recompress_method = o.gray_lossy_image_recompress_method = FZ_RECOMPRESS_JPEG;
		o.color_lossless_image_recompress_quality = o.color_lossy_image_recompress_quality = q;
		o.gray_lossless_image_recompress_quality = o.gray_lossy_image_recompress_quality = q;
		o.bitonal_image_recompress_method = FZ_RECOMPRESS_NEVER; /* 1-bit (JBIG2/CCITT) stays as it is */
		o.recompress_when = FZ_RECOMPRESS_WHEN_SMALLER;
		zr_rw_gray = 1;
		mrc_pass(ctx, doc, quality > 0 ? quality : 80); /* before the rewrite, which copies images */
		pdf_rewrite_images(ctx, doc, &o);
		phase = 2;
		pdf_parse_write_options(ctx, &w, "garbage=compact,compress");
		pdf_save_document(ctx, doc, out, &w);
	}
	fz_always(ctx)
	{
		zr_rw_gray = 0;
		pdf_drop_document(ctx, doc);
	}
	fz_catch(ctx)
	{
		rc = zr_rw_cancel ? 1 : -1;
		fz_ignore_error(ctx); /* reported through rc; keeps the log free of UNHANDLED EXCEPTION */
		unlink(out);
	}
	fz_drop_context(ctx);
	phase = 3;
	return rc;
}

/* ---- background run and file helpers for the library UI ---- */
#include <pthread.h>
#include <sys/stat.h>
#include <sys/statvfs.h>
#include <dirent.h>
#include <errno.h>
#include <fcntl.h>
#include <stdlib.h>

static char sh_in[1024], sh_out[1024];
static volatile int sh_rc = 0;
static void *sh_thread(void *arg) { (void)arg; sh_rc = zr_shrink_pdf(sh_in, sh_out, 80); return NULL; }
int zr_shrink_start(const char *in, const char *out)
{
	pthread_t t;
	pthread_attr_t a;
	if (strlen(in) >= sizeof sh_in || strlen(out) >= sizeof sh_out) return -1;
	strcpy(sh_in, in); strcpy(sh_out, out);
	unlink(out); /* stale temp from an interrupted run */
	phase = 1; sh_rc = 0; zr_rw_done = 0; zr_rw_total = 0; zr_rw_cancel = 0;
	pthread_attr_init(&a);
	pthread_attr_setdetachstate(&a, PTHREAD_CREATE_DETACHED);
	pthread_attr_setstacksize(&a, 1 << 20);
	if (pthread_create(&t, &a, sh_thread, NULL) != 0) { phase = 0; return -1; }
	pthread_attr_destroy(&a);
	return 0;
}
int zr_shrink_result(void) { return sh_rc; }
long long zr_free_bytes(const char *dir)
{
	struct statvfs s;
	if (statvfs(dir, &s) != 0) return -1;
	return (long long)s.f_bavail * (long long)s.f_frsize;
}
long long zr_fsize(const char *p)
{
	struct stat st;
	return stat(p, &st) == 0 ? (long long)st.st_size : -1;
}
static int mkdirs(char *p)
{
	for (char *s = p + 1; *s; s++)
		if (*s == '/') { *s = 0; mkdir(p, 0755); *s = '/'; }
	return 0;
}
static int copy_file(const char *a, const char *b)
{
	char buf[65536];
	int in = open(a, O_RDONLY), out;
	ssize_t n;
	if (in < 0) return -1;
	out = open(b, O_WRONLY | O_CREAT | O_TRUNC, 0644);
	if (out < 0) { close(in); return -1; }
	while ((n = read(in, buf, sizeof buf)) > 0)
		if (write(out, buf, n) != n) { n = -1; break; }
	if (fsync(out) != 0) n = -1;
	close(in); close(out);
	if (n < 0) { unlink(b); return -1; }
	return 0;
}
/* Moves src to dst (creating dst's folders; dst gets " (2)", " (3)" ... before the
 * extension if taken). Writes the final name to `final`. */
int zr_move_file(const char *src, const char *dst, char *final, int finalcap)
{
	char d[1100];
	const char *dot;
	int k = 1;
	if (strlen(dst) > 1000) return -1;
	strcpy(d, dst);
	mkdirs(d);
	dot = strrchr(dst, '.');
	if (!dot || strchr(dot, '/')) dot = dst + strlen(dst);
	while (access(d, F_OK) == 0 && k < 1000)
		snprintf(d, sizeof d, "%.*s (%d)%s", (int)(dot - dst), dst, ++k, dot);
	if (rename(src, d) != 0)
	{
		if (errno != EXDEV || copy_file(src, d) != 0) return -1;
		unlink(src);
	}
	snprintf(final, finalcap, "%s", d);
	return 0;
}
long long zr_dir_size(const char *dir)
{
	long long t = 0;
	DIR *dp = opendir(dir);
	struct dirent *e;
	char p[1200];
	struct stat st;
	if (!dp) return 0;
	while ((e = readdir(dp)))
	{
		if (!strcmp(e->d_name, ".") || !strcmp(e->d_name, "..")) continue;
		snprintf(p, sizeof p, "%s/%s", dir, e->d_name);
		if (lstat(p, &st) != 0) continue;
		if (S_ISDIR(st.st_mode)) t += zr_dir_size(p);
		else if (S_ISREG(st.st_mode)) t += st.st_size;
	}
	closedir(dp);
	return t;
}
int zr_rm_tree(const char *dir)
{
	DIR *dp = opendir(dir);
	struct dirent *e;
	char p[1200];
	struct stat st;
	if (!dp) return 0;
	while ((e = readdir(dp)))
	{
		if (!strcmp(e->d_name, ".") || !strcmp(e->d_name, "..")) continue;
		snprintf(p, sizeof p, "%s/%s", dir, e->d_name);
		if (lstat(p, &st) != 0) continue;
		if (S_ISDIR(st.st_mode)) { zr_rm_tree(p); rmdir(p); }
		else unlink(p);
	}
	closedir(dp);
	return 0;
}

/* v0.11.4 "Delete book": unlink one regular file that really lives inside the
 * books root. Symlinks (the file itself, or any directory escaping the root)
 * are refused. 0 = deleted, -1 = refused, -2 = could not delete. */
#include <limits.h>
#include <stdlib.h>
#include <errno.h>
int zr_safe_delete(const char *root, const char *path)
{
	char r[PATH_MAX], p[PATH_MAX];
	struct stat st;
	if (!root || !path || !*root || !*path) return -1;
	if (lstat(path, &st) != 0 || !S_ISREG(st.st_mode)) return -1;
	if (!realpath(root, r) || !realpath(path, p)) return -1;
	size_t n = strlen(r);
	if (n == 0 || strncmp(p, r, n) != 0 || p[n] != '/') return -1;
	if (strcmp(p, path) != 0) {
		/* the given path must resolve to itself: no symlinked directories on the way */
		char g[PATH_MAX]; size_t gl = strlen(path);
		if (gl >= sizeof g) return -1;
		memcpy(g, path, gl + 1);
		/* allow a symlinked or relative ROOT, but nothing below it */
		char rr[PATH_MAX];
		size_t rl = strlen(root);
		if (strncmp(path, root, rl) != 0 || path[rl] != '/') return -1;
		if (snprintf(rr, sizeof rr, "%s%s", r, path + rl) >= (int)sizeof rr) return -1;
		if (strcmp(rr, p) != 0) return -1;
	}
	if (access(p, W_OK) != 0 && errno == EROFS) return -2;
	return unlink(p) == 0 ? 0 : -2;
}
