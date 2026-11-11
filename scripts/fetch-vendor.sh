#!/usr/bin/env bash
# Download the Xfce 4.18 core library release tarballs into vendor/ and verify
# them by checksum.
#
# These are only needed when installing onto a host still on Xfce 4.16 (for
# example Xubuntu 22.04), where scripts/target-install-xfce418-deps.sh builds
# them into a private prefix. A host already on Xfce 4.18 does not need them.
#
#   scripts/fetch-vendor.sh
#
# The tarballs are upstream Xfce releases, unmodified; they are fetched rather
# than committed so this repository stays small and carries only its own work.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$ROOT/vendor"
BASE="https://archive.xfce.org/src/xfce"

# component|version|sha256
FILES="
libxfce4util|4.18.2|d9a329182b78f7e2520cd4aafcbb276bbbf162f6a89191676539ad2e3889c353
libxfce4ui|4.18.6|77dd99206cc8c6c7f69c269c83c7ee6a037bca9d4a89b1a6d9765e5a09ce30cd
exo|4.18.0|4f2c61d045a888cdb64297fd0ae20cc23da9b97ffb82562ed12806ed21da7d55
"

command -v sha256sum >/dev/null || { echo "sha256sum not found" >&2; exit 1; }
if command -v curl >/dev/null; then
  fetch() { curl -fL --retry 3 -o "$1" "$2"; }
elif command -v wget >/dev/null; then
  fetch() { wget -O "$1" "$2"; }
else
  echo "neither curl nor wget found" >&2; exit 1
fi

mkdir -p "$DEST"

while IFS='|' read -r name version sha; do
  [ -n "$name" ] || continue
  tarball="$name-$version.tar.bz2"
  series="${version%.*}"                       # 4.18.2 -> 4.18
  url="$BASE/$name/$series/$tarball"

  if [ -f "$DEST/$tarball" ] \
     && echo "$sha  $DEST/$tarball" | sha256sum -c - >/dev/null 2>&1; then
    echo "==> $tarball already present and verified"
    continue
  fi

  echo "==> fetching $tarball"
  fetch "$DEST/$tarball.part" "$url"
  echo "$sha  $DEST/$tarball.part" | sha256sum -c - >/dev/null \
    || { rm -f "$DEST/$tarball.part"; echo "checksum mismatch for $tarball" >&2; exit 1; }
  mv "$DEST/$tarball.part" "$DEST/$tarball"
  echo "    verified"
done <<EOF
$FILES
EOF

echo
echo "vendor/ now holds:"
ls -1 "$DEST"
