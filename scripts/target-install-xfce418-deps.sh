#!/bin/bash
#
# target-install-xfce418-deps.sh -- build the Xfce 4.18 core libraries into a
# private prefix, for a target system whose distribution still ships Xfce 4.16
# (Xubuntu / Ubuntu 22.04 "jammy", Debian 11, Linux Mint 20/21 Xfce, ...).
#
# Thunar 4.18 needs exo >= 4.17.0, libxfce4util >= 4.17.2 and
# libxfce4ui >= 4.17.6.  A 4.16 distribution has none of those, and there is no
# longer a usable backport archive for them, so they are built from the
# official release tarballs and installed OUTSIDE the package manager's reach.
#
# Nothing the distribution installed is touched or shadowed: the libraries land
# in $PREFIX (default /opt/xfce418) and only the Thunar fork is linked against
# them, via an RPATH baked in by target-install.sh.  The rest of the Xfce 4.16
# desktop keeps using its own libraries.
#
# Usage:  sudo ./target-install-xfce418-deps.sh
#         PREFIX=$HOME/xfce418 ./target-install-xfce418-deps.sh   # no sudo needed
# Env:    PREFIX     where to install the libraries   (default /opt/xfce418)
#         SRC_DIR    where the tarballs are           (default ../vendor)
#         WORK       scratch build directory          (default /var/tmp/xfce418-build)
#         JOBS       parallel compile jobs            (default nproc)
#
set -euo pipefail

PREFIX="${PREFIX:-/opt/xfce418}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SRC_DIR="${SRC_DIR:-$SCRIPT_DIR/../vendor}"
WORK="${WORK:-/var/tmp/xfce418-build}"
JOBS="${JOBS:-$(nproc)}"

# name|sha256|extra configure flags -- built in this order, each one against
# the ones before it
PACKAGES=(
  "libxfce4util-4.18.2.tar.bz2|d9a329182b78f7e2520cd4aafcbb276bbbf162f6a89191676539ad2e3889c353|"
  "libxfce4ui-4.18.6.tar.bz2|77dd99206cc8c6c7f69c269c83c7ee6a037bca9d4a89b1a6d9765e5a09ce30cd|--disable-gladeui2"
  "exo-4.18.0.tar.bz2|4f2c61d045a888cdb64297fd0ae20cc23da9b97ffb82562ed12806ed21da7d55|--enable-gio-unix"
)

# tools and headers the three builds need from the distribution
REQUIRED_COMMANDS="gcc make pkg-config msgfmt bzip2 tar sha256sum"
REQUIRED_MODULES="glib-2.0 gio-2.0 gtk+-3.0 libxfconf-0 gdk-pixbuf-2.0 pango"
APT_PACKAGES="build-essential pkg-config gettext intltool libglib2.0-dev
libgtk-3-dev libxfconf-0-dev libpango1.0-dev libgdk-pixbuf-2.0-dev
libgtop2-dev libepoxy-dev libstartup-notification0-dev"

die () { echo "error: $*" >&2; exit 1; }

# root is needed only because the default prefix is under /opt; a prefix the
# invoking user can write (PREFIX=$HOME/xfce418) works without sudo
probe="$PREFIX"
while [ -n "$probe" ] && [ ! -d "$probe" ]; do probe="$(dirname "$probe")"; done
[ -w "$probe" ] || die "cannot write $PREFIX -- re-run with sudo, or set PREFIX to a directory you own"

missing=""
for cmd in $REQUIRED_COMMANDS; do
  command -v "$cmd" >/dev/null 2>&1 || missing="$missing $cmd"
done
for mod in $REQUIRED_MODULES; do
  pkg-config --exists "$mod" 2>/dev/null || missing="$missing $mod"
done
if [ -n "$missing" ]; then
  echo "missing build prerequisites:$missing" >&2
  echo >&2
  echo "install them with:" >&2
  echo "  sudo apt install $(echo $APT_PACKAGES)" >&2
  exit 1
fi

mkdir -p "$PREFIX" "$WORK"

export PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"
export LDFLAGS="-Wl,-rpath,$PREFIX/lib${LDFLAGS:+ $LDFLAGS}"

for entry in "${PACKAGES[@]}"; do
  tarball="${entry%%|*}"
  rest="${entry#*|}"
  sha="${rest%%|*}"
  flags="${rest#*|}"
  name="${tarball%.tar.bz2}"

  echo
  echo "=== $name ==================================================="

  [ -f "$SRC_DIR/$tarball" ] || die "$SRC_DIR/$tarball not found"
  echo "$sha  $SRC_DIR/$tarball" | sha256sum -c - \
    || die "checksum mismatch for $tarball -- do not build it"

  # each tarball is unpacked into its own empty directory
  rm -rf "$WORK/$name"
  mkdir -p "$WORK/$name"
  tar xjf "$SRC_DIR/$tarball" -C "$WORK/$name" --strip-components=1

  ( cd "$WORK/$name" \
    && ./configure --prefix="$PREFIX" --disable-debug --disable-gtk-doc $flags \
    && make -j"$JOBS" \
    && make install )

  echo "=== $name installed"
done

echo
echo "Xfce 4.18 core libraries installed into $PREFIX"
echo
for mod in libxfce4util-1.0 libxfce4ui-2 libxfce4kbd-private-3 exo-2; do
  printf '  %-24s %s\n' "$mod" \
    "$(PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig" pkg-config --modversion "$mod" 2>/dev/null || echo "NOT FOUND")"
done
echo
echo "Next:  sudo DEPS_PREFIX=$PREFIX ./target-install.sh"
