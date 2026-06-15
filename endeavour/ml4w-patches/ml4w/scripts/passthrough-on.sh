#!/usr/bin/env bash
# Enter passthrough without toggling off if already active.
set -euo pipefail

sub=$(hyprctl submap 2>/dev/null | tr -d '[:space:]')
[[ "$sub" == "passthrough" ]] && exit 0

exec "$(dirname "${BASH_SOURCE[0]}")/passthrough-toggle.sh"
