#!/usr/bin/env bash
# Full Waybar on the primary monitor; minimal bar on each secondary output (Sway).
# Uses the same ~/.config/waybar templates as Hyprland/ML4W with sway/* modules.
set -euo pipefail

if [[ "${1:-}" == toggle ]]; then
    if pgrep -x waybar >/dev/null; then
        pkill -x waybar
    else
        exec "$0"
    fi
    exit 0
fi

CFG="${HOME}/.config/waybar"
STYLE_SRC="${CFG}/style.css"
RUNTIME="${XDG_RUNTIME_DIR:-/tmp}/dotfiles-waybar-sway"
CONFIG_ENV="${HOME}/.config/dotfiles/endeavour/displays/config.env"
PATCHES="${HOME}/.config/dotfiles/endeavour/ml4w-patches"

[[ -f "$CONFIG_ENV" ]] && source "$CONFIG_ENV"
: "${WAYBAR_PRIMARY_PATTERN:=VX3276-QHD}"
: "${WORK_WAYBAR_PRIMARY_PATTERN:=}"

mkdir -p "$RUNTIME"

LOCK="${RUNTIME}/launch.lock"
exec 9>"$LOCK"
if ! flock -w 15 9; then
    exit 0
fi

pkill -x waybar 2>/dev/null || true
sleep 0.15

if ! command -v swaymsg >/dev/null 2>&1 || ! swaymsg -t get_version >/dev/null 2>&1; then
    notify-send -t 3000 waybar "Sway not running"
    exit 1
fi

export CFG RUNTIME WAYBAR_PRIMARY_PATTERN WORK_WAYBAR_PRIMARY_PATTERN PATCHES STYLE_SRC
python3 <<'PY'
import json
import os
import re
import subprocess
import sys
from pathlib import Path

cfg_dir = Path(os.environ["CFG"])
runtime = Path(os.environ["RUNTIME"])
patches = Path(os.environ["PATCHES"]) / "waybar"
style_src = Path(os.environ["STYLE_SRC"])
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


def output_desc(out: dict) -> str:
    return f"{out.get('make', '')} {out.get('model', '')}".strip()


def replace_block(text: str, key: str, snippet: str) -> tuple[str, bool]:
    m = re.search(rf'[ \t]*"{re.escape(key)}"\s*:\s*\{{', text)
    if not m:
        return text, False
    start = m.start()
    i = m.end() - 1
    depth = 0
    for j in range(i, len(text)):
        c = text[j]
        if c == "{":
            depth += 1
        elif c == "}":
            depth -= 1
            if depth == 0:
                end = j + 1
                if end < len(text) and text[end] == ",":
                    end += 1
                replacement = snippet.strip().rstrip(",")
                return text[:start] + replacement + "," + text[end:], True
    return text, False


def parse_jsonc(text: str) -> dict:
    text = re.sub(r"/\*.*?\*/", "", text, flags=re.S)
    text = re.sub(r"(^|[^:])//.*$", r"\1", text, flags=re.M)
    text = re.sub(r",(\s*[}\]])", r"\1", text)
    return json.loads(text)


def parse_snippet(path: Path) -> dict:
    raw = path.read_text().strip().rstrip(",")
    return parse_jsonc("{" + raw + "}")


def sway_modules_json() -> Path:
    src = cfg_dir / "modules.json"
    if not src.exists():
        sys.exit(f"missing {src}")
    data = parse_jsonc(src.read_text())
    for key in (
        "hyprland/workspaces",
        "hyprland/window",
        "sway/workspaces",
        "sway/window",
    ):
        data.pop(key, None)
    for snippet_name in ("sway-workspaces.jsonc", "sway-window.jsonc"):
        data.update(parse_snippet(patches / snippet_name))
    data = {k.replace("hyprland/", "sway/"): v for k, v in data.items()}
    out = runtime / "modules-sway.json"
    out.write_text(json.dumps(data, indent=4) + "\n")
    return out


def patch_config(data: dict, modules_path: Path) -> dict:
    def walk(obj):
        if isinstance(obj, dict):
            return {k.replace("hyprland/", "sway/"): walk(v) for k, v in obj.items()}
        if isinstance(obj, list):
            return [walk(x) for x in obj]
        if isinstance(obj, str):
            if obj.endswith("modules.json"):
                return str(modules_path)
            return obj.replace("hyprland/", "sway/")
        return obj
    return walk(data)


for old in runtime.glob("config-secondary*.json"):
    old.unlink(missing_ok=True)
runtime.joinpath("config-secondary.json").unlink(missing_ok=True)

modules_path = sway_modules_json()

outputs = json.loads(subprocess.check_output(["swaymsg", "-t", "get_outputs"], text=True))
active = [o for o in outputs if o.get("active")]

primary = None
for pattern in patterns:
    primary = next((o["name"] for o in active if pattern in output_desc(o)), None)
    if primary:
        break

if not primary and active:
    primary = max(
        active,
        key=lambda o: (o.get("rect") or {}).get("width", 0)
        * (o.get("rect") or {}).get("height", 0),
    )["name"]

secondary = [o["name"] for o in active if o["name"] != primary]

primary_tmpl = cfg_dir / "config-primary.jsonc"
secondary_tmpl = cfg_dir / "config-secondary.jsonc"
if not primary_tmpl.exists():
    sys.exit(f"missing {primary_tmpl}")

primary_cfg = patch_config(read_jsonc(primary_tmpl), modules_path)
primary_out = runtime / "config-primary.json"

if not secondary:
    primary_cfg.pop("output", None)
    write_json(primary_out, primary_cfg)
else:
    primary_cfg["output"] = primary
    write_json(primary_out, primary_cfg)
    if secondary_tmpl.exists():
        secondary_base = patch_config(read_jsonc(secondary_tmpl), modules_path)
        for name in secondary:
            secondary_cfg = dict(secondary_base)
            secondary_cfg["output"] = name
            write_json(runtime / f"config-secondary-{name}.json", secondary_cfg)

# Waybar sway/window uses #window; keep hyprland-window CSS rules too.
style_out = runtime / "style.css"
overrides = patches / "style-overrides.css"
marker_block = "/* --- dotfiles waybar overrides"
if style_src.exists():
    css = style_src.read_text()
    css = css.replace("#hyprland-window", "#window")
    css = css.replace("#hyprland-language", "#language")
    if overrides.exists():
        if marker_block in css:
            css = css[: css.index(marker_block)]
        css = css.rstrip() + "\n\n" + overrides.read_text().lstrip()
    style_out.write_text(css)
else:
    style_out.write_text(overrides.read_text() if overrides.exists() else "")
PY

# Children must not inherit the flock fd (would block all future relaunches).
exec 9>&-

STYLE="${RUNTIME}/style.css"

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
