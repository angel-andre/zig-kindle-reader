# 0.8.0 runtime (current)

`zr08.tgz` (about 8.2 MiB) is the 0.8.0 runtime, tested on a Kindle Paperwhite 12th gen. SHA-256: `4a9027bd8bac4cc3ac94d5c8337367c0a3d7a648589e2c565b06ec111c884016`. `installed-sizes-08.json` records its build sizes.

# 0.7.0 runtime (rollback)

`zr07.tgz` (about 8.23 MiB) is the previous release, kept for rollback. `installed-sizes.json` records its build sizes.

Verify from the repository root with `sha256sum -c release/SHA256SUMS` (or `shasum -a 256 -c release/SHA256SUMS`). The manifest also covers the dictionary and its source input.

The README inside each archive is the build-time manual; follow docs/INSTALL.md for current instructions. Only install the runtime on the Kindle, not development sources.

The reader source is in this repository and the MuPDF source link and checksum are in docs/BUILD.md (see THIRD_PARTY.md).
