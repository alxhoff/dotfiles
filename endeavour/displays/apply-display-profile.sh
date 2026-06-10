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

find_primary_monitor() {
    local prof=${1:-home}
    export WAYBAR_PRIMARY_PATTERN WORK_WAYBAR_PRIMARY_PATTERN PROFILE="$prof"
    python3 <<'PY'
import json, os, subprocess

profile = os.environ.get("PROFILE", "home")
patterns = []
if profile == "work":
    patterns.append(os.environ.get("WORK_WAYBAR_PRIMARY_PATTERN", ""))
else:
    patterns.append(os.environ.get("WAYBAR_PRIMARY_PATTERN", ""))
patterns.append(os.environ.get("WORK_WAYBAR_PRIMARY_PATTERN", ""))
patterns.append(os.environ.get("WAYBAR_PRIMARY_PATTERN", ""))
patterns = [p.strip() for p in patterns if p.strip()]

monitors = json.loads(subprocess.check_output(["hyprctl", "monitors", "-j"], text=True))
edp = os.environ.get("LAPTOP_PATTERN", "eDP")
active = [
    m for m in monitors
    if not m.get("disabled")
    and edp not in m.get("name", "")
]
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

profile_disables_laptop() {
    local prof_file=$1
    local laptop_mon
    laptop_mon=$(find_laptop_monitor)
    [[ -n "$laptop_mon" ]] || return 1
    grep -qE "^monitor=${laptop_mon},disable$" "$prof_file" 2>/dev/null \
        || grep -qE "^monitor=.*${LAPTOP_PATTERN}.*,disable$" "$prof_file" 2>/dev/null
}

laptop_monitor_active() {
    local laptop_mon
    laptop_mon=$(find_laptop_monitor)
    [[ -n "$laptop_mon" ]] || return 1
    hyprctl monitors -j | python3 -c "
import json, sys
name = sys.argv[1]
for m in json.load(sys.stdin):
    if m.get('name') == name and not m.get('disabled'):
        raise SystemExit(0)
raise SystemExit(1)
" "$laptop_mon"
}

migrate_off_laptop_if_needed() {
    local prof=$1
    local prof_file=$2
    local primary_mon laptop_mon

    profile_disables_laptop "$prof_file" || return 0
    laptop_monitor_active || return 0
    [[ -x "$MIGRATE" ]] || return 0

    primary_mon=$(find_primary_monitor "$prof")
    [[ -n "$primary_mon" ]] || return 0
    laptop_mon=$(find_laptop_monitor)

    log "moving session off $laptop_mon → $primary_mon before disabling internal panel"
    "$MIGRATE" "$primary_mon" || true
}

schedule_session_refresh() {
    local refresh="${HOME}/.config/ml4w/scripts/refresh-session-layouts.sh"
    local flag="${XDG_RUNTIME_DIR:-/tmp}/dotfiles-display-needs-refresh"

    if pgrep -x hyprlock >/dev/null 2>&1; then
        touch "$flag"
        log "deferring layout refresh until unlock"
        return 0
    fi

    if [[ -x "$refresh" ]]; then
        log "refreshing session layouts"
        "$refresh" || true
    fi
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
connected = externals(all_m, edp)
active = externals(
    json.loads(subprocess.check_output(["hyprctl", "monitors", "-j"], text=True)), edp)

# Undocked: no active externals. Ignore stale `monitors all` descriptions (they block laptop).
if not active:
    if connected:
        print("skip")  # hotplug: outputs in `all` but not active yet
    else:
        print("laptop")
    raise SystemExit(0)

active_descs = " ".join(m.get("description", "") for m in active)
active_count = len(active)

def dock_match(env_key, min_count):
    parts = dock_parts(env_key)
    if len(parts) < min_count:
        return False
    return all(p in active_descs for p in parts) and active_count >= min_count

def partial_dock(env_key):
    parts = dock_parts(env_key)
    if not parts:
        return False
    matched = sum(1 for p in parts if p in active_descs)
    return 0 < matched < len(parts)

if dock_match("HOME_DOCK_DESCRIPTIONS", 3):
    print("home")
elif dock_match("WORK_DOCK_DESCRIPTIONS", 2):
    print("work")
elif partial_dock("HOME_DOCK_DESCRIPTIONS") or partial_dock("WORK_DOCK_DESCRIPTIONS"):
    print("skip")
else:
    print("skip")
PY
}

stable_detect() {
    local attempts=${1:-10}
    local delay=${2:-2}
    local i result best="skip"
    local first

    first=$(detect_profile)
    case "$first" in
        home | work)
            echo "$first"
            return 0
            ;;
        laptop)
            if [[ "$(dock_outputs_present)" != yes ]]; then
                echo laptop
                return 0
            fi
            best="skip"
            ;;
        skip)
            best="skip"
            ;;
    esac

    for ((i = 0; i < attempts; i++)); do
        result=$(detect_profile)
        case "$result" in
            home | work)
                echo "$result"
                return 0
                ;;
            laptop)
                if [[ "$(dock_outputs_present)" != yes ]]; then
                    echo laptop
                    return 0
                fi
                best="skip"
                ;;
            skip)
                best="skip"
                ;;
        esac
        sleep "$delay"
    done

    echo "$best"
}

