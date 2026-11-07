# Changelog

Earlier versions were early prototypes and are not listed.

## 0.9.3

Fast, clean Internet Archive scans: many scanned PDFs store each page as a small JPEG 2000 background, a full-size JPEG 2000 foreground and a 1-bit text mask. These pages took several seconds per turn and looked gray and blotchy. With Clean up scanned pages on, such pages are now drawn as white paper with crisp black print, skipping the slow full-size JPEG 2000 decoding (about 5–10× faster on a desktop). Pages whose background holds a picture are drawn normally, and digital books are unchanged. The reader-menu “Cleanup: every N pages” button is renamed “Full refresh” and is reset to off once, so there are no periodic full flashes by default.

## 0.9.2

Clean up scanned pages: scanned books on yellowed or sepia paper no longer show blotchy stain-like bands on a gray page; the paper becomes white and the print dark. Only pages that are a full-page scan image are changed. EPUBs, text PDFs and digital PDFs with photos or figures look exactly as before (byte-identical in tests). New setting Library → Settings → Clean up scanned pages (ON by default); `--no-clean-scans` turns it off from the command line. No extra screen flash; about 5–7 ms more render time per scanned page on a desktop.

## 0.9.1

Wi-Fi book uploads: Library → Settings (formerly Light / Sleep) → Upload books over Wi-Fi shows an address to open in a phone or computer browser on the same Wi-Fi. PDF and EPUB only, up to 500 MB each; checked file names; existing books are never overwritten (a copy becomes “Name (2).epub”); files are written to a temp file and renamed into the Books folder; an upload is refused if it would leave less than 6 GB free. The upload page runs only while that screen is open, on one port, and the library refreshes afterwards. On the Kindle, the firewall rule for the upload port is added when the screen opens and removed when it closes.

## 0.9.0

Instant reopen: the page you stopped on is saved as a small image (page pixels only, about 80–125 KiB per book, 20 MiB total with oldest removed first) and shown at once when you reopen the book; the real page is drawn behind it and only updated if it looks different, with no extra flash. Page turns tapped while a book is still opening are queued and applied as soon as it is ready. The battery icon and percentage now appear only in the library, never over the text of an open book. New `clear-cache` maintenance command removes the saved pages. A saved page is discarded automatically if the book file or any layout setting (font, margins, spacing, trim, view, page, image options) changes.

## 0.8.2

Fast tapping the library Next/Prev buttons (or fast corner page turns) no longer exits the reader. The exit shortcut is now a triple-tap in the top-left corner on the library and other list screens only; any other tap resets it. While reading, quit via the menu (tap centre) → Quit.

## 0.8.1

Library page changes no longer flicker while covers load: a cached page is one non-flashing update; uncached covers fill in with at most two partial updates limited to the cover column; no full flash on library page changes. Covers already loaded stay ready across page changes. Book count on the library bottom line (“85 books”, or “12 of 85 books” inside a folder).

## 0.8.0

Scanned-book flicker fix: grey paper tone is no longer counted as a heavy image (scan-D-type 372-page scan: 372/372 GC16 flashes → 353 REAGL + 19 intentional cleans for opening, cover and real photo pages). Periodic full refresh Off by default and its bottom label removed. Persistent cover cache (≤10 MiB) with instant placeholders and next-page prefetch. Faster first page and EPUB pagination cache. Library storage line (free/total, books total) and per-book type and size. Battery bar and percentage top-right (read-only, no extra refresh). 64-bit timestamp fix for “opened”. App core dumps disabled. Known limitation: first cold open of a big EPUB with a deep saved spot can still be slow once.

## 0.7

Lazy library covers, relative folders, Recent/Title/Progress sorting and progress bars; frontlight and warmth via LIPC only; experimental opt-in power-button sleep and independent emergency recovery.

## 0.6

PDF fit-page/fit-width/1.5×/2× and pan; EPUB persistent text anchors, adjustable typography and spacing; offline WordNet English dictionary; incremental in-book search; JSON/TXT/Markdown exports; reversible crash-dump marker helper.

## 0.5.1

REAGL for normal text; GC16 FULL for heavy image/dark transitions and context changes; full refresh Off/4/8/16 (default 8); conservative image-only grayscale dithering. Inherited hardware dark mode is preserved, not emulated or switched off.

## 0.5

Precise word hit testing in the displayed page coordinates; word-snapping drag selection and adjustable endpoints; underlines/highlights; tap a mark to delete, change style or copy its passage; JSON and text notes rewritten after edits.

## 0.4 baseline

PDF/EPUB reading, recursive library, reading-position persistence, directional pre-rendering, two render workers and 14 raster-cache slots; queued page-turn taps are merged rather than rendering every intermediate target.
