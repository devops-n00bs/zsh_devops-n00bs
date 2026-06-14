#!/usr/bin/env bash

# ==============================================================================
# AUTOMATIC ZSH CONFIGURATION MANAGER (Interactive Menu)
# Works on macOS, WSL, and Linux Server
# ==============================================================================

# Exit on error, undefined variables, and pipe failures
set -euo pipefail

# Version
VERSION="v1.2.0"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

info() { echo -e "${BLUE}[INFO]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $*"; }

# Detect if script is run locally or downloaded directly
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" &>/dev/null && pwd)"
IS_LOCAL=false
if [[ -f "${SCRIPT_DIR}/zshrc" && -f "${SCRIPT_DIR}/starship.toml" ]]; then
    IS_LOCAL=true
fi

# Detect if running in WSL
IS_WSL=false
if [ -f /proc/version ] && grep -qi microsoft /proc/version; then
    IS_WSL=true
fi

# Helper: Check sudo and ask to apply configuration to root
check_and_apply_to_root() {
    local module=$1
    
    # Check if we are already root
    if [ "$(id -u)" -eq 0 ]; then
        return
    fi

    # Check if user has sudo privileges (can run sudo without password or we check)
    if ! command -v sudo &> /dev/null; then
        return
    fi

    echo ""
    local ROOT_CHOICE
    read -r -p "Do you also want to apply this configuration to the 'root' user? (y/N): " ROOT_CHOICE < /dev/tty
    if [[ "$ROOT_CHOICE" =~ ^[Yy]$ ]]; then
        info "Applying configuration to the 'root' user..."
        local SUDO="sudo"
        
        if [ "$module" = "zsh" ]; then
            # 1. Zsh config to root
            $SUDO mkdir -p /root/.config
            $SUDO cp "${HOME}/.zshrc" /root/.zshrc
            $SUDO cp "${HOME}/.config/starship.toml" /root/.config/starship.toml
            
            # 2. Plugins to root
            $SUDO mkdir -p /root/.zsh/plugins
            $SUDO cp -r "${HOME}/.zsh/plugins/"* /root/.zsh/plugins/ 2>/dev/null || true
            
            # 3. Change root default shell to Zsh
            if command -v zsh &> /dev/null; then
                local ZSH_PATH
                ZSH_PATH=$(command -v zsh)
                if $SUDO chsh -s "$ZSH_PATH" root &>/dev/null; then
                    success "Default shell for 'root' changed to Zsh."
                else
                    # Fallback auto-launch in root .bashrc
                    $SUDO bash -c "if [ -f /root/.bashrc ] && ! grep -q 'Auto-launch Zsh' /root/.bashrc; then echo -e '\n# Auto-launch Zsh on login\nif [ -t 1 ] && command -v zsh &> /dev/null; then\n    exec zsh\nfi' >> /root/.bashrc; fi"
                    success "Added Zsh auto-forward to /root/.bashrc"
                fi
            fi
            success "Zsh & Starship configuration applied to 'root' user!"
            
        elif [ "$module" = "vim" ]; then
            # 1. Vim config to root
            $SUDO cp "${HOME}/.vimrc" /root/.vimrc
            
            # 2. Neovim config to root
            if command -v nvim &> /dev/null; then
                $SUDO mkdir -p /root/.config/nvim
                $SUDO bash -c "cat << 'EOF' > /root/.config/nvim/init.vim
set runtimepath^=~/.vim runtimepath+=~/.vim/after
let &packpath = &runtimepath
source ~/.vimrc
EOF"
                success "Neovim configured for 'root' user."
            fi
            success "Vim/Neovim configuration applied to 'root' user!"
        elif [ "$module" = "tmux" ]; then
            # 1. Tmux config to root
            $SUDO cp "${HOME}/.tmux.conf" /root/.tmux.conf
            success "Tmux configuration applied to 'root' user!"
        fi
    fi
}

