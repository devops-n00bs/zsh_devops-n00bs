#!/usr/bin/env bash

# ==============================================================================
# DEVOPS TERMINAL SUITE UNINSTALLER
# ==============================================================================

set -euo pipefail

# Source shared utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
source "${SCRIPT_DIR}/utils.sh"

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
check_status "${ROOT_HOME}/.zshrc" true
echo ""

echo -e "  ${CYAN}[2] Vim & Neovim Configuration:${NC}"
echo -ne "      - User ($(whoami)) : "
check_status "${HOME}/.vimrc" false
echo -ne "      - Root          : "
check_status "${ROOT_HOME}/.vimrc" true
echo ""

echo -e "  ${CYAN}[3] Tmux Configuration:${NC}"
echo -ne "      - User ($(whoami)) : "
check_status "${HOME}/.tmux.conf" false
echo -ne "      - Root          : "
check_status "${ROOT_HOME}/.tmux.conf" true
echo ""

echo -e "  ${CYAN}[4] FZF (Fuzzy Finder):${NC}"
echo -ne "      - User ($(whoami)) : "
if command -v fzf &> /dev/null || [[ -f "${HOME}/.local/bin/fzf" ]]; then
    echo -e "${GREEN}[INSTALLED]${NC}"
else
    echo -e "${NC}[NOT INSTALLED]${NC}"
fi
echo ""

echo -e "${PURPLE}=======================================================${NC}"
echo -e "Please select an option to uninstall:"
echo -e "  ${GREEN}1)${NC} Uninstall Zsh & Starship"
echo -e "  ${GREEN}2)${NC} Uninstall Vim & Neovim"
echo -e "  ${GREEN}3)${NC} Uninstall Tmux"
echo -e "  ${GREEN}4)${NC} Uninstall FZF (Fuzzy Finder)"
echo -e "  ${RED}5)${NC} Uninstall ALL (Complete Reset)"
echo -e "  ${YELLOW}6)${NC} Cancel / Go Back"
echo -e "${PURPLE}=======================================================${NC}"

read -r -p "Enter your choice [1-6]: " UNINSTALL_CHOICE < /dev/tty

if [ "$UNINSTALL_CHOICE" -eq 6 ] 2>/dev/null; then
    info "Going back to main menu."
    exit 0
fi

if [ "$UNINSTALL_CHOICE" -lt 1 ] || [ "$UNINSTALL_CHOICE" -gt 6 ] 2>/dev/null; then
    error "Invalid choice."
fi

# Reset method selection for config files (not applicable if only uninstalling FZF binary)
RESET_METHOD=2
if [ "$UNINSTALL_CHOICE" -ne 4 ]; then
    echo ""
    echo -e "${YELLOW}Select Reset Method for the chosen module(s):${NC}"
    echo -e "  ${GREEN}1)${NC} Restore Backup (.bak) - Recover your previous settings if available"
    echo -e "  ${GREEN}2)${NC} Fresh OS Default - Completely erase configurations back to a clean state"
    read -r -p "Enter your choice [1-2]: " RESET_METHOD < /dev/tty

    if [ "$RESET_METHOD" -ne 1 ] && [ "$RESET_METHOD" -ne 2 ] 2>/dev/null; then
        error "Invalid reset method choice."
    fi
fi

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

# Helper to reset to fresh OS default
fresh_os_reset() {
    local file=$1
    local is_root=$2
    local backup="${file}.bak"
    
    if [ "$is_root" = true ]; then
        local SUDO="sudo"
        $SUDO rm -f "$backup" 2>/dev/null
        if $SUDO [ -f "$file" ] 2>/dev/null; then
            info "Removing root $file..."
            $SUDO rm -f "$file"
            success "Removed root $file"
        fi
    else
        rm -f "$backup" 2>/dev/null
        if [ -f "$file" ]; then
            info "Removing $file..."
            rm -f "$file"
            success "Removed $file"
        fi
    fi
}

