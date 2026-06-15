#!/usr/bin/env bash
# Guake-style dropdown Spotify (+ Discord split) for Sway.
# Spotify is often X11-only: use xdotool when it is not in the sway tree.
set -euo pipefail

CONFIG="${HOME}/.config/ml4w/dropdown-spotify.env"
[[ -f "$CONFIG" ]] && source "$CONFIG"

DISPLAY_CONFIG="${HOME}/.config/dotfiles/endeavour/displays/config.env"
[[ -f "$DISPLAY_CONFIG" ]] && source "$DISPLAY_CONFIG"

: "${DROPDOWN_CLASS:=spotify}"
: "${DISCORD_CLASS:=discord}"
: "${DROPDOWN_SIZE:=100% 100%}"
: "${DROPDOWN_MOVE:=0 0}"
: "${DROPDOWN_MARGIN:=12}"
: "${DROPDOWN_GAP:=16}"
: "${DROPDOWN_RESERVED_TOP:=82}"
: "${DROPDOWN_MARK:=dropdown-spotify}"
: "${DISCORD_MARK:=dropdown-spotify-discord}"
: "${SPOTIFY_PRELOAD:=/usr/local/lib/spotify-adblock.so}"

export DROPDOWN_CLASS DISCORD_CLASS DROPDOWN_SIZE DROPDOWN_MOVE \
    DROPDOWN_MARGIN DROPDOWN_GAP DROPDOWN_RESERVED_TOP DROPDOWN_MARK DISCORD_MARK \
    SPOTIFY_PRELOAD WAYBAR_PRIMARY_PATTERN WORK_WAYBAR_PRIMARY_PATTERN

python3 - "${1:-toggle}" <<'PY'
import json
import os
import re
import subprocess
import sys
import time
from pathlib import Path

action = sys.argv[1]
spotify_token = os.environ["DROPDOWN_CLASS"].lower()
discord_token = os.environ["DISCORD_CLASS"].lower()
spotify_mark = os.environ["DROPDOWN_MARK"]
discord_mark = os.environ["DISCORD_MARK"]
preload = os.environ.get("SPOTIFY_PRELOAD", "/usr/local/lib/spotify-adblock.so")
state_file = Path(os.environ.get("XDG_RUNTIME_DIR", "/tmp")) / "dotfiles-dropdown-spotify.state"


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


def xdotool(*args):
    try:
        return subprocess.check_output(["xdotool", *args], text=True, stderr=subprocess.DEVNULL).strip()
    except (subprocess.CalledProcessError, FileNotFoundError):
        return ""


def x11_search():
    wids = []
    for spec in (["search", "--class", "Spotify"], ["search", "--class", "spotify"],
                 ["search", "--name", "Spotify"]):
        out = xdotool(*spec)
        if out:
            wids.extend(int(x) for x in out.split() if x.isdigit())
    seen = set()
    unique = []
    for wid in wids:
        if wid not in seen:
            seen.add(wid)
            unique.append(wid)
    return unique


def x11_area(wid):
    out = xdotool("getwindowgeometry", "--shell", str(wid))
    vals = dict(re.findall(r"^(WIDTH|HEIGHT)=(\d+)", out, re.M))
    w = int(vals.get("WIDTH", 0))
    h = int(vals.get("HEIGHT", 0))
    return w * h


def x11_pick(wids):
    if not wids:
        return None
    return max(wids, key=lambda w: (x11_area(w), w))


def find_by_id(cid):
    want = int(cid)
    for node in walk(tree()):
        if node.get("id") == want:
            return node
    return None


def find_by_mark(name):
    for node in walk(tree()):
        if node.get("type") != "con":
            continue
        if name in (node.get("marks") or []):
            return node
    return None


def token_match(node, token):
    if node.get("type") != "con":
        return False
    token = token.lower()
    app_id = (node.get("app_id") or "").lower()
    props = node.get("window_properties") or {}
    klass = (props.get("class") or "").lower()
    title = (node.get("name") or "").lower()
    return token in app_id or token in klass or token in title


def find_sway(token, mark_name=None, stored_id=None):
    if stored_id:
        hit = find_by_id(stored_id)
        if hit:
            return hit
    if mark_name:
        hit = find_by_mark(mark_name)
        if hit:
            return hit
    best = None
    for node in walk(tree()):
        if not token_match(node, token):
            continue
        rect = node.get("rect") or {}
        area = rect.get("width", 0) * rect.get("height", 0)
        if best is None or area > best[0]:
            best = (area, node)
    return best[1] if best else None


