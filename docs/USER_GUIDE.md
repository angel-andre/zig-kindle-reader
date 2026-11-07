# Reading, library and notes

## Touch and navigation

- Right outer 30% or swipe left: forward. Left outer 30% or swipe right: back.
- Centre tap: menu. Centre double-tap: PDF zoom cycle; centre single-tap waits briefly to distinguish it.
- Triple-tap a corner: quit and restore the stock interface.
- Power button: quit by default. Idle timeout defaults to 10 minutes and exits rather than entering reader-managed sleep.
- Contents opens a document's table of contents. The menu also offers progress, go-to and return to start.

## PDFs and EPUBs

PDF views: fit page, cropped fit width, 1.5× and 2×. Fit-width navigation steps by a screen minus a 96-pixel overlap. Drag once to pan; the pan applies on release. There is no pinch gesture. Trim margins is separate from fit-width cropping. Views and positions persist per book.

EPUBs offer nine text sizes, adjustable margins and line spacing 1.15/1.40/1.70. Chapter/text anchors relocate notes and reading positions after reflow. When relocation cannot be trusted, a passage remains in Notes/export as unresolved instead of marking unrelated text.

## Selection and annotations

Long-press a word and drag to select. Refine either endpoint with its handle after lifting. Choose Underline, Highlight, Copy to notes or Cancel. A single-word selection also offers Define.

Tap an existing mark to Delete, Change style or Copy to notes. The Notes list jumps to passages; long-press a note to delete it. Deletion rewrites all derived exports, not just the visible overlay.

`Copy to notes` stores the passage in this reader's notes. It is not a system-wide clipboard integration.

## Dictionary and search

WordNet 3.0 is offline English vocabulary with paginated senses and basic inflection/accent fallbacks. It has no pronunciation/audio and is not specialist or multilingual coverage.

Search uses an English keyboard and MuPDF text matching; it scans incrementally and can be stopped. Up to 200 hits are kept. Tap a result to navigate and briefly mark the hit. No OCR and no guarantee for cross-page phrases or broken PDF text order.

## Library and device controls

Recent → Title → Progress cycles sorting. Folder selects relative subfolders; All resets it. Covers are generated lazily only for visible rows; unavailable/complex covers get placeholders. The disk cache is capped at 10 MiB, with 32 thumbnails in RAM. Changed files refresh on a later session, not via a live watcher. Since 0.8.0 cached covers load on a separate worker, new covers show a title/type placeholder immediately, and the next library page is prefetched. The header shows free/total storage and total book size; each row shows type (PDF/EPUB) and file size. A battery bar with percentage sits top-right in library and reader (read-only, polled at most every three minutes, no extra refresh).

Light / Sleep offers separate native 0–24 brightness and warmth controls through `com.lab126.powerd` LIPC. Startup reads values and does not write them; only deliberate adjustments queue a write. No backlight sysfs write is used. Leave experimental power-button sleep OFF until the physical plan in TESTING is completed.

## Refresh and dark mode

Normal text uses REAGL. Heavy images, substantial dark/light transitions and menu/library context changes request GC16 FULL. Refresh Off/4/8/16 controls periodic text cleans (default Off since 0.8.0). Scanned pages with grey paper tone use REAGL; only real photos, covers and context changes get GC16; Off does not disable heavy/context safety cleans. Hardware dark mode is inherited, never toggled by the reader. Host previews do not simulate it.

## Your data

| Location | Purpose |
| --- | --- |
| `/mnt/us/Books/` | Your original books, recursively scanned |
| `/mnt/us/zreader/state/` | Book positions, typography and PDF view state |
| `/mnt/us/zreader/notes/` | JSON annotations and derived plain text |
| `/mnt/us/zreader/export/` | Markdown passages, rewritten after note edits |
| `/mnt/us/zreader/settings.json` | Full-refresh preferences |
| `/mnt/us/zreader/ui07.json` | Sort and experimental sleep preference |
| `/mnt/us/zreader/thumbs/` | Regenerable thumbnail cache |
| `/mnt/us/zreader.log` and `zreader-stderr.log` | Runtime diagnostics; may contain personal book paths |

Use Export all for books not currently open too. Back up JSON notes and state, not just exports. Different books sharing a basename still share the legacy note/export filename: rename them uniquely before annotating.
