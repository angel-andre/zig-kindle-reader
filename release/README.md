# 0.10.0 runtime (current)

`zr100.tgz` (about 8.6 MiB) is the 0.10.0 runtime (better EPUB text: justification, hyphenation, Font and Align choices), tested on a Kindle Paperwhite 12th gen. SHA-256: `61235f2a942d6b4ae6558eaa360af92a1bce994130ea08eff7f319218581ad40`; the reader binary inside is `3a7cc018d9edb8ce3e50f963cfebbc7be5e72c504b3259937532b7e788b720a0` and `zreader --version` prints `zreader 0.10.0`. `zr100-sizes.json` records its build sizes.

# 0.9.9 runtime (rollback)

`zr099.tgz` is the previous release (battery saving and low-battery warning), kept for rollback. SHA-256: `666657f90c2096b07d0d3605ffd3d512d5288891e758dce4ef3b4976af244179`; the reader binary inside is `670d54451951634aa7d284123aaba172176f4e554e134f446a76f96e06c51aea` (`zreader 0.9.9`). `zr099-sizes.json` records its build sizes. Older packages are no longer included; their source is in the git history.

Verify from the repository root with `sha256sum -c release/SHA256SUMS` (or `shasum -a 256 -c release/SHA256SUMS`). The manifest also covers the dictionary and its source input.
