# Installing the Thunar type-ahead fork — step by step

This bundle builds **Thunar @VERSION@** — upstream 4.18.11 plus one patch that
starts a recursive search as soon as you type in a Thunar window, the way
Nautilus does.

Written for **Xubuntu 22.04.4**, which runs Xfce 4.16 and therefore needs the
extra library step (step 4). On Xfce 4.18 or newer, skip step 4.

Everything needed is inside the bundle. No internet is required except to
install the distribution's own development packages in step 3.

Rough timings on a modern desktop: step 4 about 2–4 minutes, step 5 about
3–6 minutes. Nothing here logs you out or restarts your session.

---

## Step 1 — Check what the machine is running

```bash
thunar --version | head -1
xfce4-about --version | head -2
lsb_release -d
```

Expect `Thunar 4.16.x` and Xfce 4.16 on Xubuntu 22.04.4. Then confirm which
route applies:

```bash
pkg-config --modversion exo-2 libxfce4util-1.0 libxfce4ui-2
```

* Anything **4.16.x** → Xfce 4.16, do every step below.
* All **4.18.0 or newer** → skip step 4, and leave `DEPS_PREFIX` off in step 5.
* `pkg-config: command not found` → it arrives with step 3; re-run this after.

## Step 2 — Copy the bundle across and check it survived the trip

On the machine that built it:

```bash
scp dist/thunar-typeahead-transfer-*.tar.gz user@other-box:
```

A USB stick or a file share is equally fine. Then on the 22.04 machine:

```bash
tar xzf thunar-typeahead-transfer-*.tar.gz
cd thunar-typeahead-transfer-*/
sha256sum -c SHA256SUMS
```

Every line must say `OK`. If any says `FAILED`, the copy is corrupt — do not
build it, copy it again.

## Step 3 — Install the build prerequisites

```bash
sudo apt update
sudo apt install build-essential pkg-config gettext intltool \
  libglib2.0-dev libgtk-3-dev libxfconf-0-dev libpango1.0-dev \
  libgdk-pixbuf-2.0-dev libgtop2-dev libepoxy-dev \
  libstartup-notification0-dev libgudev-1.0-dev libnotify-dev \
  libice-dev libsm-dev
```

That one line covers both of the builds below. Nothing here is a compiler
toolchain you have to maintain afterwards; it can all be removed again once the
build is done.

Note what is **not** in the list: no `autoconf`, `automake`, `libtool`,
`xfce4-dev-tools` or `gtk-doc-tools`. The Thunar tarball in this bundle is a
release-style source distribution — `configure` and every generated source are
already in it — so the old toolchain on 22.04 is never invoked.

Both scripts below re-check this list before they do anything and stop with the
exact `apt install` line if something is missing.

## Step 4 — Build the Xfce 4.18 core libraries (Xfce 4.16 systems only)

Thunar 4.18 requires `exo` ≥ 4.17.0, `libxfce4util` ≥ 4.17.2 and
`libxfce4ui` ≥ 4.17.6. Xubuntu 22.04 ships 4.16.3, 4.16.0 and 4.16.1, and the
old `ppa:xubuntu-dev/staging` backports for jammy no longer exist, so these
three are built from the official tarballs in `vendor/`:

```bash
sudo scripts/target-install-xfce418-deps.sh
```

They install into **`/opt/xfce418`** — deliberately outside anywhere
`ldconfig` searches. Only the Thunar fork is linked against them, through an
RPATH baked into its binary in step 5. Your Xfce 4.16 panel, session manager
and settings dialogs keep using the distribution's own libraries, untouched.

It ends by printing the four versions it installed:

```
  libxfce4util-1.0         4.18.2
  libxfce4ui-2             4.18.6
  libxfce4kbd-private-3    4.18.6
  exo-2                    4.18.0
```

If you would rather not build as root, this works too — only step 5 needs
root:

```bash
PREFIX=$HOME/xfce418 scripts/target-install-xfce418-deps.sh
```

(then pass that same path as `DEPS_PREFIX` in step 5).

## Step 5 — Build and install the fork

```bash
sudo DEPS_PREFIX=/opt/xfce418 scripts/target-install.sh
```

