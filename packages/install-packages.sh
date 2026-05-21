#!/usr/bin/env bash
# Install packages chosen in packages/selected/*.list (EndeavourOS / Arch).
#
# Usage:
#   ./packages/install-packages.sh
#   DRY_RUN=1 ./packages/install-packages.sh
#
# Prerequisites on new system: network, sudo, base-devel (for AUR).
# Installs yay if missing when AUR packages are selected.
#
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
SEL="$SCRIPT_DIR/selected"
DRY_RUN=${DRY_RUN:-0}

log() { echo "==> $*"; }
run() {
    if [[ "$DRY_RUN" == 1 ]]; then
        echo "  [dry-run] $*"
    else
        "$@"
    fi
}

read_list() {
    local file=$1
    [[ -f "$file" ]] || return 0
    grep -v '^#' "$file" | grep -v '^[[:space:]]*$' || true
}

install_pacman() {
    local -a pkgs=()
    mapfile -t pkgs < <(read_list "$SEL/pacman.list")
    ((${#pkgs[@]})) || return 0
    log "pacman: ${#pkgs[@]} packages"
    run sudo pacman -S --needed --noconfirm "${pkgs[@]}"
}

ensure_yay() {
    command -v yay >/dev/null && return 0
    log "yay not found — installing from AUR (base-devel required)"
    local tmp
    tmp=$(mktemp -d)
    if [[ "$DRY_RUN" == 1 ]]; then
        echo "  [dry-run] git clone + makepkg yay"
        return 0
    fi
    git clone https://aur.archlinux.org/yay.git "$tmp/yay"
    (cd "$tmp/yay" && makepkg -si --noconfirm)
    rm -rf "$tmp"
}

install_aur() {
    local -a pkgs=()
    mapfile -t pkgs < <(read_list "$SEL/aur.list")
    ((${#pkgs[@]})) || return 0
    ensure_yay
    log "AUR (yay): ${#pkgs[@]} packages"
    # Filter Manjaro-only meta packages if they slipped in
    local -a filtered=()
    local p
    for p in "${pkgs[@]}"; do
        [[ "$p" =~ ^manjaro- ]] && { log "  skip manjaro-specific: $p"; continue; }
        [[ "$p" =~ ^pamac ]] && { log "  skip pamac: $p"; continue; }
        [[ "$p" =~ ^mhwd ]] && { log "  skip mhwd: $p"; continue; }
        filtered+=("$p")
    done
    ((${#filtered[@]})) || return 0
    run yay -S --needed --noconfirm "${filtered[@]}"
}

install_flatpak() {
    command -v flatpak >/dev/null || { log "flatpak not installed — skip (pacman -S flatpak)"; return 0; }
    local -a apps=() runtimes=()
    mapfile -t apps < <(read_list "$SEL/flatpak-apps.list")
    mapfile -t runtimes < <(read_list "$SEL/flatpak-runtimes.list")
    if ((${#runtimes[@]})); then
        log "flatpak runtimes: ${#runtimes[@]}"
        run flatpak install -y "${runtimes[@]}"
    fi
    if ((${#apps[@]})); then
        log "flatpak apps: ${#apps[@]}"
        run flatpak install -y "${apps[@]}"
    fi
}

install_pip() {
    local -a pkgs=()
    mapfile -t pkgs < <(read_list "$SEL/pip-user.list")
    ((${#pkgs[@]})) || return 0
    command -v pip >/dev/null || { log "pip missing — skip"; return 0; }
    log "pip --user: ${#pkgs[@]} packages"
    run pip install --user "${pkgs[@]}"
}

install_npm() {
    local -a pkgs=()
    mapfile -t pkgs < <(read_list "$SEL/npm-global.list")
    ((${#pkgs[@]})) || return 0
    command -v npm >/dev/null || { log "npm missing — skip"; return 0; }
    log "npm global: ${#pkgs[@]} packages"
    run sudo npm install -g "${pkgs[@]}"
}

# EndeavourOS / Arch bootstrap helpers
if [[ "$DRY_RUN" != 1 ]]; then
    if ! command -v pacman >/dev/null; then
        echo "pacman not found — this script targets Arch/EndeavourOS." >&2
        exit 1
    fi
fi

log "Reading selections from $SEL/"
install_pacman
install_aur
install_flatpak
install_pip
install_npm

log "Done. Run ./install.sh for dotfile symlinks."
