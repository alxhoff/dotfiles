#!/usr/bin/env bash
# i3-style tabbed / stacking on the active monitor (Hyprland groups).
# Usage: layout-workspace-tabs.sh tabbed|stacking|ungroup
set -euo pipefail

mode=${1:?usage: layout-workspace-tabs.sh tabbed|stacking|ungroup}
case "$mode" in tabbed|stacking|ungroup) ;; *) exit 2 ;; esac

export LAYOUT_MODE="$mode"
python3 <<'PY'
import json
import os
import subprocess
import sys
import time

mode = os.environ["LAYOUT_MODE"]


def hypr_json(*args):
    return json.loads(subprocess.check_output(["hyprctl", *args], text=True))


def dispatch(*args):
    subprocess.run(["hyprctl", "dispatch", *args], check=False, capture_output=True)


def set_stacked(enabled: bool) -> None:
    subprocess.run(
        ["hyprctl", "keyword", "group:groupbar:stacked", "true" if enabled else "false"],
        check=False,
        capture_output=True,
    )


def active_monitor_id():
    aw = hypr_json("activewindow", "-j")
    mid = aw.get("monitor")
    if mid is None:
        mons = hypr_json("monitors", "-j")
        focused = next((m for m in mons if m.get("focused")), None)
        mid = focused["id"] if focused else None
    return mid


def monitor_clients(monitor_id):
    if monitor_id is None:
        return []
    ws = hypr_json("activeworkspace", "-j")["id"]
    return [
        c
        for c in hypr_json("clients", "-j")
        if c.get("workspace", {}).get("id") == ws
        and not c.get("floating")
        and c.get("monitor") == monitor_id
    ]


def sort_clients(clients):
    return sorted(clients, key=lambda c: (c.get("at", [0, 0])[1], c.get("at", [0, 0])[0]))


def grouped_peers(client):
    peers = set(client.get("grouped") or [])
    addr = client.get("address")
    if addr in peers:
        peers.discard(addr)
    return peers


def is_grouped(client):
    grouped = client.get("grouped") or []
    if not grouped:
        return False
    # Hyprland solo groups list only this window's address; multi-member lists peers.
    if grouped_peers(client):
        return True
    addr = client.get("address")
    return len(grouped) == 1 and grouped[0] == addr


def is_solo_group(client):
    return is_grouped(client) and not grouped_peers(client)


def same_group(addr_a, addr_b, clients_by_addr):
    if not addr_a or not addr_b or addr_a == addr_b:
        return False
    a = clients_by_addr.get(addr_a, {})
    b = clients_by_addr.get(addr_b, {})
    return addr_b in grouped_peers(a) or addr_a in grouped_peers(b)


def all_grouped(clients):
    if len(clients) <= 1:
        return len(clients) == 1 and is_grouped(clients[0])
    anchor = clients[0]["address"]
    by_addr = {c["address"]: c for c in clients}
    return all(same_group(c["address"], anchor, by_addr) for c in clients[1:])


def dir_toward(frm, to):
    fx = frm["at"][0] + frm["size"][0] / 2
    fy = frm["at"][1] + frm["size"][1] / 2
    tx = to["at"][0] + to["size"][0] / 2
    ty = to["at"][1] + to["size"][1] / 2
    dx, dy = tx - fx, ty - fy
    if abs(dx) > abs(dy):
        return "r" if dx > 0 else "l"
    return "d" if dy > 0 else "u"


def monitor_name(monitor_id):
    for m in hypr_json("monitors", "-j"):
        if m.get("id") == monitor_id:
            return m.get("name")
    return None


def clients_by_addr():
    return {c["address"]: c for c in hypr_json("clients", "-j")}


def center(client):
    x, y = client.get("at") or [0, 0]
    w, h = client.get("size") or [0, 0]
    return x + w / 2, y + h / 2


def distance(a, b):
    ax, ay = center(a)
    bx, by = center(b)
    return (ax - bx) ** 2 + (ay - by) ** 2


def overlap_1d(a0, a1, b0, b1, min_px=24):
    return min(a1, b1) - max(a0, b0) >= min_px


