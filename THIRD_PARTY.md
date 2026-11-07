# Licences and corresponding source

## Reader and MuPDF

The reader links statically with MuPDF 1.28.6. Distribution is under GNU Affero General Public License version 3; the complete licence is `LICENSE`, and upstream's notice is `third_party/MuPDF-COPYING`. Do not describe the executable as MIT/BSD or closed source.

Reader source, wrapper modifications, platform support, build scripts and UI font source asset are in this repository. No MuPDF source patches were found: file-by-file comparison against the original complete source archive matched. Exact source retrieval and SHA-256 are in `docs/BUILD.md`; upstream includes third-party library and bundled document-font notices, which must be retained. This repository does not claim to relicense those dependencies.

**Binary-sharing requirement:** offer the complete matching reader sources and the exact MuPDF source archive (with bundled dependencies/licences) to every recipient, plus relevant build/install scripts. Before a release is shared, retain that source archive alongside the release; a pinned remote download is not a perpetual source-availability guarantee. Private visibility is fine only when recipients can actually obtain the corresponding source. No AGPL waiver or commercial MuPDF licence is claimed.

## WordNet 3.0

Copyright 2006 Princeton University. The included compact index is a modified gloss-only derivative, not the full relational database. `dictionary/LICENSE` retains the Princeton licence and attribution; `dictionary/FORMAT` documents the format and source, and `dictionary/source/WNdb-3.0.tar.gz` contains the licensed input. No Princeton endorsement is implied.

## Fonts

The UI uses Noto Sans; `src/fonts/NotoSans-OFL.txt` contains SIL OFL 1.1. MuPDF's bundled Charis SIL/document font resources and notices remain with its source distribution. Preserve upstream notices when redistributing.

## Books and screenshots

No private/copyrighted test books, extracted page-text traces or real-book page captures are distributed. Included EPUB/PDF test fixtures and screenshot content are synthetic project fixtures. Book titles mentioned in historical reports identify external regression inputs, not redistribution rights to those books. Host screenshot previews do not validate physical e-ink appearance.

## External reference implementations

KOReader's documented Kindle/powerd workflow was consulted as a behavioral reference. The reader is not a KOReader fork and no claim of its device coverage is made. External projects retain their own licences and trademarks.
