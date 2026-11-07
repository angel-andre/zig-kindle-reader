#!/bin/sh
# Builds the idle probe against the given platform source (default: current) and prints wakeups/s.
R=$(cd "$(dirname "$0")/.." && pwd); SRC=${1:-$R/src/platform07.c}; MU=$R/../mupdf-1.28.6-source
"$R/../zig/zig" cc -target x86_64-linux-musl -O2 -DSRC="\"$SRC\"" -I "$R/src" -I "$MU/include" "$R/tests/dev099_probe.c" "$R/src/render.c" "$MU/build/hostmusl-release/libmupdf.a" "$MU/build/hostmusl-release/libmupdf-third.a" -static -lpthread -lm -o "$R/out/dev099-probe" && PATH=/nonexistent "$R/out/dev099-probe"
