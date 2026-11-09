# Reading, library and notes

## The menu (0.12)

Tap the centre of a page. The menu shows the page number and percentage, a slider to jump anywhere in the book, and one row of buttons:

- **Contents** (table of contents), **Bookmark** (bookmark this page; it reads **Unbookmark** on a bookmarked page), **Notes** (highlights and notes), **Search**.
- **View** opens a panel above the menu with the display settings for the current book:
  - EPUB, MOBI, AZW3, FB2 and TXT: Text − / Text +, Margin − / Margin +, line spacing, Font, Align, Refresh and Go to start.
  - PDF: the view mode (Fit page, Fit width, Zoom 1.5×, Zoom 2×), Reset pan, **Trim** (margins), **Split** (two-page scans), **Reflow** (scanned PDFs only) and Refresh.
- **More** opens a panel with Bookmarks (the list), Export all, Settings and the Full refresh setting.
- Tap View or More again, or **Back**, to close the panel. **‹ Library** and **Quit** are in the bar at the top.

Labels that don't fit a button are drawn a little smaller instead of being cut off.

## Reflow for scanned pages (0.12)

Scanned books are pictures of pages, so their text can't be resized like an EPUB. In a scanned PDF, **View → Reflow** cycles **off → 1.5× → 2×**. With Reflow on, the reader finds the lines and words on the page image and sets them again, larger, to fill this screen; a page becomes several screens. Tap forward or back to step through them; past the last screen the next page starts (and a back turn lands on the previous page's last screen). Pictures on the page are kept as they are, with the lines beside them and their captions. Pages it can't reflow safely, such as pages that are mostly pictures or spreads, stay in normal page view. It works on split halves too.

The setting is remembered per book. The analysis of each page is cached in `/mnt/us/zreader/cache/` (safe to delete), so a page you have seen opens faster the next time. Reflow is only offered for scanned PDFs; digital PDFs and EPUBs aren't affected. Some words can sit slightly above or below the line.

## Two-page scans (0.11.1)

Scanned PDFs where each page is a landscape scan of two book pages are shown one book page at a time, full screen: the next tap shows the right-hand page, then the following scan's left-hand page. The gutter is found automatically and the facing page never shows at the edge. The menu shows the half, for example “Page 2 L of 6”. **View → Split: on/off** turns it off for a book. Zooming and panning work on the half you are reading (0.11.5).

## Shrink for Kindle (0.11, faster in 0.12)

Long-press a PDF in the library and choose **Shrink for Kindle** to make a smaller copy for this screen: images become greyscale and are downsampled to what the 1272×1696 screen can show (never upscaled). The text layer, fonts, links, page count and page sizes don't change, so search, highlights, notes, the dictionary and saved positions keep working. The run happens in the background with a cancellable progress line. When it finishes you see the size before and after: **Use smaller copy** replaces the book and moves the original to `/mnt/us/zreader/originals/`; **Discard** keeps the book as it was. If the copy isn't at least 10% smaller, the original is kept. **Delete originals** in the long-press menu frees that space (with a confirmation).

0.12 additions: scans stored as “mixed raster” pages (a picture layer plus a colour layer behind a sharp text mask) are shrunk too (0.12.1); the open book is closed first so Shrink has the Kindle to itself, and a watchdog cancels a run that makes no progress for two minutes instead of waiting forever (0.12.2); JPEG 2000 colour layers are decoded at half resolution and lossy images that are already small are skipped, which makes Shrink faster on large scans (0.12.3).

## Delete book (0.11.4)

Long-press a book in the library and choose **Delete book**. A confirm screen shows the title with **Cancel** first; taps within a second of the screen appearing are ignored, so a double tap can't confirm. Before deleting, the book's highlights and notes are exported to `export/`. Only the book file is deleted, and only if it's a real file inside the books folder.

## Theme: Light / Dark (0.11.4)

Library → Settings → **Theme: Light / Dark** (default Light, saved in `ui07.json`). Dark shows the library, menus and pages inverted (black paper, white text) with one redraw when switching. It uses the e-ink panel's inversion, so it depends on the device honouring it.

## Touch and navigation

