# 0.9.8 runtime (current)

`zr098.tgz` (about 8.3 MiB) is the 0.9.8 runtime (collections, favourites, size sort; includes the 0.9.7 reading stats), tested on a Kindle Paperwhite 12th gen. SHA-256: `aa821cc11226d1aaf941aa241720c2a99d627680c8ad89ed875ea94e4556b10b`; the reader binary inside is `68db827a8a0cfd71e253c178614a0124e3a5ed114b067e8eb7691baea07cf270` and `zreader --version` prints `zreader 0.9.8`. `zr098-sizes.json` records its build sizes. 0.9.7 was not released as a separate package.

# 0.9.6 runtime (rollback)

`zr096.tgz` is the previous release (highlights and notes, with export), kept for rollback. SHA-256: `283167b51c5de83a313add2334ed51ab372a5ee7ab099a589714753bc6fbeba8`; the reader binary inside is `25d68de05498c17a0128dc602a0c8eef4c2a12f450c00a026a23973b00baaac0` (`zreader 0.9.6`). `zr096-sizes.json` records its build sizes. Older packages are no longer included; their source is in the git history.

Verify from the repository root with `sha256sum -c release/SHA256SUMS` (or `shasum -a 256 -c release/SHA256SUMS`). The manifest also covers the dictionary and its source input.

The README inside each archive is the build-time manual; follow docs/INSTALL.md for current instructions. Only install the runtime on the Kindle, not development sources.

The reader source is in this repository and the MuPDF source link and checksum are in docs/BUILD.md (see THIRD_PARTY.md).
