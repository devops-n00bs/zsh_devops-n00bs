#!/usr/bin/env bash

# ==============================================================================
# FZF (FUZZY FINDER) MODULE INSTALLER
# ==============================================================================

set -euo pipefail

# Source shared utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
source "${SCRIPT_DIR}/utils.sh"

echo ""
info "=== STARTING FZF INSTALLATION ==="

# Check if FZF is already installed
if command -v fzf &> /dev/null; then
    success "FZF is already installed at $(command -v fzf)."
    exit 0
fi

info "Detecting system environment..."

SUDO=""
if [ "$(id -u)" -ne 0 ]; then
    SUDO="sudo"
fi

# Attempt installation using package manager with a Git clone fallback on failure
success_pkg=false
set +e # temporarily disable exit-on-error to catch package manager failures

if [[ "$OSTYPE" == "darwin"* ]]; then
    if command -v brew &> /dev/null; then
        info "Installing FZF via Homebrew..."
        brew install fzf && success_pkg=true
    fi
elif [ -f /etc/debian_version ]; then
    info "Installing FZF via apt-get..."
    $SUDO apt-get update && $SUDO apt-get install -y fzf && success_pkg=true
elif [ -f /etc/redhat-release ] || [ -f /etc/system-release ]; then
    info "Installing FZF via dnf/yum..."
    if command -v dnf &> /dev/null; then
        $SUDO dnf install -y fzf && success_pkg=true
    else
        $SUDO yum install -y fzf && success_pkg=true
    fi
elif [ -f /etc/arch-release ]; then
    info "Installing FZF via pacman..."
    $SUDO pacman -S --noconfirm fzf && success_pkg=true
fi

set -e # re-enable exit-on-error

if [ "$success_pkg" = false ]; then
    warn "Package manager installation failed or was blocked (e.g. apt lock). Falling back to Git repository clone..."
    
    if [ -d "${HOME}/.fzf" ]; then
        info "Updating existing FZF clone..."
        git -C "${HOME}/.fzf" pull
    else
        info "Cloning FZF repository..."
        git clone --depth 1 https://github.com/junegunn/fzf.git "${HOME}/.fzf"
    fi
    
    info "Compiling/Downloading FZF binary..."
    # --bin: only install binaries (no shell modifications, we handle this in zshrc)
    "${HOME}/.fzf/install" --bin --no-update-rc --no-bash --no-zsh
    
    # Create symlink in ~/.local/bin
    mkdir -p "${HOME}/.local/bin"
    ln -sf "${HOME}/.fzf/bin/fzf" "${HOME}/.local/bin/fzf"
    export PATH="${HOME}/.local/bin:$PATH"
fi

# Verify installation success
if command -v fzf &> /dev/null || [[ -f "${HOME}/.local/bin/fzf" ]]; then
    success "FZF successfully installed!"
    # Apply to root if requested
    check_and_apply_to_root "fzf"
else
    error "FZF installation completed, but binary was not found in PATH."
fi