- Right outer 30% or swipe left: forward. Left outer 30% or swipe right: back.
- Centre tap: menu. Centre double-tap: PDF zoom cycle; centre single-tap waits briefly to distinguish it.
- Library and other list screens: triple-tap the top-left corner to quit and restore the stock interface (any other tap resets the count).
- While reading: tap the centre to open the menu, then Quit.
- Power button: quit by default. Idle timeout defaults to 10 minutes and exits rather than entering reader-managed sleep.
- Contents opens a document's table of contents. The menu also has the page slider; Go to start is in View for reflowable books.

### Contents for books without one (0.10.1)

If a PDF or EPUB has no table of contents, the first time you open Contents the reader looks through the text for chapter headings (“CHAPTER I”, “Chapter 1”, “PART TWO”, Preface, Prologue, Index and so on), using the OCR text of scanned books. A progress line shows while it works; you can close Contents and keep reading. The list is saved, so later it opens at once, and the screen is marked “(detected)”. Tap an entry to go there. For these books Contents always has **Go to page...** (type a page number with the keyboard digits, then Save) and **Go to %...** (0–100). If no reliable headings are found, only those two buttons are shown. Books that have their own table of contents look exactly as before.

## Bookmarks

- Add: open the menu and tap **Bookmark** in the main row; it shows **Unbookmark** on a bookmarked page. **More → Bookmarks** opens the list, whose bottom button reads “Bookmark page N” or “Remove bookmark, page N” for the current page.
- A bookmarked page shows a small black ribbon at the top right. It appears or disappears as soon as you close the menu, with the normal page update and no extra flash. Pages without a bookmark look exactly as before.
- The Bookmarks screen lists bookmarks in page order with the page number, the date added and the first words of the page (blank for pages without a text layer, such as some scans). Tap an entry to jump to it; long-press to delete it.
- Bookmarks are saved per book in `state/` on the Kindle (next to the reading position) and survive restarts and updates. EPUB bookmarks keep a text anchor, so they stay on the same passage after changing text size, margins or spacing. Nothing leaves the device.

## Book formats (0.10.2)

Besides PDF and EPUB, the reader opens DRM-free **MOBI**, **AZW3** (KF8), **TXT**, **CBZ** (comic archives of JPEG/PNG pages) and **FB2**. Put them in `/mnt/us/Books` or send them with Upload books over Wi-Fi. The library shows each book's type and size, and they work with sorting, collections, favourites, stats, bookmarks and Contents.

- **MOBI, AZW3, FB2, TXT** are reflowed like EPUB: text size, margins, line spacing, Font and Align, hyphenation, highlights, notes, search and Look up all work. Chapters start on a new page. If the book has no useful table of contents, Contents finds the chapters (0.10.1).
- **TXT** becomes paragraphs (separated by blank lines, or one per line), and lines like “CHAPTER I.”, “Book II” or “Preface” become headings.
- **CBZ** pages are pictures, fitted to the screen; there is no text to select.
- **DRM.** Kindle-store books with DRM (MOBI/AZW/AZW3), Amazon KFX files and encrypted EPUBs can't be read. Opening one shows “This book is DRM-protected and can't be opened”; nothing else happens. A damaged file shows “Could not open this book”.
- Not supported: CBR (RAR comics) and KFX. Links inside AZW3 books aren't followed yet.

## PDFs and EPUBs

PDF views: fit page, cropped fit width, 1.5× and 2×. Fit-width navigation steps by a screen minus a 96-pixel overlap. Drag once to pan; the pan applies on release. There is no pinch gesture. Trim margins is separate from fit-width cropping. Views and positions persist per book.

EPUBs offer nine text sizes, adjustable margins and line spacing 1.15/1.40/1.70. Chapter/text anchors relocate notes and reading positions after reflow. When relocation cannot be trusted, a passage remains in Notes/export as unresolved instead of marking unrelated text.

### EPUB text (0.10.0)

