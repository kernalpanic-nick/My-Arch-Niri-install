#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${GREEN}=== Niri Setup Installer ===${NC}\n"

# Check if running on Arch Linux
if [ ! -f /etc/arch-release ]; then
    echo -e "${RED}Error: This script is designed for Arch Linux${NC}"
    exit 1
fi

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Install AUR helper if not present
install_aur_helper() {
    if command_exists paru; then
        echo -e "${GREEN}paru is already installed${NC}"
        AUR_HELPER="paru"
    elif command_exists yay; then
        echo -e "${GREEN}yay is already installed${NC}"
        AUR_HELPER="yay"
    else
        echo -e "${YELLOW}Installing paru AUR helper...${NC}"
        sudo pacman -S --needed --noconfirm base-devel git
        cd /tmp
        git clone https://aur.archlinux.org/paru.git
        cd paru
        makepkg -si --noconfirm
        cd "$SCRIPT_DIR"
        AUR_HELPER="paru"
    fi
}

# Install official packages
install_official_packages() {
    echo -e "\n${YELLOW}Installing official repository packages...${NC}"

    if [ ! -f "$SCRIPT_DIR/packages-official.txt" ]; then
        echo -e "${YELLOW}packages-official.txt not found, skipping${NC}"
        return 0
    fi

    # Read packages, skip comments and empty lines
    packages=$(grep -v '^#' "$SCRIPT_DIR/packages-official.txt" | grep -v '^$' | tr '\n' ' ')

    if [ -n "$packages" ]; then
        echo -e "${GREEN}Installing official packages...${NC}"
        sudo pacman -S --needed --noconfirm $packages
    fi
}

# Install AUR packages
install_aur_packages() {
    echo -e "\n${YELLOW}Installing AUR packages...${NC}"

    if [ ! -f "$SCRIPT_DIR/packages-aur.txt" ]; then
        echo -e "${YELLOW}packages-aur.txt not found, skipping${NC}"
        return 0
    fi

    # Read packages, skip comments and empty lines
    packages=$(grep -v '^#' "$SCRIPT_DIR/packages-aur.txt" | grep -v '^$' | tr '\n' ' ')

    if [ -n "$packages" ]; then
        echo -e "${GREEN}Installing AUR packages...${NC}"
        $AUR_HELPER -S --needed --noconfirm $packages
    fi
}

# Install flatpak applications
install_flatpaks() {
    echo -e "\n${YELLOW}Installing flatpak applications...${NC}"

    if ! command_exists flatpak; then
        echo -e "${YELLOW}Flatpak not installed, skipping flatpak applications${NC}"
        return 0
    fi

    if [ ! -f "$SCRIPT_DIR/flatpaks.txt" ]; then
        echo -e "${YELLOW}flatpaks.txt not found, skipping${NC}"
        return 0
    fi

    # Add flathub repository if not already added
    flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

    # Read flatpak IDs, skip comments and empty lines
    while IFS= read -r app; do
        if [[ ! "$app" =~ ^# ]] && [[ -n "$app" ]]; then
            echo -e "${GREEN}Installing: $app${NC}"
            flatpak install -y flathub "$app" || echo -e "${YELLOW}Failed to install $app, continuing...${NC}"
        fi
    done < "$SCRIPT_DIR/flatpaks.txt"
}

# Create symlinks for config files
setup_symlinks() {
    echo -e "\n${YELLOW}Setting up configuration symlinks...${NC}"

    # Backup existing config if it exists
    if [ -d "$HOME/.config/niri" ] && [ ! -L "$HOME/.config/niri" ]; then
        backup_dir="$HOME/.config/niri.backup.$(date +%Y%m%d_%H%M%S)"
        echo -e "${YELLOW}Backing up existing config to: $backup_dir${NC}"
        mv "$HOME/.config/niri" "$backup_dir"
    elif [ -L "$HOME/.config/niri" ]; then
        echo -e "${YELLOW}Removing old symlink${NC}"
        rm "$HOME/.config/niri"
    fi

    # Create .config directory if it doesn't exist
    mkdir -p "$HOME/.config"

    # Symlink niri config
    ln -sf "$SCRIPT_DIR/.config/niri" "$HOME/.config/niri"
    echo -e "${GREEN}✓ Linked niri config${NC}"
}

# Main installation
main() {
    echo "This will install niri and related packages, then symlink configs."
    read -p "Continue? [y/N] " -n 1 -r
    echo

    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Installation cancelled"
        exit 0
    fi

    install_aur_helper
    install_official_packages
    install_aur_packages
    install_flatpaks
    setup_symlinks

    echo -e "\n${GREEN}=== Installation Complete! ===${NC}"
    echo -e "\nTo start niri:"
    echo -e "  1. Log out of your current session"
    echo -e "  2. Select 'niri' from your display manager"
    echo -e "  Or run: ${YELLOW}niri${NC} from a TTY"
    echo -e "\nConfig location: ${YELLOW}~/.config/niri${NC}"
}

main
