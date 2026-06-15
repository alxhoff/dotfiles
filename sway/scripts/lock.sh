#!/usr/bin/env bash
set -euo pipefail
command -v swaylock >/dev/null || exit 0
pidof swaylock >/dev/null 2>&1 || exec swaylock -f -c 000000
