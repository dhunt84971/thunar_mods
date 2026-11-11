#!/bin/bash
# Runs the click test on its own virtual display, so it neither disturbs nor is
# disturbed by whoever is using the real desktop. gvfs is reached over the
# session bus, which is not tied to the display, so the SMB mount still works.
#
#   scripts/ui-click-test.sh <thunar-binary> <label> <location> [query]
#
# <location> is the folder to search in - a slow one is the whole point, e.g.
# smb://host/share/. [query] defaults to QCAD. Log and screenshots are written
# to $OUT (default ./ui-test-out).
#
#   scripts/ui-click-test.sh build/thunar/thunar after smb://host/share/
set -u
BIN="${1:-}"; LABEL="${2:-}"; URI="${3:-${TEST_URI:-}}"; QUERY="${4:-${TEST_QUERY:-QCAD}}"
if [ -z "$BIN" ] || [ -z "$LABEL" ] || [ -z "$URI" ]; then
  echo "usage: $0 <thunar-binary> <label> <location-uri> [query]" >&2
  exit 2
fi
S="${OUT:-$PWD/ui-test-out}"
mkdir -p "$S/shots"
LOG="$S/$LABEL.log"; : > "$LOG"
VD="${DISPLAY_NUM:-:99}"

pkill -f "Xvfb $VD" 2>/dev/null; sleep 1
Xvfb $VD -screen 0 1280x900x24 >/dev/null 2>&1 &
XPID=$!
sleep 2

export DISPLAY=$VD
pkill -x thunar 2>/dev/null; sleep 2; pkill -9 -x thunar 2>/dev/null; sleep 1

setsid "$BIN" "$URI" >"$S/$LABEL.stderr" 2>&1 &
sleep 8
WID="$(xdotool search --onlyvisible --class Thunar | tail -1)"
if [ -z "$WID" ]; then echo "no window" >> "$LOG"; kill $XPID; exit 1; fi
xdotool windowactivate --sync "$WID" 2>/dev/null; sleep 1
GEO=$(xdotool getwindowgeometry --shell "$WID"); eval "$GEO"
echo "window $WID at $X,$Y ${WIDTH}x${HEIGHT}" >> "$LOG"
SMB=$(pgrep -f "gvfsd-smb --spawner" | head -1)

xdotool type --delay 120 "$QUERY"
sleep 8
import -window "$WID" "$S/shots/$LABEL-1-results.png"

c0=$(awk '{print $14+$15}' /proc/$SMB/stat)
# first result row: the list starts just under the column headers
xdotool mousemove $((X+220)) $((Y+101)); sleep 1; xdotool click 1
echo "clicked" >> "$LOG"
sleep 4
import -window "$WID" "$S/shots/$LABEL-2-after-click.png"
c1=$(awk '{print $14+$15}' /proc/$SMB/stat); echo "0-4s after click:  smb ticks +$((c1-c0))" >> "$LOG"
sleep 16
import -window "$WID" "$S/shots/$LABEL-3-plus20s.png"
c2=$(awk '{print $14+$15}' /proc/$SMB/stat); echo "4-20s after click: smb ticks +$((c2-c1))" >> "$LOG"

pkill -x thunar 2>/dev/null; sleep 1
kill $XPID 2>/dev/null
echo done >> "$LOG"
