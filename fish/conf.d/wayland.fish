# X11 / XWayland helpers for Docker GUI apps (ub22, etc.) on Hyprland/Wayland
function docker_x11_setup --description "Prepare DISPLAY/xhost for GUI apps in Docker"
    if set -q WAYLAND_DISPLAY; and test -z "$DISPLAY"
        set -gx DISPLAY :0
    end
    if test -z "$XAUTHORITY"; and test -f "$HOME/.Xauthority"
        set -gx XAUTHORITY "$HOME/.Xauthority"
    end
    # Optional: pacman -S xorg-xhost
    if type -q xhost
        xhost +local: >/dev/null 2>&1
    end
end

if status is-interactive
    docker_x11_setup
end
