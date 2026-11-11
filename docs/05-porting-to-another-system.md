# Porting the fork to another system

Written for the second machine in use here, **Xubuntu 22.04.4**, but the
reasoning applies to any target: what matters is the version of the Xfce core
libraries the distribution ships, not the distribution itself.

## 1. Do not copy the binary

The fork was built on Ubuntu 24.04 against glibc 2.39, GTK 3.24.41 and the
Xfce 4.18 libraries. A binary built there will not start on 22.04, which has
glibc 2.35 — the dynamic loader fails on the symbol versions before `main()`
is reached. The source has to be rebuilt on each target.

## 2. What the target has to offer

Thunar 4.18.11's `configure.ac.in` requires:

| Package                  | Minimum  | Xubuntu 22.04 ships | Ubuntu 24.04 ships |
|--------------------------|----------|---------------------|--------------------|
| `exo-2`                  | 4.17.0   | **4.16.3**          | 4.18.0             |
| `libxfce4util-1.0`       | 4.17.2   | **4.16.0**          | 4.18.1             |
| `libxfce4ui-2`           | 4.17.6   | **4.16.1**          | 4.18.4             |
| `libxfce4kbd-private-3`  | 4.17.2   | **4.16.1**          | 4.18.4             |
| `libxfconf-0`            | 4.12.0   | 4.16.0 ✓            | 4.18.1 ✓           |
| `glib-2.0` / `gio-2.0`   | 2.66.0   | 2.72 ✓              | 2.80 ✓             |
| `gtk+-3.0`               | 3.24.0   | 3.24.33 ✓           | 3.24.41 ✓          |
| `gdk-pixbuf-2.0`         | 2.40.0   | 2.42 ✓              | 2.42 ✓             |
| `pango`                  | 1.38.0   | 1.50 ✓              | 1.52 ✓             |

Xubuntu 22.04 is an **Xfce 4.16** release: GTK, GLib and friends are new
enough, but all four Xfce core libraries are two feature releases short.
Jammy's own Thunar is 4.16.10.

## 3. Three ways to resolve it, and why one was chosen

**a. A backport archive — not available any more.** The route the 2022-era
guides describe, `ppa:xubuntu-dev/staging`, did carry Xfce 4.18 builds for
jammy (`4.18.x-...~bpo22.04`). It no longer does: the PPA's jammy
`Packages.gz` is now empty and its own description says it publishes for noble
and oracular only. Xubuntu has never offered a *stable* PPA for desktop
version jumps. So there is nothing to `add-apt-repository`.

**b. Patch Thunar 4.16 instead — not possible.** Recursive search is a
Thunar **4.18** feature. 4.16.10 has no `SEARCH_PREFIX`, no
`thunar_window_update_search()`, no search mode in `ThunarStandardView` and no
`misc-recursive-search` preference. The patch in this fork — 137 lines
in `thunar-window.c` plus the preference — is a *trigger* for machinery that
simply is not there in 4.16; porting it would mean
writing the whole search feature, which is a different project.

