#!/usr/bin/env bash
# Fix tiled-layout corruption and misplaced dropdown windows after display changes.
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=compositor.sh
source "$SCRIPT_DIR/compositor.sh"

CONFIG_ENV="${HOME}/.config/dotfiles/endeavour/displays/config.env"
[[ -f "$CONFIG_ENV" ]] && source "$CONFIG_ENV"
: "${PORTRAIT_MONITOR_PATTERNS:=Q27q-1L|B246WL|UP2516D}"

REFRESH_FLAG="${XDG_RUNTIME_DIR:-/tmp}/dotfiles-display-needs-refresh"
LOCK="${XDG_RUNTIME_DIR:-/tmp}/dotfiles-display-refresh.lock"
DROPDOWN_TERM="${HOME}/.config/ml4w/scripts/dropdown-terminal.sh"
DROPDOWN_SPOTIFY="${HOME}/.config/ml4w/scripts/dropdown-spotify.sh"

exec 9>"$LOCK"
flock -n 9 || exit 0

if compositor_is_sway; then
	for script in "$DROPDOWN_TERM" "$DROPDOWN_SPOTIFY"; do
		[[ -x "$script" ]] && "$script" relayout 2>/dev/null || true
	done
	rm -f "$REFRESH_FLAG"
	exit 0
fi

command -v hyprctl >/dev/null || exit 0
hyprctl version >/dev/null 2>&1 || exit 0

export PORTRAIT_MONITOR_PATTERNS
python3 <<'PY'
import json
import os
import subprocess
import sys

patterns = [p for p in os.environ.get("PORTRAIT_MONITOR_PATTERNS", "").split("|") if p]


def run(*args):
    subprocess.run(["hyprctl", "dispatch", *args], capture_output=True)


def hypr_json(*args):
    return json.loads(subprocess.check_output(["hyprctl", *args], text=True))


def is_portrait(mon: dict) -> bool:
    desc = mon.get("description") or ""
    if any(p in desc for p in patterns):
        return True
    if mon.get("transform", 0) in (1, 3):
        return True
    return mon.get("height", 0) > mon.get("width", 0)


def current_layout() -> str:
    data = hypr_json("getoption", "general:layout", "-j")
    return data.get("str") or "dwindle"


layout = current_layout()
subprocess.run(["hyprctl", "keyword", "general:layout", "master"], capture_output=True)
subprocess.run(["hyprctl", "keyword", "general:layout", layout], capture_output=True)

monitors = hypr_json("monitors", "-j")
for mon in monitors:
    if not is_portrait(mon):
        continue
    run("focusmonitor", mon["name"])
    ws = (mon.get("activeWorkspace") or {}).get("name")
    if ws:
        run("workspace", ws)
    run("layoutmsg", "preselect", "d")

clients = hypr_json("clients", "-j")
floated = 0
for client in clients:
    if client.get("floating"):
        continue
    width, height = client.get("size") or [0, 0]
    if width >= 120 and height >= 120:
        continue
    addr = client.get("address")
    if not addr:
        continue
    run("togglefloating", f"address:{addr}")
    floated += 1

if floated:
    print(
        f"refresh-session-layouts: floated {floated} corrupted tile(s); "
        "re-tile with Alt+Shift+Space or move to another workspace",
        file=sys.stderr,
    )
PY

for script in "$DROPDOWN_TERM" "$DROPDOWN_SPOTIFY"; do
    [[ -x "$script" ]] && "$script" relayout 2>/dev/null || true
done

rm -f "$REFRESH_FLAG"
