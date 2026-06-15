#!/usr/bin/env bash
# Symlink dotfiles into $HOME. Safe to re-run.
#
# Usage:
#   ./install.sh              # install everything
#   ./install.sh --dry-run    # print actions only
#   ./install.sh --only fish,vim,docker
#   ./install.sh --only displays        # symlink hypr display profiles from repo
#   ./install.sh --only configs         # all repo-owned config symlinks (needs ML4W)
#   ./install.sh --only hypr           # vanilla Hyprland (replaces ML4W symlink)
#   ./install.sh --only fish,wayland   # fish + Wayland Docker helpers
#
set -euo pipefail

DOTFILES_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
TARGET_HOME=${TARGET_HOME:-$HOME}
DRY_RUN=0
ONLY=""

usage() {
    sed -n '2,8p' "$0"
    exit 0
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run) DRY_RUN=1 ;;
        --only) ONLY=$2; shift ;;
        -h|--help) usage ;;
        *) echo "Unknown option: $1" >&2; exit 1 ;;
    esac
    shift
done

want() {
    [[ -z "$ONLY" ]] && return 0
    echo ",$ONLY," | grep -q ",$1,"
}

link_path() {
    local src=$1
    local dest=$2

    [[ -e "$src" ]] || { echo "skip missing source: $src"; return 0; }

    mkdir -p "$(dirname "$dest")"

    if [[ -L "$dest" && "$(readlink -f "$dest")" == "$(readlink -f "$src")" ]]; then
        echo "ok (already linked): $dest"
        return 0
    fi

    if [[ -e "$dest" || -L "$dest" ]]; then
        local backup="$dest.dotfiles-backup.$(date +%Y%m%d%H%M%S)"
        if [[ "$DRY_RUN" == 1 ]]; then
            echo "would backup: $dest -> $backup"
        else
            mv "$dest" "$backup"
            echo "backed up: $dest -> $backup"
        fi
    fi

    if [[ "$DRY_RUN" == 1 ]]; then
        echo "would link: $dest -> $src"
    else
        ln -sfn "$src" "$dest"
        echo "linked: $dest -> $src"
    fi
}

echo "Dotfiles: $DOTFILES_DIR"
echo "Target:   $TARGET_HOME"
[[ "$DRY_RUN" == 1 ]] && echo "(dry run)"

if [[ "$DRY_RUN" != 1 ]]; then
    mkdir -p "$TARGET_HOME/.config"
    printf '%s\n' "$DOTFILES_DIR" >"$TARGET_HOME/.config/dotfiles-path"
fi

# --- Fish ---
if want fish; then
    mkdir -p "$TARGET_HOME/.config/fish/conf.d"
    link_path "$DOTFILES_DIR/fish/config.fish" "$TARGET_HOME/.config/fish/config.fish"
    link_path "$DOTFILES_DIR/fish/conf.d/ub.fish" "$TARGET_HOME/.config/fish/conf.d/ub.fish"
    link_path "$DOTFILES_DIR/fish/conf.d/omf.fish" "$TARGET_HOME/.config/fish/conf.d/omf.fish"
    link_path "$DOTFILES_DIR/fish/conf.d/bobthefish.fish" "$TARGET_HOME/.config/fish/conf.d/bobthefish.fish"
    if [[ -f "$DOTFILES_DIR/fish/conf.d/wayland.fish" ]]; then
        link_path "$DOTFILES_DIR/fish/conf.d/wayland.fish" "$TARGET_HOME/.config/fish/conf.d/wayland.fish"
    fi
    if [[ -f "$DOTFILES_DIR/fish/conf.d/terminal-erase.fish" ]]; then
        link_path "$DOTFILES_DIR/fish/conf.d/terminal-erase.fish" "$TARGET_HOME/.config/fish/conf.d/terminal-erase.fish"
    fi
fi

# --- Bash ---
if want bash; then
    link_path "$DOTFILES_DIR/bash/bashrc" "$TARGET_HOME/.bashrc"
    link_path "$DOTFILES_DIR/bash/inputrc" "$TARGET_HOME/.inputrc"
    link_path "$DOTFILES_DIR/bash/bash_profile" "$TARGET_HOME/.bash_profile"
    link_path "$DOTFILES_DIR/bash/fzf.bash" "$TARGET_HOME/.fzf.bash"
    if [[ -f "$DOTFILES_DIR/bash/dir_colors" ]]; then
        link_path "$DOTFILES_DIR/bash/dir_colors" "$TARGET_HOME/.dir_colors"
    fi
fi

# --- Git ---
if want git; then
    link_path "$DOTFILES_DIR/git/gitconfig" "$TARGET_HOME/.gitconfig"
fi

# --- Vim (submodule) ---
if want vim; then
    if [[ ! -f "$DOTFILES_DIR/vim/vimrc" ]]; then
        echo "vim submodule missing — run: git submodule update --init vim"
    else
        link_path "$DOTFILES_DIR/vim/vim" "$TARGET_HOME/.vim"
        link_path "$DOTFILES_DIR/vim/vimrc" "$TARGET_HOME/.vimrc"
        link_path "$DOTFILES_DIR/vim/vim_runtime" "$TARGET_HOME/.vim_runtime"
    fi
fi

