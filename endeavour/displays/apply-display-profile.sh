#!/usr/bin/env bash
# Apply a saved monitor profile (home / laptop / work).
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=endeavour/displays/config.env
source "$SCRIPT_DIR/config.env"
# shellcheck source=endeavour/displays/lib.sh
source "$SCRIPT_DIR/lib.sh"

PROFILE=${1:-auto}
PROFILES_DIR=$(resolve_profiles_dir "$SCRIPT_DIR")
MONITORS_CONF="${HOME}/.config/hypr/monitors.conf"
STATE_FILE="${XDG_RUNTIME_DIR:-/tmp}/dotfiles-display-profile"
COOLDOWN_FILE="${XDG_RUNTIME_DIR:-/tmp}/dotfiles-display-cooldown"
MIGRATE="$SCRIPT_DIR/migrate-session.sh"

log() { echo "displays: $*"; }

set_cooldown() {
    echo $(($(date +%s) + ${APPLY_COOLDOWN_SEC:-8})) >"$COOLDOWN_FILE"
}

require_hypr() {
    command -v hyprctl >/dev/null || { log "hyprctl missing"; exit 1; }
    hyprctl version >/dev/null 2>&1 || { log "not in Hyprland"; exit 1; }
}

find_laptop_monitor() {
    hyprctl monitors all -j | python3 -c "
import json, sys
pat = sys.argv[1]
for m in json.load(sys.stdin):
    if pat in m.get('name', ''):
        print(m['name'])
        break
" "$LAPTOP_PATTERN" 2>/dev/null || echo "eDP-1"
}

detect_profile() {
    export HOME_DOCK_DESCRIPTIONS WORK_DOCK_DESCRIPTIONS LAPTOP_PATTERN
    python3 <<'PY'
import json, os, subprocess

def outputs():
    return json.loads(subprocess.check_output(["hyprctl", "monitors", "all", "-j"], text=True))

def externals(monitors, edp):
    return [
        m for m in monitors
        if edp not in m.get("name", "")
        and not m.get("disabled")
        and m.get("width", 0) > 100
        and m.get("height", 0) > 100
    ]

def dock_parts(env_key):
    spec = os.environ.get(env_key, "").strip()
    return [p for p in spec.split("|") if p]

edp = os.environ.get("LAPTOP_PATTERN", "eDP")
all_m = outputs()
descs = " ".join(m.get("description", "") for m in all_m)
connected = externals(all_m, edp)
active = externals(
    json.loads(subprocess.check_output(["hyprctl", "monitors", "-j"], text=True)), edp)
# Hotplugged outputs can appear in `monitors all` before they are active in monitors -j.
dock_count = max(len(connected), len(active))

def dock_match(env_key, min_count):
    parts = dock_parts(env_key)
    if len(parts) < min_count:
        return False
    return all(p in descs for p in parts) and dock_count >= min_count

def partial_dock(env_key):
    parts = dock_parts(env_key)
    if not parts:
        return False
    matched = sum(1 for p in parts if p in descs)
    return 0 < matched < len(parts)

if dock_match("HOME_DOCK_DESCRIPTIONS", 3):
    print("home")
elif dock_match("WORK_DOCK_DESCRIPTIONS", 2):
    print("work")
elif partial_dock("HOME_DOCK_DESCRIPTIONS") or partial_dock("WORK_DOCK_DESCRIPTIONS"):
    print("skip")
elif dock_count == 0:
    print("laptop")
else:
    print("skip")
PY
}

