#!/usr/bin/env bash
# Guake-style dropdown terminal for Sway (floating + mark + state file).
set -euo pipefail

CONFIG="${HOME}/.config/ml4w/dropdown-terminal.env"
[[ -f "$CONFIG" ]] && source "$CONFIG"

DISPLAY_CONFIG="${HOME}/.config/dotfiles/endeavour/displays/config.env"
[[ -f "$DISPLAY_CONFIG" ]] && source "$DISPLAY_CONFIG"

: "${DROPDOWN_TERM:=kitty}"
: "${DROPDOWN_CLASS:=dropdown-terminal}"
: "${DROPDOWN_TITLE:=Dropdown}"
: "${DROPDOWN_CMD:=}"
: "${DROPDOWN_SIZE:=100% 42%}"
: "${DROPDOWN_MOVE:=0 0}"
: "${DROPDOWN_MARGIN:=12}"
: "${DROPDOWN_MARK:=dropdown-terminal}"

export DROPDOWN_CLASS DROPDOWN_MARK DROPDOWN_SIZE DROPDOWN_MOVE DROPDOWN_MARGIN \
    DROPDOWN_TERM DROPDOWN_TITLE DROPDOWN_CMD \
    WAYBAR_PRIMARY_PATTERN WORK_WAYBAR_PRIMARY_PATTERN

