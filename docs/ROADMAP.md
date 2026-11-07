# Roadmap

## Before inviting friends to install

- Replay the installation/uninstall documentation on a consenting PW6, including stock-UI recovery and key-only SSH.
- Confirm final crash-dump marker status and firmware behavior without deliberately causing a crash.
- Physically validate frontlight/warmth and keep reader-managed sleep opt-in until event/grab/wake/battery/passcode/Hall/hibernation checks pass.
- Add portable synthetic replacements for tests currently requiring private books/reference images.
- Address same-basename note collisions with an explicit, backup-safe migration.
- Audit all release sources/licences and make the complete exact dependency source available to every binary recipient.
- Keep the repository PRIVATE unless its owner expressly chooses to publish it.

## KOReader benchmark — NOT YET MEASURED

No comparison numbers are available. Use the same physical PW6, book bytes, views/font settings, frontlight, hardware dark mode, battery/thermal conditions and refresh policy. Record versions and configuration without device/network identifiers.

Measure cold launch/book open, uncached and prefetched page turns, rapid tap bursts, text-heavy versus image-heavy pages, PDF zoom/pan, EPUB reflow, annotation/search latency, peak memory, storage/cache growth and separate battery sessions. Distinguish input-to-render from input-to-panel completion. Repeat runs and report median and tail latency with sample counts; label cache warm/cold states. Document missing measurements rather than extrapolating host timings or nominal panel waveform durations.

Retain anonymized raw measurements and a reproducible protocol before asserting an advantage. Host refresh-policy counts are not comparative performance benchmarks.
