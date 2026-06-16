#!/usr/bin/env bash
# Apply display profiles on Sway (reads the same *.hypr profile files).
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=endeavour/displays/config.env
source "$SCRIPT_DIR/config.env"
# shellcheck source=endeavour/displays/lib.sh
source "$SCRIPT_DIR/lib.sh"

PROFILE=${1:-auto}
PROFILES_DIR=$(resolve_profiles_dir "$SCRIPT_DIR")
STATE_FILE="${XDG_RUNTIME_DIR:-/tmp}/dotfiles-display-profile"
MIGRATE="$SCRIPT_DIR/migrate-session-sway.sh"
WAYBAR_LAUNCH="${HOME}/.config/sway/scripts/waybar-launch.sh"
WALLPAPER_RESTORE="${HOME}/.config/sway/scripts/wallpaper-restore.sh"
DROPDOWN_TERM="${HOME}/.config/ml4w/scripts/dropdown-terminal.sh"
DROPDOWN_SPOTIFY="${HOME}/.config/ml4w/scripts/dropdown-spotify.sh"

log() { echo "displays(sway): $*"; }

require_sway() {
    command -v swaymsg >/dev/null || { log "swaymsg missing"; exit 1; }
    swaymsg -t get_version >/dev/null 2>&1 || { log "not in Sway"; exit 1; }
}

