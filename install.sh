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
CYAN='\033[0;36m'
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

# Deploy niri configuration files (copy, not symlink)
deploy_niri_config() {
    echo -e "\n${YELLOW}Deploying niri configuration...${NC}"

    # Backup existing config if it exists
    if [ -d "$HOME/.config/niri" ] && [ ! -L "$HOME/.config/niri" ]; then
        backup_dir="$HOME/.config/niri.backup.$(date +%Y%m%d_%H%M%S)"
        echo -e "${YELLOW}Backing up existing config to: $backup_dir${NC}"
        mv "$HOME/.config/niri" "$backup_dir"
    elif [ -L "$HOME/.config/niri" ]; then
        echo -e "${YELLOW}Removing old symlink (switching to copy method)${NC}"
        rm "$HOME/.config/niri"
    fi

    # Create .config directory if it doesn't exist
    mkdir -p "$HOME/.config"

    # Copy niri config (instead of symlink)
    if [ -d "$SCRIPT_DIR/.config/niri" ]; then
        cp -r "$SCRIPT_DIR/.config/niri" "$HOME/.config/"

        # Ensure proper ownership (user, not root)
        chown -R "$USER:$USER" "$HOME/.config/niri"

        echo -e "${GREEN}✓ Copied niri config${NC}"
        echo -e "${YELLOW}Note: Config is now independent of repository${NC}"
        echo -e "${YELLOW}To update repo, manually copy changes back from ~/.config/niri/${NC}"
    else
        echo -e "${RED}Error: Niri config not found in repository${NC}"
        return 1
    fi
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

    # Ensure proper ownership (user, not root)
    chown -R "$USER:$USER" "$HOME/.config/DankMaterialShell" 2>/dev/null
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
            # Ensure proper ownership (user, not root)
            chown -R "$USER:$USER" "$HOME/Pictures/Wallpaper" 2>/dev/null

            echo -e "${GREEN}✓ Copied $wallpaper_count wallpapers${NC}"
            echo -e "${YELLOW}Use Mod+Y to browse wallpapers in DMS${NC}"
        fi
    fi
}

# Deploy GTK and Thunar theme configurations
deploy_gtk_thunar_config() {
    echo -e "\n${YELLOW}Deploying GTK and Thunar theme configurations...${NC}"

    # Create GTK config directories
    mkdir -p "$HOME/.config/gtk-3.0"
    mkdir -p "$HOME/.config/gtk-4.0"
    mkdir -p "$HOME/.config/Thunar"
    mkdir -p "$HOME/.config/xfce4/xfconf/xfce-perchannel-xml"

    # Copy GTK-3.0 configurations
    if [ -f "$SCRIPT_DIR/.config/gtk-3.0/settings.ini" ]; then
        cp "$SCRIPT_DIR/.config/gtk-3.0/settings.ini" "$HOME/.config/gtk-3.0/"
        echo -e "${GREEN}✓ Copied GTK-3.0 settings${NC}"
    fi

    if [ -f "$SCRIPT_DIR/.config/gtk-3.0/dank-colors.css" ]; then
        cp "$SCRIPT_DIR/.config/gtk-3.0/dank-colors.css" "$HOME/.config/gtk-3.0/"
        echo -e "${GREEN}✓ Copied GTK-3.0 color scheme${NC}"
    fi

    if [ -f "$SCRIPT_DIR/.config/gtk-3.0/bookmarks" ]; then
        cp "$SCRIPT_DIR/.config/gtk-3.0/bookmarks" "$HOME/.config/gtk-3.0/"
        echo -e "${GREEN}✓ Copied GTK-3.0 bookmarks${NC}"
    fi

    # Copy GTK-4.0 configurations
    if [ -f "$SCRIPT_DIR/.config/gtk-4.0/dank-colors.css" ]; then
        cp "$SCRIPT_DIR/.config/gtk-4.0/dank-colors.css" "$HOME/.config/gtk-4.0/"
        echo -e "${GREEN}✓ Copied GTK-4.0 color scheme${NC}"
    fi

    # Copy Thunar configurations
    if [ -f "$SCRIPT_DIR/.config/Thunar/accels.scm" ]; then
        cp "$SCRIPT_DIR/.config/Thunar/accels.scm" "$HOME/.config/Thunar/"
        echo -e "${GREEN}✓ Copied Thunar keyboard shortcuts${NC}"
    fi

    if [ -f "$SCRIPT_DIR/.config/Thunar/uca.xml" ]; then
        cp "$SCRIPT_DIR/.config/Thunar/uca.xml" "$HOME/.config/Thunar/"
        echo -e "${GREEN}✓ Copied Thunar custom actions${NC}"
    fi

    if [ -f "$SCRIPT_DIR/.config/xfce4/xfconf/xfce-perchannel-xml/thunar.xml" ]; then
        cp "$SCRIPT_DIR/.config/xfce4/xfconf/xfce-perchannel-xml/thunar.xml" "$HOME/.config/xfce4/xfconf/xfce-perchannel-xml/"
        echo -e "${GREEN}✓ Copied Thunar settings${NC}"
    fi

    # Ensure proper ownership (user, not root)
    chown -R "$USER:$USER" "$HOME/.config/gtk-3.0" "$HOME/.config/gtk-4.0" "$HOME/.config/Thunar" "$HOME/.config/xfce4" 2>/dev/null

    echo -e "${GREEN}✓ GTK and Thunar themes configured${NC}"
}

