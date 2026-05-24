# X11 / XWayland helpers for Docker GUI apps (ub22, etc.) on Hyprland
if status is-interactive
    if set -q WAYLAND_DISPLAY
        # XWayland typically uses :0
        if test -z "$DISPLAY"
            set -gx DISPLAY :0
        end
        # Allow local rootless docker X11 clients (optional; needs xorg-xhost)
        if type -q xhost
            xhost +local: >/dev/null 2>&1
        end
    end
end
