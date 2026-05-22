#!/usr/bin/env bash
# Capture the CURRENT Hyprland monitor layout as profile lines (arandr replacement).
#
# Usage (in Hyprland, at the dock you want to save):
#   ./capture-layout.sh home    > profiles/home.hypr
#   ./capture-layout.sh work    > profiles/work.hypr
#   ./capture-layout.sh laptop  > profiles/laptop.hypr
#
# Arrange monitors first (GUI or drag in nwg-displays), then capture.
# Test: ./apply-display-profile.sh home
#
set -euo pipefail

PROFILE=${1:-}
if [[ -z "$PROFILE" ]]; then
    echo "Usage: $0 <profile-name>  (e.g. home, work, laptop)" >&2
    echo "Redirect to profiles/:  $0 home > profiles/home.hypr" >&2
    exit 1
fi

if ! hyprctl monitors -j >/dev/null 2>&1; then
    echo "Run inside a Hyprland session." >&2
    exit 1
fi

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

{
    echo "# Captured profile: $PROFILE"
    echo "# Date: $(date -Iseconds)"
    echo "# Host: $(hostname)"
    echo "# Re-capture: cd $SCRIPT_DIR && ./capture-layout.sh $PROFILE > profiles/${PROFILE}.hypr"
    echo "#"
    hyprctl monitors -j | python3 -c "
import json, sys
data = json.load(sys.stdin)
# Laptop panel last so externals get primary positions first (optional sort)
def sort_key(m):
    n = m.get('name', '')
    return (1 if 'eDP' in n else 0, n)
for m in sorted(data, key=sort_key):
    name = m.get('name', '')
    if m.get('disabled'):
        print(f'monitor={name},disable')
        continue
    w, h = m.get('width', 0), m.get('height', 0)
    rr = m.get('refreshRate', 60)
    rr = int(round(rr)) if rr else 60
    x, y = m.get('x', 0), m.get('y', 0)
    scale = m.get('scale', 1.0)
    # Hypr scale in monitor= is integer-ish
    sc = int(scale) if scale == int(scale) else scale
    desc = m.get('description', '')
    line = f'monitor={name},{w}x{h}@{rr},{x}x{y},{sc}'
    t = m.get('transform', 0)
    if t:
        line += f',transform,{t}'
    print(f'# {desc}')
    print(line)
    print()
"
} 
