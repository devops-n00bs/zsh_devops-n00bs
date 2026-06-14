#!/usr/bin/env bash

# ==============================================================================
# AUTOMATIC ZSH CONFIGURATION MANAGER (Interactive Menu)
# Works on macOS, WSL, and Linux Server
# ==============================================================================

# Exit on error, undefined variables, and pipe failures
set -euo pipefail

# Configuration
GITHUB_USER="devops-n00bs" # Username GitHub Anda
GITHUB_REPO="zsh_devops-n00bs"
BRANCH="main"
RAW_URL="https://raw.githubusercontent.com/${GITHUB_USER}/${GITHUB_REPO}/${BRANCH}"

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

# Function: Install or Update Configuration
do_install() {
    echo ""
    info "=== MEMULAI INSTALASI / PEMBARUAN ==="
    
    # 1. Detect environment & dependencies
    info "Memeriksa dependensi..."
    MISSING_DEPS=()
    for cmd in git curl zsh; do
        if ! command -v "$cmd" &> /dev/null; then
            MISSING_DEPS+=("$cmd")
        fi
    done

    if [ ${#MISSING_DEPS[@]} -ne 0 ]; then
        warn "Dependensi berikut belum terinstal: ${MISSING_DEPS[*]}"
        info "Mencoba menginstal dependensi secara otomatis..."
        
        # Tentukan apakah perlu sudo
        SUDO=""
        if [ "$(id -u)" -ne 0 ]; then
            SUDO="sudo"
        fi
        
        # Deteksi Sistem Operasi / Package Manager
        if [[ "$OSTYPE" == "darwin"* ]]; then
            if ! command -v brew &> /dev/null; then
                error "Homebrew tidak ditemukan. Harap instal Homebrew terlebih dahulu atau pasang dependensi secara manual."
            fi
            info "Menginstal via Homebrew..."
            brew install "${MISSING_DEPS[@]}"
        elif [ -f /etc/debian_version ]; then
            info "Menginstal via apt-get..."
            $SUDO apt-get update
            $SUDO apt-get install -y "${MISSING_DEPS[@]}"
        elif [ -f /etc/redhat-release ] || [ -f /etc/system-release ]; then
            info "Menginstal via dnf/yum..."
            if command -v dnf &> /dev/null; then
                $SUDO dnf install -y "${MISSING_DEPS[@]}"
            else
                $SUDO yum install -y "${MISSING_DEPS[@]}"
            fi
        elif [ -f /etc/arch-release ]; then
            info "Menginstal via pacman..."
            $SUDO pacman -Syu --noconfirm "${MISSING_DEPS[@]}"
        else
            error "Sistem operasi tidak didukung untuk instalasi otomatis. Harap pasang secara manual: ${MISSING_DEPS[*]}"
        fi
        success "Dependensi berhasil diinstal."
    else
        info "Semua dependensi dasar terpenuhi."
    fi

    # 2. Install Starship Prompt
    if ! command -v starship &> /dev/null; then
        info "Menginstal Starship Prompt..."
        curl -sS https://starship.rs/install.sh | sh -s -- --yes
        success "Starship berhasil diinstal."
    else
        info "Starship sudah terinstal."
    fi

    # 3. Setup plugin directory and download plugins
    PLUGIN_DIR="${HOME}/.zsh/plugins"
    info "Mengatur plugin Zsh..."
    mkdir -p "${PLUGIN_DIR}"

    # Helper to clone or update plugins
    setup_plugin() {
        local name=$1
        local url=$2
        local path="${PLUGIN_DIR}/${name}"
        
        if [ -d "$path" ]; then
            info "Memperbarui plugin ${name}..."
            git -C "$path" pull
        else
            info "Mengunduh plugin ${name}..."
            git clone --depth 1 "$url" "$path"
        fi
    }

    setup_plugin "zsh-autosuggestions" "https://github.com/zsh-users/zsh-autosuggestions.git"
    setup_plugin "zsh-syntax-highlighting" "https://github.com/zsh-users/zsh-syntax-highlighting.git"

    # 4. Install configuration files
    info "Menerapkan file konfigurasi..."

    # Setup .zshrc
    if [ -f "${HOME}/.zshrc" ] && [ ! -f "${HOME}/.zshrc.bak" ]; then
        warn "Menemukan file ~/.zshrc yang sudah ada. Membuat cadangan di ~/.zshrc.bak"
        mv "${HOME}/.zshrc" "${HOME}/.zshrc.bak"
    fi

    if [ "$IS_LOCAL" = true ]; then
        cp "${SCRIPT_DIR}/zshrc" "${HOME}/.zshrc"
    else
        info "Mengunduh file zshrc dari GitHub..."
        curl -fsSL "${RAW_URL}/zshrc?v=$(date +%s)" -o "${HOME}/.zshrc"
    fi

    # Setup starship.toml
    mkdir -p "${HOME}/.config"
    if [ -f "${HOME}/.config/starship.toml" ] && [ ! -f "${HOME}/.config/starship.toml.bak" ]; then
        warn "Menemukan file ~/.config/starship.toml yang sudah ada. Membuat cadangan di ~/.config/starship.toml.bak"
        mv "${HOME}/.config/starship.toml" "${HOME}/.config/starship.toml.bak"
    fi

    if [ "$IS_LOCAL" = true ]; then
        cp "${SCRIPT_DIR}/starship.toml" "${HOME}/.config/starship.toml"
    else
        info "Mengunduh file starship.toml dari GitHub..."
        curl -fsSL "${RAW_URL}/starship.toml?v=$(date +%s)" -o "${HOME}/.config/starship.toml"
    fi

    success "Konfigurasi Zsh dan Starship telah diterapkan!"

    # 5. Suggest shell change
    CURRENT_SHELL=$(basename "$SHELL")
    if [ "$CURRENT_SHELL" != "zsh" ]; then
        warn "Shell saat ini adalah ${CURRENT_SHELL}."
        echo -e "${YELLOW}Jalankan perintah berikut untuk mengubah default shell Anda menjadi zsh:${NC}"
        echo -e "  chsh -s \$(which zsh)"
    fi

    echo -e "\n${GREEN}Instalasi selesai! Silakan buka kembali terminal Anda atau jalankan:${NC}"
    echo -e "  exec zsh\n"
}

# Function: Uninstall / Restore Configuration
do_uninstall() {
    echo ""
    info "=== MEMULAI PEMBERSIHAN TOTAL (UNINSTALL) ==="
    
    # 1. Remove Zsh configuration and backups
    info "Menghapus file konfigurasi Zsh..."
    for file in "${HOME}/.zshrc" "${HOME}/.zshrc.bak"; do
        if [ -f "$file" ]; then
            rm -f "$file"
            success "Menghapus $file"
        fi
    done

    # 2. Remove Starship configuration and backups
    info "Menghapus konfigurasi Starship..."
    for file in "${HOME}/.config/starship.toml" "${HOME}/.config/starship.toml.bak"; do
        if [ -f "$file" ]; then
            rm -f "$file"
            success "Menghapus $file"
        fi
    done

    # 3. Clean up plugins and entire .zsh directory
    info "Membersihkan seluruh folder plugin dan folder ~/.zsh..."
    if [ -d "${HOME}/.zsh" ]; then
        rm -rf "${HOME}/.zsh"
        success "Menghapus folder ~/.zsh"
    fi

    # 4. Automatically try to revert default shell to bash
    CURRENT_SHELL=$(basename "$SHELL")
    if [[ "$OSTYPE" == "darwin"* ]]; then
        info "Di macOS, shell default standar adalah zsh. Tidak perlu diubah ke bash."
    else
        if command -v bash &> /dev/null; then
            info "Mengubah default shell kembali ke bash..."
            BASH_PATH=$(which bash)
            if [ "$CURRENT_SHELL" = "zsh" ]; then
                # Ganti shell secara interaktif (bisa meminta password user)
                if chsh -s "$BASH_PATH" < /dev/tty; then
                    success "Default shell berhasil dikembalikan ke bash ($BASH_PATH)."
                else
                    warn "Gagal mengubah shell secara otomatis. Silakan jalankan manual: chsh -s $BASH_PATH"
                fi
            else
                info "Shell default saat ini bukan zsh ($CURRENT_SHELL), tidak perlu mengubah shell."
            fi
        fi
    fi

    echo -e "\n${GREEN}Pembersihan selesai! Semua file kustom telah dihapus bersih seperti semula.${NC}"
    echo -e "${YELLOW}Silakan restart terminal atau buka sesi terminal baru untuk melihat efeknya.${NC}\n"
}

# Interactive Menu Loop
clear
echo -e "${PURPLE}==================================================${NC}"
echo -e "${CYAN}           ZSH & STARSHIP SETUP MANAGER           ${NC}"
echo -e "${PURPLE}==================================================${NC}"
echo -e "Silakan pilih tindakan yang ingin Anda lakukan:"
echo -e "  ${GREEN}1)${NC} Pasang / Perbarui Konfigurasi (Install/Update)"
echo -e "  ${RED}2)${NC} Hapus Konfigurasi / Kembali ke Default (Uninstall)"
echo -e "  ${YELLOW}3)${NC} Keluar (Exit)"
echo -e "${PURPLE}==================================================${NC}"

# Read input directly from tty to support curl execution
read -r -p "Masukkan pilihan Anda [1-3]: " CHOICE < /dev/tty

case "$CHOICE" in
    1)
        do_install
        ;;
    2)
        do_uninstall
        ;;
    3)
        info "Keluar dari setup manager. Tidak ada perubahan yang dibuat."
        exit 0
        ;;
    *)
        error "Pilihan tidak valid. Silakan jalankan kembali script."
        ;;
esac
