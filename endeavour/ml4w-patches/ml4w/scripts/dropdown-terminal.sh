#!/usr/bin/env bash
# Guake-style dropdown terminal (Hyprland special workspace / Sway floating).
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=compositor.sh
source "$SCRIPT_DIR/compositor.sh"
if compositor_is_sway; then
	exec "$SCRIPT_DIR/dropdown-terminal-sway.sh" "$@"
fi

CONFIG="${HOME}/.config/ml4w/dropdown-terminal.env"
[[ -f "$CONFIG" ]] && source "$CONFIG"

DISPLAY_CONFIG="${HOME}/.config/dotfiles/endeavour/displays/config.env"
[[ -f "$DISPLAY_CONFIG" ]] && source "$DISPLAY_CONFIG"

: "${DROPDOWN_TERM:=kitty}"
: "${DROPDOWN_CLASS:=dropdown-terminal}"
: "${DROPDOWN_TITLE:=Dropdown}"
: "${DROPDOWN_WORKSPACE:=dropdown}"
: "${DROPDOWN_CMD:=}"
: "${DROPDOWN_SIZE:=100% 42%}"
: "${DROPDOWN_MOVE:=0 0}"
: "${DROPDOWN_MARGIN:=12}"

client_json() {
	hyprctl clients -j 2>/dev/null || echo '[]'
}

focused_monitor_name() {
	hyprctl monitors -j | python3 -c '
import json, sys
for m in json.load(sys.stdin):
    if m.get("focused"):
        print(m["name"])
        break
'
}

primary_monitor_name() {
	export WAYBAR_PRIMARY_PATTERN WORK_WAYBAR_PRIMARY_PATTERN
	python3 <<'PY'
import json, os, subprocess

patterns = [
    p.strip()
    for p in (
        os.environ.get("WAYBAR_PRIMARY_PATTERN", ""),
        os.environ.get("WORK_WAYBAR_PRIMARY_PATTERN", ""),
    )
    if p.strip()
]
monitors = json.loads(subprocess.check_output(["hyprctl", "monitors", "-j"], text=True))
active = [m for m in monitors if not m.get("disabled")]
primary = None
for pattern in patterns:
    primary = next(
        (m["name"] for m in active if pattern in m.get("description", "")),
        None,
    )
    if primary:
        break
if not primary and active:
    primary = max(active, key=lambda m: m.get("width", 0) * m.get("height", 0))["name"]
print(primary or "")
PY
}

has_dropdown() {
	client_json | DROPDOWN_CLASS="$DROPDOWN_CLASS" python3 -c '
import json, os, sys
want = os.environ["DROPDOWN_CLASS"]
print("yes" if any(c.get("class") == want for c in json.load(sys.stdin)) else "no")
'
}

dropdown_addr() {
	client_json | DROPDOWN_CLASS="$DROPDOWN_CLASS" python3 -c '
import json, os, sys
want = os.environ["DROPDOWN_CLASS"]
for c in json.load(sys.stdin):
    if c.get("class") == want:
        print(c["address"])
        break
'
}

spawn_terminal() {
	local -a cmd=("$DROPDOWN_TERM" "--class=$DROPDOWN_CLASS" "--title=$DROPDOWN_TITLE")
	if [[ -n "$DROPDOWN_CMD" ]]; then
		cmd+=(-e bash -lc "$DROPDOWN_CMD")
	fi
	"${cmd[@]}" &
}

layout_dropdown() {
	local addr=$1
	local target_mon=$2
	[[ -n "$addr" && -n "$target_mon" ]] || return 0

	export DROPDOWN_SIZE DROPDOWN_MOVE DROPDOWN_MARGIN TARGET_MONITOR="$target_mon"
	read -r w h x y <<<"$(python3 <<'PY'
import json, os, subprocess

def pct(token, base):
    token = token.strip()
    if token.endswith("%"):
        return int(base * float(token[:-1]) / 100)
    return int(token)

def effective_size(mon):
    w, h = mon["width"], mon["height"]
    if mon.get("transform", 0) in (1, 3):
        w, h = h, w
    return w, h

size = os.environ.get("DROPDOWN_SIZE", "100% 42%").split()
move = os.environ.get("DROPDOWN_MOVE", "0 0").split()
target = os.environ.get("TARGET_MONITOR", "").strip()
monitors = json.loads(subprocess.check_output(["hyprctl", "monitors", "-j"], text=True))
mon = next((m for m in monitors if m["name"] == target), None)
if not mon:
    mon = next((m for m in monitors if m.get("focused")), monitors[0])
eff_w, eff_h = effective_size(mon)
reserved_top = (mon.get("reserved") or [0, 0, 0, 0])[1]
margin = int(os.environ.get("DROPDOWN_MARGIN", "12"))
usable_w = eff_w - (margin * 2)
usable_h = eff_h - reserved_top - (margin * 2)
w = min(pct(size[0], usable_w), usable_w)
h = min(pct(size[1], usable_h), usable_h)
x = mon["x"] + margin + pct(move[0], usable_w)
y = mon["y"] + reserved_top + margin + pct(move[1], usable_h)
print(w, h, x, y)
PY
)"

	hyprctl dispatch resizewindowpixel exact "$w" "$h",address:"$addr" 2>/dev/null || true
	hyprctl dispatch movewindowpixel exact "$x" "$y",address:"$addr" 2>/dev/null || true
}

if [[ "${1:-}" == relayout ]]; then
	addr=$(dropdown_addr || true)
	[[ -n "$addr" ]] || exit 0
	TARGET_MONITOR=$(primary_monitor_name)
	[[ -n "$TARGET_MONITOR" ]] || TARGET_MONITOR=$(focused_monitor_name)
	layout_dropdown "$addr" "$TARGET_MONITOR"
	exit 0
fi

TARGET_MONITOR=$(focused_monitor_name)

if [[ "$(has_dropdown)" != "yes" ]]; then
	spawn_terminal
	addr=""
	for _ in $(seq 1 50); do
		sleep 0.05
		addr=$(dropdown_addr || true)
		[[ -n "$addr" ]] && break
	done
	if [[ -z "$addr" ]]; then
		echo "dropdown-terminal: failed to spawn $DROPDOWN_TERM (class=$DROPDOWN_CLASS)" >&2
		exit 1
	fi
	hyprctl dispatch movetoworkspacesilent "special:$DROPDOWN_WORKSPACE,address:$addr"
fi

addr=$(dropdown_addr || true)
[[ -n "$TARGET_MONITOR" ]] && hyprctl dispatch focusmonitor "$TARGET_MONITOR"
hyprctl dispatch togglespecialworkspace "$DROPDOWN_WORKSPACE"
layout_dropdown "$addr" "$TARGET_MONITOR"
