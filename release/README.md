# 0.10.6 runtime (current)

`zr106.tgz` is the 0.10.6 runtime (readable highlights on scanned pages, accented letters on the keyboard), tested on a Kindle Paperwhite 12th gen. SHA-256: `43a7a93545e9bebf917671959db3bba5565c871f08503ca93978b1a2cf7f933d`; the reader binary inside is `0eb25754117311efc80b153eb5efef4422d2c3adcc7d75a0d74ed77952e22015` and `zreader --version` prints `zreader 0.10.6`. The dictionaries are unchanged from 0.10.3. `zr106-sizes.json` records its build sizes.

# 0.10.5 runtime (rollback)

`zr105.tgz` is the previous release, kept for rollback (no stalls on heavy scanned pages right after opening), tested on a Kindle Paperwhite 12th gen. SHA-256: `705af6d61443b4b3575ca1d22c79d5d412da5e6695f0427f3940beedeed5d069`; the reader binary inside is `7beafb2eb51f08a4a99ecf71fc66a77a9ca68d4e671dfded8c4c586b6102e3e2` and `zreader --version` prints `zreader 0.10.5`. The dictionaries are unchanged from 0.10.3. `zr105-sizes.json` records its build sizes.

Older packages are no longer included; their source is in the git history.

Verify from the repository root with `sha256sum -c release/SHA256SUMS` (or `shasum -a 256 -c release/SHA256SUMS`). The manifest also covers both dictionaries and their source inputs.
