#!/usr/bin/env bash

# ==============================================================================
# ZSH & STARSHIP MODULE INSTALLER
# ==============================================================================

set -euo pipefail

# Source shared utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
source "${SCRIPT_DIR}/utils.sh"

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

# Try to install optional modern CLI tools (bat and eza) on best-effort basis
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

setup_plugin() {
    local name=$1
    local url=$2
    local path="${PLUGIN_DIR}/${name}"
    
    if [ -d "$path" ]; then
        info "Updating plugin ${name}..."
        git -C "$path" pull || {
            warn "Failed to update ${name} via git pull. Re-cloning..."
            rm -rf "$path"
            git clone --depth 1 "$url" "$path"
        }
    else
        info "Downloading plugin ${name}..."
        git clone --depth 1 "$url" "$path"
    fi
}

setup_plugin "zsh-autosuggestions" "https://github.com/zsh-users/zsh-autosuggestions.git"
setup_plugin "zsh-syntax-highlighting" "https://github.com/zsh-users/zsh-syntax-highlighting.git"

# 4. Install configuration files from repository
info "Applying configuration files..."

# Setup .zshrc
if [ -f "${HOME}/.zshrc" ] && [ ! -f "${HOME}/.zshrc.bak" ]; then
    warn "Existing ~/.zshrc found. Creating backup at ~/.zshrc.bak"
    mv "${HOME}/.zshrc" "${HOME}/.zshrc.bak"
fi

cp "${REPO_ROOT}/zshrc" "${HOME}/.zshrc"
success "Copied zshrc to ~/.zshrc"

# Setup starship.toml
mkdir -p "${HOME}/.config"
if [ -f "${HOME}/.config/starship.toml" ] && [ ! -f "${HOME}/.config/starship.toml.bak" ]; then
    warn "Existing ~/.config/starship.toml found. Creating backup at ~/.config/starship.toml.bak"
    mv "${HOME}/.config/starship.toml" "${HOME}/.config/starship.toml.bak"
fi

cp "${REPO_ROOT}/starship.toml" "${HOME}/.config/starship.toml"
success "Copied starship.toml to ~/.config/starship.toml"

success "Zsh and Starship configurations successfully applied!"

# 5. Set default shell to Zsh
CURRENT_SHELL="unknown"
if [ -n "${SHELL:-}" ]; then
    CURRENT_SHELL=$(basename "$SHELL")
fi
if [ "$CURRENT_SHELL" != "zsh" ]; then
    info "Attempting to change your default shell to Zsh..."
    if command -v chsh &> /dev/null; then
        # Run chsh
        if chsh -s "$(which zsh)" < /dev/tty; then
            success "Default shell successfully changed to Zsh."
        else
            warn "Could not change default shell via chsh automatically."
        fi
    else
        warn "chsh command not found. Please change default shell manually."
    fi
fi

# Fallback auto-launch hook for Linux/WSL environments
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

# Apply to root if requested
check_and_apply_to_root "zsh"

# Prompt for FZF installation
echo ""
if command -v fzf &> /dev/null; then
    info "FZF (Fuzzy Finder) is already installed."
else
    local FZF_CHOICE
    read -r -p "Do you want to install and configure FZF (Fuzzy Finder) for interactive history & file search? (y/N): " FZF_CHOICE < /dev/tty
    if [[ "$FZF_CHOICE" =~ ^[Yy]$ ]]; then
        # Execute FZF installation script
        bash "${SCRIPT_DIR}/install_fzf.sh"
    fi
fi

echo -e "\n${GREEN}Zsh & Starship installation complete! Please restart your terminal or run:${NC}"
echo -e "  exec zsh\n"
