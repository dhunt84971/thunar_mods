#!/usr/bin/env bash
# Fetch upstream Thunar and apply this repository's patches to it, producing
# the ./thunar/ working tree that scripts/build.sh expects.
#
#   scripts/get-upstream.sh           # clone (or reuse) and apply the patches
#   scripts/get-upstream.sh --reset   # throw an existing ./thunar away first
#
# ./thunar is deliberately not tracked here: it is upstream's repository, and
# the fork is only the four commits in patches/. Running this script rebuilds
# the exact branch those patches describe, authorship included.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/thunar"
PATCHES="$ROOT/patches"

UPSTREAM="https://gitlab.xfce.org/xfce/thunar.git"
BASE_TAG="thunar-4.18.11"
BRANCH="fork/4.18.11-typeahead"

if [ "${1:-}" = "--reset" ]; then
  echo "==> removing $SRC"
  rm -rf "$SRC"
fi

command -v git >/dev/null || { echo "git not found" >&2; exit 1; }

if [ -d "$SRC/.git" ]; then
  echo "==> reusing the existing clone in thunar/"
else
  echo "==> cloning $UPSTREAM (this pulls the full history, ~120 MB)"
  git clone "$UPSTREAM" "$SRC"
fi

cd "$SRC"

# The tag has to exist locally; a clone that predates it needs a fetch.
git rev-parse -q --verify "refs/tags/$BASE_TAG" >/dev/null || git fetch origin --tags

if git rev-parse -q --verify "refs/heads/$BRANCH" >/dev/null; then
  echo "==> branch $BRANCH already exists - leaving it alone"
  echo "    (re-run with --reset to rebuild it from scratch)"
  git log --oneline "$BASE_TAG..$BRANCH"
  exit 0
fi

echo "==> branching $BRANCH off $BASE_TAG"
git checkout -q -b "$BRANCH" "$BASE_TAG"

echo "==> applying the patches"
# git am needs a committer identity; the patches carry their own author.
if ! git config user.email >/dev/null; then
  echo "    no git user.email configured - setting a local placeholder" >&2
  git config user.name "Thunar fork builder"
  git config user.email "builder@localhost"
fi

for p in "$PATCHES"/0*.patch; do
  echo "    $(basename "$p")"
  git am "$p"
done

echo
echo "==> done:"
git log --oneline "$BASE_TAG..HEAD"
echo
echo "Next: scripts/build.sh"
