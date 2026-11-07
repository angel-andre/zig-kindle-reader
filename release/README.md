# 0.10.1 runtime (current)

`zr101.tgz` (about 8.6 MiB) is the 0.10.1 runtime (Contents for books without an outline, Go to page / Go to %), tested on a Kindle Paperwhite 12th gen. SHA-256: `fb47ef0d7860e748ce8f80588bd617bce964adddabb10d01b317d3e690164381`; the reader binary inside is `4dbf7aa792f72ef708182dd5c5b9f464ef2e2781f5feb6a047189ee9c4160dde` and `zreader --version` prints `zreader 0.10.1`. `zr101-sizes.json` records its build sizes.

# 0.10.0 runtime (rollback)

`zr100.tgz` is the previous release (better EPUB text: justification, hyphenation, Font and Align choices), kept for rollback. SHA-256: `61235f2a942d6b4ae6558eaa360af92a1bce994130ea08eff7f319218581ad40`; the reader binary inside is `3a7cc018d9edb8ce3e50f963cfebbc7be5e72c504b3259937532b7e788b720a0` and `zreader --version` prints `zreader 0.10.0`. `zr100-sizes.json` records its build sizes. Older packages are no longer included; their source is in the git history.

Verify from the repository root with `sha256sum -c release/SHA256SUMS` (or `shasum -a 256 -c release/SHA256SUMS`). The manifest also covers the dictionary and its source input.