# Function: Install or Update Zsh & Starship Configuration
do_install_zsh() {
    echo ""
    info "=== STARTING ZSH & STARSHIP INSTALLATION ==="
    
    # 1. Detect environment & dependencies
    info "Checking core dependencies..."
    MISSING_DEPS=()
    for cmd in git curl zsh; do
        if ! command -v "$cmd" &> /dev/null; then
            MISSING_DEPS+=("$cmd")
        fi
    done

    if [ ${#MISSING_DEPS[@]} -ne 0 ]; then
        warn "The following core dependencies are missing: ${MISSING_DEPS[*]}"
        info "Attempting to install dependencies automatically..."
        
        # Determine if sudo is needed
        SUDO=""
        if [ "$(id -u)" -ne 0 ]; then
            SUDO="sudo"
        fi
        
        # Detect OS / Package Manager
        if [[ "$OSTYPE" == "darwin"* ]]; then
            if ! command -v brew &> /dev/null; then
                error "Homebrew not found. Please install Homebrew first or install dependencies manually."
            fi
            info "Installing via Homebrew..."
            brew install "${MISSING_DEPS[@]}"
        elif [ -f /etc/debian_version ]; then
            info "Installing via apt-get..."
            $SUDO apt-get update
            $SUDO apt-get install -y "${MISSING_DEPS[@]}"
        elif [ -f /etc/redhat-release ] || [ -f /etc/system-release ]; then
            info "Installing via dnf/yum..."
            if command -v dnf &> /dev/null; then
                $SUDO dnf install -y "${MISSING_DEPS[@]}"
            else
                $SUDO yum install -y "${MISSING_DEPS[@]}"
            fi
        elif [ -f /etc/arch-release ]; then
            info "Installing via pacman..."
            $SUDO pacman -Syu --noconfirm "${MISSING_DEPS[@]}"
        else
            error "Operating system not supported for auto-installation. Please install manually: ${MISSING_DEPS[*]}"
        fi
        success "Core dependencies successfully installed."
    else
        info "All core dependencies are met."
    fi

    # Try to install optional modern CLI tools (bat and eza/exa) on best-effort basis
    info "Checking optional CLI enhancements (bat & eza)..."
    OPTIONAL_DEPS=()
    if ! command -v bat &> /dev/null && ! command -v batcat &> /dev/null; then
        OPTIONAL_DEPS+=("bat")
    fi
    if ! command -v eza &> /dev/null && ! command -v exa &> /dev/null; then
        OPTIONAL_DEPS+=("eza")
    fi

    if [ ${#OPTIONAL_DEPS[@]} -ne 0 ]; then
        info "Attempting to install optional tools: ${OPTIONAL_DEPS[*]}"
        SUDO=""
        if [ "$(id -u)" -ne 0 ]; then
            SUDO="sudo"
        fi
        
        # Temporarily disable exit-on-error so optional packages don't abort setup
        set +e
        if [[ "$OSTYPE" == "darwin"* ]]; then
            if command -v brew &> /dev/null; then
                brew install "${OPTIONAL_DEPS[@]}"
            fi
        elif [ -f /etc/debian_version ]; then
            $SUDO apt-get install -y "${OPTIONAL_DEPS[@]}"
            # If eza is missing (older Ubuntu), try installing exa as fallback
            if ! command -v eza &> /dev/null && ! command -v exa &> /dev/null; then
                $SUDO apt-get install -y exa
            fi
        elif [ -f /etc/redhat-release ] || [ -f /etc/system-release ]; then
            if command -v dnf &> /dev/null; then
                $SUDO dnf install -y "${OPTIONAL_DEPS[@]}"
            else
                $SUDO yum install -y "${OPTIONAL_DEPS[@]}"
            fi
        elif [ -f /etc/arch-release ]; then
            $SUDO pacman -S --noconfirm "${OPTIONAL_DEPS[@]}"
        fi
        set -e
    fi

    # 2. Install Starship Prompt
    if ! command -v starship &> /dev/null; then
        info "Installing Starship Prompt..."
        if [[ "$OSTYPE" == "darwin"* ]]; then
            if command -v brew &> /dev/null; then
                info "Installing via Homebrew..."
                brew install starship
            else
                warn "Homebrew not found. Using official installer script (may require sudo password)..."
                curl -sS https://starship.rs/install.sh | sudo sh -s -- --yes
            fi
        else
            # Linux / WSL
            SUDO=""
            if [ "$(id -u)" -ne 0 ]; then
                SUDO="sudo"
            fi
            curl -sS https://starship.rs/install.sh | $SUDO sh -s -- --yes
        fi
        success "Starship successfully installed."
    else
        info "Starship is already installed."
    fi

    # 3. Setup plugin directory and download plugins
    PLUGIN_DIR="${HOME}/.zsh/plugins"
    info "Setting up Zsh plugins..."
    mkdir -p "${PLUGIN_DIR}"

    # Helper to clone or update plugins
    setup_plugin() {
        local name=$1
        local url=$2
        local path="${PLUGIN_DIR}/${name}"
        
        if [ -d "$path" ]; then
            info "Updating plugin ${name}..."
            git -C "$path" pull
        else
            info "Downloading plugin ${name}..."
            git clone --depth 1 "$url" "$path"
        fi
    }

    setup_plugin "zsh-autosuggestions" "https://github.com/zsh-users/zsh-autosuggestions.git"
    setup_plugin "zsh-syntax-highlighting" "https://github.com/zsh-users/zsh-syntax-highlighting.git"

    # 4. Install configuration files
    info "Applying configuration files..."

    # Setup .zshrc
    if [ -f "${HOME}/.zshrc" ] && [ ! -f "${HOME}/.zshrc.bak" ]; then
        warn "Existing ~/.zshrc found. Creating backup at ~/.zshrc.bak"
        mv "${HOME}/.zshrc" "${HOME}/.zshrc.bak"
    fi

    if [ "$IS_LOCAL" = true ]; then
        cp "${SCRIPT_DIR}/zshrc" "${HOME}/.zshrc"
    else
        info "Writing ~/.zshrc configuration..."
        cat << 'EOF' > "${HOME}/.zshrc"
# ==============================================================================
# ZSH CONFIGURATION (Custom, Fast, and Clean)
# Compatible with macOS, Linux, and Windows WSL
# ==============================================================================

# ------------------------------------------------------------------------------
# 0. Locale settings (Ensures UTF-8 characters render correctly)
# ------------------------------------------------------------------------------
export LANG="en_US.UTF-8"
export LC_ALL="en_US.UTF-8"

# ------------------------------------------------------------------------------
# 1. History Configuration
# ------------------------------------------------------------------------------
HISTFILE="${HOME}/.zsh_history"
HISTSIZE=10000
SAVEHIST=10000

# History options
setopt appendhistory       # Append to history file, don't overwrite
setopt sharehistory        # Share history across all active sessions
setopt histignorealldups   # Delete old recorded duplicate behavior
setopt histignoredups      # Do not write events to history that are duplicates of previous event
setopt histignorespace     # Don't record commands starting with a space
setopt histreduceblanks    # Remove superfluous blanks before recording to history

# ------------------------------------------------------------------------------
# 2. Completion System (compinit)
# ------------------------------------------------------------------------------
autoload -Uz compinit
if [[ -n ${ZSH_COMPDUMP} ]]; then
    compinit -d "${ZSH_COMPDUMP}"
else
    compinit
fi

# Completion Styling
zstyle ':completion:*' menu select
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|[._-]=* r:|=*' 'l:|=* r:|=*'

# ------------------------------------------------------------------------------
# 3. Key Bindings & Behavior
# ------------------------------------------------------------------------------
# Use emacs keybindings by default (even if EDITOR is set to vi)
bindkey -e

# Auto CD: typing a directory name directly will cd into it
setopt autocd

# Up/Down arrow search history based on prefix
autoload -U up-line-or-beginning-search
autoload -U down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search
bindkey '^[[A' up-line-or-beginning-search # Up Arrow
bindkey '^[[B' down-line-or-beginning-search # Down Arrow

# ------------------------------------------------------------------------------
# 4. Plugins (Auto-suggestions & Syntax Highlighting)
# ------------------------------------------------------------------------------
# Default path for custom plugins
ZSH_PLUGIN_DIR="${HOME}/.zsh/plugins"

# Load zsh-autosuggestions
if [[ -f "${ZSH_PLUGIN_DIR}/zsh-autosuggestions/zsh-autosuggestions.zsh" ]]; then
    source "${ZSH_PLUGIN_DIR}/zsh-autosuggestions/zsh-autosuggestions.zsh"
    # Customize autosuggestion color (sleek dark gray)
    ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=8"
    # Key bindings for autosuggestions:
    # 1. Right Arrow (default): Accepts the full suggestion when cursor is at the end of the line
    # 2. Ctrl + Space: Accept full suggestion immediately
    bindkey '^ ' autosuggest-accept
    # 3. Ctrl + Right Arrow: Accept suggestion word-by-word
    bindkey '^[[1;5C' forward-word
    bindkey '^[[1;5D' backward-word
fi

# Load zsh-syntax-highlighting
if [[ -f "${ZSH_PLUGIN_DIR}/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]]; then
    source "${ZSH_PLUGIN_DIR}/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
fi

# ------------------------------------------------------------------------------
# 5. Prompt Initialization (Starship)
# ------------------------------------------------------------------------------
if command -v starship &> /dev/null; then
    eval "$(starship init zsh)"
else
    # Fallback prompt if Starship is not installed yet
    PROMPT="%F{cyan}%n%f@%F{blue}%m%f %F{green}%~%f %F{yellow}$%f "
fi

# ------------------------------------------------------------------------------
# 6. Aliases & Functions
# ------------------------------------------------------------------------------
# Default general aliases
alias grep="grep --color=auto"
alias reload="exec zsh"
alias ..="cd .."
alias ...="cd ../.."
alias ....="cd ../../.."

# Smart Auto-Aliases (Check for modern CLI replacements)
if command -v batcat &> /dev/null; then
    alias cat="batcat --style=plain"
elif command -v bat &> /dev/null; then
    alias cat="bat --style=plain"
fi

if command -v eza &> /dev/null; then
    alias ls="eza --git"
    alias ll="eza -lah --git"
    alias la="eza -a --git"
    alias l="eza -lh --git"
elif command -v exa &> /dev/null; then
    alias ls="exa --git"
    alias ll="exa -lah --git"
    alias la="exa -a --git"
    alias l="exa -lh --git"
else
    alias ls="ls --color=auto"
    alias ll="ls -lAh --color=auto"
    alias la="ls -A --color=auto"
    alias l="ls -lh --color=auto"
fi
EOF
    fi

    # Setup starship.toml
    mkdir -p "${HOME}/.config"
    if [ -f "${HOME}/.config/starship.toml" ] && [ ! -f "${HOME}/.config/starship.toml.bak" ]; then
        warn "Existing ~/.config/starship.toml found. Creating backup at ~/.config/starship.toml.bak"
        mv "${HOME}/.config/starship.toml" "${HOME}/.config/starship.toml.bak"
    fi

    if [ "$IS_LOCAL" = true ]; then
        cp "${SCRIPT_DIR}/starship.toml" "${HOME}/.config/starship.toml"
    else
        info "Writing ~/.config/starship.toml..."
        cat << 'EOF' > "${HOME}/.config/starship.toml"
# ==============================================================================
# STARSHIP CONFIGURATION (Premium & Sleek Theme)
# ==============================================================================

# Don't print a new line at the start of the prompt
add_newline = true

# Use custom format
format = """
$username$hostname$directory$git_branch$git_status$git_state
$character"""

# OS Module (Disabled for super minimal look)
[os]
disabled = true

# Username Configuration
[username]
show_always = true
style_user = "bold green"
style_root = "bold red"
format = "[$user]($style)"

# Hostname Configuration
[hostname]
ssh_only = false
style = "bold blue"
format = "[@$hostname]($style) "

# Character (Standard ASCII, no special font required)
[character]
success_symbol = "[>](bold green) "
error_symbol = "[>](bold red) "
vicmd_symbol = "[<](bold yellow) "

# Directory Settings
[directory]
style = "bold cyan"
read_only = " [RO]"
truncation_length = 5
truncate_to_repo = false
truncation_symbol = "../"
format = "[$path]($style) "

# Git Configuration
[git_branch]
symbol = "git:"
style = "bold magenta"
format = "[$symbol$branch]($style) "

[git_status]
style = "red"
format = "[[($all_status$ahead_behind)]($style)]($style) "
conflicted = "="
ahead = "⇡"
behind = "⇣"
diverged = "⇕"
untracked = "?"
stashed = "$"
modified = "!"
staged = "+"
renamed = "»"
deleted = "✘"

[git_state]
format = '\([$state( $progress_current/$progress_total)]($style)\) '
style = "bright-black"

# Command Duration
[cmd_duration]
min_time = 500
format = "took [$duration](bold yellow) "

# Time settings
[time]
disabled = false
format = "at [$time](bold black) "
time_format = "%T"

# Language and system-specific indicators (Clean & compact styles)
[nodejs]
symbol = " "
style = "bold green"
format = "via [$symbol($version)]($style) "

[python]
symbol = " "
style = "bold yellow"
format = 'via [$symbol($version)(\($virtualenv\))]($style) '

[golang]
symbol = " "
style = "bold cyan"
format = "via [$symbol($version)]($style) "

[rust]
symbol = " "
style = "bold red"
format = "via [$symbol($version)]($style) "
EOF
    fi

    success "Zsh and Starship configurations successfully applied!"

    # 5. Set default shell to Zsh
    CURRENT_SHELL=$(basename "$SHELL")
    if [ "$CURRENT_SHELL" != "zsh" ]; then
        info "Attempting to change your default shell to Zsh..."
        if command -v chsh &> /dev/null; then
            # Run chsh (may ask for user's password)
            if chsh -s "$(which zsh)" < /dev/tty; then
                success "Default shell successfully changed to Zsh."
            else
                warn "Could not change default shell via chsh automatically."
            fi
        else
            warn "chsh command not found. Please change default shell manually."
        fi
    fi

    # Fallback auto-launch hook for all Linux/WSL environments
    if [[ "$OSTYPE" != "darwin"* ]]; then
        info "Ensuring Zsh auto-launches in bash sessions..."
        BASHRC="${HOME}/.bashrc"
        if [ -f "$BASHRC" ]; then
            if ! grep -q "Auto-launch Zsh" "$BASHRC"; then
                echo -e "\n# Auto-launch Zsh on login\nif [ -t 1 ] && command -v zsh &> /dev/null; then\n    exec zsh\nfi" >> "$BASHRC"
                success "Added Zsh auto-forward to ~/.bashrc"
            else
                info "Zsh auto-forward already exists in ~/.bashrc."
            fi
        fi
    fi

    check_and_apply_to_root "zsh"

    echo -e "\n${GREEN}Zsh & Starship installation complete! Please restart your terminal or run:${NC}"
    echo -e "  exec zsh\n"
}

# Function: Install or Update Vim & Neovim Configuration
do_install_vim() {
    echo ""
    info "=== STARTING VIM/NEOVIM INSTALLATION ==="

    # 1. Detect and install Vim, Neovim & Clipboard utilities
    SUDO=""
    if [ "$(id -u)" -ne 0 ]; then
        SUDO="sudo"
    fi

    info "Installing Vim, Neovim, and Clipboard dependencies..."
    set +e
    if [[ "$OSTYPE" == "darwin"* ]]; then
        if command -v brew &> /dev/null; then
            info "Installing via Homebrew..."
            brew install vim neovim
        else
            warn "Homebrew not found. Please install dependencies (vim, neovim) manually."
        fi
    elif [ -f /etc/debian_version ]; then
        info "Installing packages via apt-get (vim-gtk3 for clipboard support, xclip, and neovim)..."
        $SUDO apt-get update
        $SUDO apt-get install -y vim-gtk3 xclip neovim
    elif [ -f /etc/redhat-release ] || [ -f /etc/system-release ]; then
        info "Installing packages via dnf/yum..."
        if command -v dnf &> /dev/null; then
            $SUDO dnf install -y vim-enhanced xclip neovim
        else
            $SUDO yum install -y vim-enhanced xclip neovim
        fi
    elif [ -f /etc/arch-release ]; then
        info "Installing packages via pacman..."
        $SUDO pacman -S --noconfirm gvim xclip neovim
    else
        warn "Operating system not fully supported for auto-installation. Please ensure vim, neovim, and xclip are installed."
    fi
    set -e

    # 2. Setup .vimrc
    if [ -f "${HOME}/.vimrc" ] && [ ! -f "${HOME}/.vimrc.bak" ]; then
        warn "Existing ~/.vimrc found. Creating backup at ~/.vimrc.bak"
        mv "${HOME}/.vimrc" "${HOME}/.vimrc.bak"
    fi

    if [ "$IS_LOCAL" = true ]; then
        cp "${SCRIPT_DIR}/vimrc" "${HOME}/.vimrc"
    else
        info "Writing ~/.vimrc configuration..."
        cat << 'EOF' > "${HOME}/.vimrc"
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
EOF
    fi
    success "Vim configuration successfully applied!"

    # 3. Configure Neovim compatibility if Neovim is installed
    if command -v nvim &> /dev/null; then
        info "Neovim detected. Linking ~/.vimrc for Neovim..."
        mkdir -p "${HOME}/.config/nvim"
        if [ -f "${HOME}/.config/nvim/init.vim" ] && [ ! -f "${HOME}/.config/nvim/init.vim.bak" ]; then
            warn "Existing Neovim config found. Creating backup at ~/.config/nvim/init.vim.bak"
            mv "${HOME}/.config/nvim/init.vim" "${HOME}/.config/nvim/init.vim.bak"
        fi
        
        # Write init.vim to source .vimrc
        cat << 'EOF' > "${HOME}/.config/nvim/init.vim"
set runtimepath^=~/.vim runtimepath+=~/.vim/after
let &packpath = &runtimepath
source ~/.vimrc
EOF
        success "Neovim successfully configured to source ~/.vimrc"
    fi

    check_and_apply_to_root "vim"

    echo -e "\n${GREEN}Vim/Neovim configuration complete!${NC}\n"
}

# Function: Install or Update Tmux Configuration
do_install_tmux() {
    echo ""
    info "=== STARTING TMUX INSTALLATION ==="

    # 1. Detect and install Tmux if missing
    if ! command -v tmux &> /dev/null; then
        info "Tmux is not installed. Installing Tmux..."
        SUDO=""
        if [ "$(id -u)" -ne 0 ]; then
            SUDO="sudo"
        fi
        
        if [[ "$OSTYPE" == "darwin"* ]]; then
            if command -v brew &> /dev/null; then
                brew install tmux
            else
                warn "Homebrew not found. Please install Tmux manually."
            fi
        elif [ -f /etc/debian_version ]; then
            $SUDO apt-get update
            $SUDO apt-get install -y tmux
        elif [ -f /etc/redhat-release ] || [ -f /etc/system-release ]; then
            if command -v dnf &> /dev/null; then
                $SUDO dnf install -y tmux
            else
                $SUDO yum install -y tmux
            fi
        elif [ -f /etc/arch-release ]; then
            $SUDO pacman -S --noconfirm tmux
        else
            warn "Could not install Tmux automatically. Please install it manually."
        fi
    else
        info "Tmux is already installed."
    fi

    # 2. Setup .tmux.conf
    if [ -f "${HOME}/.tmux.conf" ] && [ ! -f "${HOME}/.tmux.conf.bak" ]; then
        warn "Existing ~/.tmux.conf found. Creating backup at ~/.tmux.conf.bak"
        mv "${HOME}/.tmux.conf" "${HOME}/.tmux.conf.bak"
    fi

    if [ "$IS_LOCAL" = true ]; then
        cp "${SCRIPT_DIR}/tmux.conf" "${HOME}/.tmux.conf"
    else
        info "Writing ~/.tmux.conf configuration..."
        cat << 'EOF' > "${HOME}/.tmux.conf"
# ==============================================================================
# UNIVERSAL TMUX CONFIGURATION (Premium, Fast, and Clean)
# Compatible with macOS, Linux, and Windows WSL
# ==============================================================================

# ------------------------------------------------------------------------------
# 1. General & Prefix Settings
# ------------------------------------------------------------------------------
# Change prefix from Ctrl+B to Ctrl+A
unbind C-b
set -g prefix C-a
bind C-a send-prefix

# Start window and pane numbering at 1 (more intuitive)
set -g base-index 1
setw -g pane-base-index 1

# Automatically rename windows based on active process
setw -g automatic-rename on
set -g renumber-windows on

# Increase scrollback history limit (default is 2000)
set -g history-limit 10000

# Reduce delay time for esc key (improves Vim responsiveness)
set -sg escape-time 0

# Enable terminal colors
set -g default-terminal "screen-256color"
set -ga terminal-overrides ",xterm-256color:Tc"

# ------------------------------------------------------------------------------
# 2. Mouse & Clipboard Support
# ------------------------------------------------------------------------------
# Enable mouse mode (scrolling, clicking, resizing panes)
set -g mouse on

# Use system clipboard (requires xclip on Linux/WSL)
set -g set-clipboard on

# ------------------------------------------------------------------------------
# 3. Custom Key Bindings
# ------------------------------------------------------------------------------
# Reload configuration file easily
bind r source-file ~/.tmux.conf \; display-message "Tmux configuration reloaded!"

# Split window vertically using | (in current path)
bind | split-window -h -c "#{pane_current_path}"
unbind %

# Split window horizontally using - (in current path)
bind - split-window -v -c "#{pane_current_path}"
unbind '"'

# Navigate panes using Ctrl + Arrow keys (without prefix!)
bind -n C-Left select-pane -L
bind -n C-Right select-pane -R
bind -n C-Up select-pane -U
bind -n C-Down select-pane -D

# Resize panes easily using prefix + Shift + Arrow keys
bind -r H resize-pane -L 5
bind -r L resize-pane -R 5
bind -r K resize-pane -U 5
bind -r J resize-pane -D 5

# ------------------------------------------------------------------------------
# 4. Premium Theme & Status Bar (Starship Match)
# ------------------------------------------------------------------------------
# Status bar refresh rate
set -g status-interval 5

# Status bar general styling
set -g status-position bottom
set -g status-style "bg=#1C1C1C,fg=#FFFFFF"

# Status Left (Session Info)
set -g status-left-length 30
set -g status-left "#[bg=#005F87,fg=#FFFFFF,bold] [Session: #S] #[bg=default,fg=default] "

# Status Right (Clock & Date)
set -g status-right-length 50
set -g status-right "#[fg=#585858] %d-%b-%y #[fg=#FFFFFF,bold] %H:%M "

# Active window formatting
set -g window-status-current-format "#[bg=#0087AF,fg=#FFFFFF,bold] #I:#W#F "

# Inactive window formatting
set -g window-status-format "#[fg=#8A8A8A] #I:#W "

# Pane borders color
set -g pane-border-style "fg=#3A3A3A"
set -g pane-active-border-style "fg=#0087AF"

# Message bar coloring
set -g message-style "bg=#005F87,fg=#FFFFFF,bold"
EOF
    fi
    success "Tmux configuration successfully applied!"

    # 3. Ask to apply to root
    check_and_apply_to_root "tmux"

    echo -e "\n${GREEN}Tmux configuration complete!${NC}\n"
}

# Function: Install or Update All Configuration
do_install_all() {
    echo ""
    info "=== STARTING FULL INSTALLATION (ALL MODULES) ==="
    do_install_zsh
    do_install_vim
    do_install_tmux
    success "All modules successfully installed!"
}

# Function: Uninstall / Restore Configuration
do_uninstall() {
    echo ""
    info "=== SYSTEM DIAGNOSTIC (DETECTING INSTALLED MODULES) ==="
    echo ""

    # Helper to check if file exists (locally or via sudo in root)
    check_status() {
        local path=$1
        local is_root=$2
        if [ "$is_root" = true ]; then
            if sudo [ -f "$path" ] 2>/dev/null; then
                echo -e "${GREEN}[INSTALLED]${NC}"
            else
                echo -e "${NC}[NOT INSTALLED]${NC}"
            fi
        else
            if [ -f "$path" ]; then
                echo -e "${GREEN}[INSTALLED]${NC}"
            else
                echo -e "${NC}[NOT INSTALLED]${NC}"
            fi
        fi
    }

    # Print dashboard
    echo -e "  ${CYAN}[1] Zsh & Starship Configuration:${NC}"
    echo -ne "      - User ($(whoami)) : "
    check_status "${HOME}/.zshrc" false
    echo -ne "      - Root          : "
    check_status "/root/.zshrc" true
    echo ""

    echo -e "  ${CYAN}[2] Vim & Neovim Configuration:${NC}"
    echo -ne "      - User ($(whoami)) : "
    check_status "${HOME}/.vimrc" false
    echo -ne "      - Root          : "
    check_status "/root/.vimrc" true
    echo ""

    echo -e "  ${CYAN}[3] Tmux Configuration:${NC}"
    echo -ne "      - User ($(whoami)) : "
    check_status "${HOME}/.tmux.conf" false
    echo -ne "      - Root          : "
    check_status "/root/.tmux.conf" true
    echo ""
    echo -e "${PURPLE}=======================================================${NC}"
    echo -e "Please select an option to uninstall:"
    echo -e "  ${GREEN}1)${NC} Uninstall Zsh & Starship"
    echo -e "  ${GREEN}2)${NC} Uninstall Vim & Neovim"
    echo -e "  ${GREEN}3)${NC} Uninstall Tmux"
    echo -e "  ${RED}4)${NC} Uninstall ALL (Complete Reset)"
    echo -e "  ${YELLOW}5)${NC} Cancel / Go Back"
    echo -e "${PURPLE}=======================================================${NC}"

    read -r -p "Enter your choice [1-5]: " UNINSTALL_CHOICE < /dev/tty

    # Helper function to restore backup or safely delete config
    restore_backup() {
        local file=$1
        local is_root=$2
        local backup="${file}.bak"
        
        if [ "$is_root" = true ]; then
            local SUDO="sudo"
            if $SUDO [ -f "$backup" ] 2>/dev/null; then
                info "Restoring backup for root $(basename "$file")...."
                $SUDO mv -f "$backup" "$file"
                success "Restored root $file from backup."
            elif $SUDO [ -f "$file" ] 2>/dev/null; then
                info "Removing root $file..."
                $SUDO rm -f "$file"
                success "Removed root $file"
            fi
        else
            if [ -f "$backup" ]; then
                info "Restoring backup for $(basename "$file")..."
                mv -f "$backup" "$file"
                success "Restored $file from backup."
            elif [ -f "$file" ]; then
                info "Removing $file..."
                rm -f "$file"
                success "Removed $file"
            fi
        fi
    }

    case "$UNINSTALL_CHOICE" in
        1)
            echo ""
            info "=== UNINSTALLING ZSH & STARSHIP ==="
            
            # User Zsh cleanup
            restore_backup "${HOME}/.zshrc" false
            restore_backup "${HOME}/.config/starship.toml" false
            
            if [ -d "${HOME}/.zsh" ]; then
                rm -rf "${HOME}/.zsh"
                success "Removed folder ~/.zsh"
            fi
            rm -f "${HOME}/.zcompdump"*
            rm -f "${HOME}/.zsh_history"
            rm -rf "${HOME}/.cache/starship"
            success "Cleared Zsh caches and history."

            # Starship binary removal
            if command -v starship &> /dev/null; then
                local STARSHIP_PATH
                STARSHIP_PATH=$(which starship)
                info "Removing Starship binary at $STARSHIP_PATH..."
                local SUDO=""
                if [ "$(id -u)" -ne 0 ]; then SUDO="sudo"; fi
                $SUDO rm -f "$STARSHIP_PATH"
                success "Removed Starship binary."
            fi

            # Revert default shell to bash for user
            if [[ "$OSTYPE" != "darwin"* ]]; then
                if command -v bash &> /dev/null && [ "$(basename "$SHELL")" = "zsh" ]; then
                    info "Reverting default shell back to bash..."
                    chsh -s "$(which bash)" < /dev/tty 2>/dev/null || true
                fi
                if [ -f "${HOME}/.bashrc" ] && grep -q "Auto-launch Zsh" "${HOME}/.bashrc"; then
                    sed -i '/Auto-launch Zsh/,/fi/d' "${HOME}/.bashrc"
                    success "Removed Zsh auto-forward from ~/.bashrc"
                fi
            fi

            # Root Zsh cleanup if detected
            if sudo [ -f "/root/.zshrc" ] 2>/dev/null; then
                echo ""
                local RM_ROOT_ZSH
                read -r -p "Do you also want to remove Zsh configurations for 'root' user? (y/N): " RM_ROOT_ZSH < /dev/tty
                if [[ "$RM_ROOT_ZSH" =~ ^[Yy]$ ]]; then
                    restore_backup "/root/.zshrc" true
                    restore_backup "/root/.config/starship.toml" true
                    sudo rm -rf "/root/.zsh"
                    
                    sudo chsh -s /bin/bash root 2>/dev/null || true
                    if sudo [ -f "/root/.bashrc" ] 2>/dev/null; then
                        sudo sed -i '/Auto-launch Zsh/,/fi/d' "/root/.bashrc"
                        success "Removed Zsh auto-forward from /root/.bashrc"
                    fi
                    success "Root Zsh cleanup complete!"
                fi
            fi
            echo -e "\n${GREEN}Zsh & Starship uninstalled successfully!${NC}\n"
            ;;
        2)
            echo ""
            info "=== UNINSTALLING VIM & NEOVIM ==="
            
            # User Vim cleanup
            restore_backup "${HOME}/.vimrc" false
            restore_backup "${HOME}/.config/nvim/init.vim" false
            if [ -d "${HOME}/.config/nvim" ] && [ -z "$(ls -A "${HOME}/.config/nvim" 2>/dev/null)" ]; then
                rmdir "${HOME}/.config/nvim"
            fi

            # Root Vim cleanup if detected
            if sudo [ -f "/root/.vimrc" ] 2>/dev/null; then
                echo ""
                local RM_ROOT_VIM
                read -r -p "Do you also want to remove Vim configurations for 'root' user? (y/N): " RM_ROOT_VIM < /dev/tty
                if [[ "$RM_ROOT_VIM" =~ ^[Yy]$ ]]; then
                    restore_backup "/root/.vimrc" true
                    restore_backup "/root/.config/nvim/init.vim" true
                    if sudo [ -d "/root/.config/nvim" ] 2>/dev/null && [ -z "$(sudo ls -A "/root/.config/nvim" 2>/dev/null)" ]; then
                        sudo rmdir "/root/.config/nvim"
                    fi
                    success "Root Vim cleanup complete!"
                fi
            fi
            echo -e "\n${GREEN}Vim & Neovim uninstalled successfully!${NC}\n"
            ;;
        3)
            echo ""
            info "=== UNINSTALLING TMUX ==="
            restore_backup "${HOME}/.tmux.conf" false
            
            if sudo [ -f "/root/.tmux.conf" ] 2>/dev/null; then
                echo ""
                local RM_ROOT_TMUX
                read -r -p "Do you also want to remove Tmux configurations for 'root' user? (y/N): " RM_ROOT_TMUX < /dev/tty
                if [[ "$RM_ROOT_TMUX" =~ ^[Yy]$ ]]; then
                    restore_backup "/root/.tmux.conf" true
                fi
            fi
            echo -e "\n${GREEN}Tmux uninstalled successfully!${NC}\n"
            ;;
        4)
            echo ""
            info "=== UNINSTALLING ALL MODULES (COMPLETE RESET) ==="
            
            # User cleanups
            restore_backup "${HOME}/.zshrc" false
            restore_backup "${HOME}/.config/starship.toml" false
            restore_backup "${HOME}/.vimrc" false
            restore_backup "${HOME}/.config/nvim/init.vim" false
            restore_backup "${HOME}/.tmux.conf" false
            
            if [ -d "${HOME}/.config/nvim" ] && [ -z "$(ls -A "${HOME}/.config/nvim" 2>/dev/null)" ]; then
                rmdir "${HOME}/.config/nvim"
            fi
            if [ -d "${HOME}/.zsh" ]; then
                rm -rf "${HOME}/.zsh"
            fi
            rm -f "${HOME}/.zcompdump"*
            rm -f "${HOME}/.zsh_history"
            rm -rf "${HOME}/.cache/starship"

            if command -v starship &> /dev/null; then
                local STARSHIP_PATH
                STARSHIP_PATH=$(which starship)
                local SUDO=""
                if [ "$(id -u)" -ne 0 ]; then SUDO="sudo"; fi
                $SUDO rm -f "$STARSHIP_PATH"
            fi

            if [[ "$OSTYPE" != "darwin"* ]]; then
                if command -v bash &> /dev/null && [ "$(basename "$SHELL")" = "zsh" ]; then
                    chsh -s "$(which bash)" < /dev/tty 2>/dev/null || true
                fi
                if [ -f "${HOME}/.bashrc" ] && grep -q "Auto-launch Zsh" "${HOME}/.bashrc"; then
                    sed -i '/Auto-launch Zsh/,/fi/d' "${HOME}/.bashrc"
                fi
            fi

            # Root check & cleanups
            local HAS_ROOT_CONFIG=false
            if sudo [ -f "/root/.zshrc" ] || sudo [ -f "/root/.vimrc" ] || sudo [ -f "/root/.tmux.conf" ] 2>/dev/null; then
                HAS_ROOT_CONFIG=true
            fi

            if [ "$HAS_ROOT_CONFIG" = true ]; then
                echo ""
                local RM_ROOT_ALL
                read -r -p "Do you also want to remove ALL configurations for 'root' user? (y/N): " RM_ROOT_ALL < /dev/tty
                if [[ "$RM_ROOT_ALL" =~ ^[Yy]$ ]]; then
                    restore_backup "/root/.zshrc" true
                    restore_backup "/root/.config/starship.toml" true
                    restore_backup "/root/.vimrc" true
                    restore_backup "/root/.config/nvim/init.vim" true
                    restore_backup "/root/.tmux.conf" true
                    
                    if sudo [ -d "/root/.config/nvim" ] 2>/dev/null && [ -z "$(sudo ls -A "/root/.config/nvim" 2>/dev/null)" ]; then
                        sudo rmdir "/root/.config/nvim"
                    fi
                    sudo rm -rf "/root/.zsh"
                    sudo chsh -s /bin/bash root 2>/dev/null || true
                    if sudo [ -f "/root/.bashrc" ] 2>/dev/null; then
                        sudo sed -i '/Auto-launch Zsh/,/fi/d' "/root/.bashrc"
                    fi
                    success "Root cleanup complete!"
                fi
            fi
            echo -e "\n${GREEN}Complete reset successful! All configurations cleared.${NC}\n"
            ;;
        5)
            info "Going back to main menu."
            ;;
        *)
            error "Invalid choice."
            ;;
    esac
}

