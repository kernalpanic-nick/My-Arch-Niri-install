#!/bin/bash
#
# Optional Two-Factor Authentication Setup
# Supports YubiKey and other FIDO2/U2F devices
#
# This script does NOT copy any authentication configs from the repository
# It guides you through setting up 2FA interactively on YOUR system
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
echo -e "${CYAN}║  Additional Authentication Methods Setup     ║${NC}"
echo -e "${CYAN}╚═══════════════════════════════════════════════╝${NC}\n"

echo -e "${YELLOW}This script will help you set up additional authentication methods${NC}"
echo -e "${YELLOW}including FIDO2/U2F hardware keys (YubiKey, etc.)${NC}\n"

# Ask if user wants to proceed
echo -e "${BLUE}Do you want to set up hardware key authentication?${NC}"
echo -e ""
echo -e "You'll be able to choose where to apply it:"
echo -e "  - Greeter and lock screen (requires hardware key to login/unlock)"
echo -e "  - Sudo only (hardware key OR password for sudo)"
echo -e "  - Both greeter/lock + sudo (most secure)"
echo -e "  - Register keys only (configure later)"
echo -e ""
read -p "Continue with setup? [y/N] " -n 1 -r
echo

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Authentication setup cancelled${NC}"
    exit 0
fi

# Check for required packages
echo -e "\n${YELLOW}Checking for required packages...${NC}"

if ! pacman -Q pam-u2f &>/dev/null; then
    echo -e "${YELLOW}Installing pam-u2f...${NC}"
    sudo pacman -S --needed --noconfirm pam-u2f
    if [ $? -ne 0 ]; then
        echo -e "${RED}Failed to install pam-u2f${NC}"
        exit 1
    fi
fi

if ! pacman -Q libsecret &>/dev/null; then
    echo -e "${YELLOW}Installing libsecret for keyring support...${NC}"
    sudo pacman -S --needed --noconfirm libsecret
fi

echo -e "${GREEN}✓ Required packages installed${NC}"

# Register hardware key
echo -e "\n${CYAN}═══ Hardware Key Registration ═══${NC}"
echo -e "${YELLOW}Insert your hardware key (YubiKey, etc.) now${NC}"
read -p "Press Enter when ready..."

# Create config directory
mkdir -p "$HOME/.config/Yubico"

echo -e "\n${YELLOW}Please touch your hardware key when it blinks/prompts...${NC}"

# Register the key
pamu2fcfg -o pam://$(hostname) -i pam://$(hostname) > "$HOME/.config/Yubico/u2f_keys"

if [ $? -ne 0 ] || [ ! -s "$HOME/.config/Yubico/u2f_keys" ]; then
    echo -e "${RED}Failed to register hardware key${NC}"
    echo -e "Make sure your key is inserted and try again"
    exit 1
fi

echo -e "${GREEN}✓ Hardware key registered successfully${NC}"

# Ask about backup key
echo -e "\n${BLUE}Do you want to register a backup hardware key?${NC}"
echo -e "${YELLOW}HIGHLY RECOMMENDED: Register a second key and store it safely${NC}"
read -p "Register backup key now? [Y/n] " -n 1 -r
echo

if [[ ! $REPLY =~ ^[Nn]$ ]]; then
    echo -e "\n${YELLOW}Insert your BACKUP hardware key now${NC}"
    read -p "Press Enter when ready..."

    echo -e "${YELLOW}Please touch your backup key when it blinks/prompts...${NC}"

    # Append backup key to config
    pamu2fcfg -o pam://$(hostname) -i pam://$(hostname) -n >> "$HOME/.config/Yubico/u2f_keys"

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Backup key registered${NC}"
    else
        echo -e "${YELLOW}⚠ Backup key registration failed, but primary key is registered${NC}"
    fi
fi

# Backup the registration file
echo -e "\n${YELLOW}Creating backup of key registration...${NC}"
cp "$HOME/.config/Yubico/u2f_keys" "$HOME/.config/Yubico/u2f_keys.backup.$(date +%Y%m%d_%H%M%S)"
echo -e "${GREEN}✓ Backup created at: $HOME/.config/Yubico/u2f_keys.backup.*${NC}"
echo -e "${YELLOW}Store this file in a safe location (encrypted USB, cloud, etc.)${NC}"

# Ask where to apply authentication
echo -e "\n${CYAN}═══ Authentication Application ═══${NC}\n"

echo -e "${BLUE}Where do you want to apply hardware key authentication?${NC}"
echo -e "${YELLOW}You can select multiple options (e.g., '1 2 3' for all)${NC}\n"

echo -e "${GREEN}1)${NC} Greeter & Lock Screen"
echo -e "   ${YELLOW}→ Requires hardware key to login or unlock screen${NC}"
echo -e "   ${RED}⚠ You MUST have your key to login/unlock!${NC}\n"