def read_state():
    if not state_file.exists():
        return "hidden", "none", None, None
    parts = state_file.read_text().split()
    st = parts[0] if parts else "hidden"
    mode = parts[1] if len(parts) > 1 else "none"
    sid = parts[2] if len(parts) > 2 and parts[2] not in ("0", "-") else None
    did = parts[3] if len(parts) > 3 and parts[3] not in ("0", "-") else None
    if mode == "x11" and sid:
        sid = int(sid)
    elif mode == "sway" and sid:
        sid = int(sid)
    if mode == "sway" and did:
        did = int(did)
    elif mode == "x11" and did:
        did = int(did)
    return st, mode, sid, did


def write_state(st, mode, spotify_ref=None, discord_ref=None):
    s = "0"
    d = "0"
    if spotify_ref is not None:
        s = str(spotify_ref)
    if discord_ref is not None:
        d = str(discord_ref)
    state_file.write_text(f"{st} {mode} {s} {d}\n")


def monitor_desc(mon):
    return f"{mon.get('make', '')} {mon.get('model', '')}".strip()


def focused_monitor():
    outputs = json.loads(subprocess.check_output(["swaymsg", "-t", "get_outputs"], text=True))
    for o in outputs:
        if o.get("focused") and o.get("active"):
            return o
    return pick_monitor()


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


def pct(token, base):
    token = token.strip()
    if token.endswith("%"):
        return int(base * float(token[:-1]) / 100)
    return int(token)


def point_on_monitor(mon, x, y):
    rect = mon["rect"]
    return (
        rect["x"] <= x < rect["x"] + rect["width"]
        and rect["y"] <= y < rect["y"] + rect["height"]
    )


def infer_work_area(mon):
    """Match tiled window bounds on this output (waybar + gaps included)."""
    oy = mon["rect"]["y"]
    tops = []
    rects = []
    for node in walk(tree()):
        if node.get("type") != "con":
            continue
        if node.get("floating") not in (None, "auto_off"):
            continue
        cr = node.get("rect") or {}
        width = cr.get("width", 0)
        height = cr.get("height", 0)
        if width < 400 or height < 200:
            continue
        cx = cr.get("x", 0) + width // 2
        cy = cr.get("y", 0) + height // 2
        if not point_on_monitor(mon, cx, cy):
            continue
        tops.append(cr["y"] - oy)
        rects.append(cr)
    if not tops:
        return None
    content_top = max(tops)
    aligned = [cr for cr in rects if cr["y"] - oy >= content_top - 2]
    if not aligned:
        aligned = rects
    top = oy + content_top
    bottom = min(cr["y"] + cr["height"] for cr in aligned)
    left = min(cr["x"] for cr in aligned)
    right = max(cr["x"] + cr["width"] for cr in aligned)
    return {
        "x": left,
        "y": top,
        "width": right - left,
        "height": bottom - top,
    }


def layout_rects(mon, has_discord):
    margin = int(os.environ.get("DROPDOWN_MARGIN", "12"))
    gap = int(os.environ.get("DROPDOWN_GAP", "16"))
    work = infer_work_area(mon)
    if work:
        base_x = work["x"] + margin
        base_y = work["y"]
        usable_w = work["width"] - margin * 2
        usable_h = work["height"] - margin
    else:
        rect = mon["rect"]
        w, h = rect["width"], rect["height"]
        if mon.get("transform") in (90, 270):
            w, h = h, w
        reserved = int(os.environ.get("DROPDOWN_RESERVED_TOP", "82"))
        base_x = rect["x"] + margin
        base_y = rect["y"] + reserved + margin
        usable_w = w - margin * 2
        usable_h = h - reserved - margin * 2
    if has_discord:
        pane_w = (usable_w - gap) // 2
        spotify_w = usable_w - gap - pane_w
        return [
            (pane_w, usable_h, base_x, base_y),
            (spotify_w, usable_h, base_x + pane_w + gap, base_y),
        ]
    size = os.environ.get("DROPDOWN_SIZE", "100% 100%").split()
    move = os.environ.get("DROPDOWN_MOVE", "0 0").split()
    width = min(pct(size[0], usable_w), usable_w)
    height = min(pct(size[1], usable_h), usable_h)
    x = base_x + pct(move[0], usable_w)
    y = base_y + pct(move[1], usable_h)
    return [(width, height, x, y)]


def prepare_sway(node):
    if not node:
        return
    cid = str(node["id"])
    sway(f"[con_id={cid}]", "floating", "enable")
    sway(f"[con_id={cid}]", "fullscreen", "disable")


def place_sway(node, rect):
    if not node:
        return
    cid = str(node["id"])
    w, h, x, y = rect
    sway(f"[con_id={cid}]", "floating", "enable")
    sway(f"[con_id={cid}]", "resize", "set", str(w), str(h))
    sway(f"[con_id={cid}]", "move", "absolute", "position", str(x), str(y))