def adjacent(a, b, edge_tol=10):
    if a.get("monitor") != b.get("monitor"):
        return False
    ax, ay = a.get("at") or [0, 0]
    aw, ah = a.get("size") or [0, 0]
    bx, by = b.get("at") or [0, 0]
    bw, bh = b.get("size") or [0, 0]
    ax1, ay1 = ax + aw, ay + ah
    bx1, by1 = bx + bw, by + bh
    if abs(ax1 - bx) <= edge_tol and overlap_1d(ay, ay1, by, by1):
        return True
    if abs(bx1 - ax) <= edge_tol and overlap_1d(ay, ay1, by, by1):
        return True
    if abs(ay1 - by) <= edge_tol and overlap_1d(ax, ax1, bx, bx1):
        return True
    if abs(by1 - ay) <= edge_tol and overlap_1d(ax, ax1, bx, bx1):
        return True
    return False


def focus_addr(addr):
    dispatch("focuswindow", f"address:{addr}")
    time.sleep(0.03)


def ensure_on_monitor(addr, monitor_id, home_name):
    by_addr = clients_by_addr()
    client = by_addr.get(addr)
    if not client or client.get("monitor") == monitor_id:
        return True
    focus_addr(addr)
    dispatch("movewindow", f"mon:{home_name}")
    time.sleep(0.05)
    return clients_by_addr().get(addr, {}).get("monitor") == monitor_id


def ungroup_window(addr):
    focus_addr(addr)
    client = clients_by_addr().get(addr, {})
    if not is_grouped(client):
        return
    if is_solo_group(client):
        dispatch("togglegroup")
        return
    for d in ("l", "r", "u", "d"):
        dispatch("moveoutofgroup", d)
    if is_grouped(hypr_json("activewindow", "-j")):
        dispatch("togglegroup")


def revert_wrong_merge(client_addr, anchor_addr, monitor_id, home_name):
    by_addr = clients_by_addr()
    client = by_addr.get(client_addr, {})
    anchor = by_addr.get(anchor_addr, {})
    if not client:
        return
    if is_grouped(client) and not same_group(client_addr, anchor_addr, by_addr):
        ungroup_window(client_addr)
    ensure_on_monitor(client_addr, monitor_id, home_name)


def move_on_monitor(addr, direction, monitor_id, home_name):
    focus_addr(addr)
    before = clients_by_addr().get(addr, {})
    if not before:
        return False
    dispatch("movewindow", direction)
    time.sleep(0.05)
    after = clients_by_addr().get(addr, {})
    if not after or after.get("address") != addr:
        return False
    if after.get("monitor") != monitor_id:
        ensure_on_monitor(addr, monitor_id, home_name)
        return False
    return before.get("at") != after.get("at")


def bring_closer(client_addr, anchor_client, monitor_id, home_name, max_steps=10):
    for _ in range(max_steps):
        by_addr = clients_by_addr()
        client = by_addr.get(client_addr, {})
        anchor = by_addr.get(anchor_client["address"], anchor_client)
        if not client or adjacent(client, anchor):
            return
        direction = dir_toward(client, anchor)
        if not move_on_monitor(client_addr, direction, monitor_id, home_name):
            break


def merge_with_anchor(client_addr, anchor_addr, anchor_client, monitor_id, home_name):
    bring_closer(client_addr, anchor_client, monitor_id, home_name)
    focus_addr(client_addr)
    frm = clients_by_addr().get(client_addr, {})
    primary = dir_toward(frm, anchor_client) if frm else "l"
    dirs = [primary] + [d for d in ("l", "r", "u", "d") if d != primary]
    for d in dirs:
        dispatch("moveintogroup", d)
        time.sleep(0.05)
        by_addr = clients_by_addr()
        client = by_addr.get(client_addr, {})
        if client.get("monitor") != monitor_id:
            revert_wrong_merge(client_addr, anchor_addr, monitor_id, home_name)
            continue
        if same_group(client_addr, anchor_addr, by_addr):
            return True
        if is_grouped(client) and not same_group(client_addr, anchor_addr, by_addr):
            revert_wrong_merge(client_addr, anchor_addr, monitor_id, home_name)
    return same_group(client_addr, anchor_addr, clients_by_addr())


