set runtimepath+=~/.vim_runtime


source ~/.vim_runtime/vimrcs/basic.vim
source ~/.vim_runtime/vimrcs/plug.vim
source ~/.vim_runtime/vimrcs/navigation.vim
source ~/.vim_runtime/vimrcs/files.vim
source ~/.vim_runtime/vimrcs/kernel.vim
source ~/.vim_runtime/vimrcs/completion.vim
source ~/.vim_runtime/vimrcs/extended.vim
source ~/.vim_runtime/vimrcs/syntax.vim

" 1 tab == 4 spaces
set shiftwidth=4
set tabstop=4

"CTAGS
set tags=./tags,tags;$HOME
"Work kernel
set autochdir
set tags+=$HOME/Work/Optigame/odroid_4.4.4/kernel/samsung/exynos5422/tags
