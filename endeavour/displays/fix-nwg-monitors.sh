#!/usr/bin/env bash
# Fix nwg-displays Hyprland output: merge split transform lines + ensure hypr loads monitors.conf
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
REPO_ROOT=$(cd "$SCRIPT_DIR/../.." && pwd)
MON="${HOME}/.config/hypr/monitors.conf"
MON_PATCH="${REPO_ROOT}/endeavour/ml4w-patches/hypr/conf/monitor.conf"
ML4W_MON="${HOME}/.mydotfiles/com.ml4w.hyprlandstarter/.config/hypr/conf/monitor.conf"

log() { echo "==> $*"; }

[[ -f "$MON" ]] || {
    echo "No $MON — configure layout in nwg-displays and click Apply first." >&2
    exit 1
}

MON_FILE="$MON" python3 <<'PY'
import os
from pathlib import Path

path = Path(os.environ['MON_FILE'])
lines = path.read_text().splitlines()
out = []
pending = {}  # output -> base line without transform

for line in lines:
    s = line.strip()
    if not s or s.startswith('#'):
        out.append(line)
        continue
    if not s.startswith('monitor='):
        out.append(line)
        continue
    body = s[len('monitor='):]
    parts = body.split(',')
    name = parts[0]
    # monitor=DP-7,transform,1
    if len(parts) >= 2 and parts[1] == 'transform':
        t = parts[2] if len(parts) > 2 else '1'
        if name in pending:
            pending[name] = pending[name] + f',transform,{t}'
        continue
    pending[name] = s

for line in list(out):
    pass
out = [l for l in out if l.strip() and not l.strip().startswith('monitor=')]
# rebuild: keep header comments from file
header = []
for line in path.read_text().splitlines():
    if line.strip().startswith('monitor='):
        break
    header.append(line)
if not any('transform must be' in h for h in header):
    header.append('# transform on same line as monitor= (Hyprland requirement)')
text = '\n'.join(header).rstrip() + '\n'
for name in sorted(pending.keys(), key=lambda n: (n != 'eDP-1', n)):
    text += pending[name] + '\n'
path.write_text(text + '\n')
print('Fixed:', path)
PY

if [[ -f "$MON_PATCH" ]]; then
    cp "$MON_PATCH" "$ML4W_MON"
    log "hypr/conf/monitor.conf (sources monitors.conf)"
fi

if hyprctl monitors -j >/dev/null 2>&1; then
    hyprctl reload
    log "hyprctl reload — layout should match monitors.conf"
else
    log "Not in Hyprland — log in; layout loads from monitors.conf on start"
fi