def hide_sway(node):
    if not node:
        return
    sway(f"[con_id={node['id']}]", "floating", "enable")
    sway(f"[con_id={node['id']}]", "move", "absolute", "position", "10000", "10000")


def hide_sway_mark(name):
    sway(f"[con_mark={name}]", "move", "absolute", "position", "10000", "10000")


def place_x11(wid, rect):
    w, h, x, y = rect
    xdotool("windowmap", str(wid))
    xdotool("windowsize", str(wid), str(w), str(h))
    xdotool("windowmove", str(wid), str(x), str(y))
    xdotool("windowactivate", str(wid))


def hide_x11(wid):
    xdotool("windowunmap", str(wid))


def launch_spotify():
    env = os.environ.copy()
    cmd = ["/usr/bin/spotify"]
    if os.path.isfile(preload):
        env["LD_PRELOAD"] = preload
    subprocess.Popen(cmd, env=env, start_new_session=True)


def resolve_spotify(mode, sid):
    node = find_sway(spotify_token, spotify_mark, sid if mode == "sway" else None)
    if node:
        return "sway", node
    wids = x11_search()
    if sid and mode == "x11":
        if sid in wids:
            return "x11", sid
    wid = x11_pick(wids)
    if wid:
        return "x11", wid
    return None, None


def resolve_discord(mode, did):
    node = find_sway(discord_token, discord_mark, did if mode == "sway" else None)
    if node:
        return "sway", node
    return None, None


def show_panel(mon, spotify_kind, spotify, discord_kind, discord):
    rects = layout_rects(mon, bool(discord))
    if discord:
        if discord_kind == "sway":
            prepare_sway(discord)
            prepare_sway(spotify if spotify_kind == "sway" else None)
            place_sway(discord, rects[0])
            if spotify_kind == "sway":
                place_sway(spotify, rects[1])
            else:
                place_x11(spotify, rects[1])
            sway(f"[con_id={discord['id']}]", "mark", "--add", discord_mark)
            sway(f"[con_id={discord['id']}]", "focus")
        else:
            if spotify_kind == "sway":
                prepare_sway(spotify)
                place_sway(spotify, rects[0])
            else:
                place_x11(spotify, rects[0])
    else:
        if spotify_kind == "sway":
            prepare_sway(spotify)
            place_sway(spotify, rects[0])
            sway(f"[con_id={spotify['id']}]", "mark", "--add", spotify_mark)
            sway(f"[con_id={spotify['id']}]", "focus")
        else:
            place_x11(spotify, rects[0])

    sref = spotify["id"] if spotify_kind == "sway" else spotify
    dref = discord["id"] if discord and discord_kind == "sway" else (discord or 0)
    write_state("visible", spotify_kind, sref, dref if discord else None)


def hide_panel(spotify_kind, spotify, discord_kind, discord):
    if spotify_kind == "sway" and spotify:
        hide_sway(spotify)
    elif spotify_kind == "x11" and spotify:
        hide_x11(spotify)
    else:
        hide_sway_mark(spotify_mark)
    if discord_kind == "sway" and discord:
        hide_sway(discord)
    elif discord:
        hide_sway_mark(discord_mark)
    sref = spotify["id"] if spotify_kind == "sway" and spotify else (spotify or 0)
    dref = discord["id"] if discord_kind == "sway" and discord else 0
    write_state("hidden", spotify_kind, sref, dref if dref else None)


mon = pick_monitor() or focused_monitor()
state, mode, sid, did = read_state()
spotify_kind, spotify = resolve_spotify(mode, sid)
discord_kind, discord = resolve_discord(mode, did)

if action == "relayout":
    if state != "visible":
        raise SystemExit(0)
    spotify_kind, spotify = resolve_spotify(mode, sid)
    discord_kind, discord = resolve_discord(mode, did)
    if not spotify:
        raise SystemExit(0)
    show_panel(mon, spotify_kind, spotify, discord_kind, discord)
    raise SystemExit(0)

if state == "visible":
    hide_panel(spotify_kind or mode, spotify, discord_kind or "none", discord)
    raise SystemExit(0)

if not spotify:
    launch_spotify()
    spotify_kind, spotify = None, None
    for _ in range(120):
        time.sleep(0.25)
        spotify_kind, spotify = resolve_spotify("none", None)
        if spotify:
            break
    if not spotify:
        print("dropdown-spotify-sway: spawn failed", file=sys.stderr)
        raise SystemExit(1)

discord_kind, discord = resolve_discord("sway", did)
show_panel(mon, spotify_kind, spotify, discord_kind, discord)
PY
