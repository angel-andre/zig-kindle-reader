#!/bin/sh
# Builds a trimmed static MuPDF 1.28.6 for armhf (musl) with zig cc.
set -e
HERE=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
MU=${MU:-$HERE/../mupdf-1.28.6-source}
Z=${Z:-$HERE/../zig/zig}
TARGETS=${TARGETS:-libs}
cd "$MU"
# zreader's small MuPDF patches (mupdf-patches/*.patch), applied once.
for p in "$HERE"/mupdf-patches/*.patch; do
  [ -f "$p" ] || continue
  patch -p1 -R -s -f --dry-run < "$p" >/dev/null 2>&1 || patch -p1 -N -s < "$p"
done
TGT=${TGT:-arm-linux-musleabihf}
CPU=${CPU:--mcpu=cortex_a53}
PFX=${PFX:-armhf-}
DEFS="-DFZ_ENABLE_JS=0 -DFZ_ENABLE_XPS=0 -DFZ_ENABLE_SVG=0 -DFZ_ENABLE_CBZ=0 -DFZ_ENABLE_IMG=0 -DFZ_ENABLE_MD=0 -DFZ_ENABLE_MOBI=0 -DFZ_ENABLE_FB2=0 -DFZ_ENABLE_TXT=0 -DFZ_ENABLE_OFFICE=0 -DFZ_ENABLE_OCR_OUTPUT=0 -DFZ_ENABLE_ODT_OUTPUT=0 -DFZ_ENABLE_DOCX_OUTPUT=0 -DFZ_ENABLE_BARCODE=0 -DFZ_ENABLE_SPOT_RENDERING=0 -DTOFU -DTOFU_CJK -DTOFU_EMOJI -DTOFU_HISTORIC -DTOFU_SYMBOL -DFZ_ENABLE_HYPHEN_ALL=0 -DFZ_ENABLE_BROTLI=0"
export PATH="$HERE/../tools/bin:$PATH"
make -j$(nproc) build=release OS=Linux HAVE_X11=no HAVE_GLUT=no HAVE_CURL=no HAVE_LIBCRYPTO=no HAVE_OBJCOPY=no \
  USE_TESSERACT=no tesseract=no barcode=no brotli=no extract=no HAVE_PTHREAD=yes \
  CC="$Z cc -target $TGT $CPU" CXX="$Z c++ -target $TGT $CPU" \
  AR="$Z ar" XCFLAGS="-Os -ffunction-sections -fdata-sections $DEFS" \
  build_prefix=$PFX "$TARGETS"