# --- Desktop (legacy X11) ---
if want polybar; then
    link_path "$DOTFILES_DIR/polybar" "$TARGET_HOME/.config/polybar"
fi
if want rofi; then
    link_path "$DOTFILES_DIR/rofi" "$TARGET_HOME/.config/rofi"
fi
if want xdg || [[ -z "$ONLY" ]]; then
    link_path "$DOTFILES_DIR/xdg/mimeapps.list" "$TARGET_HOME/.config/mimeapps.list"
fi
if want hypr; then
    mkdir -p "$TARGET_HOME/.config"
    if [[ -z "$ONLY" ]] && [[ -d "$TARGET_HOME/.mydotfiles/com.ml4w.hyprlandstarter/.config/hypr" ]]; then
        echo "skip vanilla hypr: ML4W installed (use --only hypr to replace with dotfiles/hypr)"
    else
        link_path "$DOTFILES_DIR/hypr" "$TARGET_HOME/.config/hypr"
    fi
fi
if want i3; then
    mkdir -p "$TARGET_HOME/.config"
    link_path "$DOTFILES_DIR/i3" "$TARGET_HOME/.config/i3"
fi
if want sway; then
    mkdir -p "$TARGET_HOME/.config"
    link_path "$DOTFILES_DIR/sway" "$TARGET_HOME/.config/sway"
fi

# --- Docker Windows VM ---
if want docker; then
    link_path "$DOTFILES_DIR/docker/compose.yaml" "$TARGET_HOME/compose.yaml"
    mkdir -p "$TARGET_HOME/.local/bin"
    link_path "$DOTFILES_DIR/docker/windows-pause-on-boot.sh" \
        "$TARGET_HOME/.local/bin/windows-pause-on-boot.sh"
    if [[ "$DRY_RUN" != 1 ]]; then
        chmod +x "$TARGET_HOME/.local/bin/windows-pause-on-boot.sh" 2>/dev/null || true
    fi
    mkdir -p "$TARGET_HOME/.config/systemd/user"
    link_path "$DOTFILES_DIR/docker/windows-pause-on-boot.service" \
        "$TARGET_HOME/.config/systemd/user/windows-pause-on-boot.service"
    if [[ "$DRY_RUN" != 1 ]] && command -v systemctl >/dev/null; then
        systemctl --user daemon-reload
        systemctl --user enable windows-pause-on-boot.service 2>/dev/null || true
    fi
fi

# --- User binaries ---
if want bin; then
    mkdir -p "$TARGET_HOME/.local/bin"
    for f in "$DOTFILES_DIR"/bin/*; do
        [[ -f "$f" ]] || continue
        base=$(basename "$f")
        link_path "$f" "$TARGET_HOME/.local/bin/$base"
        if [[ "$DRY_RUN" != 1 && -x "$TARGET_HOME/.local/bin/$base" ]]; then
            :
        elif [[ "$DRY_RUN" != 1 ]]; then
            chmod +x "$TARGET_HOME/.local/bin/$base" 2>/dev/null || true
        fi
    done
fi

# --- Misc dotfiles at repo root ---
if want gdb; then
    link_path "$DOTFILES_DIR/.gdbinit" "$TARGET_HOME/.gdbinit"
fi

# --- Hyprland display profiles (repo is source of truth) ---
if want displays; then
    mkdir -p "$TARGET_HOME/.config/hypr"
    link_path "$DOTFILES_DIR/endeavour/displays/profiles" "$TARGET_HOME/.config/hypr/display-profiles"
fi

# --- ML4W / Hyprland dotfiles symlinks (requires install-ml4w-starter.sh) ---
if want configs; then
    if [[ -d "$TARGET_HOME/.mydotfiles/com.ml4w.hyprlandstarter/.config/hypr" ]]; then
        if [[ "$DRY_RUN" == 1 ]]; then
            echo "would run: $DOTFILES_DIR/endeavour/link-configs.sh --dry-run"
        else
            HOME="$TARGET_HOME" "$DOTFILES_DIR/endeavour/link-configs.sh"
        fi
    else
        echo "skip configs: ML4W not installed (run ./endeavour/install-ml4w-starter.sh)"
    fi
fi

echo ""
echo "Done. For vim plugins: vim +PlugInstall +qall"
echo "EndeavourOS guide: docs/ENDEAVOUROS.md"
echo "Hyprland (ML4W):   ./endeavour/setup-hyprland.sh  (see docs/HYPRLAND-SETUP.md)"
echo "Migration (if needed): ./migrate/restore-all.sh — see docs/MIGRATION.md"

# --- Cursor chat history (duplicate workspace IDs after opening Cursor too early) ---
if [[ "$DRY_RUN" != 1 && -d "$TARGET_HOME/.config/Cursor/User/workspaceStorage" ]]; then
    # shellcheck source=migrate/lib.sh
    source "$DOTFILES_DIR/migrate/lib.sh"
    MIGRATE_SCRIPT_DIR="$DOTFILES_DIR/migrate"
    if migrate_cursor_running; then
        echo ""
        echo "Cursor is running — quit it completely, then run:"
        echo "  cd $DOTFILES_DIR && ./migrate/fix-cursor-workspaces.sh"
    else
        echo ""
        echo "Repairing Cursor workspace / chat bindings..."
        migrate_fix_cursor_workspaces "$TARGET_HOME" 0 || true
    fi
fi
