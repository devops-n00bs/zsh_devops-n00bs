#!/usr/bin/env bash

# ==============================================================================
# AUTOMATIC TERMINAL CONFIGURATION MANAGER (Bootstrapper & Coordinator)
# Works on macOS, WSL, and Linux Server
# ==============================================================================

set -euo pipefail

# Detect if script is run locally or downloaded directly
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" &>/dev/null && pwd)"
IS_LOCAL=false
if [[ -f "${SCRIPT_DIR}/zshrc" && -f "${SCRIPT_DIR}/starship.toml" && -d "${SCRIPT_DIR}/scripts" ]]; then
    IS_LOCAL=true
fi

# Bootstrapping Mode: If running remotely (e.g. piped via curl), download & extract tarball
if [ "$IS_LOCAL" = false ]; then
    echo -e "\033[0;34m[INFO]\033[0m Bootstrapping DevOps terminal suite installer..."
    TEMP_DIR=$(mktemp -d -t devops-n00bs-XXXXXX)
    
    # Secure cleanup of temporary directory upon exit
    trap 'rm -rf "$TEMP_DIR"' EXIT
    
    # Download repository archive and extract it
    if command -v curl &> /dev/null; then
        curl -fsSL "https://github.com/devops-n00bs/zsh_devops-n00bs/archive/refs/heads/main.tar.gz" | tar -xz -C "$TEMP_DIR" --strip-components=1
    elif command -v wget &> /dev/null; then
        wget -qO- "https://github.com/devops-n00bs/zsh_devops-n00bs/archive/refs/heads/main.tar.gz" | tar -xz -C "$TEMP_DIR" --strip-components=1
    else
        echo -e "\033[0;31m[ERROR]\033[0m Neither curl nor wget is installed. Cannot download package."
        exit 1
    fi
    
    # Delegate execution to the extracted installer
    bash "$TEMP_DIR/install.sh" "$@"
    exit 0
fi

# ==============================================================================
# Local Installer Execution Coordinator
# ==============================================================================

# Source shared helpers
source "${SCRIPT_DIR}/scripts/utils.sh"

# Constants
VERSION="v1.4.9"

