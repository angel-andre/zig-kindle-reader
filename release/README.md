# 0.11.3 runtime (current)

`zr113.tgz` is the 0.11.3 runtime (better scanned books), tested on a Kindle Paperwhite 12th gen. SHA-256: `12d029879cf28babbee857a01b18d98ff903d71e20715865b04cad6450a56d52`; the reader binary inside is `8c13dc2d1293c21ba0061c7e19f07f5b79a7aed14761f81e6c822cfec7063ca2` and `zreader --version` prints `zreader 0.11.3`. The dictionaries are unchanged from 0.10.3. `zr113-sizes.json` records its build sizes.

# 0.11.2 runtime (rollback)

`zr112.tgz` is the previous release, kept for rollback (instant zoom and pan feedback), tested on a Kindle Paperwhite 12th gen. SHA-256: `81a3529466ec71a646d8e42b06161d013a056e104f2ca36b6e4bcb0eda620fed`; the reader binary inside is `f4a861ba98586f69e4b7dd77f61b8292fb82be932ff4bb6fce40182574df0144` and `zreader --version` prints `zreader 0.11.2`. The dictionaries are unchanged from 0.10.3. `zr112-sizes.json` records its build sizes.

Older packages are no longer included; their source is in the git history.

Verify from the repository root with `sha256sum -c release/SHA256SUMS` (or `shasum -a 256 -c release/SHA256SUMS`). The manifest also covers both dictionaries and their source inputs.
