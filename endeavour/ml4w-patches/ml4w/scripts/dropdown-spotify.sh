#!/usr/bin/env bash
# Guake-style dropdown Spotify (+ Discord split when running).
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=compositor.sh
source "$SCRIPT_DIR/compositor.sh"
if compositor_is_sway; then
	exec "$SCRIPT_DIR/dropdown-spotify-sway.sh" "$@"
fi

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
: "${DISCORD_CLASS:=discord}"
: "${DROPDOWN_WORKSPACE:=spotify}"
: "${DROPDOWN_SIZE:=100% 100%}"
: "${DROPDOWN_MOVE:=0 0}"
: "${DROPDOWN_MARGIN:=12}"
: "${DROPDOWN_GAP:=16}"

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

client_addr() {
	local class=$1
	client_json | DROPDOWN_CLASS="$class" python3 -c '
import json, os, sys
want = os.environ["DROPDOWN_CLASS"].lower()
best = None
for c in json.load(sys.stdin):
    if (c.get("class") or "").lower() != want:
        continue
    size = (c.get("size") or [0, 0])
    area = size[0] * size[1]
    if best is None or area > best[0]:
        best = (area, c["address"])
print(best[1] if best else "")
'
}

has_spotify() {
	[[ -n "$(client_addr "$DROPDOWN_CLASS")" ]] && echo yes || echo no
}

special_open() {
	local mon=$1
	hyprctl monitors -j | python3 -c '
import json, sys
mon, ws = sys.argv[1], sys.argv[2]
for m in json.load(sys.stdin):
    if m["name"] != mon:
        continue
    special = m.get("specialWorkspace") or {}
    name = special.get("name") or ""
    print("yes" if name == f"special:{ws}" else "no")
    break
' "$mon" "$DROPDOWN_WORKSPACE"
}

spawn_spotify() {
	# shellcheck disable=SC2086
	nohup $DROPDOWN_CMD >/dev/null 2>&1 &
}

prepare_client() {
	local addr=$1
	[[ -n "$addr" ]] || return 0

	read -r floating need_clear <<<"$(client_json | python3 -c '
import json, sys
addr = sys.argv[1]
for c in json.load(sys.stdin):
    if c["address"] != addr:
        continue
    fs = c.get("fullscreen", 0)
    fc = c.get("fullscreenClient", 0)
    print("yes" if c.get("floating") else "no", "yes" if fs or fc else "no")
    break
' "$addr")"

	if [[ "$floating" != "yes" ]]; then
		hyprctl dispatch togglefloating "address:$addr" 2>/dev/null || true
	fi

	# fullscreen 0,address:... is invalid and applies to the focused window instead.
	if [[ "$need_clear" == "yes" ]]; then
		local prev_addr=""
		prev_addr=$(hyprctl activewindow -j | python3 -c 'import json,sys; print(json.load(sys.stdin).get("address",""))')
		hyprctl dispatch focuswindow "address:$addr" 2>/dev/null || true
		hyprctl dispatch fullscreen 2>/dev/null || true
		hyprctl dispatch fullscreenstate 0 0 2>/dev/null || true
		if [[ -n "$prev_addr" && "$prev_addr" != "$addr" ]]; then
			hyprctl dispatch focuswindow "address:$prev_addr" 2>/dev/null || true
		fi
	fi
}

