#!/usr/bin/env bash
# Install Hyprland + kanshi and help set default login session (EndeavourOS).
#
# Usage: ./endeavour/setup-hyprland-default.sh
#   ./endeavour/setup-hyprland-default.sh --ml4w   # also install ML4W starter deps
#   DRY_RUN=1 ./endeavour/setup-hyprland-default.sh
#
_root=$(dirname "${BASH_SOURCE[0]:-$0}")
SCRIPT_DIR=$(cd "$_root" && pwd)
DOTFILES_DIR=$(cd "$SCRIPT_DIR/.." && pwd)

set -euo pipefail
DRY_RUN=${DRY_RUN:-0}
ML4W_DEPS=0
[[ "${1:-}" == "--ml4w" ]] && ML4W_DEPS=1

log() { echo "==> $*"; }
run() {
    if [[ "$DRY_RUN" == 1 ]]; then
        echo "  [dry-run] $*"
    else
        sudo "$@"
    fi
}

# hyprland-qtutils was renamed on Arch → hyprland-qt-support
WANTED_PKGS=(
    hyprland
    hyprland-qt-support
    hyprlock
    hyprpaper
    waybar
    wofi
    mako
    polkit-kde-agent
    xdg-desktop-portal-hyprland
    xdg-desktop-portal-gtk
    qt6-wayland
    kanshi
    socat
)

# What stock ML4W starter expects (kitty, dunst, rofi — not wofi/mako)
ML4W_EXTRA_PKGS=(
    kitty
    dunst
    rofi
    thunar
    brightnessctl
    wireplumber
    xdotool
    networkmanager
    otf-font-awesome
    ttf-fira-sans
)

resolve_packages() {
    local p
    RESOLVED_PKGS=()
    MISSING_PKGS=()
    for p in "${WANTED_PKGS[@]}"; do
        if pacman -Si "$p" &>/dev/null; then
            RESOLVED_PKGS+=("$p")
        else
            MISSING_PKGS+=("$p")
            log "skip (not in repos): $p"
        fi
    done
    if ((${#RESOLVED_PKGS[@]} == 0)); then
        log "no packages found to install"
        exit 1
    fi
}

log "Installing Hyprland stack + kanshi"
resolve_packages
log "packages: ${RESOLVED_PKGS[*]}"
run pacman -S --needed --noconfirm "${RESOLVED_PKGS[@]}"

if [[ "$ML4W_DEPS" == 1 ]]; then
    log "Installing ML4W starter dependencies (kitty, dunst, rofi, …)"
    RESOLVED_PKGS=()
    MISSING_PKGS=()
    for p in "${ML4W_EXTRA_PKGS[@]}"; do
        if pacman -Si "$p" &>/dev/null; then
            RESOLVED_PKGS+=("$p")
        else
            MISSING_PKGS+=("$p")
            log "skip (not in repos): $p"
        fi
    done
    if ((${#RESOLVED_PKGS[@]} > 0)); then
        run pacman -S --needed --noconfirm "${RESOLVED_PKGS[@]}"
    fi
    if [[ "$DRY_RUN" != 1 ]]; then
        "$DOTFILES_DIR/endeavour/apply-ml4w-patches.sh" 2>/dev/null || \
            "$DOTFILES_DIR/endeavour/fix-ml4w-autostart.sh" || true
    fi
fi

if [[ "$DRY_RUN" != 1 ]]; then
    if [[ -f /usr/share/wayland-sessions/hyprland.desktop ]]; then
        log "Hyprland session: /usr/share/wayland-sessions/hyprland.desktop"
    else
        log "WARNING: hyprland.desktop not found after install"
    fi
fi

# Kanshi user config symlink
mkdir -p "$HOME/.config/kanshi"
if [[ -f "$DOTFILES_DIR/endeavour/displays/kanshi.config" ]]; then
    if [[ "$DRY_RUN" == 1 ]]; then
        echo "  [dry-run] ln -sf kanshi.config -> ~/.config/kanshi/config"
    else
        ln -sf "$DOTFILES_DIR/endeavour/displays/kanshi.config" "$HOME/.config/kanshi/config"
        log "kanshi: no systemd unit on Arch — add to hypr autostart: exec-once = kanshi"
    fi
fi

# Hypr hook script for kanshi exec=
mkdir -p "$HOME/.config/hypr/scripts"
if [[ "$DRY_RUN" != 1 ]]; then
    ln -sf "$DOTFILES_DIR/endeavour/displays/dotfiles-display-hook.sh" \
        "$HOME/.config/hypr/scripts/dotfiles-display-hook.sh"
fi

DM=$(systemctl show -p Id display-manager --value 2>/dev/null || true)
log "Display manager: ${DM:-unknown}"

cat <<EOF

=== Default session (Hyprland) ===

Your display manager is: $DM

1) Log out to the login screen.
2) Choose session Hyprland (not Plasma).
3) Enable Default / remember session if offered.

plasmalogin (KDE): session is usually remembered per-user after first Hyprland login.
SDDM (ML4W): edit /etc/sddm.conf - [Autologin] Session=hyprland (optional).

=== Monitor auto-setup ===

1) Log into Hyprland once.
2) At home dock:  cd $DOTFILES_DIR/endeavour/displays && ./discover-monitors.sh | tee ~/monitor-discovery-home.txt
3) At work dock:   ./discover-monitors.sh | tee ~/monitor-discovery-work.txt
4) Edit profiles/*.hypr and kanshi.config with real monitor names.
5) Merge into ~/.config/hypr/conf/autostart.conf:

   exec-once = $DOTFILES_DIR/endeavour/displays/hypr-display-listener.sh

   Or use kanshi only (exec-once = kanshi in autostart.conf).

6) Test: ./apply-display-profile.sh auto

See docs/HYPRLAND-DISPLAYS.md

EOF
