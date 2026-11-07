# Changelog

Earlier versions were early prototypes and are not listed.

## 0.10.3

Latin dictionary: Look up now also searches an offline Latin dictionary built from William Whitaker’s WORDS data (`dictionary/latin.zdict`, 5,042,113 bytes). Inflected forms find their headword and the form is named: *amavit* → amo, amare, amavi, amatus (perf. act. ind. 3rd sg.); *rosarum* → rosa, rosae (gen. pl.); *est* → sum; *virumque* → vir + -que. Macrons and accents are ignored, and u/v and i/j count as the same letter. In a book whose declared language is Latin (EPUB `dc:language`, FB2 `lang`, PDF `/Lang`) Latin is looked up first; elsewhere English comes first and Latin is used when English has no entry. **EN** and **LA** buttons in the lookup popup switch between the two. A lookup takes about 10 µs on a desktop (well under 1 ms on the Kindle). Without `latin.zdict` the popup is exactly as before. The data's attribution and licence are in `dictionary/LATIN-LICENSE`; `dictionary/build_latin.py` rebuilds the file byte-identically from `dictionary/source/whitaker-words-data.tar.gz`.

## 0.10.2

More formats: DRM-free **MOBI**, **AZW3** (KF8), **TXT**, **CBZ** comics and **FB2** now open alongside PDF and EPUB, with the library (type and size shown), Wi-Fi upload, sorting, collections, stats, bookmarks and Contents. MOBI, AZW3, FB2 and TXT are reflowed like EPUB, with text size, margins, line spacing, Font, Align and hyphenation, plus highlights, notes, search and the dictionary; CBZ pages are images fitted to the screen. TXT files become paragraphs, and lines such as “CHAPTER I.” become headings that start a new page and fill Contents. AZW3 files are joined from their KF8 parts with their own CSS (internal links are not followed yet). MOBI, AZW3 and FB2 chapters start on a new page, and their Contents is detected when the file has no useful outline. DRM-protected MOBI/AZW/AZW3, Amazon KFX and encrypted EPUBs show “This book is DRM-protected and can't be opened” instead of a blank page; damaged files show “Could not open this book”. Small MuPDF patches in `mupdf-patches/` (02–05) do the TXT paragraphs, the azw/azw3 names, page breaks for non-EPUB books and the KF8 join; they are off for PDF and EPUB, whose pages are byte-identical to 0.10.1. CBR (RAR) and KFX are not supported. Released on the device together with 0.10.3.

## 0.10.1

Contents for books without an outline: when a PDF or EPUB has no table of contents, opening Contents scans the text (the OCR text layer for scanned books) in the background for chapter headings near the top of a page (CHAPTER/Chapter/PART/BOOK with digits, roman numerals or number words, plus Preface, Prologue, Epilogue, Notes, Index and similar). Progress is shown and you can keep reading; the result is cached in `state/contents/` and labelled “Contents (detected)”. Running headers and stray matches are rejected; if nothing reliable is found, no entries are shown. Contents of such books always offers “Go to page...” and “Go to %...” with number entry. Books with a real outline are unchanged, and page turns are not slowed while the scan runs. A 772-page scanned book takes about 0.55 s on a desktop and a few seconds on the Kindle. Printed contents pages are not parsed yet, and a heading the OCR misread is skipped.

## 0.10.0

Better EPUB text (EPUBs only; PDF pages unchanged): two new EPUB menu buttons either side of line spacing. Align cycles “Justify + hyphens” (the new default), “Justify” and “Align: original” (exactly the 0.9.x layout); Font cycles “Font: book” (the book’s own fonts), “Font: Charis” (Charis SIL serif) and “Font: Noto Sans”. Both are saved in `ui07.json`, and changing them re-lays the book out at the same place. Hyphenation uses MuPDF’s built-in patterns (English, German, French, Spanish, Italian, Portuguese, Russian and others) plus compact Latin patterns; books that declare no language are hyphenated as English, and `xml:lang` is honoured (a small MuPDF patch in `mupdf-patches/`, applied by `build-mupdf.sh`). A book’s own centred or right-aligned paragraphs keep their alignment. Adds about 0.39 MB (Noto Sans Bold/Italic/Bold Italic, Latin subsets).