**c. Build the four libraries into a private prefix — what the scripts do.**
`libxfce4util` 4.18.2, `libxfce4ui` 4.18.6 (which also provides
`libxfce4kbd-private-3`) and `exo` 4.18.0 are built from the official tarballs
into **`/opt/xfce418`**, and only the Thunar fork is linked against them.
(Those are the newest 4.18 point releases upstream published — slightly newer
than what 24.04 itself carries, which is fine: Thunar's floor is 4.17.x.)

Why a private prefix and not `/usr/local/lib`: the sonames do not change
between 4.16 and 4.18 (`libexo-2.so.0`, `libxfce4ui-2.so.0`, …). Installing
them where `ldconfig` looks would silently re-point the *entire* running Xfce
4.16 desktop — panel, session manager, settings dialogs — at 4.18 libraries it
was never built against. Keeping them in `/opt/xfce418` and baking
`-Wl,-rpath,/opt/xfce418/lib` into the Thunar binary confines the change to
the one process that wants it. Within that process the loader resolves each
soname once, so the plugins Thunar loads bind to the same 4.18 copies rather
than pulling in a second version.

There is also the obvious fourth option: **upgrade the machine to 24.04**,
where Xfce 4.18 is native and only step 3 below is needed. If that upgrade is
on the cards anyway it is the lower-maintenance answer — 22.04's standard
support ends in April 2027.

## 4. Why the target needs no autotools

The fork is transferred as a **release-style source distribution** made with
`make dist` on the build machine, not as a git clone. That tarball already
contains `configure` and every generated source — `thunar-marshal.c`,
`thunar-resources.c`, the GDBus proxies for the thumbnailer and the two D-Bus
service interfaces — so the target builds with plain `./configure && make`.

This matters here: jammy's `xfce4-dev-tools` is 4.16, and `xdt-autogen` from
it is not something to rely on for a 4.18 tree. Shipping the dist tarball
sidesteps `xdt-autogen`, `gtk-doc` and `--enable-maintainer-mode` altogether —
the same reason distributions build from tarballs rather than from git.

## 5. The procedure

On this machine:

```bash
scripts/make-transfer-bundle.sh
# -> dist/thunar-typeahead-transfer-<date>.tar.gz
```

The bundle holds the patched source distribution, the three Xfce 4.18 library
tarballs, the two target-side scripts, the patches and these docs, with a
`SHA256SUMS` manifest and an `INSTALL.md`. Copy it across by any means —
`scp`, a USB stick, a file share:

```bash
scp dist/thunar-typeahead-transfer-<date>.tar.gz other-machine:
```

On the target:

```bash
tar xzf thunar-typeahead-transfer-<date>.tar.gz
cd thunar-typeahead-transfer-<date>
sha256sum -c SHA256SUMS                               # check the transfer

sudo scripts/target-install-xfce418-deps.sh           # Xfce 4.16 only
sudo DEPS_PREFIX=/opt/xfce418 scripts/target-install.sh

thunar -q; hash -r; thunar &
```

On an Xfce 4.18-or-newer target, skip the deps script and run
`sudo scripts/target-install.sh` with no `DEPS_PREFIX`; it refuses to proceed
if any of the four core libraries is too old, naming the one at fault.

Both scripts stop with the exact `apt install` line when a compiler or header
is missing, rather than failing part way through a build.

## 6. What the target-side install does and does not touch

* Installs into `/usr/local`, which precedes `/usr/bin` in `PATH` and
  `/usr/share` in `XDG_DATA_DIRS`, so the shell, the panel, the desktop and
  D-Bus activation all reach the fork.
* Leaves the distribution's `thunar` package installed and untouched; apt
  keeps updating it harmlessly underneath.
* Keeps the build tree at `/usr/local/src/thunar-typeahead` so that
  `sudo make -C /usr/local/src/thunar-typeahead uninstall` still works later.
* Symlinks the third-party thunarx plugins from the distribution's plugin
  directory (`thunar-archive-plugin`, `thunar-media-tags-plugin`, and anything
  else found there such as `thunar-vcs-plugin`) into `/usr/local/lib/thunarx-3`,
  skipping Thunar's own four, which the fork installs itself. Without this the
  fork would start with no *Extract Here* / *Create Archive* entries, because
  it does not search `/usr/lib/.../thunarx-3`.

## 7. What was verified before writing this, and what was not

Verified on this machine (Ubuntu 24.04), 2026-11-10:

* `target-install-xfce418-deps.sh` builds all three libraries from the bundled
  tarballs into a private prefix and `pkg-config` then reports
  libxfce4util 4.18.2, libxfce4ui 4.18.6, libxfce4kbd-private-3 4.18.6 and
  exo 4.18.0 — every Thunar 4.18 minimum cleared.
* The `make dist` tarball configures and builds with **no** autotools,
  xdt-autogen, gtk-doc or maintainer mode involved, and the resulting binary
  reports `thunar 4.18.11 (Xfce 4.18)`.
* The isolation works as intended: the binary carries
  `RUNPATH=<prefix>/lib`, and `ldd` resolves `libexo-2.so.0`,
  `libxfce4ui-2.so.0`, `libxfce4kbd-private-3.so.0` and `libxfce4util.so.7`
  from the private prefix while every other library still comes from the
  system.
* The version gate in `target-install.sh` was tested against a stand-in
  `exo-2.pc` declaring 4.16.3: it stops with
  `error: exo-2 is 4.16.3, Thunar 4.18 needs >= 4.17.0` and points at the deps
  script, rather than failing somewhere inside the build.

Not verified: **nothing has been built on 22.04 itself.** The builds above used
24.04's GTK 3.24.41 and GLib 2.80, not jammy's 3.24.33 and 2.72. Both clear
Thunar's declared minimums (3.24.0 / 2.66.0) and Thunar 4.18 was contemporary
with those versions, so this is expected to compile — but "expected" is the
accurate word.

## 8. Risks to watch on the Xfce 4.16 target

The specific things to watch:

* **Plugin ABI.** The distribution's plugins were built against thunarx-3 from
  Thunar 4.16. `thunarx-3` only gained API between 4.16 and 4.18, so they
  should load, but if one misbehaves, delete its symlink from
  `/usr/local/lib/thunarx-3` and restart — the fork works without it.
* **Settings written by the newer Thunar.** 4.18 adds keys to the `thunar`
  xfconf channel. Switching back to 4.16 later leaves those keys present and
  ignored; harmless, but `xfconf-query -c thunar -lv` is where to look if
  4.16 behaves oddly afterwards.
* **Two Thunars, one session.** Only one process can own
  `org.xfce.FileManager`. After installing, `thunar -q` must be run so the old
  4.16 daemon exits and the fork takes the name; otherwise folder-open requests
  keep going to the distribution's binary and nothing seems to have changed.
  `pgrep -af 'thunar --daemon'` shows which one is serving.
* **The library tarball checksums** recorded in
  `scripts/target-install-xfce418-deps.sh` were taken from the files as
  downloaded from `archive.xfce.org` on 2026-11-10. Upstream publishes no
  signatures or `.sha256` files alongside them, so these verify the *transfer*,
  not the provenance.
