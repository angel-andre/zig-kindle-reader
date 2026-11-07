#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
ZIG=${ZIG:-../zig/zig}
MU=${MU:-../mupdf-1.28.6-source}
"$ZIG" test src/zreader.zig src/render.c src/dictionary.c src/platform07.c src/pagecache.c src/upload.c -lc -target x86_64-linux-musl -O ReleaseSafe \
 -I src -I "$MU/include" "$MU/build/hostmusl-release/libmupdf.a" "$MU/build/hostmusl-release/libmupdf-third.a"

"$ZIG" cc -target x86_64-linux-musl -O2 -I src -I "$MU/include"  tests/render_probe.c src/render.c "$MU/build/hostmusl-release/libmupdf.a"  "$MU/build/hostmusl-release/libmupdf-third.a" -lpthread -lm -static -o out/render-probe
out/render-probe ../testbooks/digital-small1.pdf 17 shots/21_dropcap_after.pgm > tests/page17-after.tsv
out/render-probe ../testbooks/digital-small1.pdf 19 shots/21b_edward_after.pgm > tests/page19-after.tsv
"$ZIG" cc -target x86_64-linux-musl -O2 -I src -I "$MU/include" \
 tests/render_stats_probe.c src/render.c "$MU/build/hostmusl-release/libmupdf.a" \
 "$MU/build/hostmusl-release/libmupdf-third.a" -lpthread -lm -static -o out/render-stats-probe
"$ZIG" cc -target x86_64-linux-musl -O2 -I src -I "$MU/include" \
 tests/epub_anchor_probe.c src/render.c "$MU/build/hostmusl-release/libmupdf.a" \
 "$MU/build/hostmusl-release/libmupdf-third.a" -lpthread -lm -static -o out/epub-anchor-probe
out/epub-anchor-probe tests/anchor-fixture.epub
"$ZIG" cc -target x86_64-linux-musl -O2 -I src -I "$MU/include" \
 tests/epub_dump.c src/render.c "$MU/build/hostmusl-release/libmupdf.a" \
 "$MU/build/hostmusl-release/libmupdf-third.a" -lpthread -lm -static -o out/epub-dump
"$ZIG" cc -target x86_64-linux-musl -O2 -I src tests/dictionary06_probe.c src/dictionary.c -static -o out/dictionary-probe
out/dictionary-probe dictionary/wordnet.zdict
python3 tests/dictionary06_format_verify.py
"$ZIG" cc -target x86_64-linux-musl -O2 -I src -I "$MU/include" tests/search06_probe.c src/render.c \
 "$MU/build/hostmusl-release/libmupdf.a" "$MU/build/hostmusl-release/libmupdf-third.a" -lpthread -lm -static -o out/search-probe
"$ZIG" cc -target x86_64-linux-musl -O2 -I src -I "$MU/include" tests/scan092_probe.c src/render.c \
 "$MU/build/hostmusl-release/libmupdf.a" "$MU/build/hostmusl-release/libmupdf-third.a" -lpthread -lm -static -o out/scan092-probe
out/search-probe
