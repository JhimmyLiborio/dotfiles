#!/usr/bin/env bash
# setup.sh - Dotfiles installation script
# Works on Arch Linux and Ubuntu/Debian
# Repository: https://github.com/JhimmyLiborio/dotfiles

set -euo pipefail

DOTFILES_REPO="https://github.com/JhimmyLiborio/dotfiles.git"
DOTFILES_DIR="$HOME/.dotfiles"
CONFIG_BACKUP_DIR="$HOME/.config-backup-$(date +%Y%m%d-%H%M%S)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

info()  { echo -e "${BLUE}[INFO]${NC} $1"; }
ok()    { echo -e "${GREEN}[OK]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO="${ID:-unknown}"
    else
        error "Cannot detect distribution. /etc/os-release not found."
    fi

    case "$DISTRO" in
        arch|manjaro|endeavouros)
            PKG_MANAGER="pacman"
            ;;
        ubuntu|debian|linuxmint|pop)
            PKG_MANAGER="apt"
            ;;
        fedora)
            PKG_MANAGER="dnf"
            ;;
        *)
            warn "Unsupported distro: $DISTRO. Will try to continue..."
            PKG_MANAGER="unknown"
            ;;
    esac
    info "Detected distro: $DISTRO (package manager: $PKG_MANAGER)"
}

install_packages_pacman() {
    local packages=(
        git curl wget base-devel
        neovim tmux fzf bat
        ripgrep fd
    )

    sudo pacman -Syu --needed --noconfirm "${packages[@]}"
}

install_packages_apt() {
    sudo apt update
    sudo apt install -y \
        git curl wget build-essential \
        neovim tmux fzf bat \
        ripgrep fd-find
}

install_packages_dnf() {
    sudo dnf install -y \
        git curl wget gcc make \
        neovim tmux fzf bat \
        ripgrep fd-find
}

install_packages() {
    info "Installing packages..."
    case "$PKG_MANAGER" in
        pacman) install_packages_pacman ;;
        apt)    install_packages_apt ;;
        dnf)    install_packages_dnf ;;
        *)      warn "Manual installation required. Install: git curl wget neovim tmux fzf bat ripgrep fd" ;;
    esac
    ok "Packages installed"
}

install_zoxide() {
    if command -v zoxide &>/dev/null; then
        ok "zoxide already installed"
        return
    fi
    info "Installing zoxide..."
    curl -sS https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | bash
    ok "zoxide installed"
}

install_tmux_sessionizer() {
    if command -v tmux-sessionizer &>/dev/null; then
        ok "tmux-sessionizer already installed"
        return
    fi

    if command -v cargo &>/dev/null; then
        info "Installing tmux-sessionizer via cargo..."
        cargo install tmux-sessionizer
        ok "tmux-sessionizer installed"
    else
        warn "cargo not found. Install Rust first: https://rustup.rs"
        warn "Then run: cargo install tmux-sessionizer"
    fi
}

install_kanata() {
    if command -v kanata &>/dev/null; then
        ok "kanata already installed"
        return
    fi

    info "Installing kanata..."
    if [ "$PKG_MANAGER" = "pacman" ]; then
        sudo pacman -S --needed --noconfirm kanata
    else
        local KANATA_VERSION="1.12.0"
        local ARCH=$(uname -m)
        local KANATA_URL="https://github.com/jtroo/kanata/releases/download/v${KANATA_VERSION}/kanata-v${KANATA_VERSION}-linux-${ARCH}.tar.gz"
        mkdir -p "$HOME/.bin"
        curl -sL "$KANATA_URL" | tar xz -C "$HOME/.bin"
        chmod +x "$HOME/.bin/kanata"
    fi
    ok "kanata installed"
}

setup_bare_repo() {
    if [ -d "$DOTFILES_DIR" ]; then
        ok "Bare repo already exists at $DOTFILES_DIR"
        return
    fi

    info "Cloning dotfiles as bare repo..."
    git clone --bare "$DOTFILES_REPO" "$DOTFILES_DIR"

    # Define the dotfiles alias globally
    echo 'alias dotfiles="git --git-dir=$HOME/.dotfiles --work-tree=$HOME"' >> "$HOME/.bashrc"

    ok "Bare repo cloned"
}

