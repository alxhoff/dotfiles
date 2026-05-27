#!/usr/bin/env bash
# Waybar custom/media-title — fixed-width marquee + progress bar (playerctl).
set -euo pipefail

SCRIPT_DIR=$(dirname "$(readlink -f "$0")")
PLAYERCTL="$SCRIPT_DIR/media-playerctl.sh"

width=${MEDIA_BLOCK_WIDTH:-24}

status=$("$PLAYERCTL" status 2>/dev/null || echo Stopped)
if [[ "$status" == "Stopped" ]]; then
	python3 -c 'import json; print(json.dumps({"text": ""}))'
	exit 0
fi

artist=$("$PLAYERCTL" metadata artist 2>/dev/null || true)
title=$("$PLAYERCTL" metadata title 2>/dev/null || true)
player=$("$PLAYERCTL" metadata --format '{{playerName}}' 2>/dev/null || true)
pos=$("$PLAYERCTL" position 2>/dev/null || echo "")
len_us=$("$PLAYERCTL" metadata mpris:length 2>/dev/null || echo "")

export STATUS="$status" ARTIST="$artist" TITLE="$title" PLAYER="$player" \
	WIDTH="$width" POS="$pos" LEN_US="$len_us"
python3 <<'PY'
import json
import os
import time

status = os.environ["STATUS"]
artist = os.environ.get("ARTIST", "").strip()
title = os.environ.get("TITLE", "").strip()
player = os.environ.get("PLAYER", "").strip()
width = int(os.environ["WIDTH"])
pos_raw = os.environ.get("POS", "")
len_raw = os.environ.get("LEN_US", "")

if not artist and not title:
    print(json.dumps({"text": ""}))
    raise SystemExit

line = f"{artist} — {title}" if artist and title else (artist or title)
tooltip = f"{player}: {line}" if player else line

if len(line) <= width:
    title_line = line.ljust(width)
else:
    gap = "   "
    loop = line + gap
    offset = (int(time.time()) // 2) % len(loop)
    title_line = (loop + loop)[offset : offset + width]

dot = 0
if pos_raw and len_raw:
    pos = float(pos_raw)
    duration = float(len_raw) / 1_000_000
    if duration > 0:
        ratio = max(0.0, min(1.0, pos / duration))
        dot = min(int(round(ratio * (width - 1))), width - 1)
        mins, secs = divmod(int(pos), 60)
        dm, ds = divmod(int(duration), 60)
        tooltip = f"{tooltip}\n{mins}:{secs:02d} / {dm}:{ds:02d}"

bar_parts = []
for i in range(width):
    if i < dot:
        ch, fg = "▁", "#7eb8da"
    elif i == dot:
        ch, fg = "▂", "#e8e8ec"
    else:
        ch, fg = "▁", "#5a5a66"
    bar_parts.append(f'<span foreground="{fg}">{ch}</span>')
bar = "".join(bar_parts)

mono = "JetBrainsMono Nerd Font"
text = (
    f'<span font_family="{mono}" size="small">{title_line}</span>\n'
    f'<span font_family="{mono}" size="small">{bar}</span>'
)
payload = {"text": text, "tooltip": tooltip}
if status == "Paused":
    payload["class"] = "paused"
print(json.dumps(payload))
PY