echo -e "${GREEN}2)${NC} Sudo commands (user privilege elevation)"
echo -e "   ${YELLOW}→ Hardware key OR password for sudo (flexible)${NC}\n"

echo -e "${GREEN}3)${NC} Root/su commands (switch to root user)"
echo -e "   ${YELLOW}→ Hardware key OR password for su (flexible)${NC}\n"

echo -e "${GREEN}4)${NC} Register keys only (configure manually later)"
echo -e "   ${YELLOW}→ Keys are registered but not applied to PAM${NC}\n"

read -p "Select options (space-separated, e.g., '1 2'): " USER_CHOICES
echo

APPLY_TO_LOGIN=false
APPLY_TO_SUDO=false
APPLY_TO_SU=false

# Parse user choices
for choice in $USER_CHOICES; do
    case $choice in
        1)
            APPLY_TO_LOGIN=true
            ;;
        2)
            APPLY_TO_SUDO=true
            ;;
        3)
            APPLY_TO_SU=true
            ;;
        4)
            # Keys only - skip PAM configuration
            echo -e "${YELLOW}Selected: Register keys only${NC}"
            echo -e "${GREEN}Hardware keys registered successfully!${NC}"
            echo -e "${BLUE}You can manually configure PAM later by editing:${NC}"
            echo -e "  - /etc/pam.d/system-login (for greeter/lock screen)"
            echo -e "  - /etc/pam.d/sudo (for sudo commands)"
            echo -e "  - /etc/pam.d/su (for root/su commands)"
            echo -e "\n${YELLOW}See documentation for PAM configuration examples${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}Invalid option '$choice' - ignoring${NC}"
            ;;
    esac
done

# Show what was selected
echo -e "${CYAN}Selected configuration:${NC}"
if [ "$APPLY_TO_LOGIN" = true ]; then
    echo -e "  ${GREEN}✓${NC} Greeter & Lock Screen (hardware key required)"
fi
if [ "$APPLY_TO_SUDO" = true ]; then
    echo -e "  ${GREEN}✓${NC} Sudo commands (hardware key OR password)"
fi
if [ "$APPLY_TO_SU" = true ]; then
    echo -e "  ${GREEN}✓${NC} Root/su commands (hardware key OR password)"
fi

if [ "$APPLY_TO_LOGIN" = false ] && [ "$APPLY_TO_SUDO" = false ] && [ "$APPLY_TO_SU" = false ]; then
    echo -e "${RED}No options selected - setup cancelled${NC}"
    exit 1
fi

# Confirm if login is selected (high risk)
if [ "$APPLY_TO_LOGIN" = true ]; then
    echo -e "\n${RED}WARNING: You selected Greeter & Lock Screen!${NC}"
    echo -e "${RED}You MUST have your hardware key to login/unlock!${NC}"
    echo -e "${RED}Without the key, you'll need to boot from live USB to recover.${NC}\n"
    read -p "Are you sure you want to require hardware key for login? [y/N] " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Setup cancelled${NC}"
        exit 0
    fi
fi

# Configure PAM based on user selection
if [ "$APPLY_TO_LOGIN" = true ] || [ "$APPLY_TO_SUDO" = true ] || [ "$APPLY_TO_SU" = true ]; then
    echo -e "\n${CYAN}═══ Configuring PAM ═══${NC}\n"

    # Backup original PAM configs
    if [ "$APPLY_TO_LOGIN" = true ]; then
        sudo cp /etc/pam.d/system-login "/etc/pam.d/system-login.backup.$(date +%Y%m%d_%H%M%S)"
        echo -e "${GREEN}✓ Backed up /etc/pam.d/system-login${NC}"
    fi

    if [ "$APPLY_TO_SUDO" = true ]; then
        sudo cp /etc/pam.d/sudo "/etc/pam.d/sudo.backup.$(date +%Y%m%d_%H%M%S)"
        echo -e "${GREEN}✓ Backed up /etc/pam.d/sudo${NC}"
    fi

    if [ "$APPLY_TO_SU" = true ]; then
        sudo cp /etc/pam.d/su "/etc/pam.d/su.backup.$(date +%Y%m%d_%H%M%S)" 2>/dev/null || true
        echo -e "${GREEN}✓ Backed up /etc/pam.d/su${NC}"
    fi
fi

# Apply to system-login (greeter & lock screen)
if [ "$APPLY_TO_LOGIN" = true ]; then
    echo -e "\n${YELLOW}Configuring greeter and lock screen...${NC}"

    # Create system-login config with hardware key requirement
    sudo tee /etc/pam.d/system-login > /dev/null << 'EOF'
#%PAM-1.0