The View panel has two more buttons next to line spacing. **Align** cycles “Justify + hyphens” (default), “Justify” and “Align: original” (the book’s own alignment, exactly as before 0.10.0). **Font** cycles “Font: book” (the book’s own fonts), “Font: Charis” (a serif) and “Font: Noto Sans” (a sans-serif). Both choices apply to all EPUBs, are remembered, and re-lay the book out at the same place. Hyphenation follows the book’s language (English, Latin, German, French, Spanish, Italian and more); books that don’t declare a language are hyphenated as English. Centred and right-aligned paragraphs stay as the book set them. PDFs are not affected.

## Highlights & notes

**Selecting.** Long-press a word to start, then drag to the end word, or lift and tap the end word. Either endpoint can be refined with its handle. This works on EPUB text and on PDFs with a text layer, including OCR'd scans such as Internet Archive books; pages without any text layer can't be selected.

**Popup.** Highlight, Underline, Note, Look up (single-word selections only; the offline dictionary), Copy to notes and Cancel. Tapping outside the popup, away from text, cancels.

**Notes and the keyboard.** Note saves the passage as a highlight and opens a compact on-screen keyboard: digits, letters, punctuation, Shift, Space, Backspace, Clear, Cancel and Save. The first letter, and the letter after . ? or !, is capitalised automatically. Cancel keeps the highlight without note text. The keyboard is English only (no accented letters).

**Editing.** Tap an existing highlight or underline for Edit note (Add note if it has none), Remove, switching between underline and highlight, Copy to notes or Cancel.

**Display.** Highlights are drawn with the normal page update (no extra flash) and are never stored in the saved-page cache; pages without highlights look exactly as before.

**List.** The menu's Notes button opens “Highlights & notes”: page, style, date, the passage and its note. Tap an entry to jump to it; long-press to delete it. Deletion rewrites all exports, not just the visible overlay.

**Storage.** Highlights and notes are saved per book in `notes/<book>.json` on the Kindle (the note text is an optional `comment` field). EPUB entries keep a text anchor, so they stay on the same passage after changing text size, margins or spacing.

**Export.** Markdown files are kept in `/mnt/us/zreader/export/`: one `<book>.md` per book and `All books - highlights and notes.md`. They are rewritten whenever notes change, on Export all, and when the Upload screen opens, and can be copied over USB. While the Upload screen is open, its web page (the same address used to send books) also lists every book plus the all-books file, each as Markdown or plain text, for download. The download list is read-only and disappears with the upload page when you leave the screen. Nothing is sent anywhere automatically.

`Copy to notes` stores the passage in this reader's notes. It is not a system-wide clipboard integration.

## Dictionary and search

WordNet 3.0 is offline English vocabulary with paginated senses and basic inflection/accent fallbacks. It has no pronunciation/audio and is not specialist coverage.

