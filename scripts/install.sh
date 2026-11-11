#!/usr/bin/env bash
# Install the fork into /usr/local, where it shadows the distribution's
# /usr/bin/thunar (PATH and XDG_DATA_DIRS both put /usr/local first).
# The Ubuntu "thunar" package stays installed and untouched; uninstall.sh
# reverses this.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="$ROOT/build"

[ -f "$BUILD/config.status" ] || { echo "not built yet - run scripts/build.sh" >&2; exit 1; }
[ "$(id -u)" -eq 0 ] || { echo "re-run with sudo: sudo $0" >&2; exit 1; }

make -C "$BUILD" install

# Thunar builds four of its own thunarx plugins (apr, sbr, uca, wallpaper) and
# they install alongside the fork. The archive and media-tags plugins are
# separate Ubuntu packages under /usr/lib, which the fork would not look in,
# so link them into the fork's plugin directory. They share the thunarx-3
# SONAME, so they bind to whichever libthunarx the running process loaded.
for plugin in thunar-archive-plugin thunar-media-tags-plugin; do
  src="/usr/lib/$(dpkg-architecture -qDEB_HOST_MULTIARCH 2>/dev/null || echo x86_64-linux-gnu)/thunarx-3/$plugin.so"
  if [ -e "$src" ]; then
    ln -sfn "$src" "/usr/local/lib/thunarx-3/$plugin.so"
    echo "linked $plugin"
  fi
done

ldconfig

echo
echo "Installed. Restart the file manager so the new binary takes over:"
echo "  thunar -q"
echo "  hash -r"
echo "  thunar &"