resolve_profile_lines() {
    local prof_file=$1
    export PROF_FILE="$prof_file" LAPTOP_PATTERN HOME_DOCK_DESCRIPTIONS WORK_DOCK_DESCRIPTIONS
    python3 <<'PY'
import json, os, subprocess, sys
from pathlib import Path

path = Path(os.environ["PROF_FILE"])
edp = os.environ.get("LAPTOP_PATTERN", "eDP")
all_m = json.loads(subprocess.check_output(["hyprctl", "monitors", "all", "-j"], text=True))

def dock_parts(env_key):
    spec = os.environ.get(env_key, "").strip()
    return [p for p in spec.split("|") if p]

def dock_tokens():
    tokens = []
    for key in ("HOME_DOCK_DESCRIPTIONS", "WORK_DOCK_DESCRIPTIONS"):
        tokens.extend(dock_parts(key))
    tokens.extend(("0x41AD", "Samsung Electric Company", "ViewSonic", "Acer", "Dell Inc."))
    seen = set()
    out = []
    for t in sorted(tokens, key=len, reverse=True):
        if t not in seen:
            seen.add(t)
            out.append(t)
    return out

def find_name(desc_comment: str):
    desc = desc_comment.lstrip("# ").strip()
    matched = [t for t in dock_tokens() if t in desc or t.lower() in desc.lower()]
    for token in matched:
        hits = [m for m in all_m if token in (m.get("description") or "")]
        if len(hits) == 1:
            return hits[0]["name"]
    if edp in desc_comment:
        for m in all_m:
            if edp in m.get("name", ""):
                return m.get("name")
    return None

out = []
pending = None
for raw in path.read_text().splitlines():
    line = raw.strip()
    if not line or line.startswith("# profile="):
        continue
    if line.startswith("#"):
        pending = line
        continue
    if not line.startswith("monitor="):
        continue
    body = line[len("monitor="):]
    parts = body.split(",")
    rest = ",".join(parts[1:])
    name = find_name(pending or "") if pending else None
    if not name:
        name = parts[0]
    out.append(f"monitor={name},{rest}" if rest else f"monitor={name}")
    pending = None

if not out:
    sys.exit("no monitor= lines", 1)
for ln in out:
    print(ln)
PY
}

resolve_and_apply() {
    local prof=$1
    local prof_file="$PROFILES_DIR/${prof}.hypr"
    local target_mon=""
    local -a lines=()

    if [[ ! -f "$prof_file" ]] || ! grep -q '^monitor=' "$prof_file" 2>/dev/null; then
        log "profile '$prof' missing — run: ./capture-layout.sh $prof > profiles/$prof.hypr"
        return 1
    fi

    mapfile -t lines < <(resolve_profile_lines "$prof_file") || return 1

    {
        echo "# profile=$prof applied $(date -Iseconds)"
        printf '%s\n' "${lines[@]}"
    } >"$MONITORS_CONF"

    log "applied $prof → $MONITORS_CONF"
    printf '  %s\n' "${lines[@]}" >&2

    set_cooldown
    hyprctl reload
    echo "$prof" >"$STATE_FILE"

    # Undock: enable internal panel in monitors.conf first (above), then move session.
    if [[ "$prof" == laptop ]]; then
        local target_mon brightness
        target_mon=$(find_laptop_monitor)
        sleep 0.35
        if [[ -n "$target_mon" && -x "$MIGRATE" ]]; then
            log "moving session → $target_mon"
            "$MIGRATE" "$target_mon" || true
        fi
        hyprctl dispatch dpms on 2>/dev/null || true
        brightness="${HOME}/.config/ml4w/scripts/brightness-laptop.sh"
        if [[ -x "$brightness" ]]; then
            "$brightness" restore || true
        fi
        if [[ -n "$target_mon" ]]; then
            hyprctl dispatch focusmonitor "$target_mon" 2>/dev/null || true
        fi
    fi

    waybar_launch="${HOME}/.config/ml4w/scripts/waybar-launch.sh"
    if [[ -x "$waybar_launch" ]]; then
        log "relaunching waybar"
        "$waybar_launch" &
    fi
}

main() {
    require_hypr

    if [[ "$PROFILE" == auto ]]; then
        PROFILE=$(detect_profile)
        log "detected: $PROFILE"
        [[ "$PROFILE" == skip ]] && { log "partial setup — no change"; exit 0; }
        current=$(cat "$STATE_FILE" 2>/dev/null || true)
        if [[ "$PROFILE" == "$current" ]]; then
            log "already on $PROFILE — no change"
            exit 0
        fi
    fi

    if [[ "$PROFILE" == detect ]]; then
        PROFILE=$(detect_profile)
        echo "$PROFILE"
        exit 0
    fi

    case "$PROFILE" in
        home|laptop|work) resolve_and_apply "$PROFILE" || exit 1 ;;
        recover) resolve_and_apply laptop || exit 1 ;;
        *) log "unknown profile: $PROFILE"; exit 1 ;;
    esac
}

main
