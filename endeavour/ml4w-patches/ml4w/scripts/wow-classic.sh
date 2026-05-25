#!/usr/bin/env bash
# Launch WoW Classic via Proton-GE (Deck-style local play).
set -euo pipefail

CONFIG="${HOME}/.config/ml4w/wow-classic.env"
GAMEMODE="${HOME}/.config/ml4w/scripts/wow-classic-game-mode.sh"

usage() {
    cat <<'EOF'
Usage: wow-classic.sh [battle.net|wow|install|stop|status|configure|setup|logs]

  battle.net   Launch Battle.net via Proton-GE (default, recommended)
  wow          Launch WoW Classic exe directly if WOW_EXE is set
  install      Run Battle.net-Setup.exe into the installer prefix
  stop         Kill stuck Battle.net/Wine processes and clear prefix locks
  status       Show install path, running processes, and prefix health
  configure    Disable Battle.net GPU acceleration (fixes CEF crash on Wayland)
  setup        Print one-time setup steps
  logs         Show recent Battle.net / Proton log locations and errors

Config: ~/.config/ml4w/wow-classic.env
  BNET_COMPAT_APPID=3588130076   Wine prefix (installer shortcut app id)
  BNET_EXE=...                   Battle.net Launcher.exe inside that prefix
  USE_STEAM_RUNTIME=1            Use Steam Linux Runtime (matches Steam Play)
  PROTON_USE_WINED3D=1             Helps CEF UI on Hyprland/Wayland
  USE_GAMEMODE=1                 Hyprland passthrough before launch

Steam Play button: Force Proton-GE, point the shortcut at
  Battle.net Launcher.exe (not Battle.net.exe), and set launch options:

  STEAM_COMPAT_DATA_PATH="$HOME/.local/share/Steam/steamapps/compatdata/3588130076" PROTON_USE_XALIA=0 PROTON_DISABLE_ESYNC=1 PROTON_DISABLE_FSYNC=1 WINE_SIMULATE_WRITECOPY=1 PROTON_USE_WINED3D=1 %command%

  Then run once: wow-classic.sh configure
  Easier: use this script instead.
EOF
}

[[ -f "$CONFIG" ]] && source "$CONFIG"

: "${BNET_COMPAT_APPID:=3588130076}"
: "${BNET_EXE:=$HOME/.local/share/Steam/steamapps/compatdata/$BNET_COMPAT_APPID/pfx/drive_c/Program Files (x86)/Battle.net/Battle.net Launcher.exe}"
: "${WOW_EXE:=}"
: "${PROTON_DIR:=/usr/share/steam/compatibilitytools.d/proton-ge-custom}"
: "${STEAM_RUNTIME:=$HOME/.local/share/Steam/steamapps/common/SteamLinuxRuntime_sniper/_v2-entry-point}"
: "${USE_STEAM_RUNTIME:=1}"
: "${PROTON_DISABLE_ESYNC:=1}"
: "${PROTON_DISABLE_FSYNC:=1}"
: "${PROTON_USE_XALIA:=0}"
: "${PROTON_USE_WINED3D:=1}"
: "${PROTON_LOG:=0}"
: "${WINE_SIMULATE_WRITECOPY:=1}"
: "${WINEDLLOVERRIDES:=locationapi=d}"
: "${BNET_DISABLE_GPU:=1}"
: "${BNET_INSTALLER:=$HOME/Downloads/Battle.net-Setup.exe}"
: "${USE_GAMEMODE:=1}"
: "${USE_GAMESCOPE:=0}"
: "${GAMESCOPE_ARGS:=-W 2560 -H 1440 -f}"

bnet_config_path() {
    echo "${HOME}/.local/share/Steam/steamapps/compatdata/${BNET_COMPAT_APPID}/pfx/drive_c/users/steamuser/AppData/Roaming/Battle.net/Battle.net.config"
}

ensure_bnet_config() {
    [[ "$BNET_DISABLE_GPU" == "1" ]] || return 0
    local cfg
    cfg=$(bnet_config_path)
    [[ -f "$cfg" ]] || return 0
    python3 - "$cfg" <<'PY'
import json, sys
path = sys.argv[1]
with open(path, encoding="utf-8") as f:
    data = json.load(f)
client = data.setdefault("Client", {})
if client.get("HardwareAcceleration") == "false":
    sys.exit(0)
client["HardwareAcceleration"] = "false"
with open(path, "w", encoding="utf-8") as f:
    json.dump(data, f, indent=4)
    f.write("\n")
print(f"Set Client.HardwareAcceleration=false in {path}")
PY
}

