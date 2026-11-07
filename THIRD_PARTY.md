# Licences and corresponding source

## Reader and MuPDF

The reader links statically with MuPDF 1.28.6. Distribution is under GNU Affero General Public License version 3; the complete licence is `LICENSE`, and upstream's notice is `third_party/MuPDF-COPYING`. Do not describe the executable as MIT/BSD or closed source.

Reader source, wrapper modifications, platform support, build scripts and UI font source asset are in this repository. No MuPDF source patches were found: file-by-file comparison against the original complete source archive matched. Exact source retrieval and SHA-256 are in `docs/BUILD.md`; upstream includes third-party library and bundled document-font notices, which must be retained. This repository does not claim to relicense those dependencies.

**Sharing builds:** the AGPL asks that anyone who receives a binary can also get the matching source. The reader source is all in this repository; the MuPDF source archive is linked with its SHA-256 in `docs/BUILD.md`. If you redistribute builds, keep a copy of that archive available alongside them.

## WordNet 3.0

Copyright 2006 Princeton University. The included compact index is a modified gloss-only derivative, not the full relational database. `dictionary/LICENSE` retains the Princeton licence and attribution; `dictionary/FORMAT` documents the format and source, and `dictionary/source/WNdb-3.0.tar.gz` contains the licensed input. No Princeton endorsement is implied.

## Fonts

The UI uses Noto Sans; `src/fonts/NotoSans-OFL.txt` contains SIL OFL 1.1. MuPDF's bundled Charis SIL/document font resources and notices remain with its source distribution. Preserve upstream notices when redistributing.

## Books and screenshots

No copyrighted books or pages from them are distributed. The included test EPUB/PDF files and screenshots are generated samples. Book titles mentioned in test reports are books we tested with; you need your own copies to rerun those tests.

## External reference implementations

KOReader's documented Kindle/powerd workflow was consulted as a behavioral reference. The reader is not a KOReader fork and no claim of its device coverage is made. External projects retain their own licences and trademarks.
