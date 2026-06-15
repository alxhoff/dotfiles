#!/usr/bin/env bash
# Ensure ~/.config/hypr/monitors.conf cannot boot Hyprland with zero active outputs.
# Run before Hyprland starts (session wrapper) or anytime the compositor is not running.
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=endeavour/displays/config.env
source "$SCRIPT_DIR/config.env"
# shellcheck source=endeavour/displays/lib.sh
source "$SCRIPT_DIR/lib.sh"

MONITORS_CONF="${HOME}/.config/hypr/monitors.conf"
DEFAULT_CONF="$SCRIPT_DIR/monitors.conf.default"
PROFILES_DIR=$(resolve_profiles_dir "$SCRIPT_DIR")
LAPTOP_PROFILE="$PROFILES_DIR/laptop.hypr"

log() { echo "displays-validate: $*" >&2; }

drm_connected() {
    local name=$1
    local entry status

    for entry in /sys/class/drm/card*-"$name"; do
        [[ -e "$entry/status" ]] || continue
        status=$(<"$entry/status")
        if [[ "$status" == connected ]]; then
            return 0
        fi
    done
    return 1
}

apply_laptop_conf() {
    local src=$1
    local reason=$2

    [[ -f "$src" ]] || {
        log "missing safe profile: $src"
        return 1
    }

    {
        echo "# profile=laptop validated $(date -Iseconds) ($reason)"
        grep -E '^monitor=' "$src" || true
    } >"$MONITORS_CONF"

    log "wrote laptop-safe layout ($reason) → $MONITORS_CONF"
}

main() {
    [[ -f "$MONITORS_CONF" ]] || {
        apply_laptop_conf "${DEFAULT_CONF}" "missing monitors.conf"
        exit 0
    }

    export MONITORS_CONF LAPTOP_PATTERN
    local verdict
    verdict=$(python3 <<'PY'
import os
import re
from pathlib import Path

monitors = Path(os.environ["MONITORS_CONF"])
edp = os.environ.get("LAPTOP_PATTERN", "eDP")
text = monitors.read_text(encoding="utf-8", errors="replace")

def drm_connected(name: str) -> bool:
    for entry in Path("/sys/class/drm").glob(f"card*-{name}"):
        status = entry / "status"
        if status.is_file() and status.read_text().strip() == "connected":
            return True
    return False

def parse_line(line: str):
    body = line[len("monitor="):]
    parts = body.split(",")
    name = parts[0]
    disabled = body.rstrip().endswith("disable") or (len(parts) == 2 and parts[1] == "disable")
    return name, disabled

laptop_disabled = False
active_outputs = 0

for raw in text.splitlines():
    line = raw.strip()
    if not line.startswith("monitor="):
        continue
    name, disabled = parse_line(line)
    if disabled:
        if edp in name:
            laptop_disabled = True
        continue
    if drm_connected(name):
        active_outputs += 1

if laptop_disabled and active_outputs == 0:
    print("unsafe")
elif active_outputs == 0:
    print("unsafe")
else:
    print("ok")
PY
)

    case "$verdict" in
        ok)
            exit 0
            ;;
        unsafe)
            if [[ -f "$LAPTOP_PROFILE" ]]; then
                apply_laptop_conf "$LAPTOP_PROFILE" "no active outputs for saved layout"
            else
                apply_laptop_conf "$DEFAULT_CONF" "no active outputs for saved layout"
            fi
            ;;
        *)
            log "unexpected verdict: $verdict"
            exit 1
            ;;
    esac
}

main
