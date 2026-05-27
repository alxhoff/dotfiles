#!/usr/bin/env python3
# Waybar custom/network: show Wi-Fi, Ethernet, and VPN interfaces with IPs.
# Skips docker bridges and virtual NICs; VPN (tun/tap/wg) is shown separately.
from __future__ import annotations

import json
import re
import subprocess
import sys
from pathlib import Path


SKIP_PREFIXES = ("lo", "docker", "br-", "veth", "virbr")
VPN_PREFIXES = ("tun", "tap", "wg", "ppp")
ETH_PREFIXES = ("en", "eth", "enx")
ICON_WIFI = "\uf1eb"
ICON_ETH = "\uf6ff"
ICON_VPN = "\uf023"
SEP = "   ·   "


def run(*args: str) -> str:
    try:
        return subprocess.check_output(args, text=True, stderr=subprocess.DEVNULL).strip()
    except (subprocess.CalledProcessError, FileNotFoundError):
        return ""


def should_skip(name: str) -> bool:
    return any(name == p.rstrip("-") or name.startswith(p) for p in SKIP_PREFIXES)


def is_vpn(name: str) -> bool:
    return any(name.startswith(p) for p in VPN_PREFIXES)


def is_wifi(name: str) -> bool:
    return (Path("/sys/class/net") / name / "wireless").exists()


def is_ethernet(name: str) -> bool:
    return any(name.startswith(p) for p in ETH_PREFIXES)


def operstate(name: str) -> str:
    path = Path("/sys/class/net") / name / "operstate"
    try:
        return path.read_text().strip()
    except OSError:
        return "unknown"


def carrier(name: str) -> bool:
    path = Path("/sys/class/net") / name / "carrier"
    try:
        return path.read_text().strip() == "1"
    except OSError:
        return False


def ipv4_addrs(name: str) -> list[str]:
    out = run("ip", "-4", "-o", "addr", "show", "dev", name, "scope", "global")
    addrs: list[str] = []
    for line in out.splitlines():
        parts = line.split()
        if len(parts) >= 4:
            addrs.append(parts[3].split("/")[0])
    return addrs


def default_route_devs() -> set[str]:
    devs: set[str] = set()
    for line in run("ip", "-4", "route", "show", "default").splitlines():
        m = re.search(r"\bdev\s+(\S+)", line)
        if m:
            devs.add(m.group(1))
    return devs


def wifi_meta(name: str) -> tuple[str, str]:
    conn = run("nmcli", "-t", "-f", "GENERAL.CONNECTION", "device", "show", name)
    ssid = conn.split(":", 1)[1] if conn.startswith("GENERAL.CONNECTION:") else ""
    signal = ""
    for line in run("nmcli", "-t", "-f", "ACTIVE,SSID,SIGNAL", "dev", "wifi").splitlines():
        parts = line.split(":")
        if len(parts) >= 3 and parts[0] == "yes":
            signal = parts[2]
            if not ssid:
                ssid = parts[1]
            break
    return (ssid or name), signal


def collect() -> tuple[list[dict], list[dict], list[dict]]:
    wifi: list[dict] = []
    ethernet: list[dict] = []
    vpn: list[dict] = []
    defaults = default_route_devs()

    for path in sorted(Path("/sys/class/net").iterdir()):
        name = path.name
        if should_skip(name):
            continue

        addrs = ipv4_addrs(name)
        state = operstate(name)
        up = state in {"up", "unknown"}  # tun often reports unknown while up
        has_addr = bool(addrs)

        if is_vpn(name):
            if up or has_addr:
                vpn.append(
                    {
                        "ifname": name,
                        "ips": addrs,
                        "default": name in defaults,
                        "state": state,
                    }
                )
            continue

        if is_wifi(name):
            if not up and not has_addr:
                continue
            ssid, signal = wifi_meta(name)
            wifi.append(
                {
                    "ifname": name,
                    "ssid": ssid,
                    "signal": signal,
                    "ips": addrs,
                    "default": name in defaults,
                    "state": state,
                }
            )
            continue

        if is_ethernet(name):
            if not has_addr and not carrier(name):
                continue
            ethernet.append(
                {
                    "ifname": name,
                    "ips": addrs,
                    "default": name in defaults,
                    "state": state,
                    "carrier": carrier(name),
                }
            )

    return wifi, ethernet, vpn


def default_mark(is_default: bool) -> str:
    return " *" if is_default else ""


def short_ssid(name: str, limit: int = 10) -> str:
    if len(name) <= limit:
        return name
    return name[: limit - 1] + "…"


def build() -> dict:
    wifi, ethernet, vpn = collect()
    parts: list[str] = []
    tooltip_lines: list[str] = []
    classes: list[str] = []

    for w in wifi:
        sig = w["signal"] or "—"
        mark = default_mark(w["default"])
        ssid = short_ssid(w["ssid"])
        parts.append(f"{ICON_WIFI} {ssid} {sig}%{mark}")
        tooltip_lines.append(f"Wi-Fi ({w['ifname']}) — {w['ssid']}")
        if w["ips"]:
            tooltip_lines.append(f"  IP: {', '.join(w['ips'])}")
        else:
            tooltip_lines.append("  IP: (none)")
        if w["signal"]:
            tooltip_lines.append(f"  Signal: {w['signal']}%")
        if w["default"]:
            tooltip_lines.append("  Default route")
        tooltip_lines.append("")
        classes.append("wifi")

    for e in ethernet:
        mark = default_mark(e["default"])
        parts.append(f"{ICON_ETH} Eth{mark}")
        tooltip_lines.append(f"Ethernet ({e['ifname']})")
        if e["ips"]:
            tooltip_lines.append(f"  IP: {', '.join(e['ips'])}")
        else:
            tooltip_lines.append("  IP: (none)")
        tooltip_lines.append(f"  Link: {'up' if e['carrier'] else 'down'}")
        if e["default"]:
            tooltip_lines.append("  Default route")
        tooltip_lines.append("")
        classes.append("ethernet")

    for v in vpn:
        mark = default_mark(v["default"])
        parts.append(f'<span foreground="#7fd4b8">{ICON_VPN} VPN{mark}</span>')
        tooltip_lines.append(f"VPN ({v['ifname']})")
        if v["ips"]:
            tooltip_lines.append(f"  IP: {', '.join(v['ips'])}")
        else:
            tooltip_lines.append("  IP: (none)")
        if v["default"]:
            tooltip_lines.append("  Default route (traffic via VPN)")
        tooltip_lines.append("")
        classes.append("vpn")

    if not parts:
        return {
            "text": f"{ICON_WIFI} offline",
            "tooltip": "No active network interfaces",
            "class": "disconnected",
        }

    while tooltip_lines and tooltip_lines[-1] == "":
        tooltip_lines.pop()

    text = SEP.join(parts)

    return {
        "text": text,
        "tooltip": "\n".join(tooltip_lines),
        "class": " ".join(dict.fromkeys(classes)),
    }


def main() -> int:
    print(json.dumps(build(), ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
