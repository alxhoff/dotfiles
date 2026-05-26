#!/usr/bin/env bash
# i3-style workspace tabbed / stacking via Hyprland groups.
# Usage: layout-workspace-tabs.sh tabbed|stacking
set -euo pipefail

mode=${1:?usage: layout-workspace-tabs.sh tabbed|stacking}
case "$mode" in tabbed|stacking) ;; *) exit 2 ;; esac

export LAYOUT_MODE="$mode"
python3 <<'PY'
import json
import os
import subprocess
import sys

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


def workspace_clients():
    ws = hypr_json("activeworkspace", "-j")["id"]
    return [
        c
        for c in hypr_json("clients", "-j")
        if c.get("workspace", {}).get("id") == ws and not c.get("floating")
    ]


def grouped_peers(client):
    peers = set(client.get("grouped") or [])
    addr = client.get("address")
    if addr in peers:
        peers.discard(addr)
    return peers


def same_group(addr_a, addr_b):
    if not addr_a or not addr_b or addr_a == addr_b:
        return False
    by_addr = {c["address"]: c for c in hypr_json("clients", "-j")}
    a = by_addr.get(addr_a, {})
    b = by_addr.get(addr_b, {})
    return addr_b in grouped_peers(a) or addr_a in grouped_peers(b)


def all_grouped(clients):
    if len(clients) <= 1:
        return False
    anchor = clients[0]["address"]
    return all(same_group(c["address"], anchor) for c in clients[1:])


def stacked_enabled():
    out = subprocess.check_output(
        ["hyprctl", "getoption", "group:groupbar:stacked"], text=True
    )
    return out.strip().split(":")[-1].strip() == "1"


def ungroup_all(clients, original):
    for c in clients:
        if not grouped_peers(c):
            continue
        addr = c["address"]
        dispatch("focuswindow", f"address:{addr}")
        for d in ("l", "r", "u", "d"):
            dispatch("moveoutofgroup", d)
        if grouped_peers(hypr_json("activewindow", "-j")):
            dispatch("togglegroup")
    if original:
        dispatch("focuswindow", f"address:{original}")


def merge_with_anchor(client_addr, anchor_addr):
    dispatch("focuswindow", f"address:{client_addr}")
    for d in ("l", "r", "u", "d"):
        dispatch("moveintoorcreategroup", d)
        active = hypr_json("activewindow", "-j")
        if same_group(active.get("address"), anchor_addr):
            return True
    return same_group(client_addr, anchor_addr)


def group_all(clients, original):
    if not clients:
        return False
    if len(clients) == 1:
        dispatch("focuswindow", f"address:{clients[0]['address']}")
        dispatch("togglegroup")
        return True

    anchor = clients[0]["address"]
    dispatch("focuswindow", f"address:{anchor}")
    dispatch("togglegroup")

    for c in clients[1:]:
        if not merge_with_anchor(c["address"], anchor):
            return False

    if original:
        dispatch("focuswindow", f"address:{original}")
    return all_grouped(workspace_clients())


clients = workspace_clients()
if not clients:
    sys.exit(0)

original = hypr_json("activewindow", "-j").get("address")
want_stacked = mode == "stacking"
grouped = all_grouped(clients)
stacked = stacked_enabled()

if grouped and stacked == want_stacked:
    ungroup_all(clients, original)
    set_stacked(False)
else:
    ungroup_all(clients, original)
    clients = workspace_clients()
    set_stacked(want_stacked)
    if not group_all(clients, original):
        set_stacked(False)
        subprocess.run(
            [
                "notify-send",
                "-t",
                "4000",
                "Tab layout",
                "Could not group all windows on this workspace.",
            ],
            check=False,
        )
PY
