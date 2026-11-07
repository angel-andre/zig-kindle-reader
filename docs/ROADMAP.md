# Roadmap

## Next

- Test frontlight/warmth and power-button sleep further on the device before turning sleep on by default.
- Add generated replacements for tests that currently need real books.
- Fix note collisions between books with the same file name, with a safe migration.

## KOReader benchmark plan

Use the same physical PW6, book bytes, views/font settings, frontlight, hardware dark mode, battery/thermal conditions and refresh policy. Record versions and configuration without device/network identifiers.

Measure cold launch/book open, uncached and prefetched page turns, rapid tap bursts, text-heavy versus image-heavy pages, PDF zoom/pan, EPUB reflow, annotation/search latency, peak memory, storage/cache growth and separate battery sessions. Distinguish input-to-render from input-to-panel completion. Repeat runs and report median and tail latency with sample counts; label cache warm/cold states. Document missing measurements rather than extrapolating host timings or nominal panel waveform durations.

Raw measurements and the protocol will be published with the results.

## Status after 0.8.0

- KOReader benchmark: coming.
- v0.8 on-device opening and cover times are estimates from computer measurements (see tests/REPORT08).
- First cold open of a large EPUB with a deep saved position can still be slow once; later opens use the pagination cache.
- Power-button sleep and light controls need more on-device testing.
