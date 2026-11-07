# 0.8.1 runtime (current)

`zr081.tgz` (about 8.2 MiB) is the 0.8.1 runtime, tested on a Kindle Paperwhite 12th gen. SHA-256: `0c057ae613d664d91c486c7d030cdc51c3d27e9ba7553a7c1a2d56e7b94d9f5e`. `zr081-sizes.json` records its build sizes.

# 0.8.0 runtime (rollback)

`zr08.tgz` is the previous release, kept for rollback. SHA-256 is in `SHA256SUMS`; `installed-sizes-08.json` records its build sizes. Older packages (0.7 and earlier) are no longer included; their source is in the git history.

Verify from the repository root with `sha256sum -c release/SHA256SUMS` (or `shasum -a 256 -c release/SHA256SUMS`). The manifest also covers the dictionary and its source input.

The README inside each archive is the build-time manual; follow docs/INSTALL.md for current instructions. Only install the runtime on the Kindle, not development sources.

The reader source is in this repository and the MuPDF source link and checksum are in docs/BUILD.md (see THIRD_PARTY.md).
