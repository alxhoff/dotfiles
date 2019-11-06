 """""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
 " => Nerd Tree
 """""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
 let g:NERDTreeWinPos = "right"
 let NERDTreeShowHidden=0
 let NERDTreeIgnore = ['\.pyc$', '__pycache__']
 let g:NERDTreeWinSize=35
 map <leader>nn :NERDTreeToggle<cr>
 map <leader>nb :NERDTreeFromBookmark<Space>
 map <leader>nf :NERDTreeFind<cr>

"  """""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" " => lightline
" """""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""
" let g:lightline = {
"       \ 'colorscheme': 'wombat',
"       \ }
"
" let g:lightline = {
"       \ 'colorscheme': 'wombat',
"       \ 'active': {
"       \   'left': [ ['mode', 'paste'],
"       \             ['fugitive', 'readonly', 'filename', 'modified'] ],
"       \   'right': [ [ 'lineinfo' ], ['percent'] ]
"       \ },
"       \ 'component': {
"       \   'readonly': '%{&filetype=="help"?"":&readonly?"🔒":""}',
"       \   'modified': '%{&filetype=="help"?"":&modified?"+":&modifiable?"":"-"}',
"       \   'fugitive': '%{exists("*fugitive#head")?fugitive#head():""}'
"       \ },
"       \ 'component_visible_condition': {
"       \   'readonly': '(&filetype!="help"&& &readonly)',
"       \   'modified': '(&filetype!="help"&&(&modified||!&modifiable))',
"       \   'fugitive': '(exists("*fugitive#head") && ""!=fugitive#head())'
"       \ },
"       \ 'separator': { 'left': ' ', 'right': ' ' },
"       \ 'subseparator': { 'left': ' ', 'right': ' ' }
"       \ }

"FZF fuzzy search
map ; :Files<CR>
" This is the default extra key bindings
let g:fzf_action = {
  \ 'ctrl-t': 'tab split',
  \ 'ctrl-x': 'split',
  \ 'ctrl-v': 'vsplit' }

" Default fzf layout
" - down / up / left / right
let g:fzf_layout = { 'down': '~40%' }

" In Neovim, you can set up fzf window using a Vim command
let g:fzf_layout = { 'window': 'enew' }
let g:fzf_layout = { 'window': '-tabnew' }
let g:fzf_layout = { 'window': '10split enew' }

" Customize fzf colors to match your color scheme
let g:fzf_colors =
\ { 'fg':      ['fg', 'Normal'],
  \ 'bg':      ['bg', 'Normal'],
  \ 'hl':      ['fg', 'Comment'],
  \ 'fg+':     ['fg', 'CursorLine', 'CursorColumn', 'Normal'],
  \ 'bg+':     ['bg', 'CursorLine', 'CursorColumn'],
  \ 'hl+':     ['fg', 'Statement'],
  \ 'info':    ['fg', 'PreProc'],
  \ 'border':  ['fg', 'Ignore'],
  \ 'prompt':  ['fg', 'Conditional'],
  \ 'pointer': ['fg', 'Exception'],
  \ 'marker':  ['fg', 'Keyword'],
  \ 'spinner': ['fg', 'Label'],
  \ 'header':  ['fg', 'Comment'] }

" Enable per-command history.
" CTRL-N and CTRL-P will be automatically bound to next-history and
" previous-history instead of down and up. If you don't like the change,
" explicitly bind the keys to down and up in your $FZF_DEFAULT_OPTS.
let g:fzf_history_dir = '~/.local/share/fzf-history'

"SCSOPE MAP
map l :TlistToggle<CR>

"TAG BAR
nmap <F8> :TagbarToggle<CR>

"folding
set foldmethod=syntax
set foldnestmax=10
set foldlevel=2
