# Roadmap

## Where it is now (0.12.4)

Zig Reader runs on my Kindle Paperwhite 12th gen. Page turns, scanned PDFs (Split, Trim, cleanup, Reflow), Shrink for Kindle, highlights and notes, both dictionaries, the library and the Light/Dark theme all work there. Other Kindle models are still untested.

## Next

- Reflow: better handling of multi-column pages, tables and words that sit slightly off the line.
- Test frontlight/warmth and power-button sleep further on the device before turning sleep on by default.
- Fix note collisions between books with the same file name, with a safe migration.
- Add generated replacements for the tests that still need my own books.
- An idea: share a highlight as a simple quote card image (for example to post on X).

## KOReader benchmark

First results are in the README and [BENCHMARK](BENCHMARK.md) (0.8.0). Next: repeat on more books and the current version, add physical e-ink completion timing and battery sessions.
