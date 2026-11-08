# 0.11.0 runtime (current)

`zr110.tgz` is the 0.11.0 runtime (Shrink for Kindle for PDFs), tested on a Kindle Paperwhite 12th gen. SHA-256: `bed094aa4a9ba6b6e7554cc013855c15d33a6ac7cbdff0ba0834a66423b1b443`; the reader binary inside is `18c41f7d1daf7539878a0a8a411cd8825f16bd02799a8b6b34912893a097c3f5` and `zreader --version` prints `zreader 0.11.0`. The dictionaries are unchanged from 0.10.3. `zr110-sizes.json` records its build sizes.

# 0.10.6 runtime (rollback)

`zr106.tgz` is the previous release, kept for rollback (readable highlights on scanned pages, accented letters on the keyboard), tested on a Kindle Paperwhite 12th gen. SHA-256: `43a7a93545e9bebf917671959db3bba5565c871f08503ca93978b1a2cf7f933d`; the reader binary inside is `0eb25754117311efc80b153eb5efef4422d2c3adcc7d75a0d74ed77952e22015` and `zreader --version` prints `zreader 0.10.6`. The dictionaries are unchanged from 0.10.3. `zr106-sizes.json` records its build sizes.

Older packages are no longer included; their source is in the git history.

Verify from the repository root with `sha256sum -c release/SHA256SUMS` (or `shasum -a 256 -c release/SHA256SUMS`). The manifest also covers both dictionaries and their source inputs.
