# Roadmap

## Next

- Test frontlight/warmth and power-button sleep further on the device before turning sleep on by default.
- Add generated replacements for tests that currently need real books.
- Fix note collisions between books with the same file name, with a safe migration.

## KOReader benchmark

First results are in the README and docs/BENCHMARK.md. Next: repeat on more books, add physical e-ink completion timing and battery sessions.

## Status after 0.8.0

- v0.8 on-device opening and cover times are estimates from computer measurements (see tests/REPORT08).
- First cold open of a large EPUB with a deep saved position can still be slow once; later opens use the pagination cache.
- Power-button sleep and light controls need more on-device testing.
