# ML4W config overrides

Copied into `~/.mydotfiles/com.ml4w.hyprlandstarter/.config/` by `apply-ml4w-patches.sh`.

| File | Why |
|------|-----|
| `hypr/conf/layouts.conf` | Remove `pseudotile` (Hyprland 0.55) |
| `hypr/conf/gestures.conf` | Replace `workspace_swipe` with `gesture = 3, horizontal, workspace` |
| `hypr/conf/autostart.conf` | Disable missing ML4W Settings flatpak hook |
| `waybar/style.css.font-family` | Fira Sans for default bar text |
| `waybar/style-overrides.css` | Fira for `#window`/workspaces; FA only on icon modules |
| `waybar/hyprland-workspaces.jsonc` | Workspaces **1–4 only** (`persistent-only`) |

`binds.conf` and `waybar/modules.json` are patched in the apply script (upstream line may vary).