On an Xfce 4.18-or-newer machine, drop the `DEPS_PREFIX=...` part.

First it prints the four core libraries and their versions, then configures,
builds and installs into **`/usr/local`**. It refuses to start if any library
is too old, naming the one at fault — it will not fail halfway through a
compile.

What it does:

* installs into `/usr/local`, which comes before `/usr/bin` in `PATH` and
  before `/usr/share` in `XDG_DATA_DIRS`, so the shell, the panel, the desktop
  and D-Bus activation all reach the fork;
* leaves the distribution's `thunar` package installed and untouched — apt
  keeps updating it harmlessly underneath;
* symlinks the third-party thunarx plugins the distribution installed
  (`thunar-archive-plugin`, `thunar-media-tags-plugin`, and anything else such
  as `thunar-vcs-plugin`) into the fork's plugin directory, skipping Thunar's
  own four, which the fork installs itself. Without this you would lose
  *Extract Here* and *Create Archive* from the context menu;
* keeps the build tree at `/usr/local/src/thunar-typeahead`, so uninstalling
  later still works.

## Step 6 — Hand the session over to the new binary

A running Thunar daemon owns the D-Bus name `org.xfce.FileManager`, and it will
keep answering every folder-open request until it exits. **Without this step
nothing appears to have changed.**

```bash
thunar -q          # ask the old daemon to quit
hash -r            # forget the cached /usr/bin/thunar path in this shell
thunar &           # start the fork
```

## Step 7 — Confirm the fork is the one running

```bash
which thunar                        # /usr/local/bin/thunar
thunar --version | head -1          # thunar 4.18.11 (Xfce 4.18)
pgrep -af 'thunar'                  # the live process, with its path
```

If `which` still says `/usr/bin/thunar`, your shell cached the old path —
`hash -r`, or open a new terminal.

## Step 8 — Try the feature

Open a folder that has subfolders with files in them, click once in the file
area so no text entry has focus, and type a few letters of a filename.

The location bar turns into `Search: <letters>` and matches appear as you
type, including matches from the subfolders, with a **Location** column showing
where each one lives. `Escape` cancels and returns to the folder.

Things that deliberately still work as before: `/` and `~` open the location
bar, `Space` toggles the selection, `F2` renames, and every existing keyboard
shortcut and custom action keeps its priority over the plain letters.

To turn the behaviour off without uninstalling anything:
**Edit → Preferences → Advanced → Search → "Search as you type"**.

## Step 9 — If something goes wrong

**A folder still opens in the old Thunar.** The old daemon is still alive:
`pgrep -af thunar` will show `/usr/bin/thunar --daemon`. Run `thunar -q` again.
At worst, log out and back in — D-Bus activation starts the `/usr/local` one.

**`error: exo-2 is 4.16.3, Thunar 4.18 needs >= 4.17.0`.** Step 4 was skipped,
or `DEPS_PREFIX` was not passed in step 5.

**A context-menu entry from a plugin has gone, or Thunar misbehaves after
install.** A distribution plugin built against Thunar 4.16 may not like 4.18.
Remove that one symlink and restart — the fork runs fine without it:

```bash
ls -l /usr/local/lib/thunarx-3/
sudo rm /usr/local/lib/thunarx-3/<plugin>.so
thunar -q; thunar &
```

**Thunar will not start at all** (for example a missing library). Fall back to
the distribution's binary immediately — it was never removed:

```bash
thunar -q
/usr/bin/thunar &
```

Then undo as below.

## Step 10 — Undoing it completely

```bash
sudo make -C /usr/local/src/thunar-typeahead uninstall
sudo rm -rf /opt/xfce418                 # only if step 4 was used
sudo ldconfig
thunar -q; hash -r; thunar &             # back to the distribution's 4.16
```

The distribution's Thunar was never modified, so this is a full revert. One
trace is left behind deliberately: Thunar 4.18 may have written extra keys into
the `thunar` xfconf channel, which 4.16 ignores. `xfconf-query -c thunar -lv`
lists them if you ever want to check.

---

`docs/05-porting-to-another-system.md` explains why it is done this way, what
was verified before shipping it and what was not, and
`docs/02-feature-design.md` covers how the feature itself works.
