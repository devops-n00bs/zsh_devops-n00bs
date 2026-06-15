#!/usr/bin/env bash

# ==============================================================================
# SHARED UTILITIES & ENVIRONMENT DETECTION
# Compatible with macOS, Linux, and Windows WSL
# ==============================================================================

# Output Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Logging Helpers
info() { echo -e "${BLUE}[INFO]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; exit 1; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $*"; }

# Resolve absolute paths
_UTILS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
REPO_ROOT="$(cd "${_UTILS_DIR}/.." &>/dev/null && pwd)"
export REPO_ROOT
unset _UTILS_DIR

# Resolve root home path
ROOT_HOME="/root"
if [[ "$OSTYPE" == "darwin"* ]]; then
    ROOT_HOME="/var/root"
fi
export ROOT_HOME

# Detect Operating System dynamically
detect_os() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        local os_version
        os_version=$(sw_vers -productVersion 2>/dev/null || echo "")
        echo "macOS ${os_version}"
    elif [ -f /proc/version ] && grep -qi microsoft /proc/version; then
        local distro="Linux"
        if [ -f /etc/os-release ]; then
            distro=$(grep '^NAME=' /etc/os-release | cut -d= -f2 | tr -d '"')
        fi
        echo "${distro} (WSL Mode)"
    elif [ -f /etc/os-release ]; then
        local distro
        distro=$(grep '^NAME=' /etc/os-release | cut -d= -f2 | tr -d '"')
        echo "${distro}"
    else
        echo "Unix-like OS ($(uname -s))"
    fi
}

# Detect if the environment is Root-Only or Multi-User
detect_user_env() {
    if [ "$(id -u)" -ne 0 ]; then
        echo "Multi-User Environment"
        return
    fi
    
    if [[ "$OSTYPE" == "darwin"* ]]; then
        echo "Multi-User Environment"
        return
    fi
    
    # Check if there are human users in /etc/passwd (UID >= 1000 and < 60000)
    if [ -f /etc/passwd ]; then
        local human_count
        human_count=$(awk -F: '$3 >= 1000 && $3 < 60000 {print $1}' /etc/passwd 2>/dev/null | wc -l || echo 0)
        if [ "$human_count" -eq 0 ]; then
            echo "Root-Only Environment"
        else
            echo "Multi-User Environment"
        fi
    else
        echo "Root-Only Environment"
    fi
}

# Helper to check sudo status
check_sudo() {
    if command -v sudo &> /dev/null; then
        if sudo -n true 2>/dev/null; then
            echo -e "${GREEN}Detected (No Password Required)${NC}"
        else
            echo -e "${YELLOW}Detected (Requires Password)${NC}"
        fi
    else
        echo -e "${RED}Not Available${NC}"
    fi
}

# Helper to determine module status label
get_status_label() {
    local path=$1
    local is_root=$2
    if [ "$is_root" = true ]; then
        if sudo [ -f "$path" ] 2>/dev/null; then
            echo -e "${GREEN}[INSTALLED]${NC}"
        else
            echo -e "${RED}[NOT INSTALLED]${NC}"
        fi
    else
        if [ -f "$path" ]; then
            echo -e "${GREEN}[INSTALLED]${NC}"
        else
            echo -e "${RED}[NOT INSTALLED]${NC}"
        fi
    fi
}

