# Architecture and file map

- `src/zreader.zig`: UI/input, library, state/annotations, cache scheduling and e-ink update policy. Two render workers, 14 raster-cache slots and directional prefetch keep cached page turns separate from background work.
- `src/render.c`, `render.h`, `epub-anchor.inc`, `search.inc`: MuPDF rendering/text geometry, chapter anchors, search, image statistics/dithering.
- `src/dictionary.c`, `dictionary.h`: read-only bounds-checked WordNet index and lookup.
- `src/platform07.c`: bounded LIPC commands, event subscription and isolated thumbnail rendering support.
- `src/fonts/`: UI font and its SIL OFL licence. MuPDF supplies document-font support and bundled font licences.
- `zreader-run.sh`: standalone launcher, temporary UI suspension, optional key-only SSH startup, exit restoration. Its root copy is the install/build-layout version; `scripts/` mirrors operational helpers for discoverability.
- `zreader-maintenance.sh`: ownership-aware dump marker and independent best-effort restore-ui.
- `kual/zreader/`: menu and launch glue.
- `dictionary/`: WordNet source archive, rebuild program, index, format and licence.
- `tests/`: historical reports, source harnesses, result summaries and synthetic fixtures. No private books or real-book page captures are included.
- `shots/`: metadata-stripped synthetic UI PNG previews only.
- `release/`: original 0.7 runtime plus hashes and installed-size record.

The display path uses the PW6 MTK hwtcon interface. Normal REAGL turns and GC16 FULL cleans are explicit policy choices, not framebuffer mode changes. Hardware inversion remains inherited. Brightness/warmth use powerd LIPC; no raw backlight writes. The launcher reads/restores the existing CPU governor; it does not remove platform services from disk.

No app account or internet dictionary is required for reading. Runtime logs, notes, exports and book paths stay on the user's device unless they choose to copy them. No private device inventory belongs in this repository.
