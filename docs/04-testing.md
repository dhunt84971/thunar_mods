# Verification

Run on 2026-11-10, Ubuntu 24.04.4, Xfce 4.18, X11, against the build produced by
`scripts/build.sh` (`thunar 4.18.11 (Xfce 4.18)`).

## Build

* `xdt-autogen` + `configure --enable-maintainer-mode` + `make -j` completes
  with **exit status 0**.
* **Zero compiler warnings** are produced for the three changed files
  (`thunar-window.c`, `thunar-preferences.c`, `thunar-preferences-dialog.c`);
  the whole build emits one warning, in untouched upstream code.
* `git status` in `thunar/` stays clean after a full build — the generated
  sources land in paths upstream already ignores.

## How the run was isolated

The desktop's own `Thunar --daemon` (the Ubuntu 4.18.8 build) was left running
and untouched. Because Thunar is a D-Bus service, simply launching a second
binary hands the request to that daemon, so the fork was started on a private
session bus and a private config home:

```
XDG_CONFIG_HOME=<tmp>/cfg dbus-run-session -- build/thunar/thunar <tmp>/testtree
```

Keystrokes were injected with `xdotool` (real XTEST input, not synthetic
events) and each result captured with `import`.

Test tree:

```
testtree/alpha.txt
testtree/zeta.txt
testtree/other/delta-needle.txt
testtree/sub1/bravo-needle.txt
testtree/sub1/unrelated.doc
testtree/sub1/sub2/charlie-needle.txt
```

## Results

| # | Test | Expected | Result | Evidence |
| --- | --- | --- | --- | --- |
| 1 | Type `needle` with the file view focused | search starts, matches from subfolders listed | location bar shows `Search: needle`, search toolbar button pressed, 3 matches listed — `bravo-needle.txt` (sub1), `charlie-needle.txt` (sub1/sub2), `delta-needle.txt` (other); `unrelated.doc` excluded | `screenshots/01-type-ahead-search.png` |
| 2 | `Escape` | search cancelled, folder listing back | folder contents restored **and** the icon view restored (the search had switched to the detailed view) | `screenshots/02-escape-cancels.png` |
| 3 | `Space` | no search | nothing happens, listing unchanged | `screenshots/03-space-ignored.png` |
| 4 | `/` | location bar opens, as upstream | path entry opens containing `/` | `screenshots/04-slash-location-bar.png` |
| 5 | Type `needle` with the **side pane** focused | search starts (Nautilus parity) | same search as test 1 | `screenshots/05-side-pane-focus.png` |
| 6 | With a search running, click into the result view, type `.tx` | the characters extend the running query | query becomes `needle.tx`, focus returns to the search entry, the 3 `.txt` matches stay | `screenshots/06-append-to-query.png` |
| 7 | Select a file, `F2`, type `zz` | the rename dialog gets the text, no search | rename dialog shows `zz.txt` | `screenshots/07-rename-dialog.png` |
| 8 | `Ctrl+L` | location bar opens with the full path | path entry opens with the folder path | `screenshots/08-ctrl-l.png` |
| 9 | *Preferences → Advanced → Search* | a **Search as you type** check box above *Include subfolders*, checked | present and checked | `screenshots/09-preference.png` |
| 10 | Uncheck it, type `zet` | upstream behaviour returns | `/misc-type-ahead-search` written as `false`; typing opens the GTK interactive-search popup and selects `zeta.txt` in the current folder — no search mode | `screenshots/10-preference-off-interactive-search.png` |
| 11 | Re-enable, press `Ctrl+F`, type `bravo` | the explicit search still works | `Search: bravo`, one match with its *Location* column filled in | `screenshots/11-ctrl-f-still-works.png` |

## Not covered by automation

* **Single-key accelerators and custom-action (UCA) shortcuts.** Guarded in code
  — the accel group is queried with `gtk_accel_group_query()` before the key is
  consumed, and the UCA handler is connected first so it runs first — but not
  exercised with a configured plain-letter shortcut.
* **Input methods.** The handler reads the keyval through
  `gdk_keyval_to_unicode()`, so dead keys and IM pre-edit are not routed into the
  search entry; composing an accented character before any search is running
  types the base character. Upstream's `/` and `~` handling has the same shape.
* **Very large trees.** Search cost is upstream's, unchanged.
