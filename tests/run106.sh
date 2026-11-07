#!/bin/sh
# 0.10.6: relevant tests (highlights, search, note keyboard, scans, UI) plus a regression subset.
set -eu
cd "$(dirname "$0")/.."
PATH="../tools/bin:$PATH" ./build.sh
export ZREADER_SIM_TEXT_MODE=0
./tests/run.sh
for t in search06_verify hl096_verify ui07_verify scan092_verify scan094_verify exit082_verify bm095_verify view06_verify; do
 python3 "tests/$t.py"
done
unset ZREADER_SIM_TEXT_MODE
python3 tests/text100_verify.py
python3 tests/latin103_verify.py
python3 tests/formats102_verify.py
