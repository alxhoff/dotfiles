#!/usr/bin/env bash
# Interactively choose packages to install on the new machine (requires fzf).
#
# Usage:
#   ./packages/export-inventory.sh
#   ./packages/select-packages.sh
#   ./packages/select-packages.sh --merge-recommended   # seed from recommended/*.list
#
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
INV="$SCRIPT_DIR/inventory"
SEL="$SCRIPT_DIR/selected"
REC="$SCRIPT_DIR/recommended"

MERGE_REC=0
[[ "${1:-}" == "--merge-recommended" ]] && MERGE_REC=1

if ! command -v fzf >/dev/null; then
    echo "fzf is required: pacman -S fzf" >&2
    echo "Or edit $SEL/*.list manually (one package per line)." >&2
    exit 1
fi

[[ -f "$INV/pacman.txt" ]] || {
    echo "Run ./packages/export-inventory.sh first." >&2
    exit 1
}

mkdir -p "$SEL"

seed_from_recommended() {
    local tag=$1
    local out=$2
    [[ "$MERGE_REC" != 1 ]] && return 0
    [[ -f "$REC/${tag}.list" ]] || return 0
    if [[ ! -s "$out" ]]; then
        grep -v '^#' "$REC/${tag}.list" | grep -v '^[[:space:]]*$' | sort -u >"$out"
    else
        { cat "$out"; grep -v '^#' "$REC/${tag}.list"; } | grep -v '^[[:space:]]*$' | sort -u >"${out}.tmp"
        mv "${out}.tmp" "$out"
    fi
}

select_category() {
    local tag=$1
    local inv_file=$2
    local out_file=$3
    local title=$4

    [[ -f "$inv_file" && -s "$inv_file" ]] || { : >"$out_file"; return 0; }

    seed_from_recommended "$tag" "$out_file"

    local prev=0
    [[ -s "$out_file" ]] && prev=$(wc -l <"$out_file")

    local result
    result=$(
        sort -u "$inv_file" | fzf --multi \
            --height=85% \
            --header="$title | inventory: $(wc -l <"$inv_file") | previously selected: $prev" \
            --preview='pacman -Qi {} 2>/dev/null | head -18 || flatpak info {} 2>/dev/null | head -12 || echo no-info' \
            --bind='ctrl-a:select-all,ctrl-d:deselect-all' \
            2>/dev/null || true
    )

    if [[ -n "$result" ]]; then
        echo "$result" | sort -u >"$out_file"
        echo "  $tag: $(wc -l <"$out_file") packages → $out_file"
    else
        echo "  $tag: unchanged ($(wc -l <"$out_file" 2>/dev/null || echo 0) packages)"
    fi
}

echo "Interactive package selection (fzf)"
echo "  TAB = toggle, ENTER = confirm, ESC = keep previous selection"
echo ""

select_category pacman "$INV/pacman.txt" "$SEL/pacman.list" "Pacman — official repo"
select_category aur "$INV/aur.txt" "$SEL/aur.list" "AUR — yay"
select_category flatpak "$INV/flatpak-apps.txt" "$SEL/flatpak-apps.list" "Flatpak applications"
select_category flatpak-runtime "$INV/flatpak-runtimes.txt" "$SEL/flatpak-runtimes.list" "Flatpak runtimes"

if [[ -s "$INV/pip-user.txt" ]]; then
    read -r -p "Configure pip --user packages? [y/N] " ans
    [[ "$ans" =~ ^[Yy]$ ]] && select_category pip "$INV/pip-user.txt" "$SEL/pip-user.list" "pip user"
fi

if [[ -s "$INV/npm-global.txt" ]]; then
    read -r -p "Configure global npm packages? [y/N] " ans
    [[ "$ans" =~ ^[Yy]$ ]] && select_category npm "$INV/npm-global.txt" "$SEL/npm-global.list" "npm global"
fi

echo ""
echo "Saved under $SEL/"
ls -la "$SEL/" 2>/dev/null || true
echo "Install on new machine:  ./packages/install-packages.sh"
