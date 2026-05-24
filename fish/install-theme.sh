#!/usr/bin/env bash
# Install Oh My Fish + bobthefish (same theme as the old system).
set -euo pipefail

OMF_DIR="${HOME}/.local/share/omf"
THEME_DIR="${OMF_DIR}/themes/bobthefish"
OMF_REPO="https://github.com/oh-my-fish/oh-my-fish.git"
THEME_REPO="https://github.com/oh-my-fish/theme-bobthefish.git"

if ! command -v fish >/dev/null; then
    echo "fish is not installed" >&2
    exit 1
fi

if ! fc-match -s 'JetBrainsMono Nerd Font' 2>/dev/null | grep -qi jetbrains; then
    if command -v pacman >/dev/null; then
        echo "==> Installing JetBrains Mono Nerd Font (bobthefish / kitty)"
        sudo pacman -S --needed --noconfirm ttf-jetbrains-mono-nerd
    else
        echo "Install a Nerd Font (e.g. ttf-jetbrains-mono-nerd) for bobthefish icons" >&2
    fi
fi

if [[ ! -f "${OMF_DIR}/init.fish" ]]; then
    echo "==> Cloning Oh My Fish"
    git clone --depth=1 "$OMF_REPO" "$OMF_DIR"
fi

if [[ ! -d "${THEME_DIR}/functions" ]]; then
    echo "==> Cloning bobthefish theme"
    mkdir -p "${OMF_DIR}/themes"
    git clone --depth=1 "$THEME_REPO" "$THEME_DIR"
fi

mkdir -p "${HOME}/.config/omf"
printf '%s\n' bobthefish >"${HOME}/.config/omf/theme"

DOTFILES_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
"${DOTFILES_DIR}/install.sh" --only fish

echo "==> Done. Open a new fish shell (kitty: Alt+Return)."
echo "    Terminal font should be a Nerd Font (kitty: JetBrainsMono Nerd Font)."
