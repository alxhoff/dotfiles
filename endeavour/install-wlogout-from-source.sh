#!/usr/bin/env bash
# Build wlogout from upstream release (skips AUR PGP key import when keyservers fail).
set -euo pipefail

VER=1.2.2
WORKDIR=$(mktemp -d)
trap 'rm -rf "$WORKDIR"' EXIT

log() { echo "==> $*"; }

log "Installing build deps"
sudo pacman -S --needed --noconfirm meson ninja scdoc gtk3 gobject-introspection gtk-layer-shell

cd "$WORKDIR"
log "Downloading wlogout $VER"
curl -fsSL -o wlogout.tar.gz "https://github.com/ArtsyMacaw/wlogout/releases/download/${VER}/wlogout.tar.gz"

log "Building"
tar xf wlogout.tar.gz
# Release tarball has meson files at top level (no wlogout/ subdir)
[[ -f meson.build ]] || { echo "meson.build not found after extract" >&2; exit 1; }

rm -rf build /tmp/wlogout-install
meson setup build --prefix /usr
ninja -C build
sudo DESTDIR=/tmp/wlogout-install ninja -C build install
sudo cp -a /tmp/wlogout-install/usr/* /usr/
sudo install -Dm644 LICENSE /usr/share/licenses/wlogout/LICENSE

log "Installed: $(command -v wlogout)"
wlogout -h 2>&1 | head -2 || true
