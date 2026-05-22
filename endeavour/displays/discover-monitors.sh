#!/usr/bin/env bash
# Run inside a Hyprland session. Prints monitor names, descriptions, modes — use to edit profiles/*.hypr
set -euo pipefail

if ! command -v hyprctl >/dev/null; then
    echo "hyprctl not found — install hyprland and log into Hyprland first." >&2
    exit 1
fi

echo "=== hyprctl monitors (human) ==="
hyprctl monitors

echo ""
echo "=== hyprctl monitors -j (for copy/paste) ==="
hyprctl monitors -j | python3 -m json.tool 2>/dev/null || hyprctl monitors -j

echo ""
echo "=== Suggested monitor= lines (preferred mode, auto position) ==="
hyprctl monitors -j | python3 -c "
import json, sys
data = json.load(sys.stdin)
for m in data:
    name = m.get('name', '')
    desc = m.get('description', '')
    w, h = m.get('width', 0), m.get('height', 0)
    pref = m.get('preferredMode', {}) or {}
    pw = pref.get('width', w)
    ph = pref.get('height', h)
    print(f'# {desc}')
    print(f'monitor={name},{pw}x{ph}@60,auto,1')
    print()
"

echo "Edit endeavour/displays/profiles/*.hypr then: ./apply-display-profile.sh"
