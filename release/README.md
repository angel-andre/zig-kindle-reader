# 0.10.4 runtime (current)

`zr104.tgz` is the 0.10.4 runtime (fast first page on scanned PDFs, faster EPUB reopen), tested on a Kindle Paperwhite 12th gen. SHA-256: `51f201ae75b8dfb16d4a3dbac65b097f6516c6faba7f39adba84cdbc011b8529`; the reader binary inside is `ae013d639853bc8edab4807a2672e046b3e125d994ff3719bbad40767e9f66b3` and `zreader --version` prints `zreader 0.10.4`. The dictionaries are unchanged from 0.10.3. `zr104-sizes.json` records its build sizes.

# 0.10.3 runtime (rollback)

`zr103.tgz` (about 10.1 MiB) is the previous release, kept for rollback (more formats: MOBI, AZW3, TXT, CBZ, FB2; Latin dictionary with EN/LA lookup), tested on a Kindle Paperwhite 12th gen. SHA-256: `6f2e7f7711e8097ddaec4e50d829040c68c07e37925369a1823a310ce7f2961b`; the reader binary inside is `bee5b2b5c981a62b64ff3114a1f7ce89aaaa53597bcfc2999cf427af7eefb5ba`, `dictionary/latin.zdict` is `3b904e60cc72182280f1f20e3c3835f94f5ee735607b3fc473c6a17a5ba34d3f`, and `zreader --version` prints `zreader 0.10.3`. `zr103-sizes.json` records its build sizes. 0.10.2 was not released separately.

Older packages are no longer included; their source is in the git history.

Verify from the repository root with `sha256sum -c release/SHA256SUMS` (or `shasum -a 256 -c release/SHA256SUMS`). The manifest also covers both dictionaries and their source inputs.
