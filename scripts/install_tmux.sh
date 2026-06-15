#!/usr/bin/env bash

# ==============================================================================
# TMUX MODULE INSTALLER
# ==============================================================================

set -euo pipefail

# Source shared utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
source "${SCRIPT_DIR}/utils.sh"

echo ""
info "=== STARTING TMUX INSTALLATION ==="

# 1. Detect and install Tmux if missing
if ! command -v tmux &> /dev/null || ! command -v xclip &> /dev/null; then
    info "Checking/Installing Tmux and clipboard dependencies..."
    SUDO=""
    if [ "$(id -u)" -ne 0 ]; then
        SUDO="sudo"
    fi
    
    if [[ "$OSTYPE" == "darwin"* ]]; then
        if ! command -v tmux &> /dev/null; then
            if command -v brew &> /dev/null; then
                brew install tmux
            else
                warn "Homebrew not found. Please install Tmux manually."
            fi
        fi
    elif [ -f /etc/debian_version ]; then
        $SUDO apt-get update
        $SUDO apt-get install -y tmux xclip
    elif [ -f /etc/redhat-release ] || [ -f /etc/system-release ]; then
        if command -v dnf &> /dev/null; then
            $SUDO dnf install -y tmux xclip
        else
            $SUDO yum install -y tmux xclip
        fi
    elif [ -f /etc/arch-release ]; then
        $SUDO pacman -S --noconfirm tmux xclip
    else
        warn "Could not verify/install packages automatically. Please ensure tmux and xclip/xsel are installed."
    fi
else
    info "Tmux and clipboard dependencies are met."
fi

# 2. Setup .tmux.conf
if [ -f "${HOME}/.tmux.conf" ] && [ ! -f "${HOME}/.tmux.conf.bak" ]; then
    warn "Existing ~/.tmux.conf found. Creating backup at ~/.tmux.conf.bak"
    mv "${HOME}/.tmux.conf" "${HOME}/.tmux.conf.bak"
fi

cp "${REPO_ROOT}/tmux.conf" "${HOME}/.tmux.conf"
success "Copied tmux.conf to ~/.tmux.conf"

# Apply to root if requested
check_and_apply_to_root "tmux"

echo -e "\n${GREEN}Tmux configuration complete!${NC}\n"
