#!/usr/bin/env bash
# Install everything needed to build the Thunar fork on Ubuntu 24.04 (Xfce 4.18).
# Needs root: run it as   sudo scripts/install-build-deps.sh
set -euo pipefail

PKGS=(
  # toolchain + autotools (Thunar 4.18 is autotools-based)
  build-essential autoconf automake libtool pkg-config m4
  intltool gettext xfce4-dev-tools gtk-doc-tools
  # core GLib/GTK stack
  libglib2.0-dev libgtk-3-dev libpango1.0-dev
  # Xfce libraries
  libexo-2-dev libxfce4ui-2-dev libxfce4util-dev libxfconf-0-dev
  # optional but enabled by default
  libgudev-1.0-dev libnotify-dev libxfce4panel-2.0-dev
  libice-dev libsm-dev libstartup-notification0-dev
)

if [ "$(id -u)" -ne 0 ]; then
  echo "This script installs system packages; re-run it with sudo:" >&2
  echo "  sudo $0" >&2
  exit 1
fi

apt-get update
apt-get install -y --no-install-recommends "${PKGS[@]}"

echo
echo "Build dependencies installed."
