if status is-interactive
    # Commands to run in interactive sessions can go here
end

alias v='vim'
    
function g
    # grep -r --color=auto --exclude-dir={.git,node_modules} $argv .
    grep -n -r --color=auto --exclude=tags --exclude=TAGS --exclude-dir={.git,node_modules} "$argv" . 2>/dev/null
end

function f
    find . -name "$argv" 2>/dev/null
end

function fa 
    find . -name "$argv" -exec realpath {} \; 2>/dev/null
end

function fc
    # Run find with the arguments and redirect errors to /dev/null
    set result (find . -name $argv 2>/dev/null)

    # Check if there is any result
    if test -n "$result"
        # Save the result to the clipboard
        echo "$result" | xclip -selection clipboard
        echo "Copied to clipboard:"
        echo "$result"
    else
        echo "No results found."
    end
end

function t
    set current_dir (pwd)
    xfce4-terminal --working-directory="$current_dir" &
end

function git-push-all
    # Loop through each remote and push to it
    for remote in (git remote)
        echo "Pushing to $remote..."
        git push $remote $argv
    end
end

function cjs
    # Variables
    set SERIAL_CONSOLE "/dev/serial/by-id/usb-NVIDIA_Tegra_On-Platform_Operator_TOPO0C5FB339-if03"
    set BAUD_RATE 115200

    echo "Jetson Serial Connection"
    echo "-------------------------"
    echo "Using $SERIAL_CONSOLE for serial communication."

    # Check if the device exists
    if test -e $SERIAL_CONSOLE
        echo "✅ Found device: $SERIAL_CONSOLE"
        echo "Attempting to connect at $BAUD_RATE baud..."
        sudo minicom -D $SERIAL_CONSOLE -b $BAUD_RATE
    else
        echo "❌ Device $SERIAL_CONSOLE not found. Ensure the Jetson is connected."
        return 1
    end
end

function m
    # Fetch unmounted partitions with name and size
    set -l unmounted (lsblk -rpo "NAME,SIZE,TYPE,MOUNTPOINT" | grep -E "part\s+" | awk '{print $1 " " $2}')

    if test (count $unmounted) -eq 0
        echo "No unmounted partitions found."
        return 1
    end

    echo "Unmounted partitions:"
    for i in (seq 1 (count $unmounted))
        echo "$i: $unmounted[$i]"
    end

    echo -n "Enter the index of the partition to mount: "
    read index

    if not test "$index" -gt 0 -a "$index" -le (count $unmounted)
        echo "Invalid index."
        return 1
    end

    # Extract partition name
    set partition (string split " " $unmounted[$index])[1]
    echo "Mounting $partition to /mnt..."
    sudo mount $partition /mnt
    if test $status -eq 0
        echo "$partition successfully mounted to /mnt."
        echo "Changing directory to /mnt..."
        cd /mnt
    else
        echo "Failed to mount $partition."
    end
end

function u
    echo "Unmounting /mnt..."
    sudo umount /mnt
    if test $status -eq 0
        echo "/mnt successfully unmounted."
    else
        echo "Failed to unmount /mnt."
    end
end

function s
    if test (count $argv) -lt 1
        echo "Usage: s <last_octet> [c]"
        return 1
    end

    set ip 192.168.1.$argv[1]
    set user "alxhoff"

    if test (count $argv) -eq 2
        if test $argv[2] = "c"
            set user "cartken"
        end
    end

    ssh $user@$ip
end

function sc
    if test (count $argv) -lt 1
        echo "Usage: sc <last_octet> [c]"
        return 1
    end

    set ip 192.168.1.$argv[1]
    set user "alxhoff"

    if test (count $argv) -eq 2
        if test $argv[2] = "c"
            set user "cartken"
        end
    end

    ssh-copy-id $user@$ip
end

function ubunt
    # Define the IPs and credentials
    set local_ip 192.168.1.178
    set meshnet_ip ubuntu
    set user alxhoff
    set password 008637hh
    set domain .

    # Test connectivity to local IP first
    if ping -c 1 -W 1 $local_ip > /dev/null
        echo "Connecting to local address: $local_ip"
        xfreerdp3 /v:$local_ip /d:$domain /u:$user /p:$password &
    else
        echo "Local address not reachable, connecting to meshnet: $meshnet_ip"
        xfreerdp3 /v:$meshnet_ip /d:$domain /u:$user /p:$password &
    end

    # Save the process ID of xfreerdp to a file
    echo $last_pid > ~/.rdp_session.pid
    echo "RDP session started with PID $last_pid."
end

function dubunt
    # Kill the background RDP connection
    if test -f ~/.rdp_session.pid
        set pid (cat ~/.rdp_session.pid)
        if kill $pid > /dev/null ^&1
            echo "Disconnected from the remote session (PID: $pid)."
        else
            echo "Failed to kill process. It may already be terminated."
        end
        rm ~/.rdp_session.pid
    else
        echo "No active RDP session found."
    end
end

function sync
    # Get the username of the caller
    set user (whoami)

    # Check if an argument was provided
    if test (count $argv) -gt 0
        # Use the argument to construct the IP address
        set ip "192.168.1.$argv[1]"
    else
        # Default to hostname "ubuntu"
        set ip "ubuntu"
    end

    # Rsync command to create a perfect copy
    rsync -aAXv --delete /home/$user/git/ $user@$ip:/home/$user/git/
end

function sub
    # Get the username of the caller
    set user (whoami)

    # SSH into the target using the caller's username
    ssh $user@ubuntu
end

function catc
    if test (count $argv) -ne 1
        echo "Usage: catc <file>"
        return 1
    end

    if not test -f $argv[1]
        echo "File not found: $argv[1]"
        return 1
    end

    # Use xclip or xsel to copy the file content
    if command -v xclip > /dev/null
        cat $argv[1] | xclip -selection clipboard
        echo "File copied to clipboard using xclip."
    else if command -v xsel > /dev/null
        cat $argv[1] | xsel --clipboard
        echo "File copied to clipboard using xsel."
    else
        echo "Error: xclip or xsel is required but not installed."
        return 1
    end
end

function kb
    cd /home/alxhoff/git/Github/kernel_builder
end

