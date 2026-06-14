#!/usr/bin/env bash

# ==============================================================================
# UNINSTALL / RESTORE ZSH CONFIGURATION
# Reverts changes made by the installer script
# ==============================================================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

info() { echo -e "${BLUE}[INFO]${NC} $*"; }
warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
success() { echo -e "${GREEN}[SUCCESS]${NC} $*"; }

# 1. Restore .zshrc
info "Mengembalikan konfigurasi .zshrc..."
if [ -f "${HOME}/.zshrc.bak" ]; then
    mv "${HOME}/.zshrc.bak" "${HOME}/.zshrc"
    success "Mengembalikan file ~/.zshrc dari cadangan ~/.zshrc.bak"
else
    if [ -f "${HOME}/.zshrc" ]; then
        rm "${HOME}/.zshrc"
        success "Menghapus ~/.zshrc karena tidak ada cadangan (.zshrc.bak) sebelumnya."
    else
        info "~/.zshrc sudah bersih."
    fi
fi

# 2. Restore starship.toml
info "Mengembalikan konfigurasi Starship..."
if [ -f "${HOME}/.config/starship.toml.bak" ]; then
    mv "${HOME}/.config/starship.toml.bak" "${HOME}/.config/starship.toml"
    success "Mengembalikan file ~/.config/starship.toml dari cadangan ~/.config/starship.toml.bak"
else
    if [ -f "${HOME}/.config/starship.toml" ]; then
        rm "${HOME}/.config/starship.toml"
        success "Menghapus ~/.config/starship.toml."
    fi
fi

# 3. Clean up plugins
info "Membersihkan plugin..."
if [ -d "${HOME}/.zsh/plugins" ]; then
    rm -rf "${HOME}/.zsh/plugins"
    success "Menghapus folder plugin ~/.zsh/plugins"
fi

# 4. Suggest shell change back to bash
CURRENT_SHELL=$(basename "$SHELL")
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS default shell is zsh since Catalina, so usually no need to change
    info "Di macOS, shell default adalah zsh."
else
    # Linux / WSL
    if [ "$CURRENT_SHELL" = "zsh" ] && command -v bash &> /dev/null; then
        warn "Shell aktif saat ini adalah Zsh."
        echo -e "${YELLOW}Untuk kembali menggunakan bash sebagai shell default, jalankan:${NC}"
        echo -e "  chsh -s \$(which bash)"
    fi
fi

echo -e "\n${GREEN}Pembersihan/Pengembalian selesai! Silakan buka kembali terminal Anda atau reload shell.${NC}\n"
