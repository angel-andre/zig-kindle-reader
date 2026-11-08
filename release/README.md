# 0.11.1 runtime (current)

`zr111.tgz` is the 0.11.1 runtime (two-page scans shown one page at a time), tested on a Kindle Paperwhite 12th gen. SHA-256: `c6ad8861c6a6cfc9a297b09e2e99c795398acbc67745a7fe74be88d22074927a`; the reader binary inside is `fb0b4361225a92af0a6027e901b289d1cfd8401fcd436148a1dfa23ceac18732` and `zreader --version` prints `zreader 0.11.1`. The dictionaries are unchanged from 0.10.3. `zr111-sizes.json` records its build sizes.

# 0.11.0 runtime (rollback)

`zr110.tgz` is the previous release, kept for rollback (Shrink for Kindle for PDFs), tested on a Kindle Paperwhite 12th gen. SHA-256: `bed094aa4a9ba6b6e7554cc013855c15d33a6ac7cbdff0ba0834a66423b1b443`; the reader binary inside is `18c41f7d1daf7539878a0a8a411cd8825f16bd02799a8b6b34912893a097c3f5` and `zreader --version` prints `zreader 0.11.0`. The dictionaries are unchanged from 0.10.3. `zr110-sizes.json` records its build sizes.

Older packages are no longer included; their source is in the git history.

Verify from the repository root with `sha256sum -c release/SHA256SUMS` (or `shasum -a 256 -c release/SHA256SUMS`). The manifest also covers both dictionaries and their source inputs.
