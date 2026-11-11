#!/usr/bin/env bash
# Build the Thunar fork out-of-tree. Nothing is installed; see install.sh for that.
#
#   scripts/build.sh            # configure (once) + build
#   scripts/build.sh --clean    # throw the build tree away first
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/thunar"
BUILD="$ROOT/build"
PREFIX="${PREFIX:-/usr/local}"

[ "${1:-}" = "--clean" ] && rm -rf "$BUILD"

command -v xdt-autogen >/dev/null || {
  echo "xdt-autogen not found - run: sudo $ROOT/scripts/install-build-deps.sh" >&2
  exit 1
}

# upstream's autogen.sh must run in the source tree; it only generates files
if [ ! -x "$SRC/configure" ]; then
  echo "==> generating the build system (xdt-autogen)"
  ( cd "$SRC" && NOCONFIGURE=1 ./autogen.sh )
fi

mkdir -p "$BUILD"
if [ ! -f "$BUILD/config.status" ]; then
  echo "==> configuring (prefix=$PREFIX)"
  ( cd "$BUILD" && "$SRC/configure" \
      --prefix="$PREFIX" \
      --sysconfdir=/etc \
      --libexecdir="$PREFIX/lib/thunar" \
      --enable-maintainer-mode \
      --enable-gio-unix \
      --enable-gudev \
      --enable-notifications \
      --disable-debug \
      --disable-gtk-doc )
fi

echo "==> building with $(nproc) jobs"
make -C "$BUILD" -j"$(nproc)"

echo
echo "Built: $BUILD/thunar/thunar"
"$BUILD/thunar/thunar" --version | head -1
