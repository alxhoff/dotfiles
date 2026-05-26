#!/usr/bin/env bash
# Full Waybar on the primary monitor; minimal bar on each secondary output.
set -euo pipefail

CFG="${HOME}/.config/waybar"
STYLE="${CFG}/style.css"
RUNTIME="${XDG_RUNTIME_DIR:-/tmp}/dotfiles-waybar"
CONFIG_ENV="${HOME}/.config/dotfiles/endeavour/displays/config.env"

[[ -f "$CONFIG_ENV" ]] && source "$CONFIG_ENV"
: "${WAYBAR_PRIMARY_PATTERN:=VX3276-QHD}"
: "${WORK_WAYBAR_PRIMARY_PATTERN:=}"

mkdir -p "$RUNTIME"

pkill -x waybar 2>/dev/null || true
sleep 0.15

if ! command -v hyprctl >/dev/null 2>&1 || ! hyprctl monitors -j >/dev/null 2>&1; then
    exec waybar -c "${CFG}/config-primary.jsonc" -s "$STYLE"
fi

export CFG RUNTIME WAYBAR_PRIMARY_PATTERN WORK_WAYBAR_PRIMARY_PATTERN
python3 <<'PY'
import json
import os
import re
import subprocess
import sys
from pathlib import Path

cfg_dir = Path(os.environ["CFG"])
runtime = Path(os.environ["RUNTIME"])
patterns = [
    p.strip()
    for p in (
        os.environ.get("WAYBAR_PRIMARY_PATTERN", ""),
        os.environ.get("WORK_WAYBAR_PRIMARY_PATTERN", ""),
    )
    if p.strip()
]


def read_jsonc(path: Path) -> dict:
    text = path.read_text()
    text = re.sub(r"/\*.*?\*/", "", text, flags=re.S)
    text = re.sub(r"(^|[^:])//.*$", r"\1", text, flags=re.M)
    text = re.sub(r",(\s*[}\]])", r"\1", text)
    return json.loads(text)


def write_json(path: Path, data: dict) -> None:
    path.write_text(json.dumps(data, indent=4) + "\n")


for old in runtime.glob("config-secondary*.json"):
    old.unlink(missing_ok=True)
runtime.joinpath("config-secondary.json").unlink(missing_ok=True)

monitors = json.loads(subprocess.check_output(["hyprctl", "monitors", "-j"], text=True))
active = [m for m in monitors if not m.get("disabled")]

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

secondary = [m["name"] for m in active if m["name"] != primary]

primary_tmpl = cfg_dir / "config-primary.jsonc"
secondary_tmpl = cfg_dir / "config-secondary.jsonc"
if not primary_tmpl.exists():
    sys.exit(f"missing {primary_tmpl}")

primary_cfg = read_jsonc(primary_tmpl)
primary_out = runtime / "config-primary.json"

if not secondary:
    primary_cfg.pop("output", None)
    write_json(primary_out, primary_cfg)
else:
    primary_cfg["output"] = primary
    write_json(primary_out, primary_cfg)

    if secondary_tmpl.exists():
        secondary_base = read_jsonc(secondary_tmpl)
        for name in secondary:
            secondary_cfg = dict(secondary_base)
            secondary_cfg["output"] = name
            write_json(runtime / f"config-secondary-{name}.json", secondary_cfg)
PY

start_waybar() {
    local name=$1
    local config=$2
    waybar -c "$config" -s "$STYLE" >>"${RUNTIME}/${name}.log" 2>&1 &
}

start_waybar primary "${RUNTIME}/config-primary.json"

shopt -s nullglob
secondary_cfgs=("${RUNTIME}"/config-secondary-*.json)
shopt -u nullglob

for cfg in "${secondary_cfgs[@]}"; do
    name=$(basename "$cfg" .json)
    start_waybar "$name" "$cfg"
done
