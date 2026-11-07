#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
PATH="../tools/bin:$PATH" ./build.sh
./tests/run.sh
for t in verify view06_verify epub06_verify dictionary06_verify search06_verify export06_verify maintenance06_verify refresh_verify platform07_verify ui07_verify cache08_verify v08_verify lib081_verify exit082_verify; do
 python3 "tests/$t.py"
done
