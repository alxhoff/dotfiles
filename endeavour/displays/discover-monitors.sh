#!/usr/bin/env bash
# Run inside Hyprland. Shows names (can change) and descriptions (stable for kanshi/config.env).
set -euo pipefail

if ! command -v hyprctl >/dev/null; then
    echo "hyprctl not found — log into Hyprland first." >&2
    exit 1
fi

echo "=== Connected monitors ==="
hyprctl monitors

echo ""
echo "=== For config.env (HOME_DOCK_DESCRIPTIONS) — use unique substrings ==="
hyprctl monitors -j | python3 -c "
import json, sys
for m in json.load(sys.stdin):
    d = m.get('description', '')
    n = m.get('name', '')
    print(f'  name={n}')
    print(f'  description={d}')
    # suggest substring (model-ish)
    for token in d.split():
        if len(token) > 6 and token not in ('Inc.', 'Corporation', 'Technologies', 'Group', 'Limited'):
            print(f'  → substring candidate: {token}')
    print()
"

echo "=== Current layout (for capture-layout.sh) ==="
hyprctl monitors -j | python3 -c "
import json, sys
for m in json.load(sys.stdin):
    if m.get('disabled'):
        continue
    n, d = m.get('name',''), m.get('description','')
    w, h = m.get('width',0), m.get('height',0)
    x, y = m.get('x',0), m.get('y',0)
    rr = int(round(m.get('refreshRate',60) or 60))
    sc = m.get('scale',1)
    t = m.get('transform',0)
    print(f'# {d}')
    line = f'monitor={n},{w}x{h}@{rr},{x}x{y},{sc}'
    if t: line += f',transform,{t}'
    print(line)
    print()
"

echo "Set HOME_DOCK_DESCRIPTIONS in config.env to pipe-separated substrings, e.g.:"
echo "  HOME_DOCK_DESCRIPTIONS='DELL UP2516D|VX3276-QHD|B246WL'"
