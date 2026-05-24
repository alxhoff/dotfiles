# Oh My Fish (bobthefish theme)
set -q XDG_CONFIG_HOME; or set -gx XDG_CONFIG_HOME $HOME/.config
set -gx OMF_PATH $HOME/.local/share/omf
set -gx OMF_CONFIG $XDG_CONFIG_HOME/omf

if test -f $OMF_PATH/init.fish
    source $OMF_PATH/init.fish
end
