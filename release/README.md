# 0.9.6 runtime (current)

`zr096.tgz` (about 8.3 MiB) is the 0.9.6 runtime (highlights and notes, with export), tested on a Kindle Paperwhite 12th gen. SHA-256: `283167b51c5de83a313add2334ed51ab372a5ee7ab099a589714753bc6fbeba8`; the reader binary inside is `25d68de05498c17a0128dc602a0c8eef4c2a12f450c00a026a23973b00baaac0` and `zreader --version` prints `zreader 0.9.6`. `zr096-sizes.json` records its build sizes.

# 0.9.5 runtime (rollback)

`zr095.tgz` is the previous release (bookmarks), kept for rollback. SHA-256: `0e042d268edcc2fa09d068064d67c63cde5165f018c08409eed30daeb5a58666`; the reader binary inside is `2a26ef3b46a32d1c97cad1788a5f04067d262e07a2c86cb9a5ef3ea38d368877` (`zreader 0.9.5`). `zr095-sizes.json` records its build sizes. Older packages are no longer included; their source is in the git history.

Verify from the repository root with `sha256sum -c release/SHA256SUMS` (or `shasum -a 256 -c release/SHA256SUMS`). The manifest also covers the dictionary and its source input.

The README inside each archive is the build-time manual; follow docs/INSTALL.md for current instructions. Only install the runtime on the Kindle, not development sources.

The reader source is in this repository and the MuPDF source link and checksum are in docs/BUILD.md (see THIRD_PARTY.md).
