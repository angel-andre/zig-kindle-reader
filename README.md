# Zigg Reader

A small, standalone PDF/EPUB reader written in Zig and C for a jailbroken **Kindle Paperwhite 12th generation (PW6)**. The executable is `zreader`; KUAL calls it “Zig reader”. These names refer to the same application.

**Version: 0.9.4 · tested device family: PW6 only · other Kindles: untested.**

This project is not replacement firmware. It temporarily pauses the stock interface while reading and restores it on exit. It does not remove Amazon's operating system, alter system partitions, or replace the jailbreak.

> Read the safety and recovery instructions before installing. Power-button sleep is experimental and off by default; leave it off for normal use.

## Why this exists

KOReader is a feature-rich reader, and it made SSH access to the Kindle easy. On this Kindle, though, it felt laggy: page turns and taps didn't respond as quickly as we wanted. Zigg Reader was built as a small native Zig reader focused on speed: fast page turns, clean e-ink refreshes and no bloat, while keeping the features that matter for reading PDFs and EPUBs.

## Start here

1. [Prerequisites and access](docs/PREREQUISITES.md)
2. [Install or upgrade](docs/INSTALL.md)
3. [Controls and features](docs/USER_GUIDE.md)
4. [Safe cleanup and what changed](docs/DEBLOAT.md)
5. [Recovery and troubleshooting](docs/TROUBLESHOOTING.md)
6. [Uninstall and rollback](docs/UNINSTALL.md)

Developers: [build](docs/BUILD.md) · [tests and evidence](docs/TESTING.md) · [architecture](docs/ARCHITECTURE.md) · [known limitations](docs/LIMITATIONS.md) · [benchmark](docs/BENCHMARK.md) · [roadmap](docs/ROADMAP.md) · [licences](THIRD_PARTY.md).

## Version history

Full details in [CHANGELOG.md](CHANGELOG.md). Earlier versions were early prototypes and are not listed.

| Version | Scope |
| --- | --- |
| 0.4 baseline | PDF/EPUB reading, recursive library, reading-position persistence, directional pre-rendering, two render workers and 14 raster-cache slots; queued page-turn taps are merged rather than rendering every intermediate target. |
| 0.5 | Precise word hit testing in the displayed page coordinates; word-snapping drag selection and adjustable endpoints; underlines/highlights; tap a mark to delete, change style or copy its passage; JSON and text notes rewritten after edits. |
| 0.5.1 | REAGL for normal text; GC16 FULL for heavy image/dark transitions and context changes; full refresh Off/4/8/16 (default 8); conservative image-only grayscale dithering. Inherited hardware dark mode is preserved, not emulated or switched off. |
| 0.6 | PDF fit-page/fit-width/1.5×/2× and pan; EPUB persistent text anchors, adjustable typography and spacing; offline WordNet English dictionary; incremental in-book search; JSON/TXT/Markdown exports; reversible crash-dump marker helper. |
| 0.7 | Lazy library covers, relative folders, Recent/Title/Progress sorting and progress bars; frontlight and warmth via LIPC only; experimental opt-in power-button sleep and independent emergency recovery. |
| 0.9.4 | Tidier in-book menu: “Up” and “Down” are removed (tapping or swiping the page does the same), leaving room for future buttons. Faster launch: SSH setup, the screen snapshot and the UI-pause settle delay now overlap instead of running one after another (an estimated 0.3–1 s saved), and the log gets a “launch profile:” timing line. Faster scans: a single full-page JPEG 2000 scan page is decoded at screen resolution when Clean up scanned pages is on (covers, photos and digital pages unchanged). A “slow pages:” log line flags books whose pages render slowly. Known issue: the 0.9.4 binary reports its version as 0.9.3; fixed in 0.9.5. |
| 0.9.3 | Fast, clean Internet Archive scans: many scanned PDFs store each page as a small JPEG 2000 background, a full-size JPEG 2000 foreground and a 1-bit text mask. These pages took several seconds per turn and looked gray and blotchy. With Clean up scanned pages on, such pages are now drawn as white paper with crisp black print, skipping the slow full-size JPEG 2000 decoding (about 5–10× faster on a desktop). Pages whose background holds a picture are drawn normally, and digital books are unchanged. The reader-menu “Cleanup: every N pages” button is renamed “Full refresh” and is reset to off once, so there are no periodic full flashes by default. |
| 0.9.2 | Clean up scanned pages: scanned books on yellowed or sepia paper no longer show blotchy stain-like bands on a gray page; the paper becomes white and the print dark. Only pages that are a full-page scan image are changed. EPUBs, text PDFs and digital PDFs with photos or figures look exactly as before (byte-identical in tests). New setting Library → Settings → Clean up scanned pages (ON by default); `--no-clean-scans` turns it off from the command line. No extra screen flash; about 5–7 ms more render time per scanned page on a desktop. |
| 0.9.1 | Wi-Fi book uploads: Library → Settings (formerly Light / Sleep) → Upload books over Wi-Fi shows an address to open in a phone or computer browser on the same Wi-Fi. PDF and EPUB only, up to 500 MB each; checked file names; existing books are never overwritten (a copy becomes “Name (2).epub”); files are written to a temp file and renamed into the Books folder; an upload is refused if it would leave less than 6 GB free. The upload page runs only while that screen is open, on one port, and the library refreshes afterwards. |
| 0.9.0 | Instant reopen: the page you stopped on is saved as a small image (page pixels only, about 80–125 KiB per book, 20 MiB total with oldest removed first) and shown at once when you reopen the book; the real page is drawn behind it and only updated if it looks different, with no extra flash. Page turns tapped while a book is still opening are queued and applied as soon as it is ready. The battery icon and percentage now appear only in the library, never over the text of an open book. New `clear-cache` maintenance command removes the saved pages. |
| 0.8.2 | Fast tapping the library Next/Prev buttons (or fast corner page turns) no longer exits the reader. The exit shortcut is now a triple-tap in the top-left corner on the library and other list screens only; any other tap resets it. While reading, quit via the menu (tap centre) → Quit. |
| 0.8.1 | Library page changes no longer flicker while covers load: a cached page is one non-flashing update; uncached covers fill in with at most two partial updates limited to the cover column; no full flash on library page changes. Covers already loaded stay ready across page changes. Book count on the library bottom line (“85 books”, or “12 of 85 books” inside a folder). |
| 0.8.0 | Scanned-book flicker fix: grey paper tone is no longer counted as a heavy image (scan-D-type 372-page scan: 372/372 GC16 flashes → 353 REAGL + 19 intentional cleans for opening, cover and real photo pages). Periodic full refresh Off by default and its bottom label removed. Persistent cover cache (≤10 MiB) with instant placeholders and next-page prefetch. Faster first page and EPUB pagination cache. Library storage line (free/total, books total) and per-book type and size. Battery bar and percentage top-right (read-only, no extra refresh). 64-bit timestamp fix for “opened”. App core dumps disabled. Known limitation: first cold open of a big EPUB with a deep saved spot can still be slow once. |

