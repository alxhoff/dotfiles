#!/usr/bin/env bash
# Shared paths for display profile scripts (source, do not execute).

resolve_dotfiles_dir() {
    if [[ -L "${HOME}/.config/dotfiles" ]]; then
        readlink -f "${HOME}/.config/dotfiles"
        return
    fi
    if [[ -f "${HOME}/.config/dotfiles-path" ]]; then
        cat "${HOME}/.config/dotfiles-path"
        return
    fi
    echo "${HOME}/git/Github/dotfiles"
}

resolve_profiles_dir() {
    local script_dir=${1:-}
    local linked="${HOME}/.config/hypr/display-profiles"
    local dotfiles repo

    dotfiles=$(resolve_dotfiles_dir)
    repo="${dotfiles}/endeavour/displays/profiles"

    if [[ -e "$linked" ]]; then
        readlink -f "$linked"
    elif [[ -d "$repo" ]]; then
        echo "$repo"
    elif [[ -n "$script_dir" && -d "$script_dir/profiles" ]]; then
        echo "$script_dir/profiles"
    else
        echo "${script_dir}/profiles"
    fi
}

link_display_profiles() {
    local dotfiles=$1
    local src="${dotfiles}/endeavour/displays/profiles"
    local dest="${HOME}/.config/hypr/display-profiles"
    [[ -d "$src" ]] || return 1
    mkdir -p "${HOME}/.config/hypr"
    ln -sfn "$src" "$dest"
    echo "$dest"
}

detect_profile_name() {
    local apply=$1
    local detected
    detected=$("$apply" detect 2>/dev/null) || detected=skip
    [[ -n "$detected" ]] || detected=skip
    printf '%s' "$detected"
}

debounce_running() {
    local debounce=$1
    [[ -f "$debounce" ]] && kill -0 "$(cat "$debounce")" 2>/dev/null
}

# Settle time before applying after hotplug (seconds).
hotplug_settle_sec() {
    local reason=$1 apply=$2 state=$3
    local current detected

    if [[ "$reason" == startup ]]; then
        detected=$(detect_profile_name "$apply")
        if [[ "$detected" == laptop ]]; then
            echo 0
        else
            echo "${HOTPLUG_SETTLE_SEC:-5}"
        fi
        return
    fi

    current=$(cat "$state" 2>/dev/null || true)
    detected=$(detect_profile_name "$apply")
    if [[ "$detected" == laptop && ( "$current" == home || "$current" == work ) ]]; then
        echo 1
    elif [[ "$current" == laptop && ( "$detected" == work || "$detected" == home ) ]]; then
        echo 2
    elif [[ "$reason" == monitorremoved ]]; then
        echo 1
    else
        echo "${HOTPLUG_SETTLE_SEC:-5}"
    fi
}
