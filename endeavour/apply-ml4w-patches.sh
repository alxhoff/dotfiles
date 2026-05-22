#!/usr/bin/env bash
# Apply dotfiles overrides on top of ML4W Hyprland Starter (Hyprland 0.55+, waybar).
set -euo pipefail

DOTFILES_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
PATCHES="$DOTFILES_DIR/endeavour/ml4w-patches"
ML4W_CFG="${HOME}/.mydotfiles/com.ml4w.hyprlandstarter/.config"

log() { echo "==> $*"; }

[[ -d "$ML4W_CFG/hypr" ]] || {
    echo "ML4W not installed. Run: $DOTFILES_DIR/endeavour/install-ml4w-starter.sh" >&2
    exit 1
}

for f in layouts.conf gestures.conf autostart.conf; do
    cp "$PATCHES/hypr/conf/$f" "$ML4W_CFG/hypr/conf/$f"
    log "hypr/conf/$f"
done

BINDS="$ML4W_CFG/hypr/conf/binds.conf"
if [[ -f "$BINDS" ]] && grep -qE 'bind = \$mainMod, J, togglesplit' "$BINDS"; then
    sed -i 's/bind = $mainMod, J, togglesplit,/bind = $mainMod, J, layoutmsg, togglesplit # Hyprland 0.55+/' "$BINDS"
    log "hypr/conf/binds.conf (togglesplit → layoutmsg)"
fi

MODULES="$ML4W_CFG/waybar/modules.json"
WS_SNIP="$PATCHES/waybar/hyprland-workspaces.jsonc"
if [[ -f "$MODULES" && -f "$WS_SNIP" ]]; then
    python3 <<PY
import re
from pathlib import Path
modules = Path("$MODULES")
snip = Path("$WS_SNIP").read_text().strip()
text = modules.read_text()
pat = r'[ \t]*"hyprland/workspaces"\s*:\s*\{.*?\n[ \t]*\},'
new, n = re.subn(pat, snip, text, count=1, flags=re.DOTALL)
if n != 1:
    raise SystemExit("could not replace hyprland/workspaces block in modules.json")
modules.write_text(new)
PY
    log "waybar/modules.json (workspaces 1–4 only)"
fi

WIN_SNIP="$PATCHES/waybar/hyprland-window.jsonc"
if [[ -f "$MODULES" && -f "$WIN_SNIP" ]]; then
    python3 <<PY
import re
from pathlib import Path
modules = Path("$MODULES")
snip = Path("$WIN_SNIP").read_text().strip()
text = modules.read_text()
pat = r'[ \t]*"hyprland/window"\s*:\s*\{.*?\n[ \t]*\},'
new, n = re.subn(pat, snip, text, count=1, flags=re.DOTALL)
if n == 1:
    modules.write_text(new)
PY
    log "waybar/modules.json (window title text)"
fi

STYLE="$ML4W_CFG/waybar/style.css"
OVERRIDES="$PATCHES/waybar/style-overrides.css"
MARKER="dotfiles waybar overrides"
if [[ -f "$STYLE" ]]; then
    if [[ -f "$PATCHES/waybar/style.css.font-family" ]]; then
        FONT_LINE=$(cat "$PATCHES/waybar/style.css.font-family")
        sed -i "0,/font-family:/{s|^[[:space:]]*font-family:.*|${FONT_LINE}|}" "$STYLE"
    fi
    if [[ -f "$OVERRIDES" ]]; then
        if grep -q "$MARKER" "$STYLE"; then
            sed -i "/$MARKER/,\$d" "$STYLE"
        fi
        cat "$OVERRIDES" >>"$STYLE"
        log "waybar/style.css (text vs icon fonts)"
    fi
fi

if command -v Hyprland >/dev/null 2>&1; then
    if Hyprland --verify-config -c "${HOME}/.config/hypr/hyprland.conf" 2>&1 | grep -q 'config ok'; then
        log "Hyprland config verify: OK"
    else
        Hyprland --verify-config -c "${HOME}/.config/hypr/hyprland.conf" 2>&1 | tail -8 || true
    fi
fi

log "Done."
