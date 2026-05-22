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

DISPLAYS="$DOTFILES_DIR/endeavour/displays"
if [[ -f "$DISPLAYS/monitors.conf.default" ]] && [[ ! -f "${HOME}/.config/hypr/monitors.conf" ]]; then
    install -m644 "$DISPLAYS/monitors.conf.default" "${HOME}/.config/hypr/monitors.conf"
    log "hypr/monitors.conf (safe default)"
fi
for s in "$DISPLAYS"/*.sh; do
    [[ -f "$s" ]] || continue
    chmod +x "$s"
done
log "displays/*.sh (executable)"

for f in layouts.conf gestures.conf autostart.conf monitor.conf binds-dotfiles.conf; do
    [[ -f "$PATCHES/hypr/conf/$f" ]] || continue
    cp "$PATCHES/hypr/conf/$f" "$ML4W_CFG/hypr/conf/$f"
    log "hypr/conf/$f"
done

mkdir -p "${HOME}/.config/ml4w/settings" "${HOME}/.config/ml4w/scripts"
for s in "$PATCHES/ml4w/settings/"*.sh; do
    [[ -f "$s" ]] || continue
    install -m755 "$s" "${HOME}/.config/ml4w/settings/$(basename "$s")"
    log "ml4w/settings/$(basename "$s")"
done
for s in "$PATCHES/ml4w/scripts/"*.sh; do
    [[ -f "$s" ]] || continue
    install -m755 "$s" "${HOME}/.config/ml4w/scripts/$(basename "$s")"
    log "ml4w/scripts/$(basename "$s")"
done

HYPR_MAIN="$ML4W_CFG/hypr/hyprland.conf"
if [[ -f "$HYPR_MAIN" ]] && ! grep -q 'binds-dotfiles.conf' "$HYPR_MAIN"; then
    echo 'source = ~/.config/hypr/conf/binds-dotfiles.conf' >>"$HYPR_MAIN"
    log "hyprland.conf (source binds-dotfiles.conf)"
fi

BINDS="$ML4W_CFG/hypr/conf/binds.conf"
if [[ -f "$BINDS" ]] && grep -qE 'bind = \$mainMod, J, togglesplit' "$BINDS"; then
    sed -i 's/bind = $mainMod, J, togglesplit,/bind = $mainMod, J, layoutmsg, togglesplit # Hyprland 0.55+/' "$BINDS"
    log "hypr/conf/binds.conf (togglesplit → layoutmsg)"
fi

mkdir -p "${HOME}/.config/waybar"
if [[ -f "$PATCHES/waybar/network_menu.xml" ]]; then
    install -m644 "$PATCHES/waybar/network_menu.xml" "${HOME}/.config/waybar/network_menu.xml"
    log "waybar/network_menu.xml"
fi

MODULES="$ML4W_CFG/waybar/modules.json"
if [[ -f "$MODULES" ]]; then
    MODULES="$MODULES" PATCHES="$PATCHES" python3 <<'PY'
import os
import re
import sys
from pathlib import Path

modules = Path(os.environ["MODULES"])
patches = Path(os.environ["PATCHES"]) / "waybar"

def replace_block(text: str, key: str, snippet: str) -> tuple[str, bool]:
    m = re.search(rf'[ \t]*"{re.escape(key)}"\s*:\s*\{{', text)
    if not m:
        return text, False
    start = m.start()
    i = m.end() - 1
    depth = 0
    for j in range(i, len(text)):
        c = text[j]
        if c == '{':
            depth += 1
        elif c == '}':
            depth -= 1
            if depth == 0:
                end = j + 1
                had_comma = end < len(text) and text[end] == ','
                if had_comma:
                    end += 1
                replacement = snippet.strip()
                if had_comma and not replacement.endswith(','):
                    replacement += ','
                return text[:start] + replacement + text[end:], True
    return text, False

text = modules.read_text()
# Remove orphan lines left by old broken patches
text = re.sub(
    r'\n[ \t]*"separate-outputs": true\n[ \t]*\},\n(?=[ \t]*"separate-outputs")',
    '\n',
    text,
)

for name, file in (
    ("hyprland/workspaces", "hyprland-workspaces.jsonc"),
    ("hyprland/window", "hyprland-window.jsonc"),
    ("network", "network.jsonc"),
    ("custom/exit", "custom-exit.jsonc"),
):
    snip_path = patches / file
    if not snip_path.exists():
        continue
    snip = snip_path.read_text().strip()
    text, ok = replace_block(text, name, snip)
    if not ok:
        print(f"warning: could not patch {name}", file=sys.stderr)

modules.write_text(text)
PY
    if ! [[ "$MODULES" -ef "${HOME}/.config/waybar/modules.json" ]]; then
        install -m644 "$MODULES" "${HOME}/.config/waybar/modules.json"
    fi
    log "waybar/modules.json (workspaces + window + network)"
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