compat_dir() {
    echo "${HOME}/.local/share/Steam/steamapps/compatdata/${BNET_COMPAT_APPID}"
}

bnet_dir() {
    echo "${HOME}/.local/share/Steam/steamapps/compatdata/${BNET_COMPAT_APPID}/pfx/drive_c/Program Files (x86)/Battle.net"
}

repair_compat_layout() {
    local root="${HOME}/.local/share/Steam/steamapps/compatdata"
    local target
    target=$(compat_dir)
    [[ -d "$target" ]] && return 0
    [[ -d "$root/pfx" ]] || return 0
    echo "Repairing prefix layout: restoring $(basename "$target")"
    mkdir -p "$target"
    for item in config_info pfx pfx.lock tracked_files version; do
        [[ -e "$root/$item" ]] || continue
        mv "$root/$item" "$target/"
    done
}

find_bnet_exe() {
    local dir
    dir=$(bnet_dir)
    if [[ -f "$dir/Battle.net Launcher.exe" ]]; then
        echo "$dir/Battle.net Launcher.exe"
    elif [[ -f "$dir/Battle.net.exe" ]]; then
        echo "$dir/Battle.net.exe"
    fi
}

find_installer() {
    local candidate
    for candidate in \
        "$BNET_INSTALLER" \
        "$HOME/Downloads/Battle.net-Setup.exe" \
        "$HOME/Downloads/Battle.net-Setup(1).exe"; do
        [[ -f "$candidate" ]] || continue
        echo "$candidate"
        return 0
    done
    return 1
}

stop_bnet() {
    local root="${HOME}/.local/share/Steam/steamapps/compatdata"
    local wineserver="${PROTON_DIR}/files/bin/wineserver"
    [[ -x "$wineserver" ]] || wineserver=$(command -v wineserver || true)

    echo "Stopping Battle.net / Wine processes..."
    pkill -f 'Battle.net Launcher.exe' 2>/dev/null || true
    pkill -f 'Battle.net.exe' 2>/dev/null || true
    pkill -f 'Agent\.9450/Agent.exe' 2>/dev/null || true
    pkill -f 'Battle.net-Setup.exe' 2>/dev/null || true
    sleep 2

    if [[ -n "$wineserver" && -x "$wineserver" ]]; then
        STEAM_COMPAT_DATA_PATH="$(compat_dir)" "$wineserver" -k 2>/dev/null || true
        STEAM_COMPAT_DATA_PATH="${root}/3528891620" "$wineserver" -k 2>/dev/null || true
    fi

    rm -f "$(compat_dir)/pfx.lock" "${root}/3528891620/pfx.lock" "${root}/pfx.lock"
    echo "Done. Prefix locks cleared."
}

cmd="${1:-battle.net}"

