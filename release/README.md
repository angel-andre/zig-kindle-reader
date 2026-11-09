# 0.12.4 runtime (current)

`zr124.tgz` is the 0.12.4 runtime, tested on my Kindle Paperwhite 12th gen. SHA-256: `5e47eb5e408a1c8a93504b558374aba5c8a18d2413f01abf1b59daa05c6dc8f8`; the reader binary inside is `eed5dace9082849a37cab81522e7eda9ec714d5726d20e2620d89d7d7c573975` and `zreader --version` prints `zreader 0.12.4`. The dictionaries are unchanged from 0.10.3. `zr124-sizes.json` records its sizes. The same archive is attached to the [v0.12.4 GitHub release](https://github.com/angel-andre/zig-kindle-reader/releases/tag/v0.12.4).

# 0.12.3 runtime (rollback)

`zr123.tgz` is the previous release, kept for rollback (compact View/More menu, Reflow for scanned pages, faster Shrink). SHA-256: `0ce698cc21297ec8f38b3e9adccdf8f976364a196147adb2ce3315a08271996b`; the reader binary inside is `6d24dcbf6c9b961969b05c00d5ac57f93072fc4944ed2a34f20790bfa60ecf7b` and `zreader --version` prints `zreader 0.12.3`. `zr123-sizes.json` records its sizes.

Older packages are no longer included; their source is in the git history.

Verify from the repository root with `sha256sum -c release/SHA256SUMS` (or `shasum -a 256 -c release/SHA256SUMS`). The manifest also covers both dictionaries and their source inputs.
