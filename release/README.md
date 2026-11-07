# 0.8.0 runtime (current)

`zr08.tgz` (about 8.2 MiB) is the 0.8.0 runtime installed on the reference device. SHA-256: `4a9027bd8bac4cc3ac94d5c8337367c0a3d7a648589e2c565b06ec111c884016`. `installed-sizes-08.json` records its build sizes.

# Original 0.7.0 runtime (rollback)

`zr07.tgz` is the original runtime artifact supplied for the recorded installation. The executable inside is unchanged. It is about 8.23 MiB compressed; individual files are below the 100 MB GitHub limit.

From the repository root run `sha256sum -c release/SHA256SUMS` (or `shasum -a 256 -c release/SHA256SUMS`). The manifest also covers the dictionary and its source input. `installed-sizes.json` is the historical original build-size record.

The archive's README is the historical host-build manual; its “not deployed” wording predates the recorded installation. Prefer current docs/INSTALL.md and docs/PROVENANCE.md. Do not put development sources on the Kindle.

Before sharing this binary, provide the matching repository sources **and** retain/offer the exact complete MuPDF archive pinned in docs/BUILD.md. That dependency archive is not vendored here. See THIRD_PARTY.md for the distribution gate.