if [[ "$cmd" == "logs" ]]; then
    prefix="${HOME}/.local/share/Steam/steamapps/compatdata/${BNET_COMPAT_APPID}/pfx/drive_c"
    setup_logs="$prefix/ProgramData/Battle.net/Setup/bna_2/Logs"
    client_logs="$prefix/users/steamuser/AppData/Local/Battle.net/Logs"
    echo "Compat app id: $BNET_COMPAT_APPID"
    echo "Battle.net exe: $BNET_EXE"
    echo "Proton prefix:  ${HOME}/.local/share/Steam/steamapps/compatdata/${BNET_COMPAT_APPID}/pfx"
    echo
    echo "Setup logs:   $setup_logs"
    echo "Client logs:  $client_logs"
    echo "Steam logs:   $HOME/.local/share/Steam/logs/gameprocess_log.txt"
    echo "Proton debug: PROTON_LOG=1 in wow-classic.env or /tmp/steam-*.log"
    echo
    for dir in "$setup_logs" "$client_logs"; do
        [[ -d "$dir" ]] || continue
        latest=$(ls -t "$dir"/*.log 2>/dev/null | head -1)
        [[ -n "$latest" ]] || continue
        echo "== $(basename "$latest") =="
        rg -i 'error|fail|update|certificate|gpu|crash|exception|timeout' "$latest" 2>/dev/null | tail -15 || tail -15 "$latest"
        echo
    done
    exit 0
fi

if [[ "$cmd" == "stop" ]]; then
    stop_bnet
    exit 0
fi

if [[ "$cmd" == "status" ]]; then
    repair_compat_layout
    echo "Compat app id:  $BNET_COMPAT_APPID"
    echo "Prefix:         $(compat_dir)/pfx"
    exe=$(find_bnet_exe || true)
    if [[ -n "$exe" ]]; then
        echo "Install:        OK ($exe)"
    else
        echo "Install:        MISSING (run: wow-classic.sh install)"
    fi
    echo
    echo "Running processes:"
    pgrep -af 'Battle.net|Agent\.9450/Agent.exe' 2>/dev/null | grep -v pgrep || echo "  none"
    exit 0
fi

if [[ "$cmd" == "configure" ]]; then
    ensure_bnet_config
    cfg=$(bnet_config_path)
    if [[ -f "$cfg" ]]; then
        rg 'HardwareAcceleration' "$cfg" || true
    else
        echo "No config yet — run the installer first, then configure." >&2
        exit 1
    fi
    exit 0
fi

if [[ "$cmd" == "setup" ]]; then
    usage
    cat <<'EOF'

One-time setup:
  1. yay -S proton-ge-custom-bin
  2. Steam → Settings → Compatibility → enable Steam Play for all titles
  3. Add Battle.net-Setup.exe as non-Steam game, force Proton-GE, run installer
  4. Launch Battle.net with: wow-classic.sh battle.net

If Steam Play does nothing: the shortcut likely lacks "Force Proton-GE", or
launch options are missing %command%. If it starts then dies quickly, add
STEAM_COMPAT_DATA_PATH pointing at the installer prefix (3588130076).
If it dies after ~30s with GPU errors in logs, run: wow-classic.sh configure
This script bypasses all of the above.
EOF
    exit 0
fi

launch_proton() {
    local exe=$1
    shift || true

    repair_compat_layout

    if [[ ! -f "$exe" ]]; then
        echo "Missing: $exe" >&2
        if installer=$(find_installer || true); then
            echo "Battle.net is not installed. Run: wow-classic.sh install" >&2
            echo "Installer found at: $installer" >&2
        else
            echo "Download Battle.net-Setup.exe, then run: wow-classic.sh install" >&2
        fi
        exit 1
    fi
    if [[ ! -x "${PROTON_DIR}/proton" ]]; then
        echo "Proton not found: ${PROTON_DIR}/proton" >&2
        exit 1
    fi

    ensure_bnet_config

    export STEAM_COMPAT_DATA_PATH="${HOME}/.local/share/Steam/steamapps/compatdata/${BNET_COMPAT_APPID}"
    export STEAM_COMPAT_CLIENT_INSTALL_PATH="/usr/share/steam/compatibilitytools.d"
    export PROTON_DISABLE_ESYNC PROTON_DISABLE_FSYNC PROTON_USE_XALIA PROTON_USE_WINED3D PROTON_LOG
    export WINE_SIMULATE_WRITECOPY WINEDLLOVERRIDES

    local proton=( "${PROTON_DIR}/proton" run "$exe" "$@" )
    if [[ "$USE_STEAM_RUNTIME" == "1" && -x "$STEAM_RUNTIME" ]]; then
        proton=( "$STEAM_RUNTIME" --verb=waitforexitandrun -- "${PROTON_DIR}/proton" waitforexitandrun "$exe" "$@" )
    fi

    if [[ "$USE_GAMESCOPE" == "1" ]] && command -v gamescope >/dev/null 2>&1; then
        # shellcheck disable=SC2086
        exec gamescope $GAMESCOPE_ARGS -- "${proton[@]}"
    fi

    exec "${proton[@]}"
}

[[ "$USE_GAMEMODE" == "1" && -x "$GAMEMODE" ]] && "$GAMEMODE" || true

case "$cmd" in
    battle.net|bnet)
        stop_bnet
        exe=$(find_bnet_exe || true)
        [[ -n "$exe" ]] || exe="$BNET_EXE"
        launch_proton "$exe"
        ;;
    install|installer)
        stop_bnet
        installer=$(find_installer) || {
            echo "Battle.net-Setup.exe not found in ~/Downloads" >&2
            exit 1
        }
        echo "Running installer: $installer"
        launch_proton "$installer"
        ;;
    wow)
        if [[ -z "$WOW_EXE" ]]; then
            echo "Set WOW_EXE in $CONFIG or use: wow-classic.sh battle.net" >&2
            exit 1
        fi
        launch_proton "$WOW_EXE"
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