def restore_monitor_clients(client_addrs, anchor_addr, monitor_id, home_name):
    if not home_name:
        return
    by_addr = clients_by_addr()
    for addr in client_addrs:
        ensure_on_monitor(addr, monitor_id, home_name)
    by_addr = clients_by_addr()
    for addr in client_addrs:
        client = by_addr.get(addr, {})
        if is_grouped(client) and not same_group(addr, anchor_addr, by_addr):
            revert_wrong_merge(addr, anchor_addr, monitor_id, home_name)


def dissolve_solo_groups(monitor_id, original=None):
    for c in sort_clients(monitor_clients(monitor_id)):
        if not is_solo_group(c):
            continue
        dispatch("focuswindow", f"address:{c['address']}")
        time.sleep(0.03)
        dispatch("togglegroup")
    if original:
        dispatch("focuswindow", f"address:{original}")


def ungroup_clients(clients, original):
    for c in clients:
        if not is_grouped(c):
            continue
        addr = c["address"]
        dispatch("focuswindow", f"address:{addr}")
        time.sleep(0.03)
        if is_solo_group(c):
            dispatch("togglegroup")
            continue
        for d in ("l", "r", "u", "d"):
            dispatch("moveoutofgroup", d)
        if is_grouped(hypr_json("activewindow", "-j")):
            dispatch("togglegroup")
    if original:
        dispatch("focuswindow", f"address:{original}")


def group_clients(clients, original, monitor_id, home_name):
    if not clients or len(clients) < 2:
        return False

    by_addr = {c["address"]: c for c in clients}
    anchor = clients[0]
    if original and original in by_addr:
        anchor = by_addr[original]

    anchor_addr = anchor["address"]
    focus_addr(anchor_addr)
    if not is_grouped(anchor):
        dispatch("togglegroup")
        time.sleep(0.05)
    dispatch("lockactivegroup", "lock")

    try:
        others = [c for c in clients if c["address"] != anchor_addr]
        others.sort(key=lambda c: distance(c, anchor))
        for c in others:
            by_addr = clients_by_addr()
            anchor_client = by_addr.get(anchor_addr, anchor)
            if not merge_with_anchor(
                c["address"], anchor_addr, anchor_client, monitor_id, home_name
            ):
                return False
    finally:
        focus_addr(anchor_addr)
        dispatch("lockactivegroup", "unlock")

    if original:
        focus_addr(original)
    return all_grouped(monitor_clients(monitor_id))


monitor_id = active_monitor_id()
home_monitor = monitor_name(monitor_id)
clients = sort_clients(monitor_clients(monitor_id))
original = hypr_json("activewindow", "-j").get("address")
client_addrs = [c["address"] for c in clients]
anchor_addr = original if original in client_addrs else (client_addrs[0] if client_addrs else None)

if mode == "ungroup":
    if any(is_grouped(c) for c in clients):
        ungroup_clients(clients, original)
        dissolve_solo_groups(monitor_id, original)
        set_stacked(False)
    else:
        dispatch("layoutmsg", "togglesplit")
    sys.exit(0)

if len(clients) < 2:
    dissolve_solo_groups(monitor_id, original)
    sys.exit(0)

want_stacked = mode == "stacking"

# Only ungroup windows on this monitor before re-stacking.
ungroup_clients([c for c in clients if is_grouped(c)], original)
dissolve_solo_groups(monitor_id, original)
clients = sort_clients(monitor_clients(monitor_id))
set_stacked(want_stacked)

if not group_clients(clients, original, monitor_id, home_monitor):
    restore_monitor_clients(client_addrs, anchor_addr, monitor_id, home_monitor)
    dissolve_solo_groups(monitor_id, original)
    set_stacked(False)
    subprocess.run(
        [
            "notify-send",
            "-t",
            "4000",
            "Tab layout",
            "Could not group all tiled windows on this monitor.",
        ],
        check=False,
    )
PY
