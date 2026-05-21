set -x GOOGLE_CLOUD_PROJECT cartken-ai-assistants

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

function kernels
    cd /home/alxhoff/git/Github/kernel_builder/kernels
end

function fv
    # Find files matching the pattern
    set results (find . -name "$argv" -exec realpath {} \; 2>/dev/null)

    # Count the number of results
    set count (count $results)

    if test $count -eq 0
        echo "No files found matching '$argv'"
        return 1
    else if test $count -eq 1
        # Open the single result in Vim
        vim $results[1]
    else
        # Multiple results found, list them with indexes
        echo "Multiple files found:"
        for i in (seq 1 $count)
            echo "[$i] $results[$i]"
        end

        # Prompt the user to choose a file
        echo -n "Select a file to open (1-$count): "
        read choice

        # Validate user input
        if test $choice -ge 1 -a $choice -le $count
            vim $results[$choice]
        else
            echo "Invalid choice. Exiting."
            return 1
        end
    end
end

function gcp
    if test (count $argv) -eq 0
        echo "Usage: gcp <commit1> [commit2] [commit3] ..."
        return 1
    end

    for commit in $argv
        echo "Cherry-picking: $commit"
        git cherry-pick $commit
        if test $status -ne 0
            echo "Error cherry-picking $commit. Resolve conflicts and run 'git cherry-pick --continue' or 'git cherry-pick --abort'."
            return 1
        end
    end

    echo "All commits cherry-picked successfully."
end

function windows
    if test (count $argv) -gt 0
        switch $argv[1]
            case start
                echo "Starting Windows Docker container..."
                cd ~/ && docker compose up -d windows
                sleep 3
                firefox --new-window http://localhost:8006/ &
            case pause
                echo "Pausing Windows Docker container..."
                docker pause windows
            case resume
                echo "Resuming Windows Docker container..."
                docker unpause windows
                sleep 3
                firefox --new-window http://localhost:8006/ &
            case stop
                echo "Stopping Windows Docker container..."
                docker compose down windows
			case rebuild
                echo "Rebuilding Windows Docker container (preserving data)..."
                docker compose down
                docker compose build windows
                docker compose up -d windows
                sleep 3
                firefox --new-window http://localhost:8006/ &
			case rebuild-hard
			echo "⚠️ Full rebuild of Windows container..."
				# Try deletion
				if not rm -rf ~/windows/* 2>/dev/null
					echo "⚠️ Could not delete files. Run this manually:"
					echo "    sudo rm -rf ~/windows/*"
					echo -n "Press Enter when done..."
					read
				end

				echo "Rebuilding container..."
				docker compose down
				docker compose build windows
				docker compose up -d windows
				echo "Starting browser..."
				sleep 3
				firefox --new-window http://localhost:8006/ &
			case '*'
				echo "Usage: windows {start|pause|resume|stop|rebuild|rebuild-hard}"
        end
    else
        echo "Usage: windows {start|pause|resume|stop|rebuild|rebuild-hard}"
    end
end

function spaces
    if test (count $argv) -ne 1
        echo "Usage: spaces <directory>"
        return 1
    end

    set dir $argv[1]

    if not test -d $dir
        echo "Error: '$dir' is not a valid directory"
        return 1
    end

    find $dir -type f -exec sed -i 's/\t/    /g' {} +

    echo "Converted all tabs to spaces in: $dir"
end

function rmpatch
    find . -type f \( -name '*.orig' -o -name '*.rej' \) -print -delete
end

function alert
    # run the command with all arguments
    $argv 2>&1
    # play a standard notification sound
	paplay /usr/share/sounds/freedesktop/stereo/complete.oga 
end

