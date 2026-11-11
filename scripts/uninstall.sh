#!/usr/bin/env bash
# Remove the fork from /usr/local and hand the file manager back to the
# distribution's /usr/bin/thunar.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="$ROOT/build"

[ -f "$BUILD/config.status" ] || { echo "no build tree - nothing to uninstall" >&2; exit 1; }
[ "$(id -u)" -eq 0 ] || { echo "re-run with sudo: sudo $0" >&2; exit 1; }

# drop the plugin symlinks install.sh added before make uninstall runs
rm -f /usr/local/lib/thunarx-3/thunar-archive-plugin.so \
      /usr/local/lib/thunarx-3/thunar-media-tags-plugin.so

make -C "$BUILD" uninstall
rmdir /usr/local/lib/thunarx-3 2>/dev/null || true
ldconfig

echo
echo "Removed. Restart the file manager:"
echo "  thunar -q; hash -r; thunar &"
echo
echo "The fork's own setting can be cleared with:"
echo "  xfconf-query -c thunar -p /misc-type-ahead-search -r"
