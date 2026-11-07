# 0.9.4 runtime (current)

`zr094.tgz` (about 8.3 MiB) is the 0.9.4 runtime, tested on a Kindle Paperwhite 12th gen. SHA-256: `56d20527418d1eb1ac14e9e9628e1382feec4af377067c2aed765f866551b59b`; the reader binary inside is `1a2e42e32ce15d27b654c4ae4f0a73a8c52159449a3f9af95acd6fd1f396153a`. Known issue: this binary's `--version` prints 0.9.3. `zr094-sizes.json` records its build sizes.

# 0.9.3 runtime (rollback)

`zr093.tgz` is the previous release, kept for rollback. SHA-256: `c5876ae799c58c9df2d1352612f9ede93a4647a7d86469521d6f453e53fe3c93`; `zr093-sizes.json` records its build sizes. Older packages are no longer included; their source is in the git history.

Verify from the repository root with `sha256sum -c release/SHA256SUMS` (or `shasum -a 256 -c release/SHA256SUMS`). The manifest also covers the dictionary and its source input.

The README inside each archive is the build-time manual; follow docs/INSTALL.md for current instructions. Only install the runtime on the Kindle, not development sources.

The reader source is in this repository and the MuPDF source link and checksum are in docs/BUILD.md (see THIRD_PARTY.md).
