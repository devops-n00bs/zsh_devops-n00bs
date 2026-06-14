" ==============================================================================
" UNIVERSAL VIM / NEOVIM CONFIGURATION
" Compatible with macOS, Linux, and Windows WSL
" ==============================================================================

" ------------------------------------------------------------------------------
" 1. General Settings
" ------------------------------------------------------------------------------
set nocompatible              " Be iMproved, disable compatibility with old vi
filetype plugin indent on     " Enable filetype detection, plugins, and indents
syntax on                     " Enable syntax highlighting

" Encoding
set encoding=utf-8
set fileencodings=utf-8,latin1

" History & Buffers
set history=1000              " Store more command/search history
set hidden                    " Allow switching buffers without saving first

" ------------------------------------------------------------------------------
" 2. UI & Appearance
" ------------------------------------------------------------------------------
set number                    " Show line numbers
set showcmd                   " Display incomplete commands in status bar
set showmode                  " Keep showing current mode (normal/insert/visual)
set cursorline                " Highlight the current screen line
set lazyredraw                " Don't redraw screen while executing macros
set ttyfast                   " Optimize terminal redrawing for faster response

" Mouse support
set mouse=a                   " Enable mouse support in all modes (scroll, select, resize)

" ------------------------------------------------------------------------------
" 3. Text Formatting & Indentation
" ------------------------------------------------------------------------------
set tabstop=4                 " Number of visual spaces per TAB
set softtabstop=4             " Number of spaces in tab when editing
set shiftwidth=4              " Number of spaces for autoindent
set expandtab                 " Convert TABs to spaces
set autoindent                " Copy indent from current line when starting a new one
set smartindent               " Intelligent indentation for C-like languages

" ------------------------------------------------------------------------------
" 4. Search Behavior
" ------------------------------------------------------------------------------
set hlsearch                  " Highlight search matches
set incsearch                 " Show search matches as you type
set ignorecase                " Ignore case when searching...
set smartcase                 " ...unless search term contains uppercase letters

" ------------------------------------------------------------------------------
" 5. Key Bindings & Shortcuts
" ------------------------------------------------------------------------------
" Map leader key to Space
let mapleader = " "

" Fast saving and exiting
nnoremap <leader>w :w<CR>
nnoremap <leader>q :q<CR>
nnoremap <leader>x :x<CR>

" Clear search highlighting with Esc or Space+c
nnoremap <silent> <Esc> :nohlsearch<CR>
nnoremap <silent> <leader>c :nohlsearch<CR>

" Easy pane navigation (using Ctrl + Arrow keys)
nnoremap <C-Left> <C-w>h
nnoremap <C-Down> <C-w>j
nnoremap <C-Up> <C-w>k
nnoremap <C-Right> <C-w>l

" Fast split window creation
nnoremap <leader>vs :vsplit<CR>
nnoremap <leader>hs :split<CR>

" ------------------------------------------------------------------------------
" 6. Custom Statusline (Premium & Clean Style, No Plugins Required)
" ------------------------------------------------------------------------------
set laststatus=2              " Always display the status line

" Function to return readable current mode
function! ModeCurrent()
    let l:mode = mode()
    if l:mode ==# 'n'      | return '  NORMAL  ' | endif
    if l:mode ==# 'i'      | return '  INSERT  ' | endif
    if l:mode ==# 'R'      | return '  REPLACE ' | endif
    if l:mode ==# 'v'      | return '  VISUAL  ' | endif
    if l:mode ==# 'V'      | return '  V-LINE  ' | endif
    if l:mode ==# "\<C-v>" | return '  V-BLOCK ' | endif
    if l:mode ==# 'c'      | return '  COMMAND ' | endif
    if l:mode ==# 't'      | return '  TERMINAL' | endif
    return ' ' . l:mode . ' '
endfunction

" Build the statusline
set statusline=%#StatusLineMode#%{ModeCurrent()}%*   " Mode indicator
set statusline+=\ %f\ %m\ %r\ %h\ %w                   " File path, modified, read-only
set statusline+=%=                                     " Align following items to the right
set statusline+=%y                                     " File type
set statusline+=\ [%{&ff}]                             " File format (unix/dos)
set statusline+=\ %p%%                                 " Percentage of file
set statusline+=\ %l:%c\                               " Line:Column position

" Dynamic colors for status line depending on terminal capabilities
highlight StatusLineMode ctermfg=15 ctermbg=4 cterm=bold guifg=#FFFFFF guibg=#005F87
highlight StatusLine ctermfg=15 ctermbg=8 cterm=none guifg=#FFFFFF guibg=#3A3A3A
highlight StatusLineNC ctermfg=8 ctermbg=0 cterm=none guifg=#585858 guibg=#1C1C1C

" ------------------------------------------------------------------------------
" 7. Cross-Platform Clipboard Integration (WSL, macOS, Linux)
" ------------------------------------------------------------------------------
" WSL (Windows Subsystem for Linux)
if has('unix') && filereadable('/proc/version') && matchstr(readfile('/proc/version')[0], 'Microsoft\|microsoft') != ''
    " Let Neovim use clip.exe and powershell.exe natively for y and p
    let g:clipboard = {
          \   'name': 'WslClipboard',
          \   'copy': {
          \      '+': 'clip.exe',
          \      '*': 'clip.exe',
          \    },
          \   'paste': {
          \      '+': 'powershell.exe -NoProfile -Command [Console]::Out.Write($(Get-Clipboard))',
          \      '*': 'powershell.exe -NoProfile -Command [Console]::Out.Write($(Get-Clipboard))',
          \   },
          \   'cache_enabled': 0,
          \ }

    " Ctrl+C in Visual mode to copy to Windows clipboard
    vnoremap <C-c> :w !clip.exe<CR><CR>
    " Ctrl+V in Insert mode to paste from Windows clipboard
    inoremap <C-v> <C-r>=system('powershell.exe -NoProfile -Command [Console]::Out.Write($(Get-Clipboard))')<CR>
endif

" macOS
if has('macunix')
    vnoremap <C-c> :w !pbcopy<CR><CR>
    inoremap <C-v> <C-r>=system('pbpaste')<CR>
endif

" Linux (non-WSL)
if has('unix') && !filereadable('/proc/version')
    if executable('xclip')
        vnoremap <C-c> :w !xclip -selection clipboard<CR><CR>
        inoremap <C-v> <C-r>=system('xclip -selection clipboard -o')<CR>
    elseif executable('xsel')
        vnoremap <C-c> :w !xsel -ib<CR><CR>
        inoremap <C-v> <C-r>=system('xsel -ob')<CR>
    endif
endif