run_sway() {
    python3 - "$@" <<'PY'
import json
import os
import subprocess
import sys
import time
from pathlib import Path

action = sys.argv[1]
dropdown_class = os.environ["DROPDOWN_CLASS"].lower()
dropdown_title = os.environ.get("DROPDOWN_TITLE", "Dropdown")
mark = os.environ["DROPDOWN_MARK"]
state_file = Path(os.environ.get("XDG_RUNTIME_DIR", "/tmp")) / "dotfiles-dropdown-terminal.state"


def sway(*args):
    subprocess.run(["swaymsg", *args], check=False, capture_output=True)


def tree():
    return json.loads(subprocess.check_output(["swaymsg", "-t", "get_tree"], text=True))


def walk(node):
    yield node
    for ch in node.get("nodes") or []:
        yield from walk(ch)
    for ch in node.get("floating_nodes") or []:
        yield from walk(ch)


def matches(node):
    if node.get("type") != "con":
        return False
    if mark in (node.get("marks") or []):
        return True
    title = (node.get("name") or "").strip()
    if title == dropdown_title:
        return True
    app_id = (node.get("app_id") or "").lower()
    props = node.get("window_properties") or {}
    klass = (props.get("class") or "").lower()
    return app_id == dropdown_class or klass == dropdown_class


def find_all():
    return [n for n in walk(tree()) if matches(n)]


def pick_node(nodes):
    if not nodes:
        return None
    for n in nodes:
        if mark in (n.get("marks") or []):
            return n
    return nodes[0]


def dedupe(nodes):
    keep = pick_node(nodes)
    if not keep:
        return None
    for n in nodes:
        if n["id"] != keep["id"]:
            sway(f"[con_id={n['id']}]", "kill")
    return keep


def find_by_id(cid):
    want = int(cid)
    for node in walk(tree()):
        if node.get("id") == want:
            return node
    return None


def find_by_pid(pid):
    for node in walk(tree()):
        if node.get("pid") == pid:
            return node
    return None


def read_state():
    if not state_file.exists():
        return "hidden", None
    parts = state_file.read_text().split()
    st = parts[0] if parts else "hidden"
    cid = int(parts[1]) if len(parts) > 1 and parts[1].isdigit() else None
    return st, cid


def write_state(st, node=None):
    if node:
        state_file.write_text(f"{st} {node['id']}\n")
    else:
        state_file.write_text(f"{st}\n")


def resolve_node(state, cid):
    if cid:
        hit = find_by_id(cid)
        if hit:
            return hit
    return dedupe(find_all())


def monitor_desc(mon):
    return f"{mon.get('make', '')} {mon.get('model', '')}".strip()


def pick_monitor():
    patterns = [
        p.strip()
        for p in (
            os.environ.get("WAYBAR_PRIMARY_PATTERN", ""),
            os.environ.get("WORK_WAYBAR_PRIMARY_PATTERN", ""),
        )
        if p.strip()
    ]
    outputs = json.loads(subprocess.check_output(["swaymsg", "-t", "get_outputs"], text=True))
    active = [o for o in outputs if o.get("active")]
    for pattern in patterns:
        hit = next((o for o in active if pattern in monitor_desc(o)), None)
        if hit:
            return hit
    if not active:
        return None
    return max(active, key=lambda o: o["rect"]["width"] * o["rect"]["height"])


def focused_monitor():
    outputs = json.loads(subprocess.check_output(["swaymsg", "-t", "get_outputs"], text=True))
    for o in outputs:
        if o.get("focused") and o.get("active"):
            return o
    return pick_monitor()


def pct(token, base):
    token = token.strip()
    if token.endswith("%"):
        return int(base * float(token[:-1]) / 100)
    return int(token)


def layout_rect(mon):
    size = os.environ.get("DROPDOWN_SIZE", "100% 42%").split()
    move = os.environ.get("DROPDOWN_MOVE", "0 0").split()
    margin = int(os.environ.get("DROPDOWN_MARGIN", "12"))
    rect = mon["rect"]
    w, h = rect["width"], rect["height"]
    if mon.get("transform") in (90, 270):
        w, h = h, w
    reserved = int(os.environ.get("DROPDOWN_RESERVED_TOP", "40"))
    usable_w = w - margin * 2
    usable_h = h - reserved - margin * 2
    width = min(pct(size[0], usable_w), usable_w)
    height = min(pct(size[1], usable_h), usable_h)
    x = rect["x"] + margin + pct(move[0], usable_w)
    y = rect["y"] + reserved + margin + pct(move[1], usable_h)
    return width, height, x, y


def layout_node(node, mon):
    if not node or not mon:
        return
    cid = str(node["id"])
    w, h, x, y = layout_rect(mon)
    sway(f"[con_id={cid}]", "floating", "enable")
    sway(f"[con_id={cid}]", "resize", "set", str(w), str(h))
    sway(f"[con_id={cid}]", "move", "absolute", "position", str(x), str(y))
    sway(f"[con_id={cid}]", "mark", "--add", mark)


def hide_node(node):
    if not node:
        return
    cid = str(node["id"])
    sway(f"[con_id={cid}]", "floating", "enable")
    sway(f"[con_id={cid}]", "move", "absolute", "position", "10000", "10000")


def spawn_terminal():
    term = os.environ.get("DROPDOWN_TERM", "kitty")
    title = os.environ.get("DROPDOWN_TITLE", "Dropdown")
    cmd = os.environ.get("DROPDOWN_CMD", "")
    args = [term, f"--class={dropdown_class}", f"--title={title}"]
    if cmd:
        args.extend(["-e", "bash", "-lc", cmd])
    return subprocess.Popen(args)


if action == "relayout":
    state, cid = read_state()
    node = resolve_node(state, cid)
    if state != "visible" or not node:
        raise SystemExit(0)
    mon = pick_monitor()
    if not mon:
        raise SystemExit(0)
    layout_node(node, mon)
    raise SystemExit(0)

mon = focused_monitor()
state, cid = read_state()
node = resolve_node(state, cid)

if state == "visible" and node:
    hide_node(node)
    write_state("hidden", node)
    raise SystemExit(0)

if not node:
    term = os.environ.get("DROPDOWN_TERM", "kitty")
    title = os.environ.get("DROPDOWN_TITLE", "Dropdown")
    cmd = os.environ.get("DROPDOWN_CMD", "")
    args = [term, f"--class={dropdown_class}", f"--title={title}"]
    if cmd:
        args.extend(["-e", "bash", "-lc", cmd])
    proc = subprocess.Popen(args)
    node = None
    for _ in range(80):
        time.sleep(0.05)
        node = find_by_pid(proc.pid) or pick_node(find_all())
        if node:
            break
    if not node:
        print("dropdown-terminal-sway: spawn failed", file=sys.stderr)
        raise SystemExit(1)

layout_node(node, mon)
sway(f"[con_id={node['id']}]", "focus")
write_state("visible", node)
PY
}

case "${1:-}" in
    relayout) run_sway relayout ;;
    *) run_sway toggle ;;
esac
