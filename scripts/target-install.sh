#!/bin/bash
#
# target-install.sh -- build and install the Thunar type-ahead fork on another
# machine, from the source tarball in this transfer bundle.
#
# The fork goes into /usr/local, where it shadows the distribution's
# /usr/bin/thunar: PATH and XDG_DATA_DIRS both put /usr/local first, so the
# shell, the panel and D-Bus activation all reach the fork.  The distribution's
# thunar package stays installed and untouched.
#
# The tarball is a release-style source distribution: configure and every
# generated source (marshallers, GDBus proxies, GResource) are already in it,
# so the target needs only a compiler and the development headers -- no
# autotools, no xfce4-dev-tools, no gtk-doc, no maintainer mode.
#
# On a system older than Xfce 4.18, run target-install-xfce418-deps.sh first
# and pass DEPS_PREFIX, so the fork links against the newer core libraries.
#
# Usage:  sudo ./target-install.sh                       # Xfce 4.18 or newer
#         sudo DEPS_PREFIX=/opt/xfce418 ./target-install.sh   # Xfce 4.16
# Env:    DEPS_PREFIX  private Xfce 4.18 library prefix, if one was built
#         JOBS         parallel compile jobs (default nproc)
#
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PREFIX=/usr/local
BUILD_ROOT=/usr/local/src/thunar-typeahead
DEPS_PREFIX="${DEPS_PREFIX:-}"
JOBS="${JOBS:-$(nproc)}"

# Thunar's own thunarx plugins -- these are built and installed by the fork, so
# the distribution's 4.16 copies of them must NOT be linked in beside them.
OWN_PLUGINS="thunar-apr thunar-sbr thunar-uca thunar-wallpaper-plugin"

REQUIRED_COMMANDS="gcc make pkg-config msgfmt bzip2 tar"
REQUIRED_MODULES="glib-2.0 gio-2.0 gtk+-3.0 libxfconf-0 gdk-pixbuf-2.0 pango"
APT_PACKAGES="build-essential pkg-config gettext intltool libglib2.0-dev
libgtk-3-dev libxfconf-0-dev libpango1.0-dev libgdk-pixbuf-2.0-dev
libgudev-1.0-dev libnotify-dev libice-dev libsm-dev
libstartup-notification0-dev"

die () { echo "error: $*" >&2; exit 1; }

[ "$(id -u)" -eq 0 ] || die "run this with sudo -- it installs into $PREFIX"

# --- the source tarball -----------------------------------------------------
TARBALL="${TARBALL:-}"
if [ -z "$TARBALL" ]; then
  # shellcheck disable=SC2012
  TARBALL="$(ls -1 "$SCRIPT_DIR"/thunar-*.tar.bz2 "$SCRIPT_DIR"/../thunar-*.tar.bz2 2>/dev/null | head -1 || true)"
fi
[ -n "$TARBALL" ] && [ -f "$TARBALL" ] \
  || die "no thunar-*.tar.bz2 found next to this script; pass TARBALL=/path/to/it"
VERSION="$(basename "$TARBALL" .tar.bz2)"

# --- prerequisites ----------------------------------------------------------
if [ -n "$DEPS_PREFIX" ]; then
  [ -d "$DEPS_PREFIX/lib/pkgconfig" ] \
    || die "DEPS_PREFIX=$DEPS_PREFIX has no lib/pkgconfig -- run target-install-xfce418-deps.sh first"
  export PKG_CONFIG_PATH="$DEPS_PREFIX/lib/pkgconfig${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"
  export LDFLAGS="-Wl,-rpath,$DEPS_PREFIX/lib${LDFLAGS:+ $LDFLAGS}"
fi

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

# the four version-sensitive ones, with the minimums from Thunar's configure.ac
check_version () {
  local mod="$1" min="$2" have
  have="$(pkg-config --modversion "$mod" 2>/dev/null || true)"
  [ -n "$have" ] || die "$mod not found -- on Xfce 4.16 run target-install-xfce418-deps.sh first"
  if ! pkg-config --atleast-version="$min" "$mod"; then
    echo "error: $mod is $have, Thunar 4.18 needs >= $min" >&2
    if [ -z "$DEPS_PREFIX" ]; then
      echo "       run target-install-xfce418-deps.sh and pass DEPS_PREFIX" >&2
    fi
    exit 1
  fi
  printf '  %-24s %s (>= %s)\n' "$mod" "$have" "$min"
}
echo "core libraries:"
check_version exo-2 4.17.0
check_version libxfce4util-1.0 4.17.2
check_version libxfce4ui-2 4.17.6
check_version libxfce4kbd-private-3 4.17.2

# --- build ------------------------------------------------------------------
# The build tree is kept at a fixed path so that "make uninstall" still works
# months later.
rm -rf "$BUILD_ROOT"
mkdir -p "$BUILD_ROOT"
tar xjf "$TARBALL" -C "$BUILD_ROOT" --strip-components=1

( cd "$BUILD_ROOT" \
  && ./configure \
       --prefix="$PREFIX" \
       --sysconfdir=/etc \
       --libexecdir="$PREFIX/lib/thunar" \
       --enable-gio-unix \
       --enable-gudev \
       --enable-notifications \
       --disable-debug \
       --disable-gtk-doc \
  && make -j"$JOBS" \
  && make install )

# --- third-party thunarx plugins -------------------------------------------
# Plugins the distribution installed under /usr/lib live in a directory the
# fork does not search.  Link the third-party ones into the fork's plugin
# directory so no context-menu entry is lost; skip Thunar's own, which the
# fork just installed itself.
SYS_PLUGIN_DIR="/usr/lib/$(dpkg-architecture -qDEB_HOST_MULTIARCH 2>/dev/null || echo "$(uname -m)-linux-gnu")/thunarx-3"
if [ -d "$SYS_PLUGIN_DIR" ]; then
  mkdir -p "$PREFIX/lib/thunarx-3"
  for so in "$SYS_PLUGIN_DIR"/*.so; do
    [ -e "$so" ] || continue
    name="$(basename "$so" .so)"
    case " $OWN_PLUGINS " in
      *" $name "*) continue ;;
    esac
    ln -sfn "$so" "$PREFIX/lib/thunarx-3/$name.so"
    echo "linked plugin $name"
  done
fi

ldconfig

echo
echo "$VERSION installed into $PREFIX"
if [ -n "$DEPS_PREFIX" ]; then
  echo "linked against the Xfce 4.18 libraries in $DEPS_PREFIX"
fi
echo
echo "Restart the file manager so the new binary takes over:"
echo "  thunar -q; hash -r; thunar &"
echo
echo "Check which binary is serving:   pgrep -af 'thunar --daemon'"
echo "Version it reports:              thunar --version | head -1"
echo "To remove it again:              sudo make -C $BUILD_ROOT uninstall"