**Latin (0.10.3).** Look up also has an offline Latin dictionary (William Whitaker's WORDS). Inflected words find their dictionary form, and the popup says which form it is: *amavit* shows “amo, amare, amavi, amatus (verb, 1st conj.)” with “form: perf. act. ind. 3rd sg.”; *rosarum* shows rosa (gen. pl.); *virumque* shows vir plus “-que = and”. Macrons and accents don't matter (*Rosārum* = *rosarum*), and u/v and i/j are treated as the same letter (*Iulius* = *Jūlius*). Which dictionary is used:

- In a book that declares Latin as its language (EPUB, FB2, or a PDF's language setting), Latin first.
- In other books, English first; if English has no entry, Latin.
- **EN** and **LA** buttons at the top of the popup switch between them for the selected word. The footer names the dictionary in use (“WordNet 3.0 / English” or “Whitaker's Words / Latin”).

A word that is also English (*in*, *locus*) shows English first in an English book; tap **LA**. MOBI, AZW3 and TXT books don't declare a language, so English comes first there.

Search uses an English keyboard and MuPDF text matching; it scans incrementally and can be stopped. Up to 200 hits are kept. Tap a result to navigate and briefly mark the hit. No OCR and no guarantee for cross-page phrases or broken PDF text order.

## Reading stats (0.9.7)

Everything stays on the Kindle; nothing is sent anywhere and stats are not part of the export.

- **What counts.** Only active reading: a book page is on screen, the menu is closed, the Kindle is awake, and the last page turn was less than 2.5 minutes ago. Leaving a page open and walking away stops the timer after 2.5 minutes.
- **Per book.** Time read, pages read (forward page turns), sessions (each time the book is opened), first and last opened, percent, and finished (reaching the last page). EPUBs also show an estimate of the time left at your own pace once there is enough data. This line is shown next to the title on the Contents screen.
- **Overall.** Settings › **Reading stats** shows today, the last 7 days and all-time reading time, books finished, the day streak (consecutive days with at least a minute of reading, ending today or yesterday), a 7-day grey bar chart (today in black) and the five most recently read books.
- **Reset.** **Reset stats** on that screen asks for a second tap within 5 seconds, then erases all stats.
- **Storage.** `state/stats.tsv`: one line per book and one per day (the last 400 days). It is written at most once a minute and when a book is closed, on sleep and on exit, never on every page and never while a page is rendering.

## Library and device controls

Sorting and the Folder/Show filter are described below. Covers are generated lazily only for visible rows; unavailable/complex covers get placeholders. The disk cache is capped at 10 MiB, with 32 thumbnails in RAM. Changed files refresh on a later session, not via a live watcher. Since 0.8.0 cached covers load on a separate worker, new covers show a title/type placeholder immediately, and the next library page is prefetched. The header shows free/total storage and total book size; each row shows type (PDF, EPUB, MOBI, AZW3, TXT, CBZ, FB2) and file size. A battery bar with percentage sits top-right in the library only (read-only, polled at most every three minutes, no extra refresh). Since 0.9.0 it is never drawn while a book is open, so it cannot cover text.

The Settings button (in the library, and in the reader under More; called Light / Sleep before 0.9.1) offers separate native 0–24 brightness and warmth controls through `com.lab126.powerd` LIPC. Startup reads values and does not write them; only deliberate adjustments queue a write. No backlight sysfs write is used. Leave experimental power-button sleep OFF until the physical plan in TESTING is completed.

## Sorting (incl. size, 0.9.8)

The Sort button cycles **Recent → Title → Progress → Size: largest first → Size: smallest first**. Size sorting covers all books (PDF and EPUB) and uses the file sizes the library already reads for the storage summary, so loading is not slower. Ties are ordered by title. The sort applies within whatever is shown (All, a folder, Favourites or a collection) and is saved in `ui07.json`, so it survives restarts.

## Collections & favourites (0.9.8)

- **Book menu.** Long-press a book in the library (before 0.9.8 this did nothing): **Favourite** / **Remove from Favourites**, **Add to collection** (choose one, or **+ New collection**), **Remove from collection** (only shown when the book is in one) and **Cancel**. Favourites show a small star before the title.
- **Show filter.** The Folder button opens **Show**: All books, the folders (in the same rows as before), then Favourites, each collection and **+ New collection**. Picking one filters the library and keeps the current sort; the button shows the active filter.
- **Manage.** In Show, long-press a collection for **Rename** or **Delete collection**; delete asks once more and only removes the list, never the books. New names and renames use the on-screen keyboard from 0.9.6.
- **Storage.** `state/collections.tsv` holds collection names and member lines (file size and path). If a member's path disappears, for example after a rename to “Name (3).pdf”, it is re-attached to the single book with the same size and title. When several identical copies exist it prefers the one not in any list yet, and otherwise leaves the entry alone rather than guess.

## Battery (0.9.9)

The reader now sleeps between your taps instead of checking for work ten times a second, and its device helper no longer wakes every 20 ms, so idle reading uses less power. Nothing about page turns or the screen changes. In the library, a notice appears under the battery: “Battery low (N%) · charge soon” at 15% or less, and a white-on-black “Battery very low” at 5% or less. It is never drawn over a book page. The reader does not switch Wi-Fi on or off (it is used only while the Upload screen is open); use Airplane mode for the longest standby.

## Refresh and dark mode

Normal text uses REAGL. Heavy images, substantial dark/light transitions and menu/library context changes request GC16 FULL. The Full refresh button in More (Off/4/8/16; called “Cleanup” before 0.9.3) controls periodic full refreshes of text pages. It is Off by default and was reset to Off once in 0.8.0 and again in 0.9.3. Scanned pages with grey paper tone use REAGL; only real photos, covers and context changes get GC16; Off does not disable heavy/context safety cleans. The Kindle's own dark mode is inherited, never toggled by the reader; the reader's Dark theme (above) is a separate setting.

## Your data

| Location | Purpose |
| --- | --- |
| `/mnt/us/Books/` | Your original books, recursively scanned |
| `/mnt/us/zreader/state/` | Book positions, typography and PDF view state |
| `/mnt/us/zreader/notes/` | JSON annotations and derived plain text |
| `/mnt/us/zreader/export/` | Markdown passages, rewritten after note edits |
| `/mnt/us/zreader/settings.json` | Full-refresh preferences |
| `/mnt/us/zreader/ui07.json` | Sort, theme, text style and experimental sleep preference |
| `/mnt/us/zreader/originals/` | Originals kept by Shrink for Kindle until you delete them |
| `/mnt/us/zreader/thumbs/` | Regenerable thumbnail cache |
| `/mnt/us/zreader/cache/` | Saved page images and reflow layouts (safe to delete) |
| `/mnt/us/zreader.log` and `zreader-stderr.log` | Runtime diagnostics; may contain personal book paths |

Use Export all for books not currently open too. Back up JSON notes and state, not just exports. Different books sharing a basename still share the legacy note/export filename: rename them uniquely before annotating.

## Instant reopen (0.9.0)

When you leave a book (Quit, power button, idle exit, sleep or opening another book) the page you were on is saved as a small grayscale image, and a fresh copy is saved every 8 page turns. Reopening the book shows that page immediately while the document loads; if the real page looks identical, the screen is not updated again. Page turns tapped during loading are applied once the book is ready.

Saved pages live in `/mnt/us/zreader/cache/pages/` (about 80–125 KiB per book, 20 MiB total; the least recently read books are removed first). They contain only page pixels and a check value, and are ignored if the book file or its layout settings change. To delete them all, with the reader closed:

```
sh /mnt/us/zreader/zreader-maintenance.sh clear-cache
```

Books, notes, reading positions and settings are not affected.

## Clean up scanned pages (0.9.2)

Library → Settings → **Clean up scanned pages: ON/OFF** (ON by default). On scanned books (photographed or scanned paper, often yellowed or sepia) it turns the paper white and the print dark, removing the blotchy gray bands the paper tint otherwise causes on the 16-gray screen.

It only affects scanned pages: a page whose content is one full-page image (optionally with further image layers and invisible OCR text). Any page with real text, vector drawings or a smaller photo or figure — every EPUB and normal digital PDF — is drawn exactly as before, whether the setting is on or off. Turn it off if you prefer the original paper tone of a scan. The setting is remembered; `--no-clean-scans` / `--clean-scans` override it from the command line.

Since 0.9.3 this also speeds up scanned books from the Internet Archive and similar sources, where a page is a background image plus a full-page text layer with a 1-bit mask. Such pages are drawn as white paper with the text in black, without decoding the large JPEG 2000 images, so page turns are much faster. If a page's background holds a picture, or the text layer is not mostly dark, the page is drawn normally. With the setting off, these books look and behave as before (slower).

## Upload books over Wi-Fi (0.9.1)

1. Make sure the Kindle and your phone or computer are on the same Wi-Fi.
2. In the library, tap Settings, then Upload books over Wi-Fi.
3. The screen shows an address such as `http://<Kindle address>:8080`. Open it in a browser on the phone or computer.
4. Choose one or more book files (PDF, EPUB, MOBI, AZW3, TXT, CBZ or FB2) and tap Upload. The Kindle screen shows the progress and how many books arrived.
5. Tap Close. The library refreshes and the new books appear.

Rules: .pdf .epub .mobi .azw3 .txt .cbz .fb2 only, up to 500 MB per file. File names with folders, `..`, hidden names or unusual characters are refused. An existing book is never overwritten; a second copy is saved as “Name (2).epub”. An upload is refused if it would leave less than 6 GB free. The upload page exists only while that screen is open: closing it, sleeping, quitting or the idle timeout stops it immediately.
