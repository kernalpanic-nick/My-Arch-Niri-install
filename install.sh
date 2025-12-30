#!/bin/bash
#
# Niri Setup Installer for CachyOS/Arch Linux
#
# This script installs:
# - 201 official repository packages (including Niri, Wayland essentials)
# - Hardware-specific drivers (GPU/CPU, automatically detected!)
# - 3 AUR packages (including dms-shell-git)
# - 14 flatpak applications
# - Niri window manager configuration with DMS integration (no hardcoded settings)
#
# Requirements: CachyOS or Arch Linux with internet connection
#
# Features:
# - Automatic hardware detection (CPU: AMD/Intel, GPU: NVIDIA/AMD/Intel)
# - Automatic driver installation with user confirmation
# - Idempotent - safe to run multiple times
# - Continues on non-critical errors
#
# NOTE: Monitors will be automatically configured on first niri login!
#       Use Mod+Shift+M to manually reconfigure monitors anytime.
#

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Error tracking
INSTALL_LOG="$SCRIPT_DIR/install.log"
FAILED_PACKAGES=()
WARNINGS=()

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

    # Read packages one by one, skip comments and empty lines
    local aur_count=0
    local aur_failed=0

    while IFS= read -r package; do
        # Skip empty lines and comments
        [[ -z "$package" || "$package" =~ ^# ]] && continue

        aur_count=$((aur_count + 1))
        echo -e "${BLUE}[$aur_count] Installing: $package${NC}"

        if $AUR_HELPER -S --needed --noconfirm "$package" >> "$INSTALL_LOG" 2>&1; then
            echo -e "${GREEN}✓ $package installed successfully${NC}"
        else
            echo -e "${RED}✗ Failed to install $package${NC}"
            FAILED_PACKAGES+=("$package (AUR)")
            aur_failed=$((aur_failed + 1))
        fi
    done < "$SCRIPT_DIR/packages-aur.txt"

    if [ $aur_failed -gt 0 ]; then
        echo -e "${YELLOW}Warning: $aur_failed AUR package(s) failed to install${NC}"
        echo -e "${YELLOW}Check $INSTALL_LOG for details${NC}"
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
        WARNINGS+=("Flatpak not installed - skipped flatpak applications")
        return 0
    fi

    if [ ! -f "$SCRIPT_DIR/flatpaks.txt" ]; then
        echo -e "${YELLOW}flatpaks.txt not found, skipping${NC}"
        return 0
    fi

    # Add flathub repository if not already added
    flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo

    # Read flatpak IDs, skip comments and empty lines
    local flatpak_count=0
    local flatpak_failed=0

    while IFS= read -r app; do
        # Skip empty lines and comments
        [[ -z "$app" || "$app" =~ ^# ]] && continue

        flatpak_count=$((flatpak_count + 1))
        echo -e "${BLUE}[$flatpak_count] Installing: $app${NC}"

        if flatpak install -y flathub "$app" >> "$INSTALL_LOG" 2>&1; then
            echo -e "${GREEN}✓ $app installed successfully${NC}"
        else
            echo -e "${RED}✗ Failed to install $app${NC}"
            FAILED_PACKAGES+=("$app (flatpak)")
            flatpak_failed=$((flatpak_failed + 1))
        fi
    done < "$SCRIPT_DIR/flatpaks.txt"

    if [ $flatpak_failed -gt 0 ]; then
        echo -e "${YELLOW}Warning: $flatpak_failed flatpak(s) failed to install${NC}"
        echo -e "${YELLOW}Check $INSTALL_LOG for details${NC}"
    fi
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

# Enable greetd display manager with DMS greeter
enable_greetd() {
    echo -e "\n${YELLOW}Configuring greetd display manager with DMS greeter...${NC}"

    # Check if greetd is installed
    if ! command_exists greetd; then
        echo -e "${YELLOW}greetd not installed, skipping${NC}"
        return 0
    fi

    # Create greetd config directory
    sudo mkdir -p /etc/greetd

    # Copy greetd configuration
    if [ -f "$SCRIPT_DIR/etc/greetd/config.toml" ]; then
        sudo cp "$SCRIPT_DIR/etc/greetd/config.toml" /etc/greetd/
        echo -e "${GREEN}✓ Copied greetd configuration${NC}"
    fi

    if [ -f "$SCRIPT_DIR/etc/greetd/regreet.toml" ]; then
        sudo cp "$SCRIPT_DIR/etc/greetd/regreet.toml" /etc/greetd/
        echo -e "${GREEN}✓ Copied regreet configuration${NC}"
    fi

    # Create greeter user if it doesn't exist
    if ! id -u greeter >/dev/null 2>&1; then
        sudo useradd -M -G video greeter
        echo -e "${GREEN}✓ Created greeter user${NC}"
    fi

    # Enable greetd service
    echo -e "${GREEN}Enabling greetd to start at boot...${NC}"
    sudo systemctl enable greetd

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ greetd enabled successfully${NC}"
        echo -e "${YELLOW}greetd will start automatically on next boot${NC}"
    else
        echo -e "${RED}Failed to enable greetd${NC}"
        echo -e "${YELLOW}You can enable it manually with: sudo systemctl enable greetd${NC}"
    fi
}

# Deploy DMS configuration
deploy_dms_config() {
    echo -e "\n${YELLOW}Deploying DMS configuration...${NC}"

    # Create DMS config directory
    mkdir -p "$HOME/.config/DankMaterialShell/plugins"

    # Copy settings.json
    if [ -f "$SCRIPT_DIR/.config/DankMaterialShell/settings.json" ]; then
        cp "$SCRIPT_DIR/.config/DankMaterialShell/settings.json" "$HOME/.config/DankMaterialShell/"
        echo -e "${GREEN}✓ Copied DMS settings${NC}"
    fi

    # Copy plugin_settings.json
    if [ -f "$SCRIPT_DIR/.config/DankMaterialShell/plugin_settings.json" ]; then
        cp "$SCRIPT_DIR/.config/DankMaterialShell/plugin_settings.json" "$HOME/.config/DankMaterialShell/"
        echo -e "${GREEN}✓ Copied DMS plugin settings${NC}"
    fi

    # Copy plugins
    if [ -d "$SCRIPT_DIR/.config/DankMaterialShell/plugins" ]; then
        cp -r "$SCRIPT_DIR/.config/DankMaterialShell/plugins/"* "$HOME/.config/DankMaterialShell/plugins/" 2>/dev/null
        echo -e "${GREEN}✓ Copied DMS plugins${NC}"
    fi
}

# Deploy wallpapers
deploy_wallpapers() {
    echo -e "\n${YELLOW}Deploying desktop wallpapers...${NC}"

    # Create wallpaper directory
    mkdir -p "$HOME/Pictures/Wallpaper"

    # Copy wallpapers if they exist
    if [ -d "$SCRIPT_DIR/wallpapers" ]; then
        cp "$SCRIPT_DIR/wallpapers/"*.jpg "$HOME/Pictures/Wallpaper/" 2>/dev/null
        wallpaper_count=$(ls "$SCRIPT_DIR/wallpapers/"*.jpg 2>/dev/null | wc -l)
        if [ "$wallpaper_count" -gt 0 ]; then
            echo -e "${GREEN}✓ Copied $wallpaper_count wallpapers${NC}"
            echo -e "${YELLOW}Use Mod+Y to browse wallpapers in DMS${NC}"
        fi
    fi
}

# Detect ASUS laptop
detect_asus_laptop() {
    if [ -f /sys/class/dmi/id/sys_vendor ]; then
        vendor=$(cat /sys/class/dmi/id/sys_vendor)
        if [[ "$vendor" == *"ASUS"* ]]; then
            echo "asus"
        else
            echo "none"
        fi
    else
        echo "none"
    fi
}

# Install ASUS packages
install_asus_packages() {
    local laptop_type=$(detect_asus_laptop)

    if [ "$laptop_type" = "asus" ]; then
        echo -e "\n${GREEN}ASUS laptop detected!${NC}"
        echo -e "${YELLOW}Install ASUS-specific packages (asusctl, rog-control-center, supergfxctl)?${NC}"
        read -p "Continue? [Y/n] " -n 1 -r
        echo

        if [[ ! $REPLY =~ ^[Nn]$ ]]; then
            echo -e "${GREEN}Installing ASUS packages...${NC}"

            # Install from official repos
            sudo pacman -S --needed --noconfirm asusctl rog-control-center supergfxctl

            # Enable asusd service
            sudo systemctl enable asusd

            # Copy ASUS configuration if available
            if [ -f "$SCRIPT_DIR/etc/asusd/asusd.ron" ]; then
                echo -e "${YELLOW}Copy ASUS configuration template?${NC}"
                read -p "Continue? [y/N] " -n 1 -r
                echo

                if [[ $REPLY =~ ^[Yy]$ ]]; then
                    sudo cp "$SCRIPT_DIR/etc/asusd/asusd.ron" /etc/asusd/
                    echo -e "${GREEN}✓ Copied ASUS configuration${NC}"
                fi
            fi

            echo -e "${GREEN}✓ ASUS packages installed and configured${NC}"
        fi
    fi
}

# Prompt for hibernation setup
setup_hibernation_prompt() {
    echo -e "\n${YELLOW}=== Hibernation Setup ===${NC}"
    echo "Do you want to set up hibernation support?"
    echo ""
    echo -e "${RED}WARNING: This requires:${NC}"
    echo "  • LUKS-encrypted root filesystem"
    echo "  • Limine bootloader"
    echo "  • Sufficient free disk space (swap = RAM + 10% buffer)"
    echo "  • btrfs filesystem (recommended)"
    echo ""
    echo "This will create a swap file (sized to match your RAM) and modify boot configuration."
    echo ""
    read -p "Continue with hibernation setup? [y/N] " -n 1 -r
    echo

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        if [ -f "$SCRIPT_DIR/scripts/setup-hibernation.sh" ]; then
            echo -e "${GREEN}Running hibernation setup script...${NC}"
            sudo "$SCRIPT_DIR/scripts/setup-hibernation.sh"
        else
            echo -e "${RED}Error: Hibernation setup script not found${NC}"
            echo "Expected: $SCRIPT_DIR/scripts/setup-hibernation.sh"
        fi
    else
        echo -e "${YELLOW}Skipping hibernation setup${NC}"
        echo "You can run it manually later: sudo $SCRIPT_DIR/scripts/setup-hibernation.sh"
    fi
}

# Main installation
main() {
    # Initialize log file
    echo "Installation started at $(date)" > "$INSTALL_LOG"

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
    enable_greetd
    setup_symlinks
    deploy_dms_config
    deploy_wallpapers
    install_asus_packages
    setup_hibernation_prompt

    echo -e "\n${GREEN}=== Installation Complete! ===${NC}"

    # Show summary of failures/warnings
    if [ ${#FAILED_PACKAGES[@]} -gt 0 ]; then
        echo -e "\n${YELLOW}⚠ Some packages failed to install:${NC}"
        for pkg in "${FAILED_PACKAGES[@]}"; do
            echo -e "  ${RED}✗${NC} $pkg"
        done
        echo -e "\n${BLUE}Check the log file for details:${NC} $INSTALL_LOG"
    fi

    if [ ${#WARNINGS[@]} -gt 0 ]; then
        echo -e "\n${YELLOW}Warnings:${NC}"
        for warning in "${WARNINGS[@]}"; do
            echo -e "  ⚠ $warning"
        done
    fi

    echo -e "\n${GREEN}Next steps:${NC}"
    echo -e "  1. Reboot your system"
    echo -e "  2. greetd with DMS greeter will start automatically"
    echo -e "  3. Log in and niri will start"
    echo -e "\nOr run: ${YELLOW}niri${NC} from a TTY"
    echo -e "\nConfig location: ${YELLOW}~/.config/niri${NC}"
    echo -e "\nMonitor configuration: Press ${YELLOW}Mod+Shift+M${NC} to configure monitors"
    echo -e "\nWallpapers: Press ${YELLOW}Mod+Y${NC} to browse wallpapers"

    # Exit with error code if there were failures
    if [ ${#FAILED_PACKAGES[@]} -gt 0 ]; then
        echo -e "\n${YELLOW}Installation completed with errors${NC}"
        exit 1
    fi
}

main
