# 0.11.5 runtime (current)

`zr115.tgz` is the 0.11.5 runtime (smoother zoom on split pages), tested on a Kindle Paperwhite 12th gen. SHA-256: `269178b9e270a6d6bbe39b8ec89a759f9dbecc9b116ac0c14cb6f127164031ff`; the reader binary inside is `dbbed2a1f9b11eb5403be1873ce608c0d7a9ff0e2f459c04ea2d014e959214c2` and `zreader --version` prints `zreader 0.11.5`. The dictionaries are unchanged from 0.10.3. `zr115-sizes.json` records its build sizes.

# 0.11.4 runtime (rollback)

`zr114.tgz` is the previous release, kept for rollback (Delete book, Theme Light/Dark), tested on a Kindle Paperwhite 12th gen. SHA-256: `a76ae8c8d3cc139d37e648e7b99b07c3c10d03ecccc0ca7639fa426b51f1626e`; the reader binary inside is `0f88d758cba0183900471dd05713025acaa51071e5b0f3e5ec7578d72da3462f` and `zreader --version` prints `zreader 0.11.4`. The dictionaries are unchanged from 0.10.3. `zr114-sizes.json` records its build sizes.

Older packages are no longer included; their source is in the git history.

Verify from the repository root with `sha256sum -c release/SHA256SUMS` (or `shasum -a 256 -c release/SHA256SUMS`). The manifest also covers both dictionaries and their source inputs.