# Helper: Check sudo and ask to apply configuration to root
check_and_apply_to_root() {
    local module=$1
    
    # Check if we are already root
    if [ "$(id -u)" -eq 0 ]; then
        return
    fi

    # Check if user has sudo privileges
    if ! command -v sudo &> /dev/null; then
        return
    fi

    echo ""
    local ROOT_CHOICE
    read -r -p "Do you also want to apply this configuration to the 'root' user? (y/N): " ROOT_CHOICE < /dev/tty
    if [[ "$ROOT_CHOICE" =~ ^[Yy]$ ]]; then
        info "Applying configuration to the 'root' user..."
        local SUDO="sudo"
        
        # Helper to backup existing root file safely
        backup_root_file() {
            local file=$1
            if $SUDO [ -f "$file" ] && ! $SUDO [ -f "${file}.bak" ]; then
                $SUDO mv "$file" "${file}.bak"
            fi
        }

        if [ "$module" = "zsh" ]; then
            # 1. Zsh config to root
            $SUDO mkdir -p "${ROOT_HOME}/.config"
            backup_root_file "${ROOT_HOME}/.zshrc"
            $SUDO cp "${HOME}/.zshrc" "${ROOT_HOME}/.zshrc"
            backup_root_file "${ROOT_HOME}/.config/starship.toml"
            $SUDO cp "${HOME}/.config/starship.toml" "${ROOT_HOME}/.config/starship.toml"
            
            # 2. Plugins to root
            $SUDO mkdir -p "${ROOT_HOME}/.zsh/plugins"
            $SUDO cp -r "${HOME}/.zsh/plugins/"* "${ROOT_HOME}/.zsh/plugins/" 2>/dev/null || true
            
            # 3. Change root default shell to Zsh
            if command -v zsh &> /dev/null; then
                local ZSH_PATH
                ZSH_PATH=$(command -v zsh)
                if $SUDO chsh -s "$ZSH_PATH" root &>/dev/null; then
                    success "Default shell for 'root' changed to Zsh."
                  else
                    # Fallback auto-launch in root .bashrc
                    $SUDO bash -c "if [ -f '${ROOT_HOME}/.bashrc' ] && ! grep -q 'Auto-launch Zsh' '${ROOT_HOME}/.bashrc'; then echo -e '\n# Auto-launch Zsh on login\nif [ -t 1 ] && command -v zsh &> /dev/null; then\n    exec zsh\nfi' >> '${ROOT_HOME}/.bashrc'; fi"
                    success "Added Zsh auto-forward to ${ROOT_HOME}/.bashrc"
                fi
            fi
            success "Zsh & Starship configuration applied to 'root' user!"
            
        elif [ "$module" = "vim" ]; then
            # 1. Vim config to root
            backup_root_file "${ROOT_HOME}/.vimrc"
            $SUDO cp "${HOME}/.vimrc" "${ROOT_HOME}/.vimrc"
            
            # 2. Neovim config to root
            if command -v nvim &> /dev/null; then
                $SUDO mkdir -p "${ROOT_HOME}/.config/nvim"
                backup_root_file "${ROOT_HOME}/.config/nvim/init.vim"
                $SUDO bash -c "cat << 'EOF' > ${ROOT_HOME}/.config/nvim/init.vim
set runtimepath^=~/.vim runtimepath+=~/.vim/after
let &packpath = &runtimepath
source ~/.vimrc
EOF"
                success "Neovim configured for 'root' user."
            fi
            success "Vim/Neovim configuration applied to 'root' user!"
        elif [ "$module" = "tmux" ]; then
            # 1. Tmux config to root
            backup_root_file "${ROOT_HOME}/.tmux.conf"
            $SUDO cp "${HOME}/.tmux.conf" "${ROOT_HOME}/.tmux.conf"
            success "Tmux configuration applied to 'root' user!"
        elif [ "$module" = "fzf" ]; then
            # 1. Copy FZF git clone or local binary to root if exists
            if [ -d "${HOME}/.fzf" ]; then
                $SUDO rm -rf "${ROOT_HOME}/.fzf"
                $SUDO cp -r "${HOME}/.fzf" "${ROOT_HOME}/.fzf"
                $SUDO mkdir -p "${ROOT_HOME}/.local/bin"
                $SUDO ln -sf "${ROOT_HOME}/.fzf/bin/fzf" "${ROOT_HOME}/.local/bin/fzf"
            elif [ -f "${HOME}/.local/bin/fzf" ]; then
                $SUDO mkdir -p "${ROOT_HOME}/.local/bin"
                $SUDO cp "${HOME}/.local/bin/fzf" "${ROOT_HOME}/.local/bin/fzf"
            fi
            success "FZF configuration applied to 'root' user!"
        fi
    fi
}
