/* Portable EPUB text locations. Only public MuPDF APIs; no native pointer
 * bookmarks are written to disk. This one-chapter UI-thread cache is bounded
 * to 131072 words / 2097152 Unicode scalars (roughly 13 MB worst case).
 * Rendering workers never build it. A text checksum fails closed if a book was
 * replaced or a non-linear/complex layout cannot produce stable reading order. */
struct zr_anchor_word { zr_word w; uint32_t start, end; int page; };
struct zr_anchor_index {
    int chapter, base, npages;
    size_t nw, nc, wc, cc;
    struct zr_anchor_word *words;
    uint32_t *chars;
    size_t *pages;
    uint64_t hash;
};
static void drop_anchor_index(zr_doc *z)
{
    struct zr_anchor_index *a = z->anchor_index;
    if (!a) return;
    free(a->words); free(a->chars); free(a->pages); free(a);
    z->anchor_index = NULL;
}
void zr_set_spacing(zr_doc *z, float spacing)
{
    z->styled = 1;
    z->spacing = spacing >= 1.0f && spacing <= 2.0f ? spacing : 1.4f;
}
static int anchor_ignorable(int c)
{
    return c <= 0x20 || c == 0xA0 || c == 0xAD || c == 0x1680 ||
        (c >= 0x2000 && c <= 0x200B) || c == 0x2028 || c == 0x2029 ||
        c == 0x202F || c == 0x205F || c == 0x3000 || c == 0xFEFF;
}
static int anchor_chars(const char *s, int len, uint32_t *out, int cap)
{
    int n = 0, pos = 0;
    while (pos < len) {
        int c, step = fz_chartorune(&c, s + pos);
        if (step <= 0 || pos + step > len) return -1;
        pos += step;
        if (anchor_ignorable(c)) continue;
        if (n >= cap) return -1;
        out[n++] = c;
    }
    return n;
}
static struct zr_anchor_index *anchor_index(zr_doc *z, int chapter)
{
    if (!z->reflow || chapter < 0) return NULL;
    if (z->anchor_index && z->anchor_index->chapter == chapter) return z->anchor_index;
    drop_anchor_index(z);
    struct zr_anchor_index *a = calloc(1, sizeof *a);
    zr_word *ws = NULL;
    char *text = NULL;
    int failed = 0;
    fz_var(ws); fz_var(text);
    if (!a) return NULL;
    z->anchor_index = a; /* so all error paths have a single owner */
    a->chapter = chapter;
    a->hash = UINT64_C(14695981039346656037);
    fz_try(z->ctx) {
        if (chapter >= fz_count_chapters(z->ctx, z->doc)) fz_throw(z->ctx, FZ_ERROR_ARGUMENT, "invalid anchor chapter");
        a->base = fz_page_number_from_location(z->ctx, z->doc, fz_make_location(chapter, 0));
        a->npages = fz_count_chapter_pages(z->ctx, z->doc, chapter);
        if (a->npages < 1 || a->npages > 4096) fz_throw(z->ctx, FZ_ERROR_LIMIT, "EPUB anchor chapter page limit");
        a->pages = calloc(a->npages + 1, sizeof *a->pages);
        ws = malloc(12000 * sizeof *ws);
        text = malloc(256 * 1024);
        if (!a->pages || !ws || !text) fz_throw(z->ctx, FZ_ERROR_SYSTEM, "EPUB anchor allocation");
        for (int p = 0; p < a->npages; p++) {
            a->pages[p] = a->nw;
            int n = zr_words(z, a->base + p, ws, 12000, text, 256 * 1024);
            if (n >= 12000) fz_throw(z->ctx, FZ_ERROR_LIMIT, "EPUB page word limit");
            for (int i = 0; i < n; i++) {
                if (a->nw >= 131072) fz_throw(z->ctx, FZ_ERROR_LIMIT, "EPUB anchor word limit");
                if (a->nw == a->wc) {
                    size_t cap = a->wc ? a->wc * 2 : 1024;
                    void *ptr = realloc(a->words, cap * sizeof *a->words);
                    if (!ptr) fz_throw(z->ctx, FZ_ERROR_SYSTEM, "EPUB word allocation");
                    a->words = ptr; a->wc = cap;
                }
                struct zr_anchor_word *w = &a->words[a->nw++];
                w->w = ws[i]; w->start = a->nc; w->page = a->base + p;
                const char *s = text + ws[i].off;
                int pos = 0;
                while (pos < ws[i].len) {
                    int c, step = fz_chartorune(&c, s + pos);
                    if (step <= 0 || pos + step > ws[i].len) fz_throw(z->ctx, FZ_ERROR_FORMAT, "invalid anchor UTF-8");
                    pos += step;
                    if (anchor_ignorable(c)) continue;
                    if (a->nc >= 2097152) fz_throw(z->ctx, FZ_ERROR_LIMIT, "EPUB anchor character limit");
                    if (a->nc == a->cc) {
                        size_t cap = a->cc ? a->cc * 2 : 4096;
                        void *ptr = realloc(a->chars, cap * sizeof *a->chars);
                        if (!ptr) fz_throw(z->ctx, FZ_ERROR_SYSTEM, "EPUB text allocation");
                        a->chars = ptr; a->cc = cap;
                    }
                    a->chars[a->nc++] = c;
                    /* Stable platform-independent FNV-1a over scalar little-endian bytes. */
                    for (int k = 0; k < 4; k++) {
                        a->hash ^= ((uint32_t)c >> (k * 8)) & 255;
                        a->hash *= UINT64_C(1099511628211);
                    }
                }
                w->end = a->nc;
            }
        }
        a->pages[a->npages] = a->nw;
    }
    fz_catch(z->ctx) { fz_report_error(z->ctx); failed = 1; }
    free(ws); free(text);
    if (failed) { drop_anchor_index(z); return NULL; }
    return a;
}
static struct zr_anchor_index *anchor_for_page(zr_doc *z, int page)
{
    int chapter = -1;
    if (!z->reflow || page < 0 || page >= z->pages) return NULL;
    fz_try(z->ctx) chapter = fz_location_from_page_number(z->ctx, z->doc, page).chapter;
    fz_catch(z->ctx) return NULL;
    return anchor_index(z, chapter);
}
int zr_anchor_words(zr_doc *z, int page, int first, int last, zr_anchor *out)
{
    struct zr_anchor_index *a = anchor_for_page(z, page);
    if (!a || first < 0 || last < first) return 0;
    size_t lo = a->pages[page - a->base], hi = a->pages[page - a->base + 1];
    if ((size_t)last >= hi - lo) return 0;
    out->chapter = a->chapter;
    out->start = a->words[lo + first].start;
    out->end = a->words[lo + last].end;
    out->hash = a->hash;
    return out->end > out->start;
}
int zr_anchor_page(zr_doc *z, const zr_anchor *mark)
{
    if (mark->chapter < 0 || !mark->hash) return -1;
    struct zr_anchor_index *a = anchor_index(z, mark->chapter);
    if (!a || a->hash != mark->hash || mark->start >= mark->end || mark->end > a->nc) return -1;
    for (size_t i = 0; i < a->nw; i++)
        if (a->words[i].end > mark->start) return a->words[i].page;
    return -1;
}
int zr_anchor_quads(zr_doc *z, const zr_anchor *mark, int page, float *q, int max)
{
    if (max <= 0 || mark->chapter < 0 || !mark->hash) return 0;
    /* Do not evict/rebuild the cache for notes in other chapters on every draw. */
    struct zr_anchor_index *a = anchor_for_page(z, page);
    if (!a || a->chapter != mark->chapter || a->hash != mark->hash || mark->end > a->nc) return 0;
    size_t lo = a->pages[page - a->base], hi = a->pages[page - a->base + 1];
    int n = 0, line = -1;
    for (size_t i = lo; i < hi; i++) {
        struct zr_anchor_word *w = a->words + i;
        if (w->end <= mark->start || w->start >= mark->end || w->end <= w->start) continue;
        zr_word r = w->w;
        if (n && r.line == line) {
            float *old = q + (n - 1) * 4;
            old[0] = fminf(old[0], r.x0); old[1] = fminf(old[1], r.y0);
            old[2] = fmaxf(old[2], r.x1); old[3] = fmaxf(old[3], r.y1);
        } else if (n < max) {
            float *out = q + n++ * 4;
            out[0] = r.x0; out[1] = r.y0; out[2] = r.x1; out[3] = r.y1;
        }
        line = r.line;
    }
    return n;
}
int zr_anchor_migrate(zr_doc *z, int page, const char *quote, int len, float x, float y, zr_anchor *out)
{
    if (len <= 0 || len > 8192) return 0;
    struct zr_anchor_index *a = anchor_for_page(z, page);
    if (!a) return 0;
    uint32_t norm[8192];
    int n = anchor_chars(quote, len, norm, 8192);
    if (n <= 0) return 0;
    size_t lo = a->pages[page - a->base], hi = a->pages[page - a->base + 1];
    size_t best = SIZE_MAX;
    float distance = 1e30f;
    for (size_t i = lo; i < hi; i++) {
        struct zr_anchor_word *w = a->words + i;
        if (w->start + n > a->nc || memcmp(a->chars + w->start, norm, n * sizeof *norm)) continue;
        float dx = (w->w.x0 + w->w.x1) * .5f - x;
        float dy = (w->w.y0 + w->w.y1) * .5f - y;
        float d = dx * dx + dy * dy * 16;
        if (d < distance) { best = i; distance = d; }
    }
    if (best == SIZE_MAX) return 0; /* preserve legacy text, never invent a match */
    out->chapter = a->chapter; out->start = a->words[best].start;
    out->end = out->start + n; out->hash = a->hash;
    return 1;
}
