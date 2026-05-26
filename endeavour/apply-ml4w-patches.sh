#!/usr/bin/env bash
# Apply dotfiles overrides on top of ML4W Hyprland Starter (Hyprland 0.55+, waybar).
set -euo pipefail

DOTFILES_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
PATCHES="$DOTFILES_DIR/endeavour/ml4w-patches"
ML4W_CFG="${HOME}/.mydotfiles/com.ml4w.hyprlandstarter/.config"
DISPLAYS="$DOTFILES_DIR/endeavour/displays"

log() { echo "==> $*"; }

# Symlink all repo-owned configs (~/.config/dotfiles, hypr patches, ml4w scripts, waybar jsonc, …)
"$DOTFILES_DIR/endeavour/link-configs.sh"

[[ -d "$ML4W_CFG/hypr" ]] || {
    echo "ML4W not installed. Run: $DOTFILES_DIR/endeavour/install-ml4w-starter.sh" >&2
    exit 1
}

if [[ -f "$DISPLAYS/monitors.conf.default" ]] && [[ ! -f "${HOME}/.config/hypr/monitors.conf" ]]; then
    install -m644 "$DISPLAYS/monitors.conf.default" "${HOME}/.config/hypr/monitors.conf"
    log "hypr/monitors.conf (safe default)"
fi

HYPR_MAIN="$ML4W_CFG/hypr/hyprland.conf"
for src_line in \
    'source = ~/.config/hypr/conf/binds-dotfiles.conf' \
    'source = ~/.config/hypr/conf/windowrules-dotfiles.conf' \
    'source = ~/.config/hypr/conf/general-dotfiles.conf' \
    'source = ~/.config/hypr/conf/group-dotfiles.conf'; do
    file=${src_line#source = ~/.config/hypr/conf/}
    file=${file%.conf}.conf
    if [[ -f "$HYPR_MAIN" ]] && ! grep -qF "$file" "$HYPR_MAIN"; then
        echo "$src_line" >>"$HYPR_MAIN"
        log "hyprland.conf (source $file)"
    fi
done

mkdir -p "${HOME}/.local/share/applications"
if [[ -f "$PATCHES/applications/com.valvesoftware.SteamLink.desktop" ]]; then
    sed "s|@HOME@|$HOME|g" "$PATCHES/applications/com.valvesoftware.SteamLink.desktop" \
        >"${HOME}/.local/share/applications/com.valvesoftware.SteamLink.desktop"
    log "applications/com.valvesoftware.SteamLink.desktop"
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
text = re.sub(
    r'\n[ \t]*"separate-outputs": true\n[ \t]*\},\n(?=[ \t]*"separate-outputs")',
    '\n',
    text,
)

for name, file in (
    ("hyprland/workspaces", "hyprland-workspaces.jsonc"),
    ("hyprland/window", "hyprland-window.jsonc"),
    ("custom/network", "custom-network.jsonc"),
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
    ("battery", "battery.jsonc"),
):
    snip_path = patches / file
    if not snip_path.exists():
        continue
    snip = snip_path.read_text().strip()
    text, ok = replace_block(text, name, snip)
    if not ok and name in ("mpris", "temperature", "custom/passthrough", "custom/network"):
        text, ok = append_module(text, name, snip)
    if not ok:
        print(f"warning: could not patch {name}", file=sys.stderr)

modules.write_text(text)
PY
    log "waybar/modules.json (patched from ML4W base + repo snippets)"
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
        log "waybar/style.css (ML4W base + repo overrides appended)"
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
