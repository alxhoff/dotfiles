#!/usr/bin/env bash
# Guake-style dropdown Spotify (Hyprland special workspace).
set -euo pipefail

CONFIG="${HOME}/.config/ml4w/dropdown-spotify.env"
[[ -f "$CONFIG" ]] && source "$CONFIG"

DISPLAY_CONFIG="${HOME}/.config/dotfiles/endeavour/displays/config.env"
[[ -f "$DISPLAY_CONFIG" ]] && source "$DISPLAY_CONFIG"

if command -v spotify-adblock >/dev/null 2>&1 && [[ -f /usr/local/lib/spotify-adblock.so ]]; then
	: "${DROPDOWN_CMD:=spotify-adblock}"
else
	: "${DROPDOWN_CMD:=spotify}"
fi

: "${DROPDOWN_CLASS:=spotify}"
: "${DROPDOWN_WORKSPACE:=spotify}"
: "${DROPDOWN_SIZE:=100% 50%}"
: "${DROPDOWN_MOVE:=0 4}"

client_json() {
	hyprctl clients -j 2>/dev/null || echo '[]'
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
want = os.environ["DROPDOWN_CLASS"].lower()
print("yes" if any((c.get("class") or "").lower() == want for c in json.load(sys.stdin)) else "no")
'
}

dropdown_addr() {
	client_json | DROPDOWN_CLASS="$DROPDOWN_CLASS" python3 -c '
import json, os, sys
want = os.environ["DROPDOWN_CLASS"].lower()
for c in json.load(sys.stdin):
    if (c.get("class") or "").lower() == want:
        print(c["address"])
        break
'
}

spawn_spotify() {
	# shellcheck disable=SC2086
	nohup $DROPDOWN_CMD >/dev/null 2>&1 &
}

layout_dropdown() {
	local addr=$1
	local target_mon=$2
	[[ -n "$addr" && -n "$target_mon" ]] || return 0

	export DROPDOWN_SIZE DROPDOWN_MOVE TARGET_MONITOR="$target_mon"
	read -r w h x y <<<"$(python3 <<'PY'
import json, os, subprocess

def pct(token, base):
    token = token.strip()
    if token.endswith("%"):
        return int(base * float(token[:-1]) / 100)
    return int(token)

size = os.environ.get("DROPDOWN_SIZE", "100% 50%").split()
move = os.environ.get("DROPDOWN_MOVE", "0 0").split()
target = os.environ.get("TARGET_MONITOR", "").strip()
monitors = json.loads(subprocess.check_output(["hyprctl", "monitors", "-j"], text=True))
mon = next((m for m in monitors if m["name"] == target), None)
if not mon:
    mon = next((m for m in monitors if m.get("focused")), monitors[0])
reserved_top = (mon.get("reserved") or [0, 0, 0, 0])[1]
w = pct(size[0], mon["width"])
h = pct(size[1], mon["height"])
x = mon["x"] + pct(move[0], mon["width"])
y = mon["y"] + reserved_top + pct(move[1], mon["height"])
print(w, h, x, y)
PY
)"

	hyprctl dispatch resizewindowpixel exact "$w" "$h",address:"$addr" 2>/dev/null || true
	hyprctl dispatch movewindowpixel exact "$x" "$y",address:"$addr" 2>/dev/null || true
}

TARGET_MONITOR=$(primary_monitor_name)
[[ -n "$TARGET_MONITOR" ]] || TARGET_MONITOR=$(hyprctl monitors -j | python3 -c '
import json, sys
for m in json.load(sys.stdin):
    if m.get("focused"):
        print(m["name"])
        break
')

if [[ "$(has_dropdown)" != "yes" ]]; then
	spawn_spotify
	addr=""
	for _ in $(seq 1 80); do
		sleep 0.1
		addr=$(dropdown_addr || true)
		[[ -n "$addr" ]] && break
	done
	if [[ -z "$addr" ]]; then
		echo "dropdown-spotify: failed to spawn $DROPDOWN_CMD (class=$DROPDOWN_CLASS)" >&2
		exit 1
	fi
	hyprctl dispatch movetoworkspacesilent "special:$DROPDOWN_WORKSPACE,address:$addr"
fi

addr=$(dropdown_addr || true)
hyprctl dispatch focusmonitor "$TARGET_MONITOR"
hyprctl dispatch togglespecialworkspace "$DROPDOWN_WORKSPACE"
layout_dropdown "$addr" "$TARGET_MONITOR"