# Setup automount with udiskie
setup_automount() {
    echo -e "\n${YELLOW}Setting up automount with udiskie...${NC}"

    # Create udiskie config directory
    mkdir -p "$HOME/.config/udiskie"
    mkdir -p "$HOME/.config/systemd/user"

    # Copy udiskie configuration
    if [ -f "$SCRIPT_DIR/.config/udiskie/config.yml" ]; then
        cp "$SCRIPT_DIR/.config/udiskie/config.yml" "$HOME/.config/udiskie/"
        echo -e "${GREEN}✓ Copied udiskie configuration${NC}"
    fi

    # Copy systemd user service
    if [ -f "$SCRIPT_DIR/.config/systemd/user/udiskie.service" ]; then
        cp "$SCRIPT_DIR/.config/systemd/user/udiskie.service" "$HOME/.config/systemd/user/"
        echo -e "${GREEN}✓ Copied udiskie systemd service${NC}"
    fi

    # Ensure proper ownership (should be user, not root)
    chown -R "$USER:$USER" "$HOME/.config/udiskie" "$HOME/.config/systemd/user/udiskie.service" 2>/dev/null

    # Add user to storage group if not already a member
    if ! groups "$USER" | grep -q "storage"; then
        echo -e "${YELLOW}Adding $USER to storage group for device access...${NC}"
        sudo usermod -aG storage "$USER"
        echo -e "${GREEN}✓ Added $USER to storage group${NC}"
        echo -e "${YELLOW}Note: You'll need to log out and back in for group changes to take effect${NC}"
    fi

    # Enable udiskie service as user (NOT as root)
    systemctl --user daemon-reload
    systemctl --user enable udiskie.service
    echo -e "${GREEN}✓ Enabled udiskie user service (runs as $USER, not root)${NC}"
    echo -e "${YELLOW}Note: Udiskie will auto-start on next login and handle removable media${NC}"
}

