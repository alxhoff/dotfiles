# Package migration (Manjaro → EndeavourOS)

Export what is installed on this machine, **choose** what to reinstall, and run the same set on the new system.

## Workflow

### 1. Export inventory (this machine)

```bash
cd ~/git/Github/dotfiles
./packages/export-inventory.sh
```

Creates `packages/inventory/`:

| File | Source |
|------|--------|
| `pacman.txt` | Official repo, explicitly installed (`pacman -Qen`) — **334** on this PC |
| `aur.txt` | AUR / foreign (`pacman -Qem`) — **32** |
| `flatpak-apps.txt` | User Flatpaks — **2** (Discord, KiCad) |
| `flatpak-runtimes.txt` | Flatpak runtimes — usually install only if an app needs a specific one |
| `pip-user.txt`, `npm-global.txt` | Optional language package managers |

### 2. Choose packages (interactive)

```bash
./packages/select-packages.sh --merge-recommended
```

Uses **fzf** (multi-select: TAB toggle, ENTER confirm). Run once per category.

- Starts from `packages/recommended/*.list` when using `--merge-recommended`
- Saves choices to `packages/selected/*.list` (commit these to git)

Without fzf, edit `packages/selected/*.list` by hand (one package name per line, `#` comments allowed).

### 3. Install on new machine

After EndeavourOS base install and dotfiles clone:

```bash
DRY_RUN=1 ./packages/install-packages.sh   # preview
./packages/install-packages.sh
./install.sh
```

Order: **pacman** → **yay** (auto-installed if needed) → **flatpak** → pip/npm.

Manjaro-only packages (`manjaro-*`, `mhwd`, `pamac`) are skipped automatically for AUR.

## Files to commit

- `packages/selected/*.list` — your choices
- `packages/recommended/*.list` — starting point (optional to edit)
- Do **not** commit `packages/inventory/` (machine snapshot) — it is gitignored

## Re-export

Re-run `export-inventory.sh` after installing more software; then `select-packages.sh` again to add new entries.
