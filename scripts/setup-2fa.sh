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
echo -e "${CYAN}║  Two-Factor Authentication Setup             ║${NC}"
echo -e "${CYAN}╚═══════════════════════════════════════════════╝${NC}\n"

echo -e "${YELLOW}This script will help you set up 2FA for system login${NC}"
echo -e "${YELLOW}using FIDO2/U2F hardware keys (YubiKey, etc.)${NC}\n"

# Ask if user wants to proceed
echo -e "${BLUE}Do you want to set up hardware key authentication?${NC}"
echo -e "This will:"
echo -e "  - Require your hardware key for login/unlock"
echo -e "  - Allow password OR hardware key for sudo"
echo -e "  - Automatically unlock GNOME Keyring with your password"
echo -e ""
echo -e "${RED}WARNING: You MUST have a hardware key with you to login!${NC}"
echo -e "${RED}Without the key, you'll need to boot from live USB to recover.${NC}"
echo -e ""
read -p "Continue with 2FA setup? [y/N] " -n 1 -r
echo

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}2FA setup cancelled${NC}"
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

# Configure PAM for system login
echo -e "\n${CYAN}═══ Configuring System Login ═══${NC}"

# Backup original PAM configs
sudo cp /etc/pam.d/system-login "/etc/pam.d/system-login.backup.$(date +%Y%m%d_%H%M%S)"
sudo cp /etc/pam.d/sudo "/etc/pam.d/sudo.backup.$(date +%Y%m%d_%H%M%S)"

echo -e "${YELLOW}Configuring PAM for hardware key authentication...${NC}"

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

echo -e "${GREEN}✓ PAM configuration updated${NC}"

# Summary
echo -e "\n${GREEN}╔═══════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  2FA Setup Complete!                         ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════╝${NC}\n"

echo -e "${CYAN}Configuration Summary:${NC}"
echo -e "  ${GREEN}✓${NC} Hardware key registered: $HOME/.config/Yubico/u2f_keys"
echo -e "  ${GREEN}✓${NC} System login: Requires hardware key + password"
echo -e "  ${GREEN}✓${NC} Sudo: Hardware key OR password (flexible)"
echo -e "  ${GREEN}✓${NC} GNOME Keyring: Auto-unlocks with password"
echo -e ""
echo -e "${YELLOW}Important:${NC}"
echo -e "  - ${RED}You MUST have your hardware key to login/unlock${NC}"
echo -e "  - Backup your key registration file to a safe location"
echo -e "  - Consider getting a backup hardware key (~\$25-30)"
echo -e "  - PAM backups saved: /etc/pam.d/*.backup.*"
echo -e ""
echo -e "${CYAN}Recovery:${NC}"
echo -e "  If you lose your hardware key:"
echo -e "  1. Boot from live USB"
echo -e "  2. Mount your encrypted drive"
echo -e "  3. Edit /etc/pam.d/system-login and comment out pam_u2f.so line"
echo -e "  4. Reboot and login with password only"
echo -e ""
echo -e "${GREEN}Logout and login again to test the new configuration${NC}"
