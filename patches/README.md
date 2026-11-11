# Patches

The fork as four `git am`-able patches against the upstream tag
`thunar-4.18.11`, in order:

| file | what it does |
| --- | --- |
| `0001-build-fix-automake-library-name.patch` | upstream commit `cfa85fcdb`, cherry-picked. Renames `thunar.a` to `libthunar.a`; without it automake 1.16.5 (Ubuntu 24.04) refuses to regenerate the build system: `thunar/Makefile.am:214: error: 'thunar.a' is not a standard library name`. Only needed when building from git, which is what this fork does. |
| `0002-type-ahead-recursive-search.patch` | the feature: typing in a focused window starts a recursive search. |
| `0003-breadth-first-search.patch` | makes recursive search usable on slow locations: queue subdirectories breadth-first instead of recursing inline, commit matches as each folder is read, and debounce a query that is still being typed. See `docs/06-search-performance.md`. |
| `0004-open-search-result-on-click.patch` | clicking a result opens *that* file or folder and stops the crawl. Before, the selection was thrown away while a search was running, so activating a result re-opened the folder being searched and the search carried on. |

Applying them to a plain 4.18.11 source tree:

```
cd thunar-4.18.11
git am < 0001-build-fix-automake-library-name.patch
git am < 0002-type-ahead-recursive-search.patch
git am < 0003-breadth-first-search.patch
git am < 0004-open-search-result-on-click.patch
```

or without git:

```
patch -p1 < 0001-build-fix-automake-library-name.patch
patch -p1 < 0002-type-ahead-recursive-search.patch
patch -p1 < 0003-breadth-first-search.patch
patch -p1 < 0004-open-search-result-on-click.patch
```

Patches 2, 3 and 4 alone are enough for a release tarball, whose `Makefile.in` files are
already generated.
