# Tests and evidence

## Test reports

The reports in `tests/` were produced on a development computer for each version. Device behaviour was then checked on a Kindle Paperwhite 12th gen.

| Report | Recorded scope |
| --- | --- |
| REPORT (0.5) | Word-centre hit checks, exact selection/handles, annotation edit/delete, prefetch behavior, unchanged source-PDF reference rendering, static ARM and host ABI |
| REPORT051 | Adaptive/periodic refresh policy, full-book waveform decisions, clipped image dithering without changing surrounding text; physical residue not measured |
| REPORT06 | 21 Zig units; 54 EPUB typography combinations; dictionary including malformed inputs; PDF views, search, exports, marker-helper sandboxes; previous regressions retained |
| REPORT07 | 24 Zig units; library covers/folders/sorts, bounded cache/worker behavior, light startup/no-write and mocked failure/debounce; simulated sleep/wake/restore and generated 85-book library |

The 175 MiB synthetic sparse PDF tests large offsets, **not** real 175 MiB scanned-image complexity. The KOReader benchmark is in docs/BENCHMARK.md.

## Prerequisites and commands

Build the target and host libraries and executables using BUILD. Some regression tests use real books: place your own PDF copies in `testbooks/` (each test names the file it expects). Those books are not distributed for copyright reasons. Generated sample files and their harnesses are included.

Original suite commands, from the repository root:

```sh
./tests/run.sh
python3 tests/verify.py
python3 tests/view06_verify.py
python3 tests/epub06_verify.py
python3 tests/dictionary06_verify.py
python3 tests/search06_verify.py
python3 tests/export06_verify.py
python3 tests/maintenance06_verify.py
python3 tests/refresh_verify.py
python3 tests/platform07_verify.py
python3 tests/ui07_verify.py
```

Some later scripts use probes built by earlier commands. Tests that need a book from `testbooks/` will fail if it is missing; that is not a reader bug.

A unit-suite-only invocation is (some units need a PDF in `testbooks/`):

```sh
../zig/zig test src/zreader.zig src/render.c src/dictionary.c src/platform07.c  -lc -target x86_64-linux-musl -O ReleaseSafe -I src -I ../mupdf-1.28.6-source/include  ../mupdf-1.28.6-source/build/hostmusl-release/libmupdf.a  ../mupdf-1.28.6-source/build/hostmusl-release/libmupdf-third.a
```

## On-device checklist

Keep key-only SSH ready, close other readers, retain a prior binary and notes backup. Never use mass storage during reading. Leave experimental sleep off until deliberately testing it; avoid stock passcodes.

1. Baseline brightness, warmth and powerd state through read-only LIPC; confirm inherited dark mode.
2. Library: scroll rapidly, switch sorts/folders and verify input is not blocked by covers; include real large/complex PDFs. Check cache growth and changed-book refresh next session.
3. Light: startup must not change values. Test separate brightness/warmth buttons/sliders, ends 0/24 and fast drags; compare confirmed LIPC values and restore preferred values deliberately.
4. With sleep OFF, power should exit to the stock UI. Only then explicitly test opt-in sleep: finished sleeping screen before powerd request, no accidental second toggle, no stuck touch.
5. Wake must restore the same book/page/view/annotations, preserve dark mode and accept touch. Repeat across PDF, EPUB and library; test failure recovery, rapid input and long sleep separately.
6. Measure battery and passcode/Hall/hibernation behavior separately. A connected SSH session may delay real suspend; mock events are not evidence of real suspend.
7. At any failure use `restore-ui`; if genuinely suspended press power once before SSH recovery. Do not change system files to recover.

A more detailed plan is at the end of REFERENCE_MANUAL.txt.

## Latest run

0.12.4: `tests/run.sh` passes (all 32 Zig tests, including reflow navigation, the saved reflow state and the Shrink watchdog, plus the render, EPUB anchor, dictionary and search probes; two render probes use my own book copies in `../testbooks/`), `./build.sh` rebuilds the exact released ARM binary (SHA-256 `eed5dace…3975`), and all release and dictionary checksums verify. `tests/reflow_unit.c` checks that a cached reflow analysis gives pixel-identical screens and that corrupt or missing cache files are rejected; `tests/reflowhook_probe.c` shows what the reader draws for one page with Reflow on.

The README screenshots in `docs/img/` come from `out/zreader-host --sim SCRIPT --shots DIR` with public-domain sample books only.
