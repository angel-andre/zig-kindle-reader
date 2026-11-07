# 0.9.9 runtime (current)

`zr099.tgz` (about 8.4 MiB) is the 0.9.9 runtime (battery saving and low-battery warning), tested on a Kindle Paperwhite 12th gen. SHA-256: `666657f90c2096b07d0d3605ffd3d512d5288891e758dce4ef3b4976af244179`; the reader binary inside is `670d54451951634aa7d284123aaba172176f4e554e134f446a76f96e06c51aea` and `zreader --version` prints `zreader 0.9.9`. `zr099-sizes.json` records its build sizes.

# 0.9.8 runtime (rollback)

`zr098.tgz` is the previous release (collections, favourites, size sort; includes 0.9.7 reading stats), kept for rollback. SHA-256: `aa821cc11226d1aaf941aa241720c2a99d627680c8ad89ed875ea94e4556b10b`; the reader binary inside is `68db827a8a0cfd71e253c178614a0124e3a5ed114b067e8eb7691baea07cf270` (`zreader 0.9.8`). `zr098-sizes.json` records its build sizes. Older packages are no longer included; their source is in the git history.

Verify from the repository root with `sha256sum -c release/SHA256SUMS` (or `shasum -a 256 -c release/SHA256SUMS`). The manifest also covers the dictionary and its source input.
