# 0.11.2 runtime (current)

`zr112.tgz` is the 0.11.2 runtime (instant zoom and pan feedback), tested on a Kindle Paperwhite 12th gen. SHA-256: `81a3529466ec71a646d8e42b06161d013a056e104f2ca36b6e4bcb0eda620fed`; the reader binary inside is `f4a861ba98586f69e4b7dd77f61b8292fb82be932ff4bb6fce40182574df0144` and `zreader --version` prints `zreader 0.11.2`. The dictionaries are unchanged from 0.10.3. `zr112-sizes.json` records its build sizes.

# 0.11.1 runtime (rollback)

`zr111.tgz` is the previous release, kept for rollback (two-page scans shown one page at a time), tested on a Kindle Paperwhite 12th gen. SHA-256: `c6ad8861c6a6cfc9a297b09e2e99c795398acbc67745a7fe74be88d22074927a`; the reader binary inside is `fb0b4361225a92af0a6027e901b289d1cfd8401fcd436148a1dfa23ceac18732` and `zreader --version` prints `zreader 0.11.1`. The dictionaries are unchanged from 0.10.3. `zr111-sizes.json` records its build sizes.

Older packages are no longer included; their source is in the git history.

Verify from the repository root with `sha256sum -c release/SHA256SUMS` (or `shasum -a 256 -c release/SHA256SUMS`). The manifest also covers both dictionaries and their source inputs.
