# Internal function to create and launch Ubuntu containers
function _ub_launcher --description "Helper to enter/execute commands in Ubuntu containers"
    # 1. SETUP VARIABLES
    set -l ub_version $argv[1]
    set -l command_args $argv[2..-1]

    set -l container_name "ubuntu-dev-$ub_version"
    set -l image_name "ubuntu:$ub_version.04"
    set -l home_dir "$HOME"
    set -l user_name (whoami)
    xhost +

    # 2. RESOLVE DISPLAY VARIABLE
    # We calculate this once to ensure stability even if the host variable is odd
    set -l real_display $DISPLAY
    if test -z "$real_display"
        set real_display ":0"
    end

    # 3. PRE-FLIGHT CHECKS
    if not command -v docker > /dev/null
        echo "Docker is not installed. Please install it first." >&2
        return 1
    end
    if not docker info > /dev/null 2>&1
        echo "Docker daemon is not running. Please start it first." >&2
        return 1
    end

    # 4. CHECK IF CONTAINER EXISTS
    set -l container_exists 0
    for name in (docker ps -a --format '{{.Names}}')
        if [ "$name" = "$container_name" ]
            set container_exists 1
            break
        end
    end

    # 5. CREATE CONTAINER (If needed)
    if [ $container_exists -eq 0 ]
        echo "Creating and setting up Ubuntu container '$container_name'..."
        set -l user_id (id -u)
        set -l group_id (id -g)

        docker pull $image_name

        # Create container with X11 forwarding enabled
        docker run -d \
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
            -e XAUTHORITY=$home_dir/.Xauthority \
            -v /tmp/.X11-unix:/tmp/.X11-unix \
            -v "$home_dir:$home_dir" \
            $image_name sleep infinity

        if [ $status -ne 0 ]
            echo "Failed to create the container." >&2
            return 1
        end

        # Set up user
        echo "Setting up user '$user_name'..."
        set -l existing_user (docker exec $container_name getent passwd $user_id | cut -d: -f1)
        set -l existing_group (docker exec $container_name getent group $group_id | cut -d: -f1)

        set -l setup_script "
export DEBIAN_FRONTEND=noninteractive;
apt-get update -y && apt-get install -y sudo fish xauth x11-apps;
echo '127.0.0.1 ubuntu-dev-$ub_version' >> /etc/hosts;

if [ \"$existing_user\" ]; then
    if [ \"$existing_group\" ] && [ \"$existing_group\" != \"$user_name\" ]; then
        groupmod -n $user_name $existing_group;
    fi;
    usermod -l $user_name -d $home_dir $existing_user;
    usermod -g $user_name $user_name;
else
    groupadd -g $group_id $user_name;
    useradd -u $user_id -g $group_id -d $home_dir -s /usr/bin/fish $user_name;
fi;

usermod -aG sudo $user_name;
echo '$user_name ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/$user_name;
chmod 0440 /etc/sudoers.d/$user_name;"

        docker exec $container_name bash -c $setup_script
        echo "Container '$container_name' is ready."
    end

    # 6. START CONTAINER (If stopped)
    set -l is_running 0
    for name in (docker ps --format '{{.Names}}')
        if [ "$name" = "$container_name" ]
            set is_running 1
            break
        end
    end

    if [ $is_running -eq 0 ]
        docker start $container_name > /dev/null
    end

    set -l current_dir (pwd)

    # If current directory is not inside home_dir, default to home_dir
    if not string match -qr "^$home_dir" "$current_dir"
        echo "Warning: Current directory '$current_dir' is not in the mounted home directory." >&2
        echo "Setting working directory to '$home_dir'." >&2
        set current_dir $home_dir
    end

    # 7. EXECUTE COMMAND OR SHELL
    # We pass the display variables every time to ensure GUI apps work even after re-attaching
    if count $command_args > 0
        docker exec -it -e DISPLAY=$real_display -e XAUTHORITY=$home_dir/.Xauthority -u $user_name -w "$current_dir" $container_name $command_args
    else
        docker exec -it -e DISPLAY=$real_display -e XAUTHORITY=$home_dir/.Xauthority -u $user_name -w "$current_dir" $container_name fish
    end
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
