# Zigg Reader

**A fast, native e-reader for jailbroken Kindles, written in Zig with MuPDF.**

Version **0.11.5** · tested on a Kindle Paperwhite 12th generation (1272×1696) · other Kindles untested · GNU AGPL v3

| Library | Library (Dark) | Book menu |
| --- | --- | --- |
| ![Library](docs/img/library-light.png) | ![Library in Dark theme](docs/img/library-dark.png) | ![Long-press book menu](docs/img/library-book-menu.png) |

| Reading (Dark) | Reader menu (EPUB) | Reader menu (PDF) |
| --- | --- | --- |
| ![A page in Dark theme](docs/img/page-dark.png) | ![EPUB reader menu](docs/img/reader-menu.png) | ![PDF reader menu](docs/img/pdf-menu.png) |

*Screens rendered by the reader's own simulator from the public-domain and generated test books in `tests/`; they don't show e-ink ghosting.*

## Why

A weekend project. The stock Kindle software handles PDFs and scanned books poorly, and KOReader, while very capable, felt slow on this device for the owner's use (page turns and taps lagging). Zigg Reader is a small native program focused on fast page turns, good handling of large and scanned PDFs, and an e-ink-friendly interface. It is not firmware: it pauses the stock interface while it runs and restores it on exit.

## Features

**Formats** — PDF, EPUB, MOBI, AZW3 (KF8), TXT, CBZ and FB2 (DRM-free).

**PDF and scanned books**
- **Shrink for Kindle**: long-press a PDF to make a smaller greyscale copy sized for this screen; text, links, page count and notes keep working; the original is kept in `originals/` until you delete it.
- **Two-page scans split** into single pages automatically (gutter detection, facing page never shows), per-book toggle.
- **Scan cleanup**: whiter paper, darker text, gentle sharpening; **auto-trim** of margins on real scans (digital pages are untouched).
- Fit page, fit width, 1.5× and 2× zoom with pan; an instant scaled preview while the sharp page renders, and zoom stays on the current half of a split spread.
- Instant first page on heavy scans (draft first, exact page swapped in without a flash); nearby pages pre-rendered by background workers.

