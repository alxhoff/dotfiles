# Docker helpers for Ubuntu dev containers (ub20/22/24/26) on Hyprland/Wayland.

function _ub_in_docker_group --description "True if user is in docker group (passwd db, not session)"
    set -l members (getent group docker 2>/dev/null | cut -d: -f4 | string split ',')
    contains -- $USER $members
end

function _ub_docker --description "Run docker; sg docker when group not yet in session"
    if docker info >/dev/null 2>&1
        docker $argv
        return $status
    end
    if _ub_in_docker_group
        set -l parts docker
        for arg in $argv
            set -a parts (string escape -- $arg)
        end
        echo "Note: docker group not active in this shell — using sg docker (new terminal avoids this)." >&2
        sg docker -c (string join -- ' ' $parts)
        return $status
    end
    docker $argv
end

function _ub_docker_ready --description "Check docker CLI and daemon access"
    if not command -v docker >/dev/null
        echo "Docker is not installed. Please install it first." >&2
        return 1
    end
    if _ub_docker info >/dev/null 2>&1
        return 0
    end
    if not systemctl is-active --quiet docker 2>/dev/null
        echo "Docker service is stopped. Run: sudo systemctl start docker" >&2
        return 1
    end
    if not _ub_in_docker_group
        echo "Your user is not in the 'docker' group." >&2
        echo "  sudo usermod -aG docker $USER" >&2
        echo "Then log out and back in (or: newgrp docker)." >&2
        return 1
    end
    echo "Cannot connect to the Docker daemon." >&2
    return 1
end

function _ub_setup_script --description "Path to in-container user setup script"
    set -l dotfiles "$HOME/.config/dotfiles"
    if test -f "$dotfiles/docker/ub-container-setup.sh"
        echo "$dotfiles/docker/ub-container-setup.sh"
    else
        echo (dirname (status filename))/../docker/ub-container-setup.sh
    end
end

function _ub_setup_user --description "Create/sync host user inside Ubuntu dev container"
    set -l container_name $argv[1]
    set -l ub_version $argv[2]
    set -l user_name (whoami)
    set -l user_id (id -u)
    set -l group_id (id -g)
    set -l home_dir "$HOME"
    set -l setup_script (_ub_setup_script)

    if not test -f "$setup_script"
        echo "Missing setup script: $setup_script" >&2
        return 1
    end

    echo "Setting up user '$user_name' in $container_name..."
    _ub_docker exec -i $container_name env \
        UB_USER=$user_name \
        UB_UID=$user_id \
        UB_GID=$group_id \
        UB_HOME=$home_dir \
        UB_HOST=ubuntu-dev-$ub_version \
        bash -s <$setup_script
end

function _ub_user_ready --description "True if container has the host user account"
    set -l container_name $argv[1]
    set -l user_name (whoami)
    _ub_docker exec $container_name getent passwd $user_name >/dev/null 2>&1
end

function _ub_launcher --description "Helper to enter/execute commands in Ubuntu containers"
    set -l ub_version $argv[1]
    set -l command_args $argv[2..-1]

    set -l container_name "ubuntu-dev-$ub_version"
    set -l image_name "ubuntu:$ub_version.04"
    set -l home_dir "$HOME"
    set -l user_name (whoami)

    if functions -q docker_x11_setup
        docker_x11_setup
    else if set -q WAYLAND_DISPLAY; and test -z "$DISPLAY"
        set -gx DISPLAY :0
    end

    set -l real_display $DISPLAY
    if test -z "$real_display"
        set real_display ":0"
    end

    set -l xauth_path $XAUTHORITY
    if test -z "$xauth_path"
        set xauth_path "$home_dir/.Xauthority"
    end

    if not _ub_docker_ready
        return 1
    end

    set -l container_exists 0
    for name in (_ub_docker ps -a --format '{{.Names}}')
        if test "$name" = "$container_name"
            set container_exists 1
            break
        end
    end

    if test $container_exists -eq 0
        echo "Creating and setting up Ubuntu container '$container_name'..."
        set -l user_id (id -u)
        set -l group_id (id -g)

        _ub_docker pull $image_name

        _ub_docker run -d \
            --privileged \
            --cap-add=SYS_ADMIN \
            --device=/dev/loop-control \
            --device=/dev/loop0 \
            --device=/dev/loop1 \
            --device=/dev/loop2 \
            --device=/dev/loop3 \
            --device=/dev/loop4 \
            --device=/dev/loop5 \
            --device=/dev/loop6 \
            --device=/dev/loop7 \
            --name $container_name \
            --network host \
            --hostname "ubuntu-dev-$ub_version" \
            --add-host=host.docker.internal:host-gateway \
            -e DISPLAY=$real_display \
            -e XAUTHORITY=$xauth_path \
            -v /tmp/.X11-unix:/tmp/.X11-unix \
            -v "$home_dir:$home_dir" \
            $image_name sleep infinity

        if test $status -ne 0
            echo "Failed to create the container." >&2
            return 1
        end

        _ub_setup_user $container_name $ub_version
        echo "Container '$container_name' is ready."
    else if not _ub_user_ready $container_name
        echo "Container '$container_name' exists but user '$user_name' is missing — repairing..." >&2
        _ub_setup_user $container_name $ub_version
    end

    set -l is_running 0
    for name in (_ub_docker ps --format '{{.Names}}')
        if test "$name" = "$container_name"
            set is_running 1
            break
        end
    end

    if test $is_running -eq 0
        _ub_docker start $container_name >/dev/null
    end

    set -l current_dir (pwd)
    if not string match -qr "^$home_dir" "$current_dir"
        echo "Warning: Current directory '$current_dir' is not in the mounted home directory." >&2
        echo "Setting working directory to '$home_dir'." >&2
        set current_dir $home_dir
    end

    if test (count $command_args) -gt 0
        _ub_docker exec -it -e DISPLAY=$real_display -e XAUTHORITY=$xauth_path -u $user_name -w "$current_dir" $container_name $command_args
    else
        _ub_docker exec -it -e DISPLAY=$real_display -e XAUTHORITY=$xauth_path -u $user_name -w "$current_dir" $container_name fish
    end
end

function ub-reload --description "Reload ub/wayland fish helpers after dotfiles update"
    source ~/.config/fish/conf.d/wayland.fish
    source ~/.config/fish/conf.d/ub.fish
    echo "Reloaded ub20/ub22/ub24/ub26 helpers."
end

function ub-reset --description "Remove Ubuntu dev container (e.g. ub-reset 22)"
    set -l ub_version $argv[1]
    if test -z "$ub_version"
        echo "Usage: ub-reset <20|22|24|26>" >&2
        return 1
    end
    _ub_docker rm -f ubuntu-dev-$ub_version
end

function ub20 --description "Enter or execute commands in the Ubuntu 20.04 container"
    _ub_launcher 20 $argv
end

function ub22 --description "Enter or execute commands in the Ubuntu 22.04 container"
    _ub_launcher 22 $argv
end

function ub24 --description "Enter or execute commands in the Ubuntu 24.04 container"
    _ub_launcher 24 $argv
end

function ub26 --description "Enter or execute commands in the Ubuntu 26.04 container"
    _ub_launcher 26 $argv
end
