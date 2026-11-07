# Zigg Reader

A small, standalone PDF/EPUB reader written in Zig and C for a jailbroken **Kindle Paperwhite 12th generation (PW6)**. The executable is `zreader`; KUAL calls it “Zig reader”. These names refer to the same application.

**Version: 0.8.0 · tested device family: PW6 only · other Kindles: untested.**

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

Developers: [build](docs/BUILD.md) · [tests and evidence](docs/TESTING.md) · [architecture](docs/ARCHITECTURE.md) · [known limitations](docs/LIMITATIONS.md) · [roadmap](docs/ROADMAP.md) · [licences](THIRD_PARTY.md).

## Version history

Full details in [CHANGELOG.md](CHANGELOG.md). Earlier versions were early prototypes and are not listed.

| Version | Scope |
| --- | --- |
| 0.4 baseline | PDF/EPUB reading, recursive library, reading-position persistence, directional pre-rendering, two render workers and 14 raster-cache slots; queued page-turn taps are merged rather than rendering every intermediate target. |
| 0.5 | Precise word hit testing in the displayed page coordinates; word-snapping drag selection and adjustable endpoints; underlines/highlights; tap a mark to delete, change style or copy its passage; JSON and text notes rewritten after edits. |
| 0.5.1 | REAGL for normal text; GC16 FULL for heavy image/dark transitions and context changes; full refresh Off/4/8/16 (default 8); conservative image-only grayscale dithering. Inherited hardware dark mode is preserved, not emulated or switched off. |
| 0.6 | PDF fit-page/fit-width/1.5×/2× and pan; EPUB persistent text anchors, adjustable typography and spacing; offline WordNet English dictionary; incremental in-book search; JSON/TXT/Markdown exports; reversible crash-dump marker helper. |
| 0.7 | Lazy library covers, relative folders, Recent/Title/Progress sorting and progress bars; frontlight and warmth via LIPC only; experimental opt-in power-button sleep and independent emergency recovery. |
| 0.8.0 | Scanned-book flicker fix: grey paper tone is no longer counted as a heavy image (scan-D-type 372-page scan: 372/372 GC16 flashes → 353 REAGL + 19 intentional cleans for opening, cover and real photo pages). Periodic full refresh Off by default and its bottom label removed. Persistent cover cache (≤10 MiB) with instant placeholders and next-page prefetch. Faster first page and EPUB pagination cache. Library storage line (free/total, books total) and per-book type and size. Battery bar and percentage top-right (read-only, no extra refresh). 64-bit timestamp fix for “opened”. App core dumps disabled. Known limitation: first cold open of a big EPUB with a deep saved spot can still be slow once. |

Notes are overlays: original book files are never modified. Books belong in `/mnt/us/Books`, including subfolders. DRM-protected books are not supported by this workflow.

## Benchmark: Zigg Reader vs KOReader

A side-by-side test on the same Kindle Paperwhite 12th gen, with the same books and settings, is coming. It will measure:

- tap-to-screen latency for page turns
- rapid taps (bursts of page turns)
- book open time
- memory use

Results will be published here once the test has been run.

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

## Space and distribution

The installed ARM executable is **6,645,540 bytes** and the WordNet index **14,449,559 bytes** (13.78 MiB). The original compressed runtime is about 8.23 MiB. Allow at least 50 MiB free for a fresh installation, and more for upgrade backups and staging. Library thumbnails grow lazily to at most 10 MiB of cache payload, plus a small RAM cache. Books, notes and backups are additional.

On our test Kindle, cleanup recovered about 2.5 GB of crash dumps and 150 MB of VoiceView data, leaving about 9.2 GB free. Your numbers will differ. System partitions were left alone.

`release/zr08.tgz` is the current 0.8.0 runtime; `release/zr07.tgz` is kept for rollback. Checksums are in `release/SHA256SUMS`. `docs/REFERENCE_MANUAL.txt` is the detailed technical manual written during development.

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
