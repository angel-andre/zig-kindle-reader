#!/bin/sh
# Builds out/zreader (static armhf), out/zreader-host (x86_64, for --sim tests) and out/einktest.
# MuPDF first: ./build-mupdf.sh ; host: TGT=x86_64-linux-musl CPU=-mcpu=baseline PFX=hostmusl- ./build-mupdf.sh
set -e
cd "$(dirname "$0")"
ZIG=${ZIG:-../zig/zig}
MU=${MU:-../mupdf-1.28.6-source}
mkdir -p out
build() {
	MUB=$MU/build/$3-release
	$ZIG build-exe src/zreader.zig src/render.c src/dictionary.c src/platform07.c -lc -target $1 -mcpu $2 -O ReleaseFast -fstrip \
		-I src -I $MU/include -cflags -Os -- $MUB/libmupdf.a $MUB/libmupdf-third.a -static -femit-bin=$4
}
build arm-linux-musleabihf cortex_a53 armhf out/zreader
if [ -d $MU/build/hostmusl-release ]; then build x86_64-linux-musl baseline hostmusl out/zreader-host; fi
$ZIG build-exe src/einktest.zig -target arm-linux-musleabihf -mcpu cortex_a53 -O ReleaseSmall -fstrip -fsingle-threaded -femit-bin=out/einktest