# Interactive Menu Loop
clear
echo -e "${PURPLE}==================================================${NC}"
echo -e "${CYAN}       UNIVERSAL TERMINAL SETUP MANAGER (${VERSION})    ${NC}"
echo -e "${PURPLE}==================================================${NC}"
echo -e "Please select an option:"
echo -e "  ${GREEN}1)${NC} Install / Update Zsh & Starship"
echo -e "  ${GREEN}2)${NC} Install / Update Vim / Neovim"
echo -e "  ${GREEN}3)${NC} Install / Update Tmux (Soon)"
echo -e "  ${GREEN}4)${NC} Install / Update ALL (Zsh, Vim, Tmux)"
echo -e "  ${RED}5)${NC} Uninstall / Revert to Default"
echo -e "  ${YELLOW}6)${NC} Exit"
echo -e "${PURPLE}==================================================${NC}"

# Read input directly from tty to support curl execution
read -r -p "Enter your choice [1-6]: " CHOICE < /dev/tty

case "$CHOICE" in
    1)
        do_install_zsh
        ;;
    2)
        do_install_vim
        ;;
    3)
        do_install_tmux
        ;;
    4)
        do_install_all
        ;;
    5)
        do_uninstall
        ;;
    6)
        info "Exiting setup manager. No changes were made."
        exit 0
        ;;
    *)
        error "Invalid choice. Please run the script again."
        ;;
esac
