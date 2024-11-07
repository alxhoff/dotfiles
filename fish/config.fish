if status is-interactive
    # Commands to run in interactive sessions can go here
end
    
function g
    # grep -r --color=auto --exclude-dir={.git,node_modules} $argv .
    grep -n -r --color=auto --exclude=tags --exclude=TAGS --exclude-dir={.git,node_modules} "$argv" .
end

function f
    find . -name "$argv"
end

function t
    set current_dir (pwd)
    xfce4-terminal --working-directory="$current_dir" &
end

