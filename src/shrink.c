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
static volatile int phase; /* 0 idle, 1 images, 2 saving, 3 done */

void zr_shrink_cancel(void) { zr_rw_cancel = 1; }
int zr_shrink_progress(int *done, int *total) { *done = zr_rw_done; *total = zr_rw_total; return phase; }

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
