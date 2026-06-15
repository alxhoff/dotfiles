#!/usr/bin/env bash
# Lock via hyprlock only. Avoid loginctl lock-session — plasmalogin shows the boot greeter.
set -euo pipefail

command -v hyprlock >/dev/null 2>&1 || exit 0
pidof hyprlock >/dev/null 2>&1 || exec hyprlock