# Cleanup CachyOS bloat packages
cleanup_cachyos_bloat() {
    echo -e "\n${BLUE}═══ CachyOS Bloat Cleanup ═══${NC}"
    echo -e "${YELLOW}Remove unnecessary CachyOS packages?${NC}"
    echo -e "This will remove:"
    echo -e "  - cachyos-fish-config (Fish shell config - conflicts with custom configs)"
    echo -e "  - cachyos-zsh-config (ZSH config - conflicts with custom configs)"
    echo -e "  - cachyos-micro-settings (Micro editor settings - not needed)"
    echo -e "  - cachyos-rate-mirrors (Mirror rating tool - only needed once)"
    echo -e ""
    echo -e "${GREEN}This will keep essential packages:${NC}"
    echo -e "  ✓ cachyos-keyring, mirrorlist (required for package repos)"
    echo -e "  ✓ cachyos-settings, hooks (system configuration)"
    echo -e "  ✓ cachyos-ananicy-rules (process priority optimization)"
    echo -e "  ✓ cachyos-snapper-support (btrfs snapshots - currently active)"
    echo -e "  ✓ linux-cachyos kernels"
    echo -e ""
    read -p "Remove bloat packages? [y/N] " -n 1 -r
    echo

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Removing CachyOS bloat packages...${NC}"

        # List of packages to remove
        local bloat_packages=(
            "cachyos-fish-config"
            "cachyos-zsh-config"
            "cachyos-micro-settings"
            "cachyos-rate-mirrors"
        )

        # Remove packages that are actually installed
        local to_remove=()
        for pkg in "${bloat_packages[@]}"; do
            if pacman -Q "$pkg" &>/dev/null; then
                to_remove+=("$pkg")
            fi
        done

        if [ ${#to_remove[@]} -gt 0 ]; then
            echo -e "${GREEN}Removing: ${to_remove[*]}${NC}"
            sudo pacman -Rns --noconfirm "${to_remove[@]}" 2>&1 | tee -a "$INSTALL_LOG"

            if [ $? -eq 0 ]; then
                echo -e "${GREEN}✓ Successfully removed CachyOS bloat packages${NC}"
            else
                echo -e "${YELLOW}⚠ Some packages could not be removed (check log)${NC}"
            fi
        else
            echo -e "${GREEN}✓ No bloat packages found to remove${NC}"
        fi
    else
        echo -e "${YELLOW}Skipped CachyOS cleanup${NC}"
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

            # Create asus-users group and add current user
            echo -e "${YELLOW}Adding user to asus-users group...${NC}"
            if ! getent group asus-users >/dev/null 2>&1; then
                sudo groupadd asus-users
                echo -e "${GREEN}✓ Created asus-users group${NC}"
            fi

            sudo usermod -aG asus-users "$USER"
            echo -e "${GREEN}✓ Added $USER to asus-users group${NC}"
            echo -e "${YELLOW}Note: You'll need to log out and back in for group changes to take effect${NC}"

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

# Interactive menu for optional features
optional_features_menu() {
    echo -e "\n${CYAN}╔═══════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║  Optional Features Setup                     ║${NC}"
    echo -e "${CYAN}╚═══════════════════════════════════════════════╝${NC}\n"

    echo -e "${YELLOW}The base system installation is complete!${NC}"
    echo -e "${YELLOW}You can now choose which optional features to set up.${NC}\n"

    local features_selected=()
    local laptop_type=$(detect_asus_laptop)

    # Show available features
    echo -e "${BLUE}Available optional features:${NC}\n"

    # ASUS support (only show if ASUS laptop detected)
    local asus_option=""
    if [ "$laptop_type" = "asus" ]; then
        echo -e "${GREEN}1)${NC} ASUS Laptop Support (asusctl, RGB controls, fan profiles)"
        asus_option="available"
    fi

    echo -e "${GREEN}2)${NC} Hibernation Support (swap file, suspend-then-hibernate)"
    echo -e "${GREEN}3)${NC} Two-Factor Authentication (YubiKey, FIDO2/U2F hardware keys)"
    echo -e "${GREEN}4)${NC} Secure Boot (sign bootloader, enroll keys)"
    echo -e "${GREEN}5)${NC} CachyOS Bloat Cleanup (remove unnecessary packages)"
    echo -e "${GREEN}6)${NC} All of the above"
    echo -e "${GREEN}7)${NC} None - Skip optional features"

    echo -e "\n${YELLOW}Select an option [1-7]:${NC} "
    read -r choice

    case $choice in
        1)
            if [ "$asus_option" = "available" ]; then
                features_selected+=("asus")
            else
                echo -e "${RED}ASUS laptop not detected - skipping${NC}"
            fi
            ;;
        2)
            features_selected+=("hibernation")
            ;;
        3)
            features_selected+=("2fa")
            ;;
        4)
            features_selected+=("secureboot")
            ;;
        5)
            features_selected+=("cleanup")
            ;;
        6)
            # All features
            [ "$asus_option" = "available" ] && features_selected+=("asus")
            features_selected+=("hibernation" "2fa" "secureboot" "cleanup")
            ;;
        7)
            echo -e "${YELLOW}Skipping all optional features${NC}"
            return
            ;;
        *)
            echo -e "${RED}Invalid option - skipping optional features${NC}"
            return
            ;;
    esac

    # Execute selected features
    for feature in "${features_selected[@]}"; do
        case $feature in
            asus)
                echo -e "\n${CYAN}═══ Setting up ASUS Laptop Support ═══${NC}\n"
                install_asus_packages_noninteractive
                ;;
            hibernation)
                echo -e "\n${CYAN}═══ Setting up Hibernation ═══${NC}\n"
                setup_hibernation_noninteractive
                ;;
            2fa)
                echo -e "\n${CYAN}═══ Setting up Two-Factor Authentication ═══${NC}\n"
                setup_2fa_guided
                ;;
            secureboot)
                echo -e "\n${CYAN}═══ Setting up Secure Boot ═══${NC}\n"
                setup_secureboot_guided
                ;;
            cleanup)
                echo -e "\n${CYAN}═══ Cleaning up CachyOS Bloat ═══${NC}\n"
                cleanup_cachyos_bloat
                ;;
        esac
    done

    echo -e "\n${GREEN}✓ Optional features setup complete${NC}"
}

