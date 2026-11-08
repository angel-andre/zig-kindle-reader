# 0.11.4 runtime (current)

`zr114.tgz` is the 0.11.4 runtime (Delete book, Theme Light/Dark), tested on a Kindle Paperwhite 12th gen. SHA-256: `a76ae8c8d3cc139d37e648e7b99b07c3c10d03ecccc0ca7639fa426b51f1626e`; the reader binary inside is `0f88d758cba0183900471dd05713025acaa51071e5b0f3e5ec7578d72da3462f` and `zreader --version` prints `zreader 0.11.4`. The dictionaries are unchanged from 0.10.3. `zr114-sizes.json` records its build sizes.

# 0.11.3 runtime (rollback)

`zr113.tgz` is the previous release, kept for rollback (better scanned books), tested on a Kindle Paperwhite 12th gen. SHA-256: `12d029879cf28babbee857a01b18d98ff903d71e20715865b04cad6450a56d52`; the reader binary inside is `8c13dc2d1293c21ba0061c7e19f07f5b79a7aed14761f81e6c822cfec7063ca2` and `zreader --version` prints `zreader 0.11.3`. The dictionaries are unchanged from 0.10.3. `zr113-sizes.json` records its build sizes.

Older packages are no longer included; their source is in the git history.

Verify from the repository root with `sha256sum -c release/SHA256SUMS` (or `shasum -a 256 -c release/SHA256SUMS`). The manifest also covers both dictionaries and their source inputs.
