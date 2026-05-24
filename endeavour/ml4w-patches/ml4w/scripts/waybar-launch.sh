#!/usr/bin/env bash
# Full Waybar on the primary monitor; minimal bar on portrait/secondary outputs.
set -euo pipefail

CFG="${HOME}/.config/waybar"
STYLE="${CFG}/style.css"
RUNTIME="${XDG_RUNTIME_DIR:-/tmp}/dotfiles-waybar"
CONFIG_ENV="@DOTFILES@/endeavour/displays/config.env"

[[ -f "$CONFIG_ENV" ]] && source "$CONFIG_ENV"
: "${WAYBAR_PRIMARY_PATTERN:=VX3276-QHD}"

mkdir -p "$RUNTIME"

pkill -x waybar 2>/dev/null || true
sleep 0.15

if ! command -v hyprctl >/dev/null 2>&1 || ! hyprctl monitors -j >/dev/null 2>&1; then
    exec waybar -c "${CFG}/config-primary.jsonc" -s "$STYLE"
fi

export CFG RUNTIME WAYBAR_PRIMARY_PATTERN
python3 <<'PY'
import json
import os
import re
import subprocess
import sys
from pathlib import Path

cfg_dir = Path(os.environ["CFG"])
runtime = Path(os.environ["RUNTIME"])
pattern = os.environ.get("WAYBAR_PRIMARY_PATTERN", "")


def read_jsonc(path: Path) -> dict:
    text = path.read_text()
    text = re.sub(r"/\*.*?\*/", "", text, flags=re.S)
    text = re.sub(r"(^|[^:])//.*$", r"\1", text, flags=re.M)
    text = re.sub(r",(\s*[}\]])", r"\1", text)
    return json.loads(text)


def write_json(path: Path, data: dict) -> None:
    path.write_text(json.dumps(data, indent=4) + "\n")


monitors = json.loads(subprocess.check_output(["hyprctl", "monitors", "-j"], text=True))
active = [m for m in monitors if not m.get("disabled")]

primary = next(
    (m["name"] for m in active if pattern and pattern in m.get("description", "")),
    None,
)
secondary = [m["name"] for m in active if m["name"] != primary]

primary_tmpl = cfg_dir / "config-primary.jsonc"
secondary_tmpl = cfg_dir / "config-secondary.jsonc"
if not primary_tmpl.exists():
    sys.exit(f"missing {primary_tmpl}")

primary_cfg = read_jsonc(primary_tmpl)
primary_out = runtime / "config-primary.json"
secondary_out = runtime / "config-secondary.json"

if not primary or not secondary:
    primary_cfg.pop("output", None)
    write_json(primary_out, primary_cfg)
    secondary_out.unlink(missing_ok=True)
else:
    primary_cfg["output"] = primary
    write_json(primary_out, primary_cfg)

    if secondary_tmpl.exists():
        secondary_cfg = read_jsonc(secondary_tmpl)
        secondary_cfg["output"] = secondary
        write_json(secondary_out, secondary_cfg)
    else:
        secondary_out.unlink(missing_ok=True)
PY

start_waybar() {
    local name=$1
    local config=$2
    waybar -c "$config" -s "$STYLE" >>"${RUNTIME}/${name}.log" 2>&1 &
}

if [[ -f "${RUNTIME}/config-secondary.json" ]]; then
    start_waybar primary "${RUNTIME}/config-primary.json"
    start_waybar secondary "${RUNTIME}/config-secondary.json"
else
    start_waybar primary "${RUNTIME}/config-primary.json"
fi
