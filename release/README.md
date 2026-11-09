# 0.12.3 runtime (current)

`zr123.tgz` is the 0.12.3 runtime (compact View/More menu, Reflow for scanned pages, faster Shrink), tested on my Kindle Paperwhite 12th gen. SHA-256: `0ce698cc21297ec8f38b3e9adccdf8f976364a196147adb2ce3315a08271996b`; the reader binary inside is `6d24dcbf6c9b961969b05c00d5ac57f93072fc4944ed2a34f20790bfa60ecf7b` and `zreader --version` prints `zreader 0.12.3`. The dictionaries are unchanged from 0.10.3. `zr123-sizes.json` records its sizes. The same archive is attached to the [v0.12.3 GitHub release](https://github.com/angel-andre/zig-kindle-reader/releases/tag/v0.12.3).

# 0.11.5 runtime (rollback)

`zr115.tgz` is the previous release, kept for rollback (smoother zoom on split pages), tested on a Kindle Paperwhite 12th gen. SHA-256: `269178b9e270a6d6bbe39b8ec89a759f9dbecc9b116ac0c14cb6f127164031ff`; the reader binary inside is `dbbed2a1f9b11eb5403be1873ce608c0d7a9ff0e2f459c04ea2d014e959214c2` and `zreader --version` prints `zreader 0.11.5`. `zr115-sizes.json` records its build sizes.

Older packages are no longer included; their source is in the git history.

Verify from the repository root with `sha256sum -c release/SHA256SUMS` (or `shasum -a 256 -c release/SHA256SUMS`). The manifest also covers both dictionaries and their source inputs.