main() {
    require_sway
    export PROFILE PROFILES_DIR STATE_FILE LAPTOP_PATTERN MIGRATE \
        HOME_DOCK_DESCRIPTIONS WORK_DOCK_DESCRIPTIONS \
        WAYBAR_PRIMARY_PATTERN WORK_WAYBAR_PRIMARY_PATTERN SCRIPT_DIR
    local apply_rc=0
    python3 <<'PY' || apply_rc=$?
import json
import os
import subprocess
import sys
from pathlib import Path

profile = os.environ["PROFILE"]
profiles_dir = Path(os.environ["PROFILES_DIR"])
state_file = Path(os.environ["STATE_FILE"])
script_dir = Path(os.environ["SCRIPT_DIR"])
edp = os.environ.get("LAPTOP_PATTERN", "eDP")


def log(msg):
    print(f"displays(sway): {msg}", file=sys.stderr)


def sway(*args):
    subprocess.run(["swaymsg", *args], check=False, capture_output=True)


def outputs(all_outputs=False):
    data = json.loads(subprocess.check_output(["swaymsg", "-t", "get_outputs"], text=True))
    if all_outputs:
        return data
    return [o for o in data if o.get("active")]


def desc(o):
    return f"{o.get('make', '')} {o.get('model', '')}".strip()


def dock_parts(env_key):
    return [p for p in os.environ.get(env_key, "").split("|") if p]


def externals(active):
    return [
        o for o in active
        if edp not in o.get("name", "")
        and o.get("active")
        and o["rect"]["width"] > 100
        and o["rect"]["height"] > 100
    ]


def detect_profile():
    active = outputs()
    connected = externals(outputs(all_outputs=True))
    live = externals(active)
    if not live:
        current = state_file.read_text().strip() if state_file.exists() else ""
        if current in ("home", "work"):
            return "laptop"
        if connected:
            return "skip"
        return "laptop"
    active_descs = " ".join(desc(o) for o in live)

    def dock_match(env_key, min_count):
        parts = dock_parts(env_key)
        return len(parts) >= min_count and all(p in active_descs for p in parts) and len(live) >= min_count

    def partial(env_key):
        parts = dock_parts(env_key)
        if not parts:
            return False
        matched = sum(1 for p in parts if p in active_descs)
        return 0 < matched < len(parts)

    if dock_match("HOME_DOCK_DESCRIPTIONS", 3):
        return "home"
    if dock_match("WORK_DOCK_DESCRIPTIONS", 2):
        return "work"
    if partial("HOME_DOCK_DESCRIPTIONS") or partial("WORK_DOCK_DESCRIPTIONS"):
        return "skip"
    return "skip"


def dock_outputs_present():
    return "yes" if externals(outputs()) else "no"


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


def resolve_name(comment, fallback):
    tokens = dock_tokens()
    text = (comment or "").lstrip("# ").strip()
    for token in tokens:
        if token in text:
            hits = [o for o in outputs(all_outputs=True) if token in desc(o)]
            if len(hits) == 1:
                return hits[0]["name"]
    if edp in text:
        for o in outputs(all_outputs=True):
            if edp in o.get("name", ""):
                return o["name"]
    return fallback


def hypr_transform_to_sway(value):
    # Home dock portrait panels: Hypr transform,1 is 90° in profile capture but
    # needs Sway 270° for correct edge-up (wlroots direction differs in practice).
    return {0: "normal", 1: "270", 2: "180", 3: "90"}.get(int(value), "normal")


def normalize_mode(mode):
    if mode == "preferred":
        return "preferred"
    # Hypr uses 2560x1440@60 — Sway wants 2560x1440 or 2560x1440@59.950Hz
    return mode.split("@", 1)[0]


def parse_hypr_line(line):
    body = line[len("monitor="):]
    parts = body.split(",")
    name = parts[0]
    if body.rstrip().endswith("disable") or (len(parts) == 2 and parts[1] == "disable"):
        return {"name": name, "disable": True}
    mode = parts[1] if len(parts) > 1 else "preferred"
    pos = parts[2] if len(parts) > 2 else "auto"
    transform = "normal"
    if "transform" in parts:
        idx = parts.index("transform")
        if idx + 1 < len(parts):
            transform = hypr_transform_to_sway(parts[idx + 1])
    x, y = 0, 0
    if "x" in pos:
        xs, ys = pos.split("x", 1)
        x, y = int(xs), int(ys)
    elif pos == "auto":
        x, y = None, None
    return {"name": name, "disable": False, "mode": mode, "x": x, "y": y, "transform": transform}


def resolve_profile_lines(prof_file: Path):
    pending = None
    out = []
    for raw in prof_file.read_text().splitlines():
        line = raw.strip()
        if not line or line.startswith("# profile="):
            continue
        if line.startswith("#"):
            pending = line
            continue
        if not line.startswith("monitor="):
            continue
        parsed = parse_hypr_line(line)
        parsed["name"] = resolve_name(pending, parsed["name"])
        out.append(parsed)
        pending = None
    return out


def to_swaymsg(spec):
    if spec["disable"]:
        return ["output", spec["name"], "disable"]
    args = ["output", spec["name"], "enable"]
    mode = normalize_mode(spec["mode"])
    if mode == "preferred":
        args.extend(["mode", "preferred"])
    else:
        args.extend(["mode", mode])
    if spec["x"] is not None and spec["y"] is not None:
        args.extend(["position", str(spec["x"]), str(spec["y"])])
    else:
        args.extend(["position", "auto"])
    if spec["transform"] != "normal":
        args.extend(["transform", spec["transform"]])
    return args


def apply_profile(prof):
    prof_file = profiles_dir / f"{prof}.hypr"
    if not prof_file.is_file():
        log(f"missing {prof_file}")
        raise SystemExit(1)
    specs = resolve_profile_lines(prof_file)
    if not specs:
        log(f"no monitor lines in {prof_file}")
        raise SystemExit(1)
    # Position external monitors before disabling the laptop panel.
    specs.sort(key=lambda s: (s["disable"], s["name"]))
    for spec in specs:
        args = to_swaymsg(spec)
        log(f"swaymsg {' '.join(args)}")
        sway(*args)
    state_file.write_text(prof)
    log(f"applied {prof}")


def norm_sway_transform(value):
    if value is None or value == "normal" or value == 0:
        return "normal"
    if isinstance(value, str) and value.isdigit():
        return value
    return str(int(value))


def layout_drifts(prof):
    prof_file = profiles_dir / f"{prof}.hypr"
    if not prof_file.is_file():
        return False
    specs = resolve_profile_lines(prof_file)
    active = {o["name"]: o for o in outputs()}
    for spec in specs:
        name = spec["name"]
        if spec["disable"]:
            if name in active:
                return True
            continue
        live = active.get(name)
        if not live:
            return True
        if norm_sway_transform(live.get("transform")) != spec["transform"]:
            return True
        if spec["x"] is not None:
            rect = live["rect"]
            if rect["x"] != spec["x"] or rect["y"] != spec["y"]:
                return True
    return False


def needs_refresh(prof):
    # Re-apply when externals count mismatches expected dock/laptop profile.
    current = state_file.read_text().strip() if state_file.exists() else ""
    detected = detect_profile()
    if prof == "laptop" and externals(outputs()):
        return True
    if prof in ("home", "work") and not externals(outputs()):
        return True
    if layout_drifts(prof):
        return True
    return current != prof or detected == "skip"


if profile == "detect":
    print(detect_profile())
    raise SystemExit(2)

if profile == "needs-refresh":
    prof = detect_profile()
    if prof == "skip":
        print("no")
    elif prof != (state_file.read_text().strip() if state_file.exists() else ""):
        print("yes")
    elif layout_drifts(prof):
        print("yes")
    elif needs_refresh(prof):
        print("yes")
    else:
        print("no")
    raise SystemExit(2)

if profile == "auto":
    profile = detect_profile()
    log(f"detected: {profile}")
    if profile == "skip":
        log("partial setup — no change")
        raise SystemExit(2)
    if profile == "laptop" and dock_outputs_present() == "yes":
        log("deferring laptop — dock outputs still present")
        raise SystemExit(2)
    current = state_file.read_text().strip() if state_file.exists() else ""
    if profile == current and not needs_refresh(profile):
        log(f"already on {profile}")
        raise SystemExit(2)

if profile == "laptop" and dock_outputs_present() == "yes":
    log("refusing laptop apply — externals connected")
    raise SystemExit(2)

if profile not in ("home", "work", "laptop", "recover"):
    log(f"unknown profile: {profile}")
    raise SystemExit(1)

if profile == "recover":
    profile = state_file.read_text().strip() if state_file.exists() else detect_profile()
    if profile not in ("home", "work", "laptop"):
        profile = "laptop"

apply_profile(profile)
PY
    if [[ "$apply_rc" -eq 2 ]]; then
        return 0
    fi
    if [[ "$apply_rc" -ne 0 ]]; then
        return "$apply_rc"
    fi

    applied_profile=$(cat "$STATE_FILE" 2>/dev/null || true)
    if [[ "$applied_profile" == laptop ]]; then
        laptop_mon=$(
            swaymsg -t get_outputs | python3 -c "
import json, sys
pat = sys.argv[1]
for o in json.load(sys.stdin):
    if pat in o.get('name', ''):
        print(o['name'])
        break
" "$LAPTOP_PATTERN" 2>/dev/null || echo "eDP-1"
        )
        sleep 0.35
        if [[ -n "$laptop_mon" && -x "$MIGRATE" ]]; then
            log "moving session → $laptop_mon"
            "$MIGRATE" "$laptop_mon" || true
        fi
        swaymsg output "$laptop_mon" dpms on 2>/dev/null || true
        brightness="${HOME}/.config/ml4w/scripts/brightness-laptop.sh"
        if [[ -x "$brightness" ]]; then
            "$brightness" restore || true
        fi
        if [[ -n "$laptop_mon" ]]; then
            swaymsg focus output "$laptop_mon" 2>/dev/null || true
        fi
    fi

    if [[ -x "$WAYBAR_LAUNCH" ]]; then
        log "relaunching waybar"
        "$WAYBAR_LAUNCH" &
    fi
    if [[ -x "$WALLPAPER_RESTORE" ]]; then
        "$WALLPAPER_RESTORE" &
    fi
    for script in "$DROPDOWN_TERM" "$DROPDOWN_SPOTIFY"; do
        [[ -x "$script" ]] && "$script" relayout 2>/dev/null || true
    done
}

main
