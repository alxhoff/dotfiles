#!/usr/bin/env bash
# Launch WoW Classic via Steam + Proton (Steam Deck-style local play).
set -euo pipefail

CONFIG="${HOME}/.config/ml4w/wow-classic.env"
GAMEMODE="${HOME}/.config/ml4w/scripts/wow-classic-game-mode.sh"

usage() {
    cat <<'EOF'
Usage: wow-classic.sh [battle.net|wow|setup]

  battle.net   Launch Battle.net through Steam (default)
  wow          Launch WoW Classic if WOW_STEAM_APPID is set
  setup        Print one-time Steam + Proton-GE setup steps

Config: ~/.config/ml4w/wow-classic.env
  BNET_STEAM_APPID=...   Steam app id for Battle.net (non-Steam shortcut)
  WOW_STEAM_APPID=...    Optional direct WoW Classic shortcut app id
  PROTON_GE=...          e.g. GE-Proton10-XX (empty = Steam default)
  USE_GAMEMODE=1         Hyprland passthrough + focus before launch
  USE_GAMESCOPE=0        Wrap in gamescope fullscreen (set 1 to enable)
  GAMESCOPE_ARGS=-W 2560 -H 1440 -f
EOF
}

[[ -f "$CONFIG" ]] && source "$CONFIG"

: "${BNET_STEAM_APPID:=}"
: "${WOW_STEAM_APPID:=}"
: "${PROTON_GE:=}"
: "${USE_GAMEMODE:=1}"
: "${USE_GAMESCOPE:=0}"
: "${GAMESCOPE_ARGS:=-W 2560 -H 1440 -f}"

cmd="${1:-battle.net}"

if [[ "$cmd" == "setup" ]]; then
    usage
    cat <<'EOF'

One-time setup (Deck-style):
  1. sudo pacman -S steam
  2. yay -S proton-ge-custom-bin   (or protonplus)
  3. Steam → Settings → Compatibility → enable Steam Play for all titles
  4. Download Battle.net installer from Blizzard
  5. Steam → Add a non-Steam game → pick the installer
  6. Properties → Compatibility → force latest GE-Proton
  7. Launch once, install Battle.net, then install WoW Classic
  8. Right-click shortcut → Properties → copy App ID into wow-classic.env

Optional: add WoW Classic exe as its own non-Steam game for direct launch.

Hyprland: Alt+Esc toggles passthrough; set USE_GAMEMODE=1 in wow-classic.env.
EOF
    exit 0
fi

if ! command -v steam >/dev/null 2>&1; then
    echo "steam not installed — run: wow-classic.sh setup" >&2
    exit 1
fi

launch_steam() {
    local appid=$1
    local -a args=(steam -silent -applaunch "$appid")

    if [[ -n "$PROTON_GE" ]]; then
        export STEAM_COMPAT_CLIENT_INSTALL_PATH="${STEAM_COMPAT_CLIENT_INSTALL_PATH:-$HOME/.steam/root/compatibilitytools.d}"
        export STEAM_COMPAT_DATA_PATH="${STEAM_COMPAT_DATA_PATH:-$HOME/.steam/steam/steamapps/compatdata}"
    fi

    if [[ "$USE_GAMESCOPE" == "1" ]] && command -v gamescope >/dev/null 2>&1; then
        # shellcheck disable=SC2086
        exec gamescope $GAMESCOPE_ARGS -- "${args[@]}"
    fi

    exec "${args[@]}"
}

[[ "$USE_GAMEMODE" == "1" && -x "$GAMEMODE" ]] && "$GAMEMODE" || true

case "$cmd" in
    battle.net|bnet)
        if [[ -z "$BNET_STEAM_APPID" ]]; then
            echo "Set BNET_STEAM_APPID in $CONFIG (run: wow-classic.sh setup)" >&2
            exit 1
        fi
        launch_steam "$BNET_STEAM_APPID"
        ;;
    wow)
        if [[ -z "$WOW_STEAM_APPID" ]]; then
            echo "Set WOW_STEAM_APPID in $CONFIG or use: wow-classic.sh battle.net" >&2
            exit 1
        fi
        launch_steam "$WOW_STEAM_APPID"
        ;;
    -h|--help|help)
        usage
        ;;
    *)
        echo "Unknown command: $cmd" >&2
        usage >&2
        exit 1
        ;;
esac