# Main Menu Loop
while true; do
    clear

    OS_NAME=$(detect_os)
    SUDO_STATUS=$(check_sudo)
    CURRENT_SHELL="${SHELL:-unknown}"
    ACTIVE_USER=$(whoami)
    CPU_ARCH=$(uname -m 2>/dev/null || echo "unknown")
    USER_ENV=$(detect_user_env)

    # Retrieve Module Status Labels
    if [ "$(id -u)" -eq 0 ]; then
        ZSH_ROOT_STATUS=$(get_status_label "${ROOT_HOME}/.zshrc" true)
        VIM_ROOT_STATUS=$(get_status_label "${ROOT_HOME}/.vimrc" true)
        TMUX_ROOT_STATUS=$(get_status_label "${ROOT_HOME}/.tmux.conf" true)
        
        if [ -f "${ROOT_HOME}/.local/bin/fzf" ] || [ -f "${ROOT_HOME}/.fzf/bin/fzf" ] || command -v fzf >/dev/null 2>&1; then
            FZF_ROOT_STATUS="${GREEN}[INSTALLED]${NC}"
        else
            FZF_ROOT_STATUS="${RED}[NOT INSTALLED]${NC}"
        fi
    else
        ZSH_USER_STATUS=$(get_status_label "${HOME}/.zshrc" false)
        ZSH_ROOT_STATUS=$(get_status_label "${ROOT_HOME}/.zshrc" true)

        VIM_USER_STATUS=$(get_status_label "${HOME}/.vimrc" false)
        VIM_ROOT_STATUS=$(get_status_label "${ROOT_HOME}/.vimrc" true)

        TMUX_USER_STATUS=$(get_status_label "${HOME}/.tmux.conf" false)
        TMUX_ROOT_STATUS=$(get_status_label "${ROOT_HOME}/.tmux.conf" true)

        if [ -f "${HOME}/.local/bin/fzf" ] || [ -f "${HOME}/.fzf/bin/fzf" ] || command -v fzf >/dev/null 2>&1; then
            FZF_USER_STATUS="${GREEN}[INSTALLED]${NC}"
        else
            FZF_USER_STATUS="${RED}[NOT INSTALLED]${NC}"
        fi

        if sudo [ -f "${ROOT_HOME}/.local/bin/fzf" ] 2>/dev/null || sudo [ -f "${ROOT_HOME}/.fzf/bin/fzf" ] 2>/dev/null || sudo sh -c 'command -v fzf' >/dev/null 2>&1; then
            FZF_ROOT_STATUS="${GREEN}[INSTALLED]${NC}"
        else
            FZF_ROOT_STATUS="${RED}[NOT INSTALLED]${NC}"
        fi
    fi

    # Print Title ASCII Art
    echo -e "${CYAN}  ____                 ___               _  _         "
    echo -e " |  _ \\  _____   __   / _ \\ _ __  ___   | || |__  ___ "
    echo -e " | | | |/ _ \\ \\ / /  | | | | '_ \\/ _ \\  | || '_ \\/ __|"
    echo -e " | |_| |  __/\\ V /   | |_| | |_) \\__ \\  | || |_) \\__ \\"
    echo -e " |____/ \\___| \\_/     \\___/| .__/|___/  |_||_.__/|___/"
    echo -e "                           |_|                        ${NC}"
    echo -e "${PURPLE}               DEVOPS-N00BS TERMINAL SUITE (${VERSION})${NC}"
    echo -e "${BLUE}               Created by: @devops-n00bs | Repo: zsh_devops-n00bs${NC}"
    echo -e "${BLUE}================================================================================${NC}"
    echo -e "${YELLOW} SYSTEM DIAGNOSTICS:${NC}"
    echo -e "   * Operating System : ${GREEN}${OS_NAME}${NC}"
    echo -e "   * CPU Architecture : ${CYAN}${CPU_ARCH}${NC}"
    if [ "$(id -u)" -eq 0 ]; then
        echo -e "   * Active User      : ${GREEN}${ACTIVE_USER}${NC} (${USER_ENV})"
    else
        echo -e "   * Active User      : ${GREEN}${ACTIVE_USER}${NC} (Sudo: ${SUDO_STATUS})"
    fi
    echo -e "   * Current Shell    : ${YELLOW}${CURRENT_SHELL}${NC}"
    echo -e "${BLUE}================================================================================${NC}"
    echo -e "${YELLOW} MODULE STATUS:${NC}"
    if [ "$(id -u)" -eq 0 ]; then
        echo -e "   [1] Zsh Shell & Starship Prompt  : Root: ${ZSH_ROOT_STATUS}"
        echo -e "   [2] Vim & Neovim Configurations  : Root: ${VIM_ROOT_STATUS}"
        echo -e "   [3] Tmux Premium Layout          : Root: ${TMUX_ROOT_STATUS}"
        echo -e "   [4] FZF (Fuzzy Finder) Module    : Root: ${FZF_ROOT_STATUS}"
    else
        echo -e "   [1] Zsh Shell & Starship Prompt  : User: ${ZSH_USER_STATUS} / Root: ${ZSH_ROOT_STATUS}"
        echo -e "   [2] Vim & Neovim Configurations  : User: ${VIM_USER_STATUS} / Root: ${VIM_ROOT_STATUS}"
        echo -e "   [3] Tmux Premium Layout          : User: ${TMUX_USER_STATUS} / Root: ${TMUX_ROOT_STATUS}"
        echo -e "   [4] FZF (Fuzzy Finder) Module    : User: ${FZF_USER_STATUS} / Root: ${FZF_ROOT_STATUS}"
    fi
    echo -e "${BLUE}================================================================================${NC}"
    echo -e "${YELLOW} ABOUT THIS SUITE:${NC}"
    echo -e "   Automates deployment of a high-performance, keyboard-driven terminal environment."
    echo -e "   Features native clipboard sync, custom statusline, and zero font dependencies."
    echo -e "${BLUE}================================================================================${NC}"
    echo -e "${YELLOW} ACTIONS MENU:${NC}"
    echo -e "   ${GREEN}1)${NC} Install / Update Zsh & Starship Prompt"
    echo -e "   ${GREEN}2)${NC} Install / Update Vim / Neovim Configuration"
    echo -e "   ${GREEN}3)${NC} Install / Update Tmux Premium Layout & Clipboard"
    echo -e "   ${GREEN}4)${NC} Install / Update FZF (Fuzzy Finder) & Zsh Integration"
    echo -e "   ${GREEN}5)${NC} Install / Update ALL Modules (Zsh, Vim, Tmux, FZF)"
    echo -e "   ${RED}6)${NC} Uninstall / Revert to Default"
    echo -e "   ${YELLOW}7)${NC} Exit"
    echo -e "${BLUE}================================================================================${NC}"

    # Read input directly from tty to support curl pipe execution
    read -r -p "Enter your choice [1-7]: " CHOICE < /dev/tty

    case "$CHOICE" in
        1)
            if ! bash "${SCRIPT_DIR}/scripts/install_zsh.sh"; then
                warn "Zsh & Starship installation encountered an error."
            fi
            ;;
        2)
            if ! bash "${SCRIPT_DIR}/scripts/install_vim.sh"; then
                warn "Vim/Neovim installation encountered an error."
            fi
            ;;
        3)
            if ! bash "${SCRIPT_DIR}/scripts/install_tmux.sh"; then
                warn "Tmux installation encountered an error."
            fi
            ;;
        4)
            if ! bash "${SCRIPT_DIR}/scripts/install_fzf.sh"; then
                warn "FZF installation encountered an error."
            fi
            ;;
        5)
            info "=== STARTING FULL INSTALLATION (ALL MODULES) ==="
            local err=0
            bash "${SCRIPT_DIR}/scripts/install_zsh.sh" || err=1
            bash "${SCRIPT_DIR}/scripts/install_vim.sh" || err=1
            bash "${SCRIPT_DIR}/scripts/install_tmux.sh" || err=1
            bash "${SCRIPT_DIR}/scripts/install_fzf.sh" || err=1
            if [ $err -eq 0 ]; then
                success "All modules successfully installed!"
            else
                warn "One or more modules encountered an error during installation."
            fi
            ;;
        6)
            if ! bash "${SCRIPT_DIR}/scripts/uninstall.sh"; then
                warn "Uninstallation encountered an error."
            fi
            ;;
        7)
            info "Exiting setup manager. Goodbye!"
            exit 0
            ;;
        *)
            warn "Invalid choice. Please choose a valid menu option."
            sleep 2
            continue
            ;;
    esac

    echo ""
    read -r -p "Press Enter to return to the main menu..." < /dev/tty
done
