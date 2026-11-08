#!/bin/sh
# 0.11.2: instant zoom drafts plus a regression subset.
set -eu
cd "$(dirname "$0")/.."
PATH="../tools/bin:$PATH" ./build.sh
export ZREADER_SIM_TEXT_MODE=0
./tests/run.sh
for t in zoom112_perf split111_verify shrink110_verify col098_verify search06_verify hl096_verify ui07_verify scan094_verify exit082_verify bm095_verify view06_verify; do
 python3 "tests/$t.py"
done
unset ZREADER_SIM_TEXT_MODE
python3 tests/text100_verify.py
python3 tests/latin103_verify.py
