# Which Thunar version can this machine run?

## The machine

| | |
| --- | --- |
| OS | Ubuntu 24.04.4 LTS (noble) |
| Desktop stack | Xfce 4.18 |
| Thunar installed | 4.18.8-1build3 (`universe`) |
| GTK | 3.24.41 |
| GLib | 2.80.0 |
| exo | 4.18.0 |
| libxfce4ui | 4.18.4 |
| libxfce4util | 4.18.x |
| xfconf | 4.18.1 |

## Upstream releases available

`git ls-remote https://gitlab.xfce.org/xfce/thunar.git` (checked 2026-11-10) ends at
**4.20.10** on the stable series (2026-09-12) with **4.21.7** on the unstable
development series. Xfce uses even minor numbers for stable releases, odd ones
for development snapshots, so 4.21.x is not a candidate.

## Why not 4.20.x

Thunar's required dependency versions, read out of each tag's `configure.ac`:

| Thunar | requires exo | requires libxfce4ui |
| --- | --- | --- |
| 4.18.0 – 4.18.11 | **4.17.0** | 4.17.6 |
| 4.19.1 – 4.20.10 | **4.19.0** | 4.17.6 |
| 4.21.0 – 4.21.2 | (exo dropped) | **4.21.0** |

The bump landed in commit `c5d8bfa92` ("Bump min exo version to 4.19,0", required
by `0d6c6dbb`), so it is a real API requirement, not a courtesy bump.

This machine has **exo 4.18.0**, and 4.19.0 is not in the Ubuntu 24.04 archive —
exo is a core Xfce library shared by the panel, the desktop, the terminal and the
session manager, so pulling in 4.19 from source would mean replacing part of the
running desktop system-wide. The 4.21.x series needs libxfce4ui 4.21, which is
two Xfce cycles ahead of what is installed.

## Decision

Fork **`thunar-4.18.11`** — the last release of the 4.18 series (2024-07-30).
It is the newest Thunar that configures, builds and runs against the Xfce 4.18
libraries this OS ships, and it keeps `thunarx-3` plugin compatibility with the
distribution's Thunar plugins (`thunar-archive-plugin`,
`thunar-media-tags-plugin`, …).

It is also three patch releases newer than the 4.18.8 Ubuntu ships, so the fork
brings upstream's 4.18.9 – 4.18.11 fixes along with the new feature.
