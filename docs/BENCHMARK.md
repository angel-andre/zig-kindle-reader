# Benchmark: Zig Reader vs KOReader

Run November 6, 2026. These are results from this test on one device. They aren't a general claim about every Kindle or every book.

## Method

- Device: one Kindle Paperwhite 12th gen (1272×1696, hardware dark mode on), same frontlight and settings for both readers.
- Readers: KOReader as installed on the device vs Zig Reader 0.8.0.
- Books: the same 1.5 MB EPUB and the same 47 MB scanned-image PDF for both readers (not distributed, for copyright reasons).
- Input: identical touch events injected into the touchscreen input device by `benchmarks/tools/probe.c`, at the same screen position (right side, page forward).
- Timing: from touch injection to the first framebuffer change (`first_change_ms`). This is when the reader hands the new page to the display, not when the e-ink panel physically finishes updating.
- Page turns: 8 warm-up turns (discarded), then 20 measured turns per book per reader.
- Book open: 3 cold opens per book per reader, timed to each reader's own "ready" log line.
- Rapid taps: 10 taps in a quick burst; counts how many distinct page changes were seen.
- Memory: resident (RSS) and peak (VmHWM) memory of the reader processes after the turn runs.

Raw CSVs: [`benchmarks/2026-11-06/`](../benchmarks/2026-11-06/). Tools: [`benchmarks/tools/`](../benchmarks/tools/).

## Latency

| Metric | Reader | Median | p90 | Max | Samples |
| --- | --- | --- | --- | --- | --- |
| Page turn, EPUB | KOReader | 59 ms | 60 ms | 89 ms | 20 |
| Page turn, EPUB | Zig Reader | 45 ms | 46 ms | 47 ms | 20 |
| Page turn, scanned PDF | KOReader | 1286 ms | 2696 ms | 2711 ms | 20 |
| Page turn, scanned PDF | Zig Reader | 58 ms | 69 ms | 83 ms | 20 |
| Book open to ready, EPUB | KOReader | 3.12 s | – | 3.21 s | 3 |
| Book open to ready, EPUB | Zig Reader | 1.85 s | – | 2.03 s | 3 |
| Book open to ready, scanned PDF | KOReader | 5.12 s | – | 5.18 s | 3 |
| Book open to ready, scanned PDF | Zig Reader | 2.58 s | – | 2.70 s | 3 |
| Library launch (last change) | Zig Reader | 1.18 s | – | 1.19 s | 3 |

In KOReader's scanned-PDF run, 6 of 20 turns were about 43 ms and the other 14 ranged from about 0.3 to 2.7 s, which explains the large spread.

## Rapid taps

| Book | Reader | Page changes seen | Last change after |
| --- | --- | --- | --- |
| EPUB | KOReader | 8 of 10 | 1626 ms |
| EPUB | Zig Reader | 10 of 10 | 1628 ms |
| scanned PDF | KOReader | 1 of 10 | 162 ms |
| scanned PDF | Zig Reader | 3 of 10 | 513 ms |

The scanned-PDF burst is inconclusive for both readers (each skips or merges queued pages by design), so it isn't compared.

## Memory

| Book | Reader | RSS | Peak |
| --- | --- | --- | --- |
| EPUB | KOReader | 52 MB | 52 MB |
| EPUB | Zig Reader | 57 MB | 57 MB |
| scanned PDF | KOReader | 133 MB | 156 MB |
| scanned PDF | Zig Reader | 316 MB | 336 MB |

Zig Reader's higher PDF memory comes from pre-rendering and caching nearby pages, which is what keeps its page turns fast.

## Caveats

- times are to the framebuffer update; the e-ink refresh itself adds roughly 250 ms for both readers. The test measured steady forward reading, where Zig Reader had already prefetched the next pages. On a heavy scanned PDF, a page that isn't prefetched yet (right after opening, after a jump, or when turning faster than pages render) can take about 1–3 s in Zig Reader too. KOReader was measured the same way, so the comparison is like for like.

- One device, two books, one session. Results may differ on other books or firmware.
- Framebuffer-change timing, not physical e-ink completion.
- KOReader's library-launch samples were invalid (no usable screen change was captured), so library launch is not compared. Zig Reader's library launch was about 1.18 s.
- KOReader was measured with its existing settings on this device; it may be faster with other settings.
