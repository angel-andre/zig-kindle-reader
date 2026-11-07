# 0.10.5 runtime (current)

`zr105.tgz` is the 0.10.5 runtime (no stalls on heavy scanned pages right after opening), tested on a Kindle Paperwhite 12th gen. SHA-256: `705af6d61443b4b3575ca1d22c79d5d412da5e6695f0427f3940beedeed5d069`; the reader binary inside is `7beafb2eb51f08a4a99ecf71fc66a77a9ca68d4e671dfded8c4c586b6102e3e2` and `zreader --version` prints `zreader 0.10.5`. The dictionaries are unchanged from 0.10.3. `zr105-sizes.json` records its build sizes.

# 0.10.4 runtime (rollback)

`zr104.tgz` is the previous release, kept for rollback (fast first page on scanned PDFs, faster EPUB reopen), tested on a Kindle Paperwhite 12th gen. SHA-256: `51f201ae75b8dfb16d4a3dbac65b097f6516c6faba7f39adba84cdbc011b8529`; the reader binary inside is `ae013d639853bc8edab4807a2672e046b3e125d994ff3719bbad40767e9f66b3` and `zreader --version` prints `zreader 0.10.4`. The dictionaries are unchanged from 0.10.3. `zr104-sizes.json` records its build sizes.

Older packages are no longer included; their source is in the git history.

Verify from the repository root with `sha256sum -c release/SHA256SUMS` (or `shasum -a 256 -c release/SHA256SUMS`). The manifest also covers both dictionaries and their source inputs.
