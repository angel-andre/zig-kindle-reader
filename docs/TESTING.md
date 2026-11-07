# Tests and evidence

## Evidence levels

The reports in `tests/REPORT`, `REPORT051`, `REPORT06` and `REPORT07` are historical host-build records. Their “not deployed” labels describe those test runs. The later device install was reported as version 0.7.0; that does not turn host mocks into physical validation. This repository assembly did not access the Kindle or a personal computer.

| Report | Recorded scope |
| --- | --- |
| REPORT (0.5) | Word-centre hit checks, exact selection/handles, annotation edit/delete, prefetch behavior, unchanged source-PDF reference rendering, static ARM and host ABI |
| REPORT051 | Adaptive/periodic refresh policy, full-book waveform decisions, clipped image dithering without changing surrounding text; physical residue not measured |
| REPORT06 | 21 Zig units; 54 EPUB typography combinations; dictionary including malformed inputs; PDF views, search, exports, marker-helper sandboxes; previous regressions retained |
| REPORT07 | 24 Zig units; library covers/folders/sorts, bounded cache/worker behavior, light startup/no-write and mocked failure/debounce; simulated sleep/wake/restore and generated 85-book library |

The 175 MiB synthetic sparse PDF tests large offsets, **not** real 175 MiB scanned-image complexity. A real image-heavy PDF used by the historical tests was much smaller. No KOReader comparative benchmark has been measured.

## Prerequisites and commands

Build both target and host libraries/executables using BUILD. `tests/run.sh` needs private `../testbooks/digital-small1.pdf`; full refresh audits also need `digital-big.pdf`. Those copyrighted books and extracted page-text traces are intentionally omitted. Matching external-renderer reference images are omitted too. Consequently a clean checkout cannot reproduce every historical real-book check without supplying your own authorized copies and the expected local reference baselines. Synthetic fixtures and their source harnesses are included.

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

Some later scripts assume probes built by earlier commands. Do not interpret missing private fixture failures as functional failures. Packaging scripts tied to the original sibling `stage/` output, and a packaging verifier containing private-environment denylist literals, are not copied into this clean tree. Result summaries are retained as historical evidence, not freshly rerun full-suite results.

A unit-suite-only invocation is (several units still require the private PDF fixture):

```sh
../zig/zig test src/zreader.zig src/render.c src/dictionary.c src/platform07.c  -lc -target x86_64-linux-musl -O ReleaseSafe -I src -I ../mupdf-1.28.6-source/include  ../mupdf-1.28.6-source/build/hostmusl-release/libmupdf.a  ../mupdf-1.28.6-source/build/hostmusl-release/libmupdf-third.a
```

## Physical PW6 checklist — outstanding

Keep key-only SSH ready, close other readers, retain a prior binary and notes backup. Never use mass storage during reading. Leave experimental sleep off until deliberately testing it; avoid stock passcodes.

1. Baseline brightness, warmth and powerd state through read-only LIPC; confirm inherited dark mode.
2. Library: scroll rapidly, switch sorts/folders and verify input is not blocked by covers; include real large/complex PDFs. Check cache growth and changed-book refresh next session.
3. Light: startup must not change values. Test separate brightness/warmth buttons/sliders, ends 0/24 and fast drags; compare confirmed LIPC values and restore preferred values deliberately.
4. With sleep OFF, power should exit to the stock UI. Only then explicitly test opt-in sleep: finished sleeping screen before powerd request, no accidental second toggle, no stuck touch.
5. Wake must restore the same book/page/view/annotations, preserve dark mode and accept touch. Repeat across PDF, EPUB and library; test failure recovery, rapid input and long sleep separately.
6. Measure battery and passcode/Hall/hibernation behavior separately. A connected SSH session may delay real suspend; mock events are not evidence of real suspend.
7. At any failure use `restore-ui`; if genuinely suspended press power once before SSH recovery. Do not change system files to recover.

The detailed historical plan is also retained at the end of REFERENCE_MANUAL.txt.

## Fresh repository-assembly check

November 6, 2026 (Toronto): the copied tree passed all **24 Zig tests**, using the already-existing local private PDF fixture read-only. Shell syntax checks passed for both build scripts, launcher, maintenance helper and KUAL launch script; all release/dictionary checksum checks passed. See `tests/repository-assembly-validation.txt`. Generated annotation test data and compiler caches were removed afterwards. This is a host result, not a fresh device test or a full black-box-suite rerun.
