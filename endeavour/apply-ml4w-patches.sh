#!/usr/bin/env bash
# Apply dotfiles overrides on top of ML4W Hyprland Starter (Hyprland 0.55+, waybar).
set -euo pipefail

DOTFILES_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
PATCHES="$DOTFILES_DIR/endeavour/ml4w-patches"
ML4W_CFG="${HOME}/.mydotfiles/com.ml4w.hyprlandstarter/.config"

log() { echo "==> $*"; }

# Replace @DOTFILES@ with the actual repo path (clone location may differ).
install_with_dotfiles() {
    local src=$1 dest=$2 mode=${3:-644}
    if grep -q '@DOTFILES@' "$src" 2>/dev/null; then
        sed "s|@DOTFILES@|$DOTFILES_DIR|g" "$src" >"$dest"
    else
        install -m"$mode" "$src" "$dest"
        return
    fi
    chmod "$mode" "$dest"
}

mkdir -p "${HOME}/.config"
printf '%s\n' "$DOTFILES_DIR" >"${HOME}/.config/dotfiles-path"
log "wrote ~/.config/dotfiles-path"

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

for f in layouts.conf gestures.conf autostart.conf monitor.conf binds.conf binds-dotfiles.conf windowrules-dotfiles.conf general-dotfiles.conf group-dotfiles.conf; do
    [[ -f "$PATCHES/hypr/conf/$f" ]] || continue
    install_with_dotfiles "$PATCHES/hypr/conf/$f" "$ML4W_CFG/hypr/conf/$f" 644
    log "hypr/conf/$f"
done
for f in hyprlock.conf hypridle.conf; do
    [[ -f "$PATCHES/hypr/conf/$f" ]] || continue
    install -m644 "$PATCHES/hypr/conf/$f" "$ML4W_CFG/hypr/$f"
    log "hypr/$f"
done
if [[ -f "$PATCHES/hypr/hyprpaper.conf" ]]; then
    install -m644 "$PATCHES/hypr/hyprpaper.conf" "$ML4W_CFG/hypr/hyprpaper.conf"
    log "hypr/hyprpaper.conf"
fi

mkdir -p "${HOME}/.config/waypaper"
if [[ -f "$PATCHES/waypaper/config.ini" ]]; then
    install -m644 "$PATCHES/waypaper/config.ini" "${HOME}/.config/waypaper/config.ini"
    log "waypaper/config.ini"
fi

mkdir -p "${HOME}/.config/ml4w/settings" "${HOME}/.config/ml4w/scripts"
for s in "$PATCHES/ml4w/settings/"*.sh; do
    [[ -f "$s" ]] || continue
    install -m755 "$s" "${HOME}/.config/ml4w/settings/$(basename "$s")"
    log "ml4w/settings/$(basename "$s")"
done
for s in "$PATCHES/ml4w/scripts/"*.sh; do
    [[ -f "$s" ]] || continue
    install_with_dotfiles "$s" "${HOME}/.config/ml4w/scripts/$(basename "$s")" 755
    log "ml4w/scripts/$(basename "$s")"
done

HYPR_MAIN="$ML4W_CFG/hypr/hyprland.conf"
if [[ -f "$HYPR_MAIN" ]] && ! grep -q 'binds-dotfiles.conf' "$HYPR_MAIN"; then
    echo 'source = ~/.config/hypr/conf/binds-dotfiles.conf' >>"$HYPR_MAIN"
    log "hyprland.conf (source binds-dotfiles.conf)"
fi
if [[ -f "$HYPR_MAIN" ]] && ! grep -q 'windowrules-dotfiles.conf' "$HYPR_MAIN"; then
    echo 'source = ~/.config/hypr/conf/windowrules-dotfiles.conf' >>"$HYPR_MAIN"
    log "hyprland.conf (source windowrules-dotfiles.conf)"
fi
if [[ -f "$HYPR_MAIN" ]] && ! grep -q 'general-dotfiles.conf' "$HYPR_MAIN"; then
    echo 'source = ~/.config/hypr/conf/general-dotfiles.conf' >>"$HYPR_MAIN"
    log "hyprland.conf (source general-dotfiles.conf)"
fi
if [[ -f "$HYPR_MAIN" ]] && ! grep -q 'group-dotfiles.conf' "$HYPR_MAIN"; then
    echo 'source = ~/.config/hypr/conf/group-dotfiles.conf' >>"$HYPR_MAIN"
    log "hyprland.conf (source group-dotfiles.conf)"
fi

mkdir -p "${HOME}/.local/share/applications"
if [[ -f "$PATCHES/applications/com.valvesoftware.SteamLink.desktop" ]]; then
    sed "s|@HOME@|$HOME|g" "$PATCHES/applications/com.valvesoftware.SteamLink.desktop" \
        >"${HOME}/.local/share/applications/com.valvesoftware.SteamLink.desktop"
    log "applications/com.valvesoftware.SteamLink.desktop"
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

