#!/usr/bin/env bash
# Run the freshly built fork without installing it.
#
# Thunar is a D-Bus service: if the distribution's thunar daemon is already
# running, a second thunar process just asks that daemon to open a window - the
# old binary would answer. So the running daemon is shut down first.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BIN="$ROOT/build/thunar/thunar"

[ -x "$BIN" ] || { echo "not built yet - run scripts/build.sh" >&2; exit 1; }

echo "==> stopping any running Thunar daemon"
thunar -q 2>/dev/null || true
sleep 1

echo "==> starting the fork: $BIN ${*:-$HOME}"
exec "$BIN" "${@:-$HOME}"
