#!/usr/bin/env bash
# Detect home / work / laptop and apply matching Hyprland monitor profile.
#
# Usage:
#   ./apply-display-profile.sh              # auto-detect
#   ./apply-display-profile.sh home       # force profile
#   PROFILE=work ./apply-display-profile.sh
#
# Requires: Hyprland session, profiles in endeavour/displays/profiles/
#
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
# shellcheck source=endeavour/displays/config.env
source "$SCRIPT_DIR/config.env"

PROFILE=${1:-${PROFILE:-auto}}
PROFILES_DIR="$SCRIPT_DIR/profiles"
STATE_FILE="${XDG_RUNTIME_DIR:-/tmp}/dotfiles-display-profile"

log() { echo "displays: $*"; }

require_hypr() {
    command -v hyprctl >/dev/null || { log "hyprctl missing"; exit 1; }
    hyprctl version >/dev/null 2>&1 || { log "not in a Hyprland session"; exit 1; }
}

connected_names() {
    hyprctl monitors -j | python3 -c "
import json, sys
for m in json.load(sys.stdin):
    print(m.get('name',''))
"
}

has_pattern() {
    local pat=$1
    connected_names | grep -q "$pat"
}

count_external() {
    local n=0
    while read -r name; do
        [[ -z "$name" ]] && continue
        [[ "$name" =~ $LAPTOP_PATTERN ]] && continue
        n=$((n + 1))
    done < <(connected_names)
    echo "$n"
}

has_resolution() {
    local want_w=$1 want_h=$2
    hyprctl monitors -j | python3 -c "
import json, sys
w, h = int(sys.argv[1]), int(sys.argv[2])
for m in json.load(sys.stdin):
    if m.get('width') == w and m.get('height') == h:
        sys.exit(0)
sys.exit(1)
" "$want_w" "$want_h"
}

detect_profile() {
    local ext
    ext=$(count_external)

    # Work: HDMI present + multiple externals (old setup used HDMI-A-0)
    if has_pattern "$WORK_HDMI_PATTERN" && [[ "$ext" -ge "${WORK_MIN_EXTERNAL:-2}" ]]; then
        echo work
        return
    fi

    # Home: 4K panel present (3840x2160) + dock externals
    if has_resolution 3840 2160 && [[ "$ext" -ge "${HOME_MIN_EXTERNAL:-2}" ]]; then
        echo home
        return
    fi

    # Home without counting 4K: many DisplayPorts
    if has_pattern "$HOME_DP_PATTERNS" && [[ "$ext" -ge "${HOME_MIN_EXTERNAL:-2}" ]] && ! has_pattern "$WORK_HDMI_PATTERN"; then
        echo home
        return
    fi

    echo laptop
}

apply_profile_file() {
    local prof=$1
    local file="$PROFILES_DIR/${prof}.hypr"
    [[ -f "$file" ]] || { log "no profile file: $file"; return 1; }

    log "applying profile: $prof"
    while IFS= read -r line || [[ -n "$line" ]]; do
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        [[ "$line" =~ ^[[:space:]]*$ ]] && continue
        [[ "$line" =~ ^monitor= ]] || continue
        hyprctl keyword "$line"
    done <"$file"
    echo "$prof" >"$STATE_FILE"
}

main() {
    require_hypr

    if [[ "$PROFILE" == auto ]]; then
        PROFILE=$(detect_profile)
        log "detected: $PROFILE ($(connected_names | tr '\n' ' '))"
    fi

    apply_profile_file "$PROFILE"
}

main
