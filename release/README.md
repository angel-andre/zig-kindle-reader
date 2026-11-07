# 0.10.3 runtime (current)

`zr103.tgz` (about 10.1 MiB) is the 0.10.3 runtime (more formats: MOBI, AZW3, TXT, CBZ, FB2; Latin dictionary with EN/LA lookup), tested on a Kindle Paperwhite 12th gen. SHA-256: `6f2e7f7711e8097ddaec4e50d829040c68c07e37925369a1823a310ce7f2961b`; the reader binary inside is `bee5b2b5c981a62b64ff3114a1f7ce89aaaa53597bcfc2999cf427af7eefb5ba`, `dictionary/latin.zdict` is `3b904e60cc72182280f1f20e3c3835f94f5ee735607b3fc473c6a17a5ba34d3f`, and `zreader --version` prints `zreader 0.10.3`. `zr103-sizes.json` records its build sizes. 0.10.2 was not released separately.

# 0.10.1 runtime (rollback)

`zr101.tgz` (about 8.6 MiB) is the previous release (Contents for books without an outline, Go to page / Go to %), kept for rollback. SHA-256: `fb47ef0d7860e748ce8f80588bd617bce964adddabb10d01b317d3e690164381`; the reader binary inside is `4dbf7aa792f72ef708182dd5c5b9f464ef2e2781f5feb6a047189ee9c4160dde` and `zreader --version` prints `zreader 0.10.1`. `zr101-sizes.json` records its build sizes.

Older packages are no longer included; their source is in the git history.

Verify from the repository root with `sha256sum -c release/SHA256SUMS` (or `shasum -a 256 -c release/SHA256SUMS`). The manifest also covers both dictionaries and their source inputs.
