#!/bin/bash
#
# make-transfer-bundle.sh -- pack everything another machine needs to build and
# install the fork into one tarball under dist/.
#
# The bundle carries a release-style source distribution of the patched Thunar
# (configure and all generated sources already in it), the three Xfce 4.18 core
# library tarballs needed on a system still running Xfce 4.16, the two
# target-side install scripts, the patches and the relevant docs.  The target
# needs a compiler and the distribution's development headers -- nothing else,
# and no network access.
#
# Usage:  ./make-transfer-bundle.sh [--refresh]
#           --refresh   rebuild the source distribution even if one is current
#
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD="$ROOT/build"
DIST="$ROOT/dist"
REFRESH=0
if [ "${1:-}" = "--refresh" ]; then
  REFRESH=1
fi

die () { echo "error: $*" >&2; exit 1; }

[ -f "$BUILD/config.status" ] || die "not built yet -- run scripts/build.sh first"

# --- the patched source distribution ---------------------------------------
TARBALL="$(ls -1t "$BUILD"/thunar-*.tar.bz2 2>/dev/null | head -1 || true)"
NEWEST_SOURCE="$(find "$ROOT/thunar" -name .git -prune -o -type f -newer "${TARBALL:-$BUILD/config.status}" -print 2>/dev/null | head -1 || true)"
if [ "$REFRESH" -eq 1 ] || [ -z "$TARBALL" ] || [ -n "$NEWEST_SOURCE" ]; then
  echo "building the source distribution ..."
  make -C "$BUILD" dist
  TARBALL="$(ls -1t "$BUILD"/thunar-*.tar.bz2 | head -1)"
fi
VERSION="$(basename "$TARBALL" .tar.bz2)"
echo "source distribution: $(basename "$TARBALL")"

# the feature must actually be in there
# grep -c, not grep -q: -q exits on the first match, SIGPIPEs tar, and
# pipefail then reports the pipeline as failed even though the match was found
tar xjOf "$TARBALL" "$VERSION/thunar/thunar-window.c" | grep -c type_ahead_search >/dev/null \
  || die "$TARBALL does not contain the type-ahead patch"

# --- assemble ---------------------------------------------------------------
NAME="thunar-typeahead-transfer-$(date +%Y%m%d)"
STAGE="$DIST/$NAME"
rm -rf "$STAGE"
mkdir -p "$STAGE/scripts" "$STAGE/vendor" "$STAGE/docs" "$STAGE/patches"

cp "$TARBALL" "$STAGE/"
cp "$ROOT"/vendor/*.tar.bz2 "$STAGE/vendor/"
cp "$ROOT"/scripts/target-install-xfce418-deps.sh \
   "$ROOT"/scripts/target-install.sh "$STAGE/scripts/"
cp "$ROOT"/patches/*.patch "$ROOT"/patches/README.md "$STAGE/patches/"
cp "$ROOT"/docs/02-feature-design.md \
   "$ROOT"/docs/05-porting-to-another-system.md \
   "$ROOT"/docs/06-search-performance.md "$STAGE/docs/"
cp "$ROOT"/thunar/FORK.md "$STAGE/"

# the target-side walkthrough lives in docs/ so it is version-controlled
# with everything else; only the version number is substituted in
sed "s/@VERSION@/${VERSION#thunar-}/g" "$ROOT/docs/INSTALL-target.md" > "$STAGE/INSTALL.md"

( cd "$STAGE" && find . -type f ! -name SHA256SUMS -print0 | sort -z \
    | xargs -0 sha256sum > SHA256SUMS )

( cd "$DIST" && tar czf "$NAME.tar.gz" "$NAME" )

echo
echo "bundle: $DIST/$NAME.tar.gz  ($(du -h "$DIST/$NAME.tar.gz" | cut -f1))"
echo "staged: $STAGE/"
echo
echo "Copy it over, then on the other machine:"
echo "  tar xzf $NAME.tar.gz && cd $NAME && less INSTALL.md"