checkout_configs() {
    info "Checking out dotfiles..."

    # Backup existing configs
    mkdir -p "$CONFIG_BACKUP_DIR"
    local files=(
        ".bashrc"
        ".bash_profile"
        ".bash_logout"
        ".config/kanata/config.kbd"
        ".config/nvim/init.lua"
        ".config/tmux/tmux.conf"
        ".config/tmux-sessionizer/tmux-sessionizer.conf"
    )

    for file in "${files[@]}"; do
        if [ -e "$HOME/$file" ]; then
            mkdir -p "$CONFIG_BACKUP_DIR/$(dirname "$file")"
            cp "$HOME/$file" "$CONFIG_BACKUP_DIR/$file" 2>/dev/null || true
        fi
    done

    # Checkout using bare repo (skip errors for existing files)
    cd "$HOME"
    git --git-dir="$DOTFILES_DIR" --work-tree="$HOME" checkout main 2>&1 || {
        warn "Some files may already exist. Backing up and retrying..."
        for file in "${files[@]}"; do
            if [ -e "$HOME/$file" ] && [ ! -L "$HOME/$file" ]; then
                rm -f "$HOME/$file"
            fi
        done
        git --git-dir="$DOTFILES_DIR" --work-tree="$HOME" checkout main
    }

    # Hide untracked files from dotfiles status
    git --git-dir="$DOTFILES_DIR" --work-tree="$HOME" config --local status.showUntrackedFiles no

    ok "Configs checked out"
}

setup_kanata_service() {
    if [ "$PKG_MANAGER" = "pacman" ] && systemctl --user is-enabled kanata &>/dev/null 2>&1; then
        ok "kanata service already active"
        return
    fi

    local SERVICE_DIR="$HOME/.config/systemd/user"
    mkdir -p "$SERVICE_DIR"

    if [ ! -f "$SERVICE_DIR/kanata.service" ]; then
        cat > "$SERVICE_DIR/kanata.service" << 'EOF'
[Unit]
Description=Kanata keyboard remapper
After=graphical-session.target

[Service]
ExecStart=%h/.bin/kanata --cfg %h/.config/kanata/config.kbd
Restart=on-failure
RestartSec=5

[Install]
WantedBy=default.target
EOF
    fi

    # Enable uinput and input groups
    if ! groups "$USER" | grep -q uinput; then
        info "Adding user to uinput group..."
        sudo groupadd -f uinput
        sudo usermod -aG uinput "$USER"
        ok "Added to uinput group"
    fi

    if ! groups "$USER" | grep -q input; then
        info "Adding user to input group..."
        sudo usermod -aG input "$USER"
        ok "Added to input group"
    fi

    # Create udev rule if not exists
    if [ ! -f /etc/udev/rules.d/99-uinput.rules ]; then
        echo 'KERNEL=="uinput", MODE="0660", GROUP="uinput"' | sudo tee /etc/udev/rules.d/99-uinput.rules > /dev/null
        sudo udevadm control --reload-rules
        sudo udevadm trigger
    fi

    # Enable and start service
    systemctl --user daemon-reload
    systemctl --user enable kanata
    systemctl --user start kanata

    ok "kanata service configured"
}

print_summary() {
    echo ""
    echo -e "${GREEN}============================================${NC}"
    echo -e "${GREEN}  Dotfiles installation complete!${NC}"
    echo -e "${GREEN}============================================${NC}"
    echo ""
    echo "Installed configs:"
    echo "  - .bashrc, .bash_profile, .bash_logout"
    echo "  - nvim   -> ~/.config/nvim/init.lua"
    echo "  - tmux   -> ~/.config/tmux/tmux.conf"
    echo "  - kanata -> ~/.config/kanata/config.kbd"
    echo "  - tmux-sessionizer -> ~/.config/tmux-sessionizer/"
    echo ""
    echo "Config backups saved to: $CONFIG_BACKUP_DIR"
    echo ""
    echo "Next steps:"
    echo "  1. Log out and back in (for group changes to take effect)"
    echo "  2. Install tmux-sessionizer: cargo install tmux-sessionizer"
    echo "  3. Edit ~/.config/tmux-sessionizer/tmux-sessionizer.conf"
    echo "     to match your project directories"
    echo ""
    echo "Dotfiles alias: dotfiles status"
    echo ""
    warn "Reboot recommended to apply uinput/input group changes"
}

main() {
    echo -e "${GREEN}Dotfiles Setup - JhimmyLiborio${NC}"
    echo "============================================"
    echo ""

    detect_distro
    install_packages
    install_zoxide
    install_tmux_sessionizer
    install_kanata
    setup_bare_repo
    checkout_configs
    setup_kanata_service
    print_summary
}

main "$@"
