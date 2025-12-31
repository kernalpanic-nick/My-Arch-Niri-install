#!/bin/bash
#
# Optional Secure Boot Setup for Limine Bootloader
# Guides you through setting up secure boot with sbctl
#
# This script does NOT copy any keys from the repository
# It generates YOUR keys on YOUR system and guides you through the process
#

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    echo -e "${RED}Error: Do not run this script as root${NC}"
    echo -e "Run as your regular user account"
    exit 1
fi

echo -e "${CYAN}╔═══════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║  Secure Boot Setup for Limine                ║${NC}"
echo -e "${CYAN}╚═══════════════════════════════════════════════╝${NC}\n"

echo -e "${YELLOW}This script will help you set up secure boot with Limine bootloader${NC}"
echo -e "${YELLOW}using sbctl (Secure Boot Manager)${NC}\n"

# Prerequisites check
echo -e "${CYAN}═══ Prerequisites Check ═══${NC}\n"

# Check for sbctl
if ! command -v sbctl &>/dev/null; then
    echo -e "${RED}✗ sbctl is not installed${NC}"
    echo -e "${YELLOW}Installing sbctl...${NC}"
    sudo pacman -S --needed --noconfirm sbctl
    if [ $? -ne 0 ]; then
        echo -e "${RED}Failed to install sbctl${NC}"
        exit 1
    fi
    echo -e "${GREEN}✓ sbctl installed${NC}\n"
else
    echo -e "${GREEN}✓ sbctl is installed${NC}\n"
fi

# Check if system supports UEFI
if [ ! -d /sys/firmware/efi ]; then
    echo -e "${RED}Error: This system does not support UEFI${NC}"
    echo -e "Secure boot requires UEFI firmware"
    exit 1
fi
echo -e "${GREEN}✓ System supports UEFI${NC}\n"

# Check current secure boot status
echo -e "${CYAN}═══ Current Secure Boot Status ═══${NC}\n"
sudo sbctl status

echo -e "\n${BLUE}Understanding the output:${NC}"
echo -e "  - ${YELLOW}Setup Mode: Enabled${NC} = Ready to enroll new keys (good!)"
echo -e "  - ${YELLOW}Setup Mode: Disabled${NC} = Keys already enrolled (may need to clear)"
echo -e "  - ${YELLOW}Secure Boot: Disabled${NC} = Not yet active (normal at this stage)"
echo -e "  - ${YELLOW}Secure Boot: Enabled${NC} = Already active"

# Important warning
echo -e "\n${RED}═══ IMPORTANT UEFI FIRMWARE REQUIREMENTS ═══${NC}\n"
echo -e "${YELLOW}Before continuing, you MUST do the following in UEFI/BIOS:${NC}"
echo -e "  1. Boot into UEFI/BIOS settings (usually F2, Del, or Esc during boot)"
echo -e "  2. Find the Secure Boot settings"
echo -e "  3. ${RED}Clear/Delete existing Secure Boot keys${NC} (puts system in Setup Mode)"
echo -e "  4. ${RED}Keep Secure Boot ENABLED${NC} but it should show 'Setup Mode'"
echo -e "  5. Save and reboot back to this system"
echo -e ""
echo -e "${RED}WARNING: If Setup Mode is not enabled, this script may fail!${NC}"
echo -e "${YELLOW}Some systems call this: 'Clear Secure Boot Keys' or 'Reset to Setup Mode'${NC}"

echo -e "\n${BLUE}Do you want to continue with secure boot setup?${NC}"
read -p "Continue? [y/N] " -n 1 -r
echo

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Secure boot setup cancelled${NC}"
    exit 0
fi

# Phase 1: Key Generation
echo -e "\n${CYAN}═══ Phase 1: Key Generation ═══${NC}\n"

# Check if keys already exist
if [ -d "/var/lib/sbctl/keys" ] && [ "$(sudo ls -A /var/lib/sbctl/keys 2>/dev/null)" ]; then
    echo -e "${YELLOW}⚠ Keys already exist at /var/lib/sbctl/keys${NC}"
    echo -e "${BLUE}Do you want to recreate them?${NC}"
    echo -e "${RED}WARNING: Recreating keys will require re-enrolling in UEFI!${NC}"
    read -p "Recreate keys? [y/N] " -n 1 -r
    echo

    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Removing old keys...${NC}"
        sudo rm -rf /var/lib/sbctl/keys
        echo -e "${YELLOW}Creating new keys...${NC}"
        sudo sbctl create-keys
    else
        echo -e "${GREEN}✓ Using existing keys${NC}"
    fi
