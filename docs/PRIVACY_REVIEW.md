# Privacy and release hygiene

The staged tree uses placeholders for hosts and key paths. It excludes device serial/MAC/network inventory, personal-computer paths, actual keys/tokens, runtime device logs, copyrighted books and real-book screenshots. Synthetic UI PNGs were re-encoded without metadata and visually inspected.

Before any upload, scan all text, binary strings, archive members, fixture document metadata and PNG metadata. Reject actual credentials, network/device identifiers and personal paths. Check generated artifacts too, not only tracked source. Test fixtures containing public example data must not be confused with actual device configuration.

The packaging verifier from the original work tree was excluded because its denylist literally contained private-environment search terms. Historical result summaries and tests that do not embed those terms were preserved. Machine-specific packaging scripts and extracted real-book traces were also excluded.

MuPDF is pinned by a complete official source URL and checksum rather than copying its unedited large archive here; unrelated upstream sample keys, network literals and workstation paths are not imported into this repository. Retain and offer the unmodified exact source archive to binary recipients as described in THIRD_PARTY. Do not strip licence attribution to make a simplistic keyword scan green.

Never commit raw personal-device logs, note exports, local network data or SSH key material. Review commit author/metadata as well as file content. Do not make the repository public without its owner's explicit decision.

## Assembly release gate

The personal/device-data scan passed. The stricter literal-address scan found one standard loopback constant inside the statically linked runtime. It is not this device's network address, but it still conflicts with an absolute ban on all numeric address literals. No value is reproduced here and no binary patch was attempted. The overall strict scan remains FAIL; do not upload that runtime until the release policy is resolved or a properly rebuilt/verified artifact is provided.
