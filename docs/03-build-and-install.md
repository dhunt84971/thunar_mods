# Building, running and removing the fork

Everything below is run from the project root — the directory holding this
`docs/` — and paths are relative to it.

The upstream source is not part of this repository. Fetch it first:

```
scripts/get-upstream.sh      # clones Thunar 4.18.11 and applies patches/
```

## 1. Build dependencies (once, needs root)

```
sudo scripts/install-build-deps.sh
```

It installs the autotools toolchain plus the GTK 3 and Xfce 4.18 development
headers (`xfce4-dev-tools`, `libexo-2-dev`, `libxfce4ui-2-dev`,
`libxfce4util-dev`, `libxfconf-0-dev`, `libgtk-3-dev`, `libglib2.0-dev`,
`libpango1.0-dev`, `libgudev-1.0-dev`, `libnotify-dev`,
`libxfce4panel-2.0-dev`, …). Nothing is removed and the distribution's
`thunar` package is left alone.

## 2. Build

```
scripts/build.sh            # configure once, then make -j
scripts/build.sh --clean    # start the build tree over
```

`xdt-autogen` is run in `thunar/` (it only writes generated build files) and the
compile happens out of tree in `build/`, so the source tree stays clean and
`git status` in `thunar/` keeps being readable. The result is
`build/thunar/thunar`.

`--enable-maintainer-mode` is passed on purpose: the rules that generate
`thunar-marshal.c`, the GDBus proxies and the GResource bundle live behind
automake's `MAINTAINER_MODE` conditional, because a release tarball ships those
files pre-generated. Building from git does not, so the rules have to be
switched on or `make` stops at `No rule to make target 'thunar-marshal.c'`.

## 3. Try it without installing

```
scripts/run-fork.sh              # opens $HOME
scripts/run-fork.sh /some/dir
```

Thunar is a D-Bus service, so this stops a running Thunar daemon first
(`thunar -q`) — otherwise a second `thunar` process just asks the already
running *distribution* binary to open a window and nothing appears to change.

## 4. Install system-wide

```
scripts/build.sh
sudo scripts/install.sh
thunar -q; hash -r; thunar &
```

The fork installs into `/usr/local`, which comes before `/usr` in both `PATH`
and `XDG_DATA_DIRS`, so `/usr/local/bin/thunar` and the `/usr/local` D-Bus
service files shadow the packaged ones. The Ubuntu `thunar` package stays
installed; apt upgrades of it will not touch `/usr/local`.

### Plugins

Thunar builds four thunarx plugins itself — `thunar-apr` (extra properties
pages), `thunar-sbr` (bulk rename), `thunar-uca` (custom actions) and
`thunar-wallpaper-plugin` — and those install with the fork into
`/usr/local/lib/thunarx-3`. Two more are separate Ubuntu packages living in
`/usr/lib/<triplet>/thunarx-3`, which the fork does not search:

* `thunar-archive-plugin` — *Extract Here* / *Create Archive*
* `thunar-media-tags-plugin` — audio tag pages and tag-based renaming

`install.sh` symlinks those two into the fork's plugin directory, and
`uninstall.sh` removes the links again. Both are built against the same
`thunarx-3` ABI and resolve the `libthunarx-3.so.0` SONAME to whichever copy
the running process already loaded, so one library is in play, not two.

### Installed on this machine

Installed 2026-11-10 and made the live file manager:

* `/usr/local/bin/thunar` → `thunar 4.18.11 (Xfce 4.18)`, ahead of
  `/usr/bin/thunar` (4.18.8, still installed and untouched)
* the old `Thunar --daemon` was stopped and the fork started in its place; the
  only windows it owned were the daemon's two 1x1 off-screen helper windows
* `thunar-archive-plugin` confirmed loading into the running fork
* no autostart entry or saved session pins the old path, so D-Bus activation
  through `/usr/local/share/dbus-1/services` brings the fork up at next login
  too

To check at any time which binary is serving:

```
pgrep -af 'thunar --daemon'
readlink -f /proc/$(pgrep -f '^/usr/local/bin/thunar --daemon' | head -1)/exe
```

## 5. Go back to the distribution's Thunar

```
sudo scripts/uninstall.sh
thunar -q; hash -r; thunar &
xfconf-query -c thunar -p /misc-type-ahead-search -r   # optional, drops the setting
```

## Rebasing onto a newer upstream release

`thunar/` is a full clone whose `origin` is
`https://gitlab.xfce.org/xfce/thunar.git`:

```
cd thunar
git fetch origin --tags
git rebase thunar-4.18.12 fork/4.18.11-typeahead   # when such a tag appears
```

The fork is four commits, so a rebase is cheap. `patches/` holds the same change
as `git am`-able patches, for applying it to a source tree obtained some other
way (a distribution source package, a release tarball):

```
cd /some/other/thunar-4.18.11
git am < /path/to/thunar_mods/patches/0001-build-fix-automake-library-name.patch
git am < /path/to/thunar_mods/patches/0002-type-ahead-recursive-search.patch
git am < /path/to/thunar_mods/patches/0003-breadth-first-search.patch
git am < /path/to/thunar_mods/patches/0004-open-search-result-on-click.patch
# or, without git:
for p in /path/to/thunar_mods/patches/0*.patch; do patch -p1 < "$p"; done
```

Patch 1 is upstream commit `cfa85fcdb`, only needed when the build system is
regenerated from a git checkout; a release tarball ships generated `Makefile.in`
files and does not need patch 1. See `patches/README.md`.