else
    echo -e "${YELLOW}Creating secure boot keys...${NC}"
    sudo sbctl create-keys

    if [ $? -ne 0 ]; then
        echo -e "${RED}Failed to create keys${NC}"
        exit 1
    fi
fi

echo -e "${GREEN}✓ Keys created at /var/lib/sbctl/keys/${NC}"
echo -e "  - PK (Platform Key)"
echo -e "  - KEK (Key Exchange Key)"
echo -e "  - db (Signature Database)\n"

# Phase 2: Key Enrollment
echo -e "${CYAN}═══ Phase 2: Key Enrollment ═══${NC}\n"

echo -e "${YELLOW}Enrolling keys with Microsoft certificates...${NC}"
echo -e "${BLUE}The -m flag includes Microsoft certificates, which is required for:${NC}"
echo -e "  - Firmware signed with Microsoft keys"
echo -e "  - Hardware device validation"
echo -e "  - Preventing system brick on some hardware\n"

sudo sbctl enroll-keys -m

if [ $? -ne 0 ]; then
    echo -e "${RED}Failed to enroll keys${NC}"
    echo -e "${YELLOW}Common reasons:${NC}"
    echo -e "  - UEFI is not in Setup Mode (check BIOS settings)"
    echo -e "  - Administrator password required in UEFI"
    echo -e "  - Hardware-specific UEFI restrictions"
    echo -e ""
    echo -e "${BLUE}Try:${NC}"
    echo -e "  1. Reboot into UEFI/BIOS"
    echo -e "  2. Set an administrator password (if not set)"
    echo -e "  3. Clear Secure Boot keys (Setup Mode)"
    echo -e "  4. Ensure Secure Boot is ENABLED but in Setup Mode"
    echo -e "  5. Run this script again"
    exit 1
fi

echo -e "${GREEN}✓ Keys enrolled successfully${NC}\n"

# Phase 3: Sign Limine Bootloader
echo -e "${CYAN}═══ Phase 3: Sign Limine Bootloader ═══${NC}\n"

echo -e "${YELLOW}Searching for Limine EFI binaries to sign...${NC}\n"

# Find all Limine EFI binaries
LIMINE_LOCATIONS=(
    "/boot/EFI/BOOT/BOOTX64.EFI"
    "/boot/efi/EFI/BOOT/BOOTX64.EFI"
    "/boot/EFI/limine/BOOTX64.EFI"
    "/boot/efi/EFI/limine/BOOTX64.EFI"
)

FOUND_FILES=()
for location in "${LIMINE_LOCATIONS[@]}"; do
    if [ -f "$location" ]; then
        FOUND_FILES+=("$location")
        echo -e "${GREEN}✓ Found: $location${NC}"
    fi
done

