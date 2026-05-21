# Setup fzf — managed in dotfiles (bash/fzf.bash)
if [[ ! "$PATH" == *"$HOME/.fzf/bin"* ]]; then
  PATH="${PATH:+${PATH}:}$HOME/.fzf/bin"
fi

eval "$(fzf --bash)"