# Helper to clean bashrc auto-launch forwarding
clean_bashrc() {
    local is_root=$1
    local target="${HOME}/.bashrc"
    local template="/etc/skel/.bashrc"
    local SUDO=""
    
    if [ "$is_root" = true ]; then
        target="${ROOT_HOME}/.bashrc"
        SUDO="sudo"
    fi

    # Remove the auto-launch lines first
    if [ "$is_root" = true ]; then
        if $SUDO [ -f "$target" ] 2>/dev/null; then
            $SUDO sed -i '/Auto-launch Zsh/,/fi/d' "$target" 2>/dev/null || true
        fi
    else
        if [ -f "$target" ]; then
            sed -i '/Auto-launch Zsh/,/fi/d' "$target" 2>/dev/null || true
        fi
    fi

    # If doing a fresh OS reset, replace the whole file with template
    if [ "$RESET_METHOD" -eq 2 ]; then
        if [ -f "$template" ] && [ "$is_root" = false ]; then
            info "Restoring template $template to $target..."
            cp "$template" "$target"
            success "Restored default template to $target"
        elif [ "$is_root" = true ] && [ -f "$template" ]; then
            info "Restoring template $template to root $target..."
            $SUDO cp "$template" "$target"
            success "Restored default template to root $target"
        fi
    fi
}

# Helper to uninstall FZF
do_uninstall_fzf() {
    info "Uninstalling FZF..."
    # 1. Remove FZF Git folder if exists
    if [ -d "${HOME}/.fzf" ]; then
        rm -rf "${HOME}/.fzf"
        success "Removed ~/.fzf folder"
    fi
    # 2. Remove local binary
    if [ -f "${HOME}/.local/bin/fzf" ]; then
        rm -f "${HOME}/.local/bin/fzf"
        success "Removed FZF binary from ~/.local/bin"
    fi
    # 3. Attempt package manager removal
    local SUDO=""
    if [ "$(id -u)" -ne 0 ]; then
        SUDO="sudo"
    fi
    
    set +e
    if [[ "$OSTYPE" == "darwin"* ]]; then
        if command -v brew &>/dev/null; then
            brew uninstall fzf 2>/dev/null
        fi
    elif [ -f /etc/debian_version ]; then
        $SUDO apt-get remove -y fzf 2>/dev/null
    elif [ -f /etc/redhat-release ] || [ -f /etc/system-release ]; then
        if command -v dnf &>/dev/null; then
            $SUDO dnf remove -y fzf 2>/dev/null
        else
            $SUDO yum remove -y fzf 2>/dev/null
        fi
    elif [ -f /etc/arch-release ]; then
        $SUDO pacman -Rs --noconfirm fzf 2>/dev/null
    fi
    set -e
    success "FZF uninstalled successfully."
}