**Reading**
- Highlights, underlines and notes on PDF and reflowed books; bookmarks; Markdown/JSON/TXT export.
- Offline dictionaries: English (WordNet 3.0) and Latin (Whitaker's WORDS, with inflected forms).
- Contents (table of contents), in-book search, go to page, reading progress.
- Typography for reflowed books: size, margins, line spacing, Justify with hyphenation (English and Latin patterns), Charis SIL / Noto Sans / book font.
- **Theme: Light / Dark** (Dark uses the panel's inversion).

**Library**
- Covers, folders, collections and favourites; sort by recent, title, progress or size; progress bars; book count, storage and battery.
- **Delete book** from the long-press menu (confirmation, notes exported first, only inside the books folder).
- Upload books over Wi-Fi from a browser; frontlight and warmth controls.

**E-ink behaviour** — no periodic full refreshes; non-flashing updates for text, a clean refresh only where heavy images need it; fast or repeated taps never exit the app.

## Quick start

Requirements: a **jailbroken** Kindle with **KUAL**; SSH (key-only) is optional but recommended for recovery. Details: [prerequisites](docs/PREREQUISITES.md).

1. Download `release/zr115.tgz` and check it against [`release/SHA256SUMS`](release/SHA256SUMS).
2. Follow [Install or upgrade](docs/INSTALL.md) (copy, extract to `/mnt/us`, start "Zig reader" from KUAL).
3. Put DRM-free books in `/mnt/us/Books` (sub-folders are fine), or upload them over Wi-Fi from Settings.

More: [user guide](docs/USER_GUIDE.md) · [uninstall and rollback](docs/UNINSTALL.md) (the previous release, `release/zr114.tgz`, is kept for rollback; see [release/README.md](release/README.md)) · [troubleshooting](docs/TROUBLESHOOTING.md) · [safe cleanup](docs/DEBLOAT.md)

Developers: [build from source](docs/BUILD.md) · [tests](docs/TESTING.md) · [architecture](docs/ARCHITECTURE.md) · [benchmark details](docs/BENCHMARK.md) · [roadmap](docs/ROADMAP.md)

## Known limitations

- Tested on one device family (Paperwhite 12th gen); others are untested.
- Zoom and pan are limited by e-ink refresh; pan applies on release (no pinch).
- Some scans keep artefacts that are in the source file (for example stray marks in a separated text layer).
- Not supported: DRM-protected books, KFX, CBR. Links inside AZW3 books aren't followed yet.
- Dark depends on the e-ink panel honouring display inversion.

Full list: [docs/LIMITATIONS.md](docs/LIMITATIONS.md).

## Recent releases

| Version | Highlights |
| --- | --- |
| 0.11.5 | Zoom/pan on the current half of split spreads; stale renders cancelled (latest wins). |
| 0.11.4 | Delete book from the library; Theme Light/Dark. |
| 0.11.3 | Shrink now really downsizes oversized scans; auto-trim on real scans; gentle sharpen in scan cleanup. |
| 0.11.2 | Instant zoom/pan preview; slow-render log. |
| 0.11.1 | Two-page scans shown one page at a time. |
| 0.11.0 | Shrink for Kindle. |

Everything else: [CHANGELOG.md](CHANGELOG.md).

## Performance (0.10.4, on the Kindle)

Kindle Paperwhite 12th gen, measured with the headless bench in [tools/bench](tools/bench/) (CPU governor as the reader sets it, cold open with empty caches). Reports: [benchmarks/2026-11-07](benchmarks/2026-11-07/).

| Book | 0.10.3 first page | 0.10.4 first page (draft) | 0.10.4 exact page |
| --- | --- | --- | --- |
| Scanned PDF, 772 pages | 5.9 s | **0.67 s** | about 4.2 s |
| Scanned PDF, 478 pages | 13.0 s | **0.65 s** | about 5.9 s |

Normal pages of these scans render in about 0.34–0.37 s each in the background and are pre-rendered, so steady page turns stay at about 6 ms to the framebuffer. Reopening an EPUB at a saved place without a cached layout (a 613-page book) takes 1.5 s instead of 3.2 s. 0.10.5 removes most of the remaining stall on heavy front-matter pages right after opening (478-page scanned PDF, cold open, 0.10.4 → 0.10.5):

| Measure | 0.10.4 | 0.10.5 |
| --- | --- | --- |
| First 8 pages, average | 2,294 ms | **533 ms** |
| First 8 pages, slowest | 8,179 ms | **779 ms** |
| Page turn p90 | 496 ms | **134 ms** |
| Slowest page turn | 3.67 s | **2.76 s** |
| Slowest background render | 8.2 s | **6.2 s** |

Warm page turns are unchanged (p50 about 11 ms).

## Benchmark: Zigg Reader vs KOReader

In this test on one device (Kindle Paperwhite 12th gen, Zigg Reader 0.8.0 vs KOReader as installed), with identical injected touch events, a 1.5 MB EPUB and a 47 MB scanned-image PDF. Times run from touch injection to the framebuffer changing, not to the e-ink panel finishing. Lower is better. Full method and raw data: [docs/BENCHMARK.md](docs/BENCHMARK.md).

| Metric (median) | KOReader | Zigg Reader |
| --- | --- | --- |
| Page turn, EPUB (20 turns) | 59 ms | **45 ms** |
| Page turn, scanned PDF (20 turns) | 1,286 ms (6 of 20 at ~43 ms, the rest 0.3–2.7 s) | **58 ms** (max 83 ms) |
| Book open to ready, EPUB (3 opens) | 3.1 s | **1.8 s** |
| Book open to ready, scanned PDF (3 opens) | 5.1 s | **2.6 s** |
| 10 rapid taps, EPUB: page changes seen | 8 of 10 | **10 of 10** |
| Memory (RSS), EPUB | **52 MB** | 57 MB |
| Memory (RSS), scanned PDF | **133 MB** (peak 156) | 316 MB (peak 336) |

Zigg Reader uses more memory on the PDF because it pre-renders and caches nearby pages, which is what keeps its page turns fast. Rapid taps on the PDF were inconclusive, and KOReader's library-launch samples were invalid, so neither is compared here.

About these numbers: times are to the framebuffer update; the e-ink refresh itself adds roughly 250 ms for both readers. The test measured steady forward reading, where Zigg Reader had already prefetched the next pages. On a heavy scanned PDF, a page that isn't prefetched yet (right after opening, after a jump, or when turning faster than pages render) can take about 1–3 s in Zigg Reader too. KOReader was measured the same way, so the comparison is like for like.

## Size

0.11.5: the ARM executable is **7,760,232 bytes**; the runtime archive is **10.8 MB** (`release/zr115.tgz`), about **26 MiB** installed including the English (14.4 MB) and Latin (5.0 MB) dictionaries ([sizes](release/zr115-sizes.json)).

## Safety

- Back up books, notes, reading state and an older runtime before changing anything.
- Keep a working **key-only SSH** recovery connection. Never enable passwordless/no-auth access.
- Never run the stock reader, KOReader and Zigg Reader together.
- Do not use USB mass storage while reading.
- Do not edit `/`, `/var/base-local`, kernel settings, startup jobs or system partitions for cleanup.
- Do not enable experimental sleep with a stock passcode or rely on it overnight.

Emergency command, on the Kindle over SSH:

```sh
sh /mnt/us/zreader/zreader-maintenance.sh restore-ui
```

Zigg Reader is an independent project, not affiliated with or endorsed by Amazon. Use it at your own risk.

## Licence

The MuPDF-linked application is distributed under **GNU AGPL version 3**; see [LICENSE](LICENSE). WordNet uses Princeton's separate licence; the Latin dictionary is built from William Whitaker's WORDS data (free for any use, attribution in `dictionary/LATIN-LICENSE`); embedded fonts retain SIL OFL notices. No books are included. The full reader source is in this repository, and the exact MuPDF source link and checksum are in [BUILD](docs/BUILD.md) and [THIRD_PARTY](THIRD_PARTY.md). If you share modified builds, please share your source too, as the AGPL asks.

## Credits

- [MuPDF](https://mupdf.com) by Artifex (AGPL) renders every format.
- WordNet 3.0, Princeton University, for the English dictionary.
- WORDS, a Latin dictionary, by Colonel William Whitaker (USAF, Retired), Copyright William A. Whitaker (1936-2010), for the Latin dictionary; data as published at github.com/mk270/whitakers-words.
- Noto Sans and Charis SIL fonts (SIL OFL); Latin hyphenation patterns by Claudio Beccari (hyph-utf8).
- Test text: the first chapters of *Alice's Adventures in Wonderland* by Lewis Carroll (public domain, Project Gutenberg eBook #11).