def append_module(text: str, key: str, snippet: str) -> tuple[str, bool]:
    if re.search(rf'"{re.escape(key)}"\s*:', text):
        return text, False
    snippet = snippet.strip().rstrip(",") + ",\n"
    idx = text.rstrip().rfind("}")
    if idx < 0:
        return text, False
    return text[:idx] + "\n" + snippet + text[idx:], True

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
    ("custom/appmenu", "custom-appmenu.jsonc"),
    ("custom/passthrough", "custom-passthrough.jsonc"),
    ("mpris", "mpris.jsonc"),
    ("temperature", "temperature.jsonc"),
    ("disk", "disk.jsonc"),
    ("cpu", "cpu.jsonc"),
    ("memory", "memory.jsonc"),
    ("idle_inhibitor", "idle-inhibitor.jsonc"),
    ("clock", "clock.jsonc"),
):
    snip_path = patches / file
    if not snip_path.exists():
        continue
    snip = snip_path.read_text().strip()
    text, ok = replace_block(text, name, snip)
    if not ok and name in ("mpris", "temperature", "custom/passthrough"):
        text, ok = append_module(text, name, snip)
    if not ok:
        print(f"warning: could not patch {name}", file=sys.stderr)

modules.write_text(text)
PY
    if ! [[ "$MODULES" -ef "${HOME}/.config/waybar/modules.json" ]]; then
        install -m644 "$MODULES" "${HOME}/.config/waybar/modules.json"
    fi
    log "waybar/modules.json (workspaces + media + stats)"
fi

WAYBAR_PRIMARY="$PATCHES/waybar/config-primary.jsonc"
if [[ -f "$WAYBAR_PRIMARY" ]]; then
install -m644 "$PATCHES/waybar/config-primary.jsonc" "${HOME}/.config/waybar/config-primary.jsonc"
install -m644 "$PATCHES/waybar/config-secondary.jsonc" "${HOME}/.config/waybar/config-secondary.jsonc"
install -m644 "$PATCHES/waybar/config-primary.jsonc" "$ML4W_CFG/waybar/config-primary.jsonc"
install -m644 "$PATCHES/waybar/config-secondary.jsonc" "$ML4W_CFG/waybar/config-secondary.jsonc"
log "waybar/config-primary.jsonc + config-secondary.jsonc"

MODULES_RIGHT="$PATCHES/waybar/config-modules-right.jsonc"
if [[ -f "$WAYBAR_PRIMARY" && -f "$MODULES_RIGHT" ]]; then
    WAYBAR_CFG="$WAYBAR_PRIMARY" MODULES_RIGHT="$MODULES_RIGHT" python3 <<'PY'
import os, re
from pathlib import Path

cfg = Path(os.environ["WAYBAR_CFG"])
right = Path(os.environ["MODULES_RIGHT"]).read_text().strip()
text = cfg.read_text()
pat = r'"modules-right"\s*:\s*\[[^\]]*\]\s*,?'
new, n = re.subn(pat, right, text, count=1, flags=re.DOTALL)
if n != 1:
    raise SystemExit("could not patch modules-right in waybar config")
cfg.write_text(new)
PY
    log "waybar/config-primary.jsonc (modules-right)"
fi

MODULES_LEFT="$PATCHES/waybar/config-modules-left.jsonc"
if [[ -f "$WAYBAR_PRIMARY" && -f "$MODULES_LEFT" ]]; then
    WAYBAR_CFG="$WAYBAR_PRIMARY" MODULES_LEFT="$MODULES_LEFT" python3 <<'PY'
import os, re
from pathlib import Path

cfg = Path(os.environ["WAYBAR_CFG"])
left = Path(os.environ["MODULES_LEFT"]).read_text().strip()
text = cfg.read_text()
pat = r'"modules-left"\s*:\s*\[[^\]]*\]\s*,?'
new, n = re.subn(pat, left, text, count=1, flags=re.DOTALL)
if n != 1:
    raise SystemExit("could not patch modules-left in waybar config")
cfg.write_text(new)
PY
    log "waybar/config-primary.jsonc (modules-left + passthrough)"
fi

install -m644 "$WAYBAR_PRIMARY" "${HOME}/.config/waybar/config-primary.jsonc"
install -m644 "$WAYBAR_PRIMARY" "$ML4W_CFG/waybar/config-primary.jsonc"
install -m644 "$WAYBAR_PRIMARY" "$ML4W_CFG/waybar/config"
install -m644 "$WAYBAR_PRIMARY" "${HOME}/.config/waybar/config"
log "waybar/config (legacy copy of primary layout)"
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