## 0.9.9

Battery saving and a low-battery warning: the reader no longer wakes on a timer while you read or sit in the library. The input loop sleeps until a touch, the power button, a finished page or cover, or its next real deadline; the device helper thread, which used to wake every 20 ms (about 50 times a second), now waits for a request, a powerd event or its 3-minute battery read. Host measurements: idle wakeups about 10/s → 0/s in the reader and library, and about 50/s → 0.1/s in the device thread. Page turns, pixels, the refresh policy and the exit gesture are unchanged; the frontlight and Wi-Fi radio are not touched. In the library only, a notice under the battery reads “Battery low (N%) · charge soon” at 15% or less and “Battery very low” (white on black) at 5% or less; it is drawn with the normal library update and never over book pages.

## 0.9.8

Collections, favourites and size sort: long-press a book in the library for Favourite, Add to collection, Remove from collection or Cancel; favourites get a small star. The Folder button now opens “Show”: All books, the folders, Favourites, each collection and “+ New collection” (the current sort is kept). Long-press a collection there to rename or delete it; deleting never removes books. Names use the on-screen keyboard. The Sort button adds “Size: largest first” and “Size: smallest first”, using the file sizes the library already reads; the chosen sort is kept across restarts. Collections are stored in `state/collections.tsv`; a book renamed with an upload “(N)” suffix stays in its lists. Includes 0.9.7 reading stats.

## 0.9.7

Reading stats, kept on the Kindle only: Settings › Reading stats shows today, last 7 days and all-time reading time, books finished, a day streak, a 7-day bar chart and the most recent books; Reset stats asks for a second tap. Contents shows the open book’s time read, pages, sessions and percent, plus an estimate of the time left for EPUBs. Only active reading counts (a page on screen, menu closed, awake, a page turn within 2.5 minutes). Stats are saved in `state/stats.tsv` at most once a minute and on close, sleep and exit, never during page turns. Book pages are unchanged. (Released on the device together with 0.9.8.)

## 0.9.6

Highlights and notes, with export: long-press a word, then drag or tap the end word (EPUB text and PDFs with a text layer, including OCR scans). The popup offers Highlight, Underline, Note, Look up (single word, offline dictionary), Copy to notes and Cancel. Note saves a highlight and opens a compact on-screen keyboard. Tapping a highlight offers Edit note, Remove, change style, Copy to notes and Cancel. The menu’s Notes button opens “Highlights & notes” (page, style, date, passage, note; tap to jump, long-press to delete). Highlights are drawn with the normal page update and never stored in the page cache; pages without them are unchanged. Export: the Upload screen’s web page offers each book’s highlights and notes, plus an all-books file, as Markdown or plain text while the screen is open, and the same files are kept in `export/` on the Kindle for USB. Nothing is sent anywhere automatically.

## 0.9.5

Bookmarks: “Bookmark” / “Unbookmark” in the PDF menu’s second row and a “Bookmarks” button for PDF and EPUB. The Bookmarks screen lists them in page order with the date and the first words of the page; tap to jump, long-press to delete, and its bottom button bookmarks or un-bookmarks the current page. A bookmarked page shows a small ribbon at the top right, drawn with the normal page update (no extra flash). Bookmarks are stored per book on the Kindle and EPUB bookmarks follow reflow. Pages without a bookmark look exactly as before. `--version` now prints the correct version.

## 0.9.4

Tidier in-book menu: “Up” and “Down” are removed (tapping or swiping the page does the same), leaving room for future buttons. Faster launch: SSH setup, the screen snapshot and the UI-pause settle delay now overlap instead of running one after another (an estimated 0.3–1 s saved), and the log gets a “launch profile:” timing line. Faster scans: a single full-page JPEG 2000 scan page is decoded at screen resolution when Clean up scanned pages is on (covers, photos and digital pages unchanged). A “slow pages:” log line flags books whose pages render slowly. Known issue: the 0.9.4 binary reports its version as 0.9.3; fixed in 0.9.5.

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
