#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
PATH="../tools/bin:$PATH" ./build.sh
# Tests from before 0.10.0 check the 0.9.x EPUB layout (their probes lay out EPUBs
# independently); text100_verify checks the new default and that 0.9.x output is kept.
export ZREADER_SIM_TEXT_MODE=0
./tests/run.sh
for t in verify view06_verify epub06_verify dictionary06_verify search06_verify export06_verify maintenance06_verify refresh_verify platform07_verify ui07_verify cache08_verify v08_verify lib081_verify exit082_verify pc090_verify up091_verify scan092_verify scan093_verify scan094_verify bm095_verify hl096_verify st097_verify col098_verify bat099_verify; do
 python3 "tests/$t.py"
done
unset ZREADER_SIM_TEXT_MODE
python3 tests/text100_verify.py
