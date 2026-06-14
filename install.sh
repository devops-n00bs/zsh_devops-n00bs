#!/usr/bin/env bash

# ==============================================================================
# AUTOMATIC ZSH CONFIGURATION MANAGER (Interactive Menu)
# Works on macOS, WSL, and Linux Server
# ==============================================================================

# Exit on error, undefined variables, and pipe failures
set -euo pipefail

# Version
VERSION="v1.1.2"

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

# Function: Install or Update Configuration
do_install() {
    echo ""
    info "=== STARTING INSTALLATION / UPDATE ==="
    
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
$directory$git_branch$git_status$git_state
$character"""

# OS Module (Disabled for super minimal look)
[os]
disabled = true

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

    # 5. Suggest shell change
    CURRENT_SHELL=$(basename "$SHELL")
    if [ "$CURRENT_SHELL" != "zsh" ]; then
        warn "Current shell is ${CURRENT_SHELL}."
        echo -e "${YELLOW}Run the following command to change your default shell to Zsh:${NC}"
        echo -e "  chsh -s \$(which zsh)"
    fi

    if [ "$IS_WSL" = true ]; then
        info "WSL environment detected. Ensuring Zsh auto-launches on startup..."
        BASHRC="${HOME}/.bashrc"
        if [ -f "$BASHRC" ]; then
            if ! grep -q "Auto-launch Zsh in WSL" "$BASHRC"; then
                echo -e "\n# Auto-launch Zsh in WSL sessions\nif [ -t 1 ] && command -v zsh &> /dev/null; then\n    exec zsh\nfi" >> "$BASHRC"
                success "Added Zsh auto-forward to ~/.bashrc"
            else
                info "Zsh auto-forward already exists in ~/.bashrc."
            fi
        fi
    fi

    echo -e "\n${GREEN}Installation complete! Please restart your terminal or run:${NC}"
    echo -e "  exec zsh\n"
}

# Function: Uninstall / Restore Configuration
do_uninstall() {
    echo ""
    info "=== STARTING SYSTEM CLEANUP (UNINSTALL) ==="
    
    # 1. Remove Zsh configuration and backups
    info "Removing Zsh configuration files..."
    for file in "${HOME}/.zshrc" "${HOME}/.zshrc.bak"; do
        if [ -f "$file" ]; then
            rm -f "$file"
            success "Removed $file"
        fi
    done

    # 2. Remove Starship configuration and backups
    info "Removing Starship configurations..."
    for file in "${HOME}/.config/starship.toml" "${HOME}/.config/starship.toml.bak"; do
        if [ -f "$file" ]; then
            rm -f "$file"
            success "Removed $file"
        fi
    done

    # 3. Clean up plugins and entire .zsh directory
    info "Cleaning up Zsh plugins folder..."
    if [ -d "${HOME}/.zsh" ]; then
        rm -rf "${HOME}/.zsh"
        success "Removed folder ~/.zsh"
    fi

    # 4. Clean up cache and history
    info "Cleaning up terminal caches and history..."
    rm -f "${HOME}/.zcompdump"*
    rm -f "${HOME}/.zsh_history"
    rm -rf "${HOME}/.cache/starship"
    success "Zcompdump cache, Starship cache, and Zsh history (~/.zsh_history) successfully cleared."

    # 5. Remove Starship binary if installed
    if command -v starship &> /dev/null; then
        STARSHIP_PATH=$(which starship)
        info "Removing Starship binary at $STARSHIP_PATH..."
        SUDO=""
        if [ "$(id -u)" -ne 0 ]; then
            SUDO="sudo"
        fi
        $SUDO rm -f "$STARSHIP_PATH"
        success "Starship binary successfully removed."
    fi

    # 6. Automatically try to revert default shell to bash
    CURRENT_SHELL=$(basename "$SHELL")
    if [[ "$OSTYPE" == "darwin"* ]]; then
        info "On macOS, the default shell is Zsh. No need to revert to bash."
    else
        if command -v bash &> /dev/null; then
            info "Reverting default shell back to bash..."
            BASH_PATH=$(which bash)
            if [ "$CURRENT_SHELL" = "zsh" ]; then
                # Revert shell interactively (may ask for user password)
                if chsh -s "$BASH_PATH" < /dev/tty; then
                    success "Default shell successfully reverted to bash ($BASH_PATH)."
                else
                    warn "Failed to change shell automatically. Please run manually: chsh -s $BASH_PATH"
                fi
            else
                info "Current default shell is not Zsh ($CURRENT_SHELL). Revert skipped."
            fi
        fi
    fi

    # 7. Clean up WSL auto-forward from ~/.bashrc if present
    BASHRC="${HOME}/.bashrc"
    if [ -f "$BASHRC" ] && grep -q "Auto-launch Zsh in WSL" "$BASHRC"; then
        info "Removing Zsh auto-forward from ~/.bashrc..."
        sed -i '/Auto-launch Zsh in WSL/,/fi/d' "$BASHRC"
        success "Removed Zsh auto-forward from ~/.bashrc"
    fi

    echo -e "\n${GREEN}Cleanup complete! All custom configurations, binaries, and caches have been fully removed.${NC}"
    echo -e "${YELLOW}Please restart your terminal or open a new session to see changes.${NC}\n"
    exit 0
}

# Interactive Menu Loop
clear
echo -e "${PURPLE}==================================================${NC}"
echo -e "${CYAN}       ZSH & STARSHIP SETUP MANAGER (${VERSION})      ${NC}"
echo -e "${PURPLE}==================================================${NC}"
echo -e "Please select an option:"
echo -e "  ${GREEN}1)${NC} Install / Update Configuration"
echo -e "  ${RED}2)${NC} Uninstall / Revert to Default"
echo -e "  ${YELLOW}3)${NC} Exit"
echo -e "${PURPLE}==================================================${NC}"

# Read input directly from tty to support curl execution
read -r -p "Enter your choice [1-3]: " CHOICE < /dev/tty

case "$CHOICE" in
    1)
        do_install
        ;;
    2)
        do_uninstall
        ;;
    3)
        info "Exiting setup manager. No changes were made."
        exit 0
        ;;
    *)
        error "Invalid choice. Please run the script again."
        ;;
esac
