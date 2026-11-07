# 0.9.3 runtime (current)

`zr093.tgz` (about 8.3 MiB) is the 0.9.3 runtime, tested on a Kindle Paperwhite 12th gen. SHA-256: `c5876ae799c58c9df2d1352612f9ede93a4647a7d86469521d6f453e53fe3c93`. `zr093-sizes.json` records its build sizes.

# 0.9.2 runtime (rollback)

`zr092.tgz` is the previous release, kept for rollback. SHA-256: `6448f68150040fa37d438826fae39cd8c8e56d74e40ed4b34d9001b535687600`; `zr092-sizes.json` records its build sizes. Older packages are no longer included; their source is in the git history.

Verify from the repository root with `sha256sum -c release/SHA256SUMS` (or `shasum -a 256 -c release/SHA256SUMS`). The manifest also covers the dictionary and its source input.

The README inside each archive is the build-time manual; follow docs/INSTALL.md for current instructions. Only install the runtime on the Kindle, not development sources.

The reader source is in this repository and the MuPDF source link and checksum are in docs/BUILD.md (see THIRD_PARTY.md).