if [ ${#FOUND_FILES[@]} -eq 0 ]; then
    echo -e "${RED}✗ No Limine EFI binaries found!${NC}"
    echo -e "${YELLOW}Expected locations:${NC}"
    for location in "${LIMINE_LOCATIONS[@]}"; do
        echo -e "  - $location"
    done
    echo -e "\n${YELLOW}Please verify Limine is installed correctly${NC}"
    exit 1
fi

echo -e "\n${YELLOW}Signing Limine EFI binaries...${NC}\n"

for file in "${FOUND_FILES[@]}"; do
    echo -e "${BLUE}Signing: $file${NC}"
    sudo sbctl sign -s "$file"

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Signed successfully${NC}\n"
    else
        echo -e "${RED}✗ Failed to sign $file${NC}\n"
    fi
done

# Verify all files are signed
echo -e "${YELLOW}Verifying signatures...${NC}\n"
sudo sbctl verify

echo -e "\n${BLUE}Checking signed files list:${NC}"
sudo sbctl list-files

echo -e "\n${YELLOW}IMPORTANT: Only Limine EFI binaries should be signed${NC}"
echo -e "${YELLOW}Do NOT sign kernel images - Limine handles their verification via checksums${NC}\n"

# Phase 4: Enable Limine Verification
echo -e "${CYAN}═══ Phase 4: Enable Limine Configuration Verification ═══${NC}\n"

LIMINE_CONFIG="/etc/default/limine"

if [ ! -f "$LIMINE_CONFIG" ]; then
    echo -e "${RED}Warning: $LIMINE_CONFIG not found${NC}"
    echo -e "${YELLOW}Limine configuration verification cannot be enabled${NC}"
    echo -e "${YELLOW}This is optional but recommended${NC}\n"
else
    # Check if ENABLE_VERIFICATION is already set
    if grep -q "^ENABLE_VERIFICATION=yes" "$LIMINE_CONFIG"; then
        echo -e "${GREEN}✓ ENABLE_VERIFICATION is already set to 'yes'${NC}\n"
    else
        echo -e "${YELLOW}Setting ENABLE_VERIFICATION=yes in $LIMINE_CONFIG${NC}"

        # Backup original config
        sudo cp "$LIMINE_CONFIG" "$LIMINE_CONFIG.backup.$(date +%Y%m%d_%H%M%S)"
        echo -e "${GREEN}✓ Backup created: $LIMINE_CONFIG.backup.*${NC}"

        # Add or update ENABLE_VERIFICATION
        if grep -q "^ENABLE_VERIFICATION=" "$LIMINE_CONFIG"; then
            sudo sed -i 's/^ENABLE_VERIFICATION=.*/ENABLE_VERIFICATION=yes/' "$LIMINE_CONFIG"
        else
            echo "ENABLE_VERIFICATION=yes" | sudo tee -a "$LIMINE_CONFIG" > /dev/null
        fi

        echo -e "${GREEN}✓ ENABLE_VERIFICATION=yes configured${NC}"

        # Regenerate configuration
        echo -e "${YELLOW}Regenerating initramfs and updating Limine...${NC}"
        sudo mkinitcpio -P && sudo limine-update

        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✓ Configuration regenerated${NC}\n"
        else
            echo -e "${RED}✗ Failed to regenerate configuration${NC}\n"
        fi
    fi
fi

# Final Instructions
echo -e "${GREEN}╔═══════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  Secure Boot Setup Complete!                 ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════╝${NC}\n"

echo -e "${CYAN}Next Steps:${NC}\n"

echo -e "${YELLOW}1. Verify current status:${NC}"
echo -e "   ${BLUE}sudo sbctl status${NC}"
echo -e "   - Should show Setup Mode: Disabled"
echo -e "   - Should show Secure Boot: Disabled (we'll enable it next)\n"

echo -e "${YELLOW}2. Reboot into UEFI/BIOS:${NC}"
echo -e "   ${BLUE}sudo systemctl reboot --firmware-setup${NC}"
echo -e "   OR manually reboot and press F2/Del/Esc during boot\n"

echo -e "${YELLOW}3. In UEFI/BIOS settings:${NC}"
echo -e "   - Navigate to Secure Boot settings"
echo -e "   - ${GREEN}ENABLE Secure Boot${NC} (if not already enabled)"
echo -e "   - ${GREEN}Ensure Setup Mode is DISABLED${NC} (keys are enrolled)"
echo -e "   - Save settings and exit\n"

echo -e "${YELLOW}4. After rebooting, verify secure boot is active:${NC}"
echo -e "   ${BLUE}sbctl status${NC}"
echo -e "   Should show:"
echo -e "   ${GREEN}✓ Secure Boot: Enabled${NC}"
echo -e "   ${GREEN}✓ Setup Mode: Disabled${NC}\n"

echo -e "${CYAN}Automatic Re-signing:${NC}"
echo -e "  - sbctl pacman hook is installed at /usr/share/libalpm/hooks/zz-sbctl.hook"
echo -e "  - Automatically re-signs enrolled files during updates"
echo -e "  - No manual intervention needed\n"

echo -e "${CYAN}Verification After Updates:${NC}"
echo -e "  ${BLUE}sudo sbctl list-files${NC}  # Show tracked files"
echo -e "  ${BLUE}sudo sbctl verify${NC}      # Verify all signatures"
echo -e "  ${BLUE}sbctl status${NC}           # Check secure boot status\n"

echo -e "${RED}Emergency Recovery:${NC}"
echo -e "  If system won't boot after enabling secure boot:"
echo -e "  1. Boot into UEFI and DISABLE Secure Boot temporarily"
echo -e "  2. Boot into system and run: ${BLUE}sudo sbctl verify${NC}"
echo -e "  3. Re-sign any unsigned files: ${BLUE}sudo sbctl sign -s /path/to/file${NC}"
echo -e "  4. Re-enable Secure Boot in UEFI\n"

echo -e "${GREEN}Configuration backups saved:${NC}"
if [ -f "$LIMINE_CONFIG.backup"* ]; then
    echo -e "  - $LIMINE_CONFIG.backup.*"
fi
echo -e "  - Recovery instructions in SECURE_BOOT.md\n"

echo -e "${BLUE}For detailed troubleshooting, see:${NC}"
echo -e "  ~/niri-setup/SECURE_BOOT.md\n"
