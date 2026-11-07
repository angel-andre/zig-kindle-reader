# Zigg Reader

A small, standalone PDF/EPUB reader written in Zig and C for a jailbroken **Kindle Paperwhite 12th generation (PW6)**. The executable is `zreader`; KUAL calls it “Zig reader”. These names refer to the same application.

**Version: 0.7.0 · tested device family: PW6 only · other Kindles: untested.**

This project is not replacement firmware. It temporarily pauses the stock interface while reading and restores it on exit. It does not remove Amazon's operating system, alter system partitions, or replace the jailbreak. There is no claim of broader compatibility or measured superiority over KOReader.

> Keep this repository private until its owner explicitly decides otherwise. Read the safety and recovery instructions before installation. Power-button sleep is EXPERIMENTAL, OFF by default, and not yet physically validated. Leave it off for normal use.

## Start here

1. [Prerequisites and access](docs/PREREQUISITES.md)
2. [Install or upgrade](docs/INSTALL.md)
3. [Controls and features](docs/USER_GUIDE.md)
4. [Safe cleanup and what changed](docs/DEBLOAT.md)
5. [Recovery and troubleshooting](docs/TROUBLESHOOTING.md)
6. [Uninstall and rollback](docs/UNINSTALL.md)

Developers: [build](docs/BUILD.md) · [tests and evidence](docs/TESTING.md) · [architecture](docs/ARCHITECTURE.md) · [known limitations](docs/LIMITATIONS.md) · [roadmap and benchmark plan](docs/ROADMAP.md) · [licences](THIRD_PARTY.md).

## Features by version

| Version | Scope |
| --- | --- |
| 0.4 baseline | PDF/EPUB reading, recursive library, reading-position persistence, directional pre-rendering, two render workers and 14 raster-cache slots; queued page-turn taps are merged rather than rendering every intermediate target. |
| 0.5 | Precise word hit testing in the displayed page coordinates; word-snapping drag selection and adjustable endpoints; underlines/highlights; tap a mark to delete, change style or copy its passage; JSON and text notes rewritten after edits. |
| 0.5.1 | REAGL for normal text; GC16 FULL for heavy image/dark transitions and context changes; full refresh Off/4/8/16 (default 8); conservative image-only grayscale dithering. Inherited hardware dark mode is preserved, not emulated or switched off. |
| 0.6 | PDF fit-page/fit-width/1.5×/2× and pan; EPUB persistent text anchors, adjustable typography and spacing; offline WordNet English dictionary; incremental in-book search; JSON/TXT/Markdown exports; reversible crash-dump marker helper. |
| 0.7 | Lazy library covers, relative folders, Recent/Title/Progress sorting and progress bars; frontlight and warmth via LIPC only; experimental opt-in power-button sleep and independent emergency recovery. |

Notes are overlays: original book files are never modified. Books belong in `/mnt/us/Books`, including subfolders. DRM-protected books are not supported by this workflow.

## Screenshots

These are host-generated UI previews from synthetic books and fixtures. They show framebuffer values, not physical e-ink ghosting or hardware dark-mode appearance.

| Library | Folders | Light & Sleep |
| --- | --- | --- |
| ![Library](shots/71_library_covers_preview.png) | ![Folders](shots/73_library_folders_preview.png) | ![Light and sleep](shots/75_light_inherited_preview.png) |

| EPUB typography | Selection and annotations | Search |
| --- | --- | --- |
| ![Typography](shots/50_epub_typography_preview.png) | ![Annotations](shots/53_epub_annotation_popup_preview.png) | ![Search](shots/61_search_keyboard_preview.png) |

## Space and distribution

The installed ARM executable is **6,645,540 bytes** and the WordNet index **14,449,559 bytes** (13.78 MiB). The original compressed runtime is about 8.23 MiB. Allow at least 50 MiB free for a fresh installation, and more for upgrade backups and staging. Library thumbnails grow lazily to at most 10 MiB of cache payload, plus a small RAM cache. Books, notes and backups are additional.

The reference cleanup recovered approximately 2.5 GB of crash dumps and 150 MB of VoiceView data; the user partition subsequently had about 9.2 GB free. These are historical approximate values, not promised savings on another device. System partitions were intentionally left alone.

`release/zr07.tgz` is the original installed-version runtime, with checksum records. Its bundled README and `docs/REFERENCE_MANUAL.txt` are historical build-time documents: their “not deployed” statements describe the original host build, not the later recorded installation. See [provenance](docs/PROVENANCE.md) for what was and was not verified.

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

The MuPDF-linked application is distributed under **GNU AGPL version 3**; see [LICENSE](LICENSE). WordNet uses Princeton's separate licence; embedded fonts retain SIL OFL notices. No rights to third-party books are included. Exact dependency sources and checksums are documented in [BUILD](docs/BUILD.md) and [THIRD_PARTY](THIRD_PARTY.md). Source must remain available to binary recipients; private repository visibility is not a substitute for providing it.
