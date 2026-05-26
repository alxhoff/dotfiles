#!/usr/bin/env bash
# Save the CURRENT on-screen layout into profiles/<name>.hypr in this repo, then apply it.
#
# Use after arranging monitors in nwg-displays (Apply) or any time the layout looks right.
# nwg-displays only updates ~/.config/hypr/monitors.conf — it does NOT update profiles/*.hypr.
#
# Usage:
#   ./save-display-profile.sh work
#   ./save-display-profile.sh home
#   ./save-display-profile.sh laptop
#
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
PROFILE=${1:-}

if [[ -z "$PROFILE" ]]; then
    echo "Usage: $0 <home|work|laptop>" >&2
    exit 1
fi

case "$PROFILE" in
    home|work|laptop) ;;
    *) echo "Unknown profile: $PROFILE (use home, work, or laptop)" >&2; exit 1 ;;
esac

if ! hyprctl monitors -j >/dev/null 2>&1; then
    echo "Run inside Hyprland." >&2
    exit 1
fi

# shellcheck source=endeavour/displays/config.env
source "$SCRIPT_DIR/config.env"
# shellcheck source=endeavour/displays/lib.sh
source "$SCRIPT_DIR/lib.sh"

detected=$("$SCRIPT_DIR/apply-display-profile.sh" detect 2>/dev/null || true)
if [[ -n "$detected" && "$detected" != skip && "$detected" != "$PROFILE" ]]; then
    echo "Warning: connected hardware looks like '$detected', but you are saving '$PROFILE'." >&2
    echo "         Continue only if you mean to overwrite the $PROFILE profile." >&2
    read -r -p "Save anyway? [y/N] " ans
    [[ "${ans,,}" == y ]] || exit 1
fi

if [[ -f "${HOME}/.config/hypr/monitors.conf" ]] \
    && grep -q '^monitor=.*,transform,' "${HOME}/.config/hypr/monitors.conf" 2>/dev/null; then
    "$SCRIPT_DIR/fix-nwg-monitors.sh" >/dev/null
fi

prof_file="$(resolve_profiles_dir "$SCRIPT_DIR")/${PROFILE}.hypr"
"$SCRIPT_DIR/capture-layout.sh" "$PROFILE" >"$prof_file"
echo "Saved → $prof_file"

"$SCRIPT_DIR/apply-display-profile.sh" "$PROFILE"
echo ""
echo "Commit when happy:"
echo "  git add endeavour/displays/profiles/${PROFILE}.hypr && git commit -m \"Update ${PROFILE} display profile\""
