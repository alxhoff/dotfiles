# dotfiles

Configs for **EndeavourOS**, Hyprland (via [ML4W starter](https://github.com/mylinuxforwork/hyprland-starter)), fish, vim, and Docker dev workflows.

| Doc | When |
|-----|------|
| [AGENTS.md](AGENTS.md) | **Cursor / agent onboarding** — architecture, reproduce steps, what's automated |
| [docs/ENDEAVOUROS.md](docs/ENDEAVOUROS.md) | **Daily use** on the new system |
| [docs/MIGRATION.md](docs/MIGRATION.md) | Backup disk restore (mostly done) |
| [migrate/SESSION-LOG.md](migrate/SESSION-LOG.md) | Agent notes + Cursor repair history |
| [packages/README.md](packages/README.md) | pacman / yay / flatpak selection |

## Quick start

```bash
git clone --recurse-submodules git@github.com:alxhoff/dotfiles.git ~/git/Github/dotfiles
cd ~/git/Github/dotfiles
./packages/install-packages.sh
./endeavour/setup-hyprland.sh    # ML4W + install.sh + fish theme — docs/HYPRLAND-SETUP.md
vim +PlugInstall +qall
```

`setup-hyprland.sh` runs `install.sh` (symlinks vim, fish, docker, …). Quit Cursor first if you want automatic workspace/chat repair during that step.

## Layout

| Path | Purpose |
|------|---------|
| `fish/` | Fish + `ub20`/`ub22`/`ub24` Docker shells |
| `bash/`, `git/` | bashrc, gitconfig |
| `vim/` | Submodule |
| `docker/` | Windows VM compose (`windows` fish function) |
| `bin/` | `spotify-adblock`, etc. |
| `endeavour/` | **Hyprland setup** (`setup-hyprland.sh`), ML4W patches, displays |
| `packages/` | Install lists for pacman/yay/flatpak |
| `migrate/` | DD backup restore + Cursor fixes |
| `i3/`, `polybar/`, `rofi/` | Legacy Manjaro/X11 (reference) |

## Fish

- `ub22`, `ub24` — Ubuntu dev containers
- `windows` — Windows 11 in Docker (http://localhost:8006)
- `g`, `f`, `fc`, `gcp`, … — search/git helpers

## License

GPL — see [LICENSE](LICENSE).
