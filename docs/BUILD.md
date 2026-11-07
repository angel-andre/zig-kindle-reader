# Build from corresponding source

Build on a Linux x86-64 computer, not the Kindle. Tested toolchain: **Zig 0.17.1**, MuPDF **1.28.6**, GNU make, Python 3, Pillow, standard C build tools and common command-line utilities. Scripts use `nproc`; macOS-native builds have not been verified. Zig cross-compiles the static `arm-linux-musleabihf` executable with `cortex_a53` CPU targeting.

## 1. Obtain exact MuPDF source

The extracted source used by the build was compared file-by-file with the original archive: no changed or missing archive files were found. There are **no project-specific MuPDF patches**. Feature trimming is through `build-mupdf.sh` flags; the project's own renderer wrapper is `src/render.c`.

Download the official complete source archive, including bundled dependencies, on your computer:

```sh
curl -fL https://github.com/ArtifexSoftware/mupdf-downloads/releases/download/1.28.6/mupdf-1.28.6-source.tar.gz  -o ../mupdf-1.28.6-source.tar.gz
printf '%s  %s\n' dc85000640a45d90ca9b77b061f6ca67cce0c4d4fbecf8819647baf573eef101 ../mupdf-1.28.6-source.tar.gz | sha256sum -c -
tar -xzf ../mupdf-1.28.6-source.tar.gz -C ..
```

The checked archive is 68,924,915 bytes. The official archive URL was reachable when this documentation was assembled. The source is intentionally fetched rather than edited: upstream examples include unrelated sample credentials, example network literals and third-party workstation paths. Do not mistake those examples for device configuration or import them into privacy-sensitive release notes.

Install Zig 0.17.1 so `../zig/zig` exists, or set an absolute `Z`/`ZIG` path. Keep this sibling layout:

```text
work/
  zig/zig
  mupdf-1.28.6-source/
  zig-kindle-reader/   # this tree
  testbooks/          # optional private regression inputs
```

## 2. Build libraries, then executables

From this repository root:

```sh
./build-mupdf.sh
TGT=x86_64-linux-musl CPU=-mcpu=baseline PFX=hostmusl- ./build-mupdf.sh
./build.sh
```

For a non-default toolchain/source location, export `Z` for the MuPDF script, `ZIG` for application/tests and `MU` for the source tree. The host MuPDF build enables host simulation/tests; ARM-only builds are supported when no host libraries exist.

Outputs: `out/zreader` (Kindle), `out/zreader-host` (host when libraries exist), `out/einktest` (diagnostic utility; not required for reading). Build flags disable unrelated document formats, JS, OCR and several heavyweight features; consult the preserved script for exact flags. No system-installed MuPDF substitution was used.

## 3. Dictionary

The complete licensed WordNet source input and builder are included:

```sh
python3 dictionary/build.py dictionary/source/WNdb-3.0.tar.gz dictionary/wordnet.zdict
```

Input SHA-256: `658b1ba191f5f98c2e9bae3e25c186013158f30ef779f191d2a44e5d25046dc8`.
Output SHA-256: `d2db381060fab8254f1b68551ffa1ec6d533c4662f22a2bb343abfd4b16a297b`.
Format and provenance: `dictionary/FORMAT`, Princeton notice: `dictionary/LICENSE`.

## 4. Verify and distribute

See TESTING. Rebuilding is documented, not a claim of bit-for-bit reproducibility across arbitrary toolchains. The included runtime is the earlier installed-version artifact; its binary checksum is in README.

For every binary distribution, provide the full corresponding reader source, build scripts, fonts and licence notices **and the exact complete MuPDF source**. The pinned upstream URL is a retrieval recipe, not a promise that a third party will retain it forever. Before sharing a release, download and retain that original archive alongside the reader sources and offer both to recipients. Do not send only the binary or rely on a private repository that recipients cannot access. Preserve all bundled dependency licences from the MuPDF source distribution.
