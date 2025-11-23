#!/bin/bash
#
# Niri Setup Installer for CachyOS/Arch Linux
#
# This script installs:
# - 202 official repository packages (including Niri, Wayland essentials)
# - Hardware-specific drivers (GPU/CPU, automatically detected!)
# - 4 AUR packages (including dms-shell-git)
# - 14 flatpak applications
# - Niri window manager configuration with DMS integration (no hardcoded monitors)
#
# Requirements: CachyOS or Arch Linux with internet connection
#
# Features:
# - Automatic hardware detection (CPU: AMD/Intel, GPU: NVIDIA/AMD/Intel)
# - Automatic driver installation with user confirmation
# - Idempotent - safe to run multiple times
#
# NOTE: Monitors will be automatically configured on first niri login!
#       Use Mod+Shift+M to manually reconfigure monitors anytime.
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${GREEN}=== Niri Setup Installer ===${NC}\n"

# Check if running on Arch Linux or CachyOS
if [ ! -f /etc/arch-release ]; then
    echo -e "${RED}Error: This script is designed for Arch Linux / CachyOS${NC}"
    exit 1
fi

# Detect if running CachyOS
if [ -f /etc/cachyos-release ]; then
    echo -e "${GREEN}Detected CachyOS${NC}"
    CACHYOS=true
else
    echo -e "${YELLOW}Detected Arch Linux${NC}"
    CACHYOS=false
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

# Detect CPU vendor
detect_cpu() {
    local cpu_vendor=$(grep -m1 "vendor_id" /proc/cpuinfo | awk '{print $3}')

    case "$cpu_vendor" in
        AuthenticAMD)
            echo "amd"
            ;;
        GenuineIntel)
            echo "intel"
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

# Detect GPU vendors
detect_gpus() {
    local gpus=""

    # Check for NVIDIA
    if lspci | grep -i "vga\|3d" | grep -iq "nvidia"; then
        gpus="$gpus nvidia"
    fi

    # Check for AMD
    if lspci | grep -i "vga\|3d" | grep -iq "amd\|radeon"; then
        gpus="$gpus amd"
    fi

    # Check for Intel
    if lspci | grep -i "vga\|3d" | grep -iq "intel"; then
        gpus="$gpus intel"
    fi

    echo "$gpus"
}

# Build hardware package list
build_hardware_packages() {
    local packages=""
    local cpu=$(detect_cpu)
    local gpus=$(detect_gpus)

    # Add CPU microcode
    case "$cpu" in
        amd)
            packages="$packages amd-ucode"
            ;;
        intel)
            packages="$packages intel-ucode"
            ;;
    esac

    # Add GPU drivers
    for gpu in $gpus; do
        case "$gpu" in
            nvidia)
                packages="$packages nvidia-utils lib32-nvidia-utils opencl-nvidia lib32-opencl-nvidia"
                packages="$packages libva-nvidia-driver nvidia-settings"
                packages="$packages linux-cachyos-nvidia-open linux-cachyos-lts-nvidia-open"
                ;;
            amd)
                packages="$packages vulkan-radeon lib32-vulkan-radeon xf86-video-amdgpu"
                ;;
            intel)
                packages="$packages vulkan-intel lib32-vulkan-intel intel-media-driver libva-intel-driver"
                ;;
        esac
    done

    echo "$packages"
}

# Install hardware-specific packages
install_hardware_packages() {
    echo -e "\n${YELLOW}Detecting hardware...${NC}"

    local cpu=$(detect_cpu)
    local gpus=$(detect_gpus)

    echo -e "${GREEN}CPU:${NC} $cpu"
    echo -e "${GREEN}GPU(s):${NC} $gpus"

    # Build package list
    local packages=$(build_hardware_packages)

    if [ -z "$packages" ]; then
        echo -e "${YELLOW}No hardware-specific packages detected.${NC}"
        echo -e "${YELLOW}Hardware detection may have failed. You can manually edit packages-hardware.txt${NC}"
        return 0
    fi

    echo -e "\n${GREEN}Will install the following hardware drivers:${NC}"
    echo "$packages" | tr ' ' '\n' | sed 's/^/  - /'

    echo -e "\n${YELLOW}Install these drivers automatically?${NC}"
    read -p "Continue? [Y/n] " -n 1 -r
    echo

    if [[ $REPLY =~ ^[Nn]$ ]]; then
        echo -e "${YELLOW}Skipping hardware drivers. Edit packages-hardware.txt to install manually.${NC}"
        return 0
    fi

    echo -e "${GREEN}Installing hardware-specific packages...${NC}"
    sudo pacman -S --needed --noconfirm $packages
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
    install_hardware_packages
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