Notes are overlays: original book files are never modified. Books belong in `/mnt/us/Books`, including subfolders. DRM-protected books are not supported by this workflow.

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

## Screenshots

These previews are rendered on a computer from sample books, so they don't show e-ink ghosting or the Kindle's hardware dark mode.

| Library | Folders | Light & Sleep |
| --- | --- | --- |
| ![Library](shots/71_library_covers_preview.png) | ![Folders](shots/73_library_folders_preview.png) | ![Light and sleep](shots/75_light_inherited_preview.png) |

| EPUB typography | Selection and annotations | Search |
| --- | --- | --- |
| ![Typography](shots/50_epub_typography_preview.png) | ![Annotations](shots/53_epub_annotation_popup_preview.png) | ![Search](shots/61_search_keyboard_preview.png) |

| Storage and battery (0.8, mock data) | Scanned-book refresh log (0.8) |
| --- | --- |
| ![Storage and battery](shots/86_library_storage_battery_mock_dark.png) | ![Refresh log](shots/89_scan_turn_log.png) |

| Book count (0.8.1, mock data) | Folder book count (0.8.1, mock data) |
| --- | --- |
| ![Book count](shots/90_library_book_count_mock_dark.png) | ![Folder count](shots/91_library_folder_count_mock_dark.png) |

## Space and distribution

The installed ARM executable is **6,645,540 bytes** and the WordNet index **14,449,559 bytes** (13.78 MiB). The original compressed runtime is about 8.23 MiB. Allow at least 50 MiB free for a fresh installation, and more for upgrade backups and staging. Library thumbnails grow lazily to at most 10 MiB of cache payload, plus a small RAM cache. Books, notes and backups are additional.

On our test Kindle, cleanup recovered about 2.5 GB of crash dumps and 150 MB of VoiceView data, leaving about 9.2 GB free. Your numbers will differ. System partitions were left alone.

`release/zr094.tgz` is the current 0.9.4 runtime; `release/zr093.tgz` (0.9.3) is kept for rollback. Checksums are in `release/SHA256SUMS`. `docs/REFERENCE_MANUAL.txt` is the detailed technical manual written during development.

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

## Licence

The MuPDF-linked application is distributed under **GNU AGPL version 3**; see [LICENSE](LICENSE). WordNet uses Princeton's separate licence; embedded fonts retain SIL OFL notices. No books are included. The full reader source is in this repository, and the exact MuPDF source link and checksum are in [BUILD](docs/BUILD.md) and [THIRD_PARTY](THIRD_PARTY.md). If you share modified builds, please share your source too, as the AGPL asks.