# Non-interactive ASUS package installation (called from menu)
install_asus_packages_noninteractive() {
    echo -e "${GREEN}Installing ASUS packages...${NC}"

    # Install from official repos
    sudo pacman -S --needed --noconfirm asusctl rog-control-center supergfxctl

    # Enable asusd service
    sudo systemctl enable asusd

    # Create asus-users group and add current user
    echo -e "${YELLOW}Adding user to asus-users group...${NC}"
    if ! getent group asus-users >/dev/null 2>&1; then
        sudo groupadd asus-users
        echo -e "${GREEN}✓ Created asus-users group${NC}"
    fi

    sudo usermod -aG asus-users "$USER"
    echo -e "${GREEN}✓ Added $USER to asus-users group${NC}"
    echo -e "${YELLOW}Note: You'll need to log out and back in for group changes to take effect${NC}"

    # Copy ASUS configuration if available
    if [ -f "$SCRIPT_DIR/etc/asusd/asusd.ron" ]; then
        sudo cp "$SCRIPT_DIR/etc/asusd/asusd.ron" /etc/asusd/
        echo -e "${GREEN}✓ Copied ASUS configuration${NC}"
    fi

    echo -e "${GREEN}✓ ASUS packages installed and configured${NC}"
}

# Non-interactive hibernation setup (called from menu)
setup_hibernation_noninteractive() {
    if [ -f "$SCRIPT_DIR/scripts/setup-hibernation.sh" ]; then
        echo -e "${GREEN}Running hibernation setup script...${NC}"
        sudo "$SCRIPT_DIR/scripts/setup-hibernation.sh"
    else
        echo -e "${RED}Error: Hibernation setup script not found${NC}"
        echo "Expected: $SCRIPT_DIR/scripts/setup-hibernation.sh"
    fi
}

# Guided 2FA setup (called from menu)
setup_2fa_guided() {
    if [ -f "$SCRIPT_DIR/scripts/setup-2fa.sh" ]; then
        echo -e "${YELLOW}Launching 2FA setup wizard...${NC}\n"
        bash "$SCRIPT_DIR/scripts/setup-2fa.sh"
    else
        echo -e "${RED}Error: 2FA setup script not found${NC}"
        echo "Expected: $SCRIPT_DIR/scripts/setup-2fa.sh"
        echo -e "${YELLOW}You can set up 2FA manually later${NC}"
    fi
}

# Guided secure boot setup (called from menu)
setup_secureboot_guided() {
    if [ -f "$SCRIPT_DIR/scripts/setup-secure-boot.sh" ]; then
        echo -e "${YELLOW}Launching Secure Boot setup wizard...${NC}\n"
        bash "$SCRIPT_DIR/scripts/setup-secure-boot.sh"
    else
        echo -e "${RED}Error: Secure Boot setup script not found${NC}"
        echo "Expected: $SCRIPT_DIR/scripts/setup-secure-boot.sh"
        echo -e "${YELLOW}See SECURE_BOOT.md for manual setup instructions${NC}"
    fi
}

# Main installation
main() {
    # Initialize log file
    echo "Installation started at $(date)" > "$INSTALL_LOG"

    echo "This will install niri and related packages, then deploy configs."
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
    deploy_niri_config
    deploy_dms_config
    deploy_gtk_thunar_config
    deploy_wallpapers
    setup_automount

    # Show optional features menu
    optional_features_menu

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

    echo -e "\n${CYAN}Optional features (if skipped):${NC}"
    echo -e "  Hibernation: ${YELLOW}sudo ~/niri-setup/scripts/setup-hibernation.sh${NC}"
    echo -e "  2FA Setup:   ${YELLOW}~/niri-setup/scripts/setup-2fa.sh${NC}"
    echo -e "  Secure Boot: ${YELLOW}~/niri-setup/scripts/setup-secure-boot.sh${NC}"

    # Exit with error code if there were failures
    if [ ${#FAILED_PACKAGES[@]} -gt 0 ]; then
        echo -e "\n${YELLOW}Installation completed with errors${NC}"
        exit 1
    fi
}

main
