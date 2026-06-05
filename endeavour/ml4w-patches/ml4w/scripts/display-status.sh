#!/usr/bin/env bash
# Waybar custom/display — current display profile + detected dock hint.
set -euo pipefail

STATE="${XDG_RUNTIME_DIR:-/tmp}/dotfiles-display-profile"
APPLY="${HOME}/.config/dotfiles/endeavour/displays/apply-display-profile.sh"

current=$(cat "$STATE" 2>/dev/null || echo unknown)
detected=$("$APPLY" detect 2>/dev/null || echo "?")

case "$current" in
	home) letter=H ;;
	work) letter=W ;;
	laptop) letter=L ;;
	*) letter="?" ;;
esac

icon=$'\uf108' # desktop / display
text=" ${icon} ${letter} "

tooltip="Display: ${current}"
if [[ "$detected" != "?" && "$detected" != skip && "$detected" != "$current" ]]; then
	tooltip="${tooltip} (detected: ${detected})"
fi
tooltip="${tooltip}"$'\n'"Click: profile menu"

export TEXT="$text" TOOLTIP="$tooltip" MISMATCH=
if [[ "$detected" != "?" && "$detected" != skip && "$detected" != "$current" ]]; then
	MISMATCH=1
fi

python3 <<'PY'
import json, os
payload = {"text": os.environ["TEXT"], "tooltip": os.environ["TOOLTIP"]}
if os.environ.get("MISMATCH"):
    payload["class"] = "mismatch"
print(json.dumps(payload))
PY