# Hardware key authentication (REQUIRED for login)
auth     required   pam_u2f.so cue origin=pam://$(hostname) appid=pam://$(hostname)

# Password authentication
auth     include    system-auth

# Account checks
account  include    system-auth

# Password change
password include    system-auth

# Session setup
session  optional   pam_loginuid.so
session  include    system-auth
session  optional   pam_motd.so
session  optional   pam_mail.so dir=/var/spool/mail standard quiet
-session optional   pam_systemd.so

# GNOME Keyring auto-unlock with password
-auth    optional   pam_gnome_keyring.so
-session optional   pam_gnome_keyring.so auto_start
EOF

    echo -e "${GREEN}✓ Greeter and lock screen configured with hardware key requirement${NC}"
fi

# Apply to sudo (flexible authentication)
if [ "$APPLY_TO_SUDO" = true ]; then
    echo -e "\n${YELLOW}Configuring sudo with flexible authentication...${NC}"

    # Create sudo config with flexible authentication
    sudo tee /etc/pam.d/sudo > /dev/null << 'EOF'
#%PAM-1.0

# Hardware key (if present, no password needed)
auth     sufficient pam_u2f.so cue origin=pam://$(hostname) appid=pam://$(hostname)

# Fall back to password authentication
auth     include    system-auth

account  include    system-auth
session  include    system-auth
EOF

    echo -e "${GREEN}✓ Sudo configured with flexible authentication (hardware key OR password)${NC}"
fi

# Apply to su (root access - flexible authentication)
if [ "$APPLY_TO_SU" = true ]; then
    echo -e "\n${YELLOW}Configuring root/su with flexible authentication...${NC}"

    # Create su config with flexible authentication
    sudo tee /etc/pam.d/su > /dev/null << 'EOF'
#%PAM-1.0

# Hardware key (if present, no password needed)
auth     sufficient pam_u2f.so cue origin=pam://$(hostname) appid=pam://$(hostname)

# Fall back to password authentication
auth     sufficient pam_rootok.so
auth     required   pam_unix.so

account  required   pam_unix.so
session  required   pam_unix.so
EOF

    echo -e "${GREEN}✓ Root/su configured with flexible authentication (hardware key OR password)${NC}"
fi

echo -e "\n${GREEN}✓ PAM configuration completed${NC}"

# Summary
echo -e "\n${GREEN}╔═══════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  Authentication Setup Complete!              ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════╝${NC}\n"

echo -e "${CYAN}Configuration Summary:${NC}"
echo -e "  ${GREEN}✓${NC} Hardware key registered: $HOME/.config/Yubico/u2f_keys"

if [ "$APPLY_TO_LOGIN" = true ]; then
    echo -e "  ${GREEN}✓${NC} Greeter & Lock Screen: Requires hardware key + password"
    echo -e "  ${GREEN}✓${NC} GNOME Keyring: Auto-unlocks with password"
fi

if [ "$APPLY_TO_SUDO" = true ]; then
    echo -e "  ${GREEN}✓${NC} Sudo: Hardware key OR password (flexible)"
fi

if [ "$APPLY_TO_SU" = true ]; then
    echo -e "  ${GREEN}✓${NC} Root/su: Hardware key OR password (flexible)"
fi

if [ "$APPLY_TO_LOGIN" = false ] && [ "$APPLY_TO_SUDO" = false ] && [ "$APPLY_TO_SU" = false ]; then
    echo -e "  ${YELLOW}⚠${NC} No PAM configuration applied (keys registered only)"
fi

echo -e ""
echo -e "${YELLOW}Important:${NC}"
echo -e "  - Backup your key registration file to a safe location"
echo -e "  - Consider getting a backup hardware key (~\$25-30)"

if [ "$APPLY_TO_LOGIN" = true ]; then
    echo -e "  - ${RED}You MUST have your hardware key to login/unlock${NC}"
fi

if [ "$APPLY_TO_LOGIN" = true ] || [ "$APPLY_TO_SUDO" = true ] || [ "$APPLY_TO_SU" = true ]; then
    echo -e "  - PAM backups saved: /etc/pam.d/*.backup.*"
fi

if [ "$APPLY_TO_LOGIN" = true ]; then
    echo -e ""
    echo -e "${CYAN}Recovery (if you lose your hardware key):${NC}"
    echo -e "  1. Boot from live USB"
    echo -e "  2. Mount your encrypted drive"
    echo -e "  3. Edit /etc/pam.d/system-login and comment out pam_u2f.so line"
    echo -e "  4. Reboot and login with password only"
fi

if [ "$APPLY_TO_LOGIN" = true ] || [ "$APPLY_TO_SUDO" = true ] || [ "$APPLY_TO_SU" = true ]; then
    echo -e ""
    echo -e "${GREEN}Logout and login again to test the new configuration${NC}"
fi
