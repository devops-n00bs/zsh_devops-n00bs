#!/usr/bin/env bash

# ==============================================================================
# VIM & NEOVIM MODULE INSTALLER
# ==============================================================================

set -euo pipefail

# Source shared utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
source "${SCRIPT_DIR}/utils.sh"

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

cp "${REPO_ROOT}/vimrc" "${HOME}/.vimrc"
success "Copied vimrc to ~/.vimrc"

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

# Apply to root if requested
check_and_apply_to_root "vim"

echo -e "\n${GREEN}Vim/Neovim configuration complete!${NC}\n"