case "$UNINSTALL_CHOICE" in
    1)
        echo ""
        info "=== UNINSTALLING ZSH & STARSHIP ==="
        
        if [ "$RESET_METHOD" -eq 1 ]; then
            restore_backup "${HOME}/.zshrc" false
            restore_backup "${HOME}/.config/starship.toml" false
        else
            fresh_os_reset "${HOME}/.zshrc" false
            fresh_os_reset "${HOME}/.config/starship.toml" false
        fi
        
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

        clean_bashrc false

        # Revert default shell to bash for user
        if [[ "$OSTYPE" != "darwin"* ]]; then
            if command -v bash &> /dev/null && [ "$(basename "${SHELL:-}")" = "zsh" ]; then
                info "Reverting default shell back to bash..."
                chsh -s "$(which bash)" < /dev/tty 2>/dev/null || true
            fi
        fi

        # Root Zsh cleanup if detected
        if sudo [ -f "${ROOT_HOME}/.zshrc" ] || sudo [ -f "${ROOT_HOME}/.zshrc.bak" ] 2>/dev/null; then
            echo ""
            local RM_ROOT_ZSH
            read -r -p "Do you also want to remove Zsh configurations for 'root' user? (y/N): " RM_ROOT_ZSH < /dev/tty
            if [[ "$RM_ROOT_ZSH" =~ ^[Yy]$ ]]; then
                if [ "$RESET_METHOD" -eq 1 ]; then
                    restore_backup "${ROOT_HOME}/.zshrc" true
                    restore_backup "${ROOT_HOME}/.config/starship.toml" true
                else
                    fresh_os_reset "${ROOT_HOME}/.zshrc" true
                    fresh_os_reset "${ROOT_HOME}/.config/starship.toml" true
                fi
                sudo rm -rf "${ROOT_HOME}/.zsh"
                
                sudo chsh -s /bin/bash root 2>/dev/null || true
                clean_bashrc true
                success "Root Zsh cleanup complete!"
            fi
        fi
        echo -e "\n${GREEN}Zsh & Starship uninstalled successfully!${NC}\n"
        ;;
    2)
        echo ""
        info "=== UNINSTALLING VIM & NEOVIM ==="
        
        if [ "$RESET_METHOD" -eq 1 ]; then
            restore_backup "${HOME}/.vimrc" false
            restore_backup "${HOME}/.config/nvim/init.vim" false
        else
            fresh_os_reset "${HOME}/.vimrc" false
            fresh_os_reset "${HOME}/.config/nvim/init.vim" false
        fi
        if [ -d "${HOME}/.config/nvim" ] && [ -z "$(ls -A "${HOME}/.config/nvim" 2>/dev/null)" ]; then
            rmdir "${HOME}/.config/nvim"
        fi

        # Root Vim cleanup if detected
        if sudo [ -f "${ROOT_HOME}/.vimrc" ] || sudo [ -f "${ROOT_HOME}/.vimrc.bak" ] 2>/dev/null; then
            echo ""
            local RM_ROOT_VIM
            read -r -p "Do you also want to remove Vim configurations for 'root' user? (y/N): " RM_ROOT_VIM < /dev/tty
            if [[ "$RM_ROOT_VIM" =~ ^[Yy]$ ]]; then
                if [ "$RESET_METHOD" -eq 1 ]; then
                    restore_backup "${ROOT_HOME}/.vimrc" true
                    restore_backup "${ROOT_HOME}/.config/nvim/init.vim" true
                else
                    fresh_os_reset "${ROOT_HOME}/.vimrc" true
                    fresh_os_reset "${ROOT_HOME}/.config/nvim/init.vim" true
                fi
                if sudo [ -d "${ROOT_HOME}/.config/nvim" ] 2>/dev/null && [ -z "$(sudo ls -A "${ROOT_HOME}/.config/nvim" 2>/dev/null)" ]; then
                    sudo rmdir "${ROOT_HOME}/.config/nvim"
                fi
                success "Root Vim cleanup complete!"
            fi
        fi
        echo -e "\n${GREEN}Vim & Neovim uninstalled successfully!${NC}\n"
        ;;
    3)
        echo ""
        info "=== UNINSTALLING TMUX ==="
        if [ "$RESET_METHOD" -eq 1 ]; then
            restore_backup "${HOME}/.tmux.conf" false
        else
            fresh_os_reset "${HOME}/.tmux.conf" false
        fi
        
        if sudo [ -f "${ROOT_HOME}/.tmux.conf" ] || sudo [ -f "${ROOT_HOME}/.tmux.conf.bak" ] 2>/dev/null; then
            echo ""
            local RM_ROOT_TMUX
            read -r -p "Do you also want to remove Tmux configurations for 'root' user? (y/N): " RM_ROOT_TMUX < /dev/tty
            if [[ "$RM_ROOT_TMUX" =~ ^[Yy]$ ]]; then
                if [ "$RESET_METHOD" -eq 1 ]; then
                    restore_backup "${ROOT_HOME}/.tmux.conf" true
                else
                    fresh_os_reset "${ROOT_HOME}/.tmux.conf" true
                fi
            fi
        fi
        echo -e "\n${GREEN}Tmux uninstalled successfully!${NC}\n"
        ;;
    4)
        echo ""
        info "=== UNINSTALLING FZF (FUZZY FINDER) ==="
        do_uninstall_fzf
        echo -e "\n${GREEN}FZF uninstalled successfully!${NC}\n"
        ;;
    5)
        echo ""
        info "=== UNINSTALLING ALL MODULES (COMPLETE RESET) ==="
        
        # User cleanups
        if [ "$RESET_METHOD" -eq 1 ]; then
            restore_backup "${HOME}/.zshrc" false
            restore_backup "${HOME}/.config/starship.toml" false
            restore_backup "${HOME}/.vimrc" false
            restore_backup "${HOME}/.config/nvim/init.vim" false
            restore_backup "${HOME}/.tmux.conf" false
        else
            fresh_os_reset "${HOME}/.zshrc" false
            fresh_os_reset "${HOME}/.config/starship.toml" false
            fresh_os_reset "${HOME}/.vimrc" false
            fresh_os_reset "${HOME}/.config/nvim/init.vim" false
            fresh_os_reset "${HOME}/.tmux.conf" false
        fi
        
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

        do_uninstall_fzf

        clean_bashrc false

        if [[ "$OSTYPE" != "darwin"* ]]; then
            if command -v bash &> /dev/null && [ "$(basename "${SHELL:-}")" = "zsh" ]; then
                chsh -s "$(which bash)" < /dev/tty 2>/dev/null || true
            fi
        fi

        # Root check & cleanups
        local HAS_ROOT_CONFIG=false
        if sudo [ -f "${ROOT_HOME}/.zshrc" ] || sudo [ -f "${ROOT_HOME}/.zshrc.bak" ] || \
           sudo [ -f "${ROOT_HOME}/.vimrc" ] || sudo [ -f "${ROOT_HOME}/.vimrc.bak" ] || \
           sudo [ -f "${ROOT_HOME}/.tmux.conf" ] || sudo [ -f "${ROOT_HOME}/.tmux.conf.bak" ] 2>/dev/null; then
            HAS_ROOT_CONFIG=true
        fi

        if [ "$HAS_ROOT_CONFIG" = true ]; then
            echo ""
            local RM_ROOT_ALL
            read -r -p "Do you also want to remove ALL configurations for 'root' user? (y/N): " RM_ROOT_ALL < /dev/tty
            if [[ "$RM_ROOT_ALL" =~ ^[Yy]$ ]]; then
                if [ "$RESET_METHOD" -eq 1 ]; then
                    restore_backup "${ROOT_HOME}/.zshrc" true
                    restore_backup "${ROOT_HOME}/.config/starship.toml" true
                    restore_backup "${ROOT_HOME}/.vimrc" true
                    restore_backup "${ROOT_HOME}/.config/nvim/init.vim" true
                    restore_backup "${ROOT_HOME}/.tmux.conf" true
                else
                    fresh_os_reset "${ROOT_HOME}/.zshrc" true
                    fresh_os_reset "${ROOT_HOME}/.config/starship.toml" true
                    fresh_os_reset "${ROOT_HOME}/.vimrc" true
                    fresh_os_reset "${ROOT_HOME}/.config/nvim/init.vim" true
                    fresh_os_reset "${ROOT_HOME}/.tmux.conf" true
                fi
                
                if sudo [ -d "${ROOT_HOME}/.config/nvim" ] 2>/dev/null && [ -z "$(sudo ls -A "${ROOT_HOME}/.config/nvim" 2>/dev/null)" ]; then
                    sudo rmdir "${ROOT_HOME}/.config/nvim"
                fi
                sudo rm -rf "${ROOT_HOME}/.zsh"
                sudo chsh -s /bin/bash root 2>/dev/null || true
                clean_bashrc true
                success "Root cleanup complete!"
            fi
        fi
        echo -e "\n${GREEN}Complete reset successful! All configurations cleared.${NC}\n"
        ;;
    *)
        error "Invalid choice."
        ;;
esac