layout_windows() {
	local spotify_addr=$1
	local discord_addr=${2:-}
	local target_mon=$3

	export DROPDOWN_SIZE DROPDOWN_MOVE DROPDOWN_MARGIN DROPDOWN_GAP \
		TARGET_MONITOR="$target_mon" SPOTIFY_ADDR="$spotify_addr" DISCORD_ADDR="$discord_addr"
	read -r -a rects <<<"$(python3 <<'PY'
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

target = os.environ.get("TARGET_MONITOR", "").strip()
spotify = os.environ.get("SPOTIFY_ADDR", "").strip()
discord = os.environ.get("DISCORD_ADDR", "").strip()
monitors = json.loads(subprocess.check_output(["hyprctl", "monitors", "-j"], text=True))
mon = next((m for m in monitors if m["name"] == target), None)
if not mon:
    mon = next((m for m in monitors if m.get("focused")), monitors[0])
eff_w, eff_h = effective_size(mon)
reserved = mon.get("reserved") or [0, 0, 0, 0]
reserved_top = reserved[1]
margin = int(os.environ.get("DROPDOWN_MARGIN", "12"))
base_x = mon["x"] + margin
base_y = mon["y"] + reserved_top + margin
usable_w = eff_w - (margin * 2)
usable_h = eff_h - reserved_top - (margin * 2)

if discord:
    gap = int(os.environ.get("DROPDOWN_GAP", "16"))
    pane_w = (usable_w - gap) // 2
    spotify_w = usable_w - gap - pane_w
    discord_x = base_x
    spotify_x = base_x + pane_w + gap
    print(
        pane_w, usable_h, discord_x, base_y,
        spotify_w, usable_h, spotify_x, base_y,
    )
else:
    size = os.environ.get("DROPDOWN_SIZE", "100% 100%").split()
    move = os.environ.get("DROPDOWN_MOVE", "0 0").split()
    w = min(pct(size[0], usable_w), usable_w)
    h = min(pct(size[1], usable_h), usable_h)
    x = base_x + pct(move[0], usable_w)
    y = base_y + pct(move[1], usable_h)
    print(w, h, x, y)
PY
)"

	if [[ -n "$discord_addr" ]]; then
		prepare_client "$discord_addr"
		prepare_client "$spotify_addr"
		local dw=${rects[0]} dh=${rects[1]} dx=${rects[2]} dy=${rects[3]}
		local sw=${rects[4]} sh=${rects[5]} sx=${rects[6]} sy=${rects[7]}
		hyprctl dispatch resizewindowpixel exact "$dw" "$dh",address:"$discord_addr" 2>/dev/null || true
		hyprctl dispatch movewindowpixel exact "$dx" "$dy",address:"$discord_addr" 2>/dev/null || true
		hyprctl dispatch resizewindowpixel exact "$sw" "$sh",address:"$spotify_addr" 2>/dev/null || true
		hyprctl dispatch movewindowpixel exact "$sx" "$sy",address:"$spotify_addr" 2>/dev/null || true
	else
		prepare_client "$spotify_addr"
		local w=${rects[0]} h=${rects[1]} x=${rects[2]} y=${rects[3]}
		hyprctl dispatch resizewindowpixel exact "$w" "$h",address:"$spotify_addr" 2>/dev/null || true
		hyprctl dispatch movewindowpixel exact "$x" "$y",address:"$spotify_addr" 2>/dev/null || true
	fi
}

adopt_discord() {
	local discord_addr=$1
	[[ -n "$discord_addr" ]] || return 0
	hyprctl dispatch movetoworkspacesilent "special:$DROPDOWN_WORKSPACE,address:$discord_addr" 2>/dev/null || true
	prepare_client "$discord_addr"
}

if [[ "${1:-}" == relayout ]]; then
	TARGET_MONITOR=$(primary_monitor_name)
	[[ -n "$TARGET_MONITOR" ]] || exit 0
	spotify_addr=$(client_addr "$DROPDOWN_CLASS" || true)
	discord_addr=$(client_addr "$DISCORD_CLASS" || true)
	[[ -n "$spotify_addr" || -n "$discord_addr" ]] || exit 0
	[[ -n "$spotify_addr" ]] || spotify_addr=""
	layout_windows "$spotify_addr" "$discord_addr" "$TARGET_MONITOR"
	exit 0
fi

TARGET_MONITOR=$(primary_monitor_name)
[[ -n "$TARGET_MONITOR" ]] || TARGET_MONITOR=$(hyprctl monitors -j | python3 -c '
import json, sys
for m in json.load(sys.stdin):
    if m.get("focused"):
        print(m["name"])
        break
')

open_before=$(special_open "$TARGET_MONITOR")
discord_addr=$(client_addr "$DISCORD_CLASS" || true)

if [[ "$open_before" != "yes" ]]; then
	if [[ "$(has_spotify)" != "yes" ]]; then
		spawn_spotify
		spotify_addr=""
		for _ in $(seq 1 80); do
			sleep 0.1
			spotify_addr=$(client_addr "$DROPDOWN_CLASS" || true)
			[[ -n "$spotify_addr" ]] && break
		done
		if [[ -z "$spotify_addr" ]]; then
			echo "dropdown-spotify: failed to spawn $DROPDOWN_CMD (class=$DROPDOWN_CLASS)" >&2
			exit 1
		fi
	else
		spotify_addr=$(client_addr "$DROPDOWN_CLASS")
	fi

	hyprctl dispatch movetoworkspacesilent "special:$DROPDOWN_WORKSPACE,address:$spotify_addr" 2>/dev/null || true
	if [[ -n "$discord_addr" ]]; then
		adopt_discord "$discord_addr"
	fi

	# Size windows while the special workspace is still hidden to avoid a visible resize flash.
	spotify_addr=$(client_addr "$DROPDOWN_CLASS")
	discord_addr=$(client_addr "$DISCORD_CLASS" || true)
	layout_windows "$spotify_addr" "$discord_addr" "$TARGET_MONITOR"
fi

hyprctl dispatch focusmonitor "$TARGET_MONITOR"
hyprctl dispatch togglespecialworkspace "$DROPDOWN_WORKSPACE"