dock_outputs_present() {
    export HOME_DOCK_DESCRIPTIONS WORK_DOCK_DESCRIPTIONS LAPTOP_PATTERN
    python3 <<'PY'
import json, os, subprocess

def outputs():
    return json.loads(subprocess.check_output(["hyprctl", "monitors", "all", "-j"], text=True))

def dock_parts(env_key):
    return [p for p in os.environ.get(env_key, "").split("|") if p]

edp = os.environ.get("LAPTOP_PATTERN", "eDP")
active = json.loads(subprocess.check_output(["hyprctl", "monitors", "-j"], text=True))
externals = [
    m for m in active
    if edp not in m.get("name", "")
    and not m.get("disabled")
    and m.get("width", 0) > 100
    and m.get("height", 0) > 100
]
print("yes" if externals else "no")
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

needs_refresh() {
    local prof=$1
    local prof_file="$PROFILES_DIR/${prof}.hypr"
    local answer
    [[ -f "$prof_file" ]] || return 1

    local -a lines=()
    mapfile -t lines < <(resolve_profile_lines "$prof_file") || return 1

    export REFRESH_PROFILE="$prof" LAPTOP_PATTERN
    answer=$(printf '%s\n' "${lines[@]}" | python3 <<'PY'
import json, os, subprocess, sys

profile = os.environ["REFRESH_PROFILE"]
edp = os.environ.get("LAPTOP_PATTERN", "eDP")
expected = [ln.strip() for ln in sys.stdin if ln.strip()]

def active_monitors():
    return json.loads(subprocess.check_output(["hyprctl", "monitors", "-j"], text=True))

def parse_line(line: str):
    body = line[len("monitor="):]
    parts = body.split(",")
    name = parts[0]
    disabled = body.rstrip().endswith("disable") or (len(parts) == 2 and parts[1] == "disable")
    transform = 0
    if "transform" in parts:
        idx = parts.index("transform")
        if idx + 1 < len(parts):
            transform = int(parts[idx + 1])
    return {"name": name, "disabled": disabled, "transform": transform}

def externals(monitors):
    return [
        m for m in monitors
        if edp not in m.get("name", "")
        and not m.get("disabled")
        and m.get("width", 0) > 100
    ]

active = active_monitors()
active_by_name = {m["name"]: m for m in active}

for line in expected:
    exp = parse_line(line)
    act = active_by_name.get(exp["name"])
    if exp["disabled"]:
        if act and not act.get("disabled"):
            print("yes")
            raise SystemExit(0)
        continue
    if not act:
        print("yes")
        raise SystemExit(0)
    if act.get("transform", 0) != exp["transform"]:
        print("yes")
        raise SystemExit(0)

# Laptop panel appeared after dock profile (lid open / plug-before-open).
for line in expected:
    exp = parse_line(line)
    if exp["disabled"] and edp in exp["name"]:
        for m in active:
            if edp in m.get("name", "") and not m.get("disabled"):
                print("yes")
                raise SystemExit(0)

if profile == "laptop" and externals(active):
    print("yes")
    raise SystemExit(0)

print("no")
PY
)
    [[ "$answer" == yes ]]
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

    migrate_off_laptop_if_needed "$prof" "$prof_file"

    {
        echo "# profile=$prof applied $(date -Iseconds)"
        printf '%s\n' "${lines[@]}"
    } >"$MONITORS_CONF"

    log "applied $prof → $MONITORS_CONF"
    printf '  %s\n' "${lines[@]}" >&2

    set_cooldown
    hyprctl reload
    echo "$prof" >"$STATE_FILE"

    if [[ "$prof" == home ]]; then
        local laptop_mon=""
        laptop_mon=$(find_laptop_monitor)
        if [[ -n "$laptop_mon" ]]; then
            hyprctl keyword monitor "${laptop_mon},disable" 2>/dev/null || true
        fi
    fi

    sleep 0.2
    schedule_session_refresh

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
        PROFILE=$(stable_detect)
        log "detected: $PROFILE"
        [[ "$PROFILE" == skip ]] && { log "partial setup — no change"; exit 0; }
        if [[ "$PROFILE" == laptop ]] && [[ "$(dock_outputs_present)" == yes ]]; then
            log "deferring laptop — dock outputs still present"
            exit 0
        fi
        current=$(cat "$STATE_FILE" 2>/dev/null || true)
        if [[ "$PROFILE" == "$current" ]]; then
            if needs_refresh "$PROFILE"; then
                log "refreshing $PROFILE layout (monitors changed or drifted)"
            else
                log "already on $PROFILE — no change"
                exit 0
            fi
        fi
    fi

    if [[ "$PROFILE" == detect ]]; then
        PROFILE=$(detect_profile)
        echo "$PROFILE"
        exit 0
    fi

    if [[ "$PROFILE" == needs-refresh ]]; then
        PROFILE=$(detect_profile)
        if [[ "$PROFILE" == skip ]]; then
            echo no
            exit 0
        fi
        current=$(cat "$STATE_FILE" 2>/dev/null || true)
        if [[ "$PROFILE" != "$current" ]]; then
            echo yes
            exit 0
        fi
        if needs_refresh "$PROFILE"; then
            echo yes
        else
            echo no
        fi
        exit 0
    fi

    case "$PROFILE" in
        home|work) resolve_and_apply "$PROFILE" || exit 1 ;;
        laptop)
            if [[ "$(dock_outputs_present)" == yes ]]; then
                log "refusing laptop apply — external monitors connected"
                exit 0
            fi
            resolve_and_apply "$PROFILE" || exit 1
            ;;
        recover) resolve_and_apply laptop || exit 1 ;;
        *) log "unknown profile: $PROFILE"; exit 1 ;;
    esac
}

main
