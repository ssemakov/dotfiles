set term=xterm-256color
filetype plugin indent on
syntax on

set number

autocmd FileType gitcommit setlocal spell
set complete+=kspell

set tabstop=2
set shiftwidth=4
set expandtab
" Set some nice character listings, then activate list
set list listchars=tab:⟶\ ,trail:·,extends:>,precedes:<,nbsp:%
set list
set showmatch " show matching brackets

" Highlight current line
set cursorline
hi CursorLine   cterm=NONE ctermbg=blue

" Show when lines get too long
set textwidth=80
set colorcolumn=+1
highlight OverLength ctermbg=red ctermfg=white guibg=#592929
match OverLength /\%81v.\+/

set autoindent " keep intendation level

