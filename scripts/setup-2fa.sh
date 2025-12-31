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
echo -e "${YELLOW}including hardware keys (YubiKey, FIDO2/U2F) and facial recognition${NC}\n"

# Ask which authentication method to set up
echo -e "${BLUE}Which authentication method do you want to set up?${NC}\n"
echo -e "${GREEN}1)${NC} Hardware Key (YubiKey, FIDO2/U2F devices)"
echo -e "   ${YELLOW}→ Physical security key authentication${NC}\n"

echo -e "${GREEN}2)${NC} Facial Recognition (Howdy - Windows Hello style)"
echo -e "   ${YELLOW}→ Face unlock using your webcam${NC}\n"

echo -e "${GREEN}3)${NC} Both (Hardware Key + Facial Recognition)"
echo -e "   ${YELLOW}→ Set up both methods (can use either)${NC}\n"

read -p "Select authentication method [1-3]: " -n 1 -r
echo -e "\n"

SETUP_HARDWARE_KEY=false
SETUP_FACIAL_RECOGNITION=false

case $REPLY in
    1)
        SETUP_HARDWARE_KEY=true
        echo -e "${YELLOW}Selected: Hardware Key authentication${NC}"
        ;;
    2)
        SETUP_FACIAL_RECOGNITION=true
        echo -e "${YELLOW}Selected: Facial Recognition${NC}"
        ;;
    3)
        SETUP_HARDWARE_KEY=true
        SETUP_FACIAL_RECOGNITION=true
        echo -e "${YELLOW}Selected: Both Hardware Key and Facial Recognition${NC}"
        ;;
    *)
        echo -e "${RED}Invalid option - setup cancelled${NC}"
        exit 1
        ;;
esac

echo

# Check for required packages
echo -e "${YELLOW}Installing required packages...${NC}\n"

# Install packages for hardware key
if [ "$SETUP_HARDWARE_KEY" = true ]; then
    if ! pacman -Q pam-u2f &>/dev/null; then
        echo -e "${YELLOW}Installing pam-u2f for hardware key support...${NC}"
        sudo pacman -S --needed --noconfirm pam-u2f
        if [ $? -ne 0 ]; then
            echo -e "${RED}Failed to install pam-u2f${NC}"
            exit 1
        fi
    fi
    echo -e "${GREEN}✓ pam-u2f installed${NC}"
fi

# Install packages for facial recognition
if [ "$SETUP_FACIAL_RECOGNITION" = true ]; then
    # Check if paru or yay is available (needed for AUR packages)
    if ! command -v paru &>/dev/null && ! command -v yay &>/dev/null; then
        echo -e "${RED}Error: AUR helper (paru or yay) is required for Howdy${NC}"
        echo -e "${YELLOW}Please install paru or yay first${NC}"
        exit 1
    fi

    # Determine which AUR helper to use
    if command -v paru &>/dev/null; then
        AUR_HELPER="paru"
    else
        AUR_HELPER="yay"
    fi

    echo -e "${YELLOW}Installing Howdy for facial recognition...${NC}"
    echo -e "${BLUE}Note: This will install from AUR and may take a few minutes${NC}"

    $AUR_HELPER -S --needed --noconfirm howdy
    if [ $? -ne 0 ]; then
        echo -e "${RED}Failed to install Howdy${NC}"
        echo -e "${YELLOW}You can continue with hardware key only${NC}"
        SETUP_FACIAL_RECOGNITION=false
    else
        echo -e "${GREEN}✓ Howdy installed${NC}"
    fi
fi

# Install libsecret for keyring support
if ! pacman -Q libsecret &>/dev/null; then
    echo -e "${YELLOW}Installing libsecret for keyring support...${NC}"
    sudo pacman -S --needed --noconfirm libsecret
fi

echo -e "\n${GREEN}✓ Required packages installed${NC}"

# Setup Facial Recognition (Howdy)
if [ "$SETUP_FACIAL_RECOGNITION" = true ]; then
    echo -e "\n${CYAN}═══ Facial Recognition Setup (Howdy) ═══${NC}\n"

    echo -e "${YELLOW}We'll now capture your face for recognition${NC}"
    echo -e "${BLUE}Make sure you're in good lighting and facing the camera${NC}\n"

    read -p "Press Enter when ready to capture your face..."

    echo -e "\n${YELLOW}Adding your face model...${NC}"
    echo -e "${BLUE}Look at the camera and follow the prompts${NC}\n"

    # Add the user's face to Howdy
    sudo howdy add

    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ Face model added successfully${NC}"

        # Ask if they want to add a second model (different lighting/angle)
        echo -e "\n${BLUE}Do you want to add another face model?${NC}"
        echo -e "${YELLOW}Recommended: Add a model in different lighting conditions${NC}"
        read -p "Add another model? [Y/n] " -n 1 -r
        echo

        if [[ ! $REPLY =~ ^[Nn]$ ]]; then
            echo -e "\n${YELLOW}Adding second face model...${NC}"
            sudo howdy add
            if [ $? -eq 0 ]; then
                echo -e "${GREEN}✓ Second face model added${NC}"
            fi
        fi

        # Test the facial recognition
        echo -e "\n${BLUE}Do you want to test facial recognition now?${NC}"
        read -p "Test now? [Y/n] " -n 1 -r
        echo

        if [[ ! $REPLY =~ ^[Nn]$ ]]; then
            echo -e "\n${YELLOW}Testing facial recognition...${NC}"
            echo -e "${BLUE}Look at the camera${NC}\n"
            sudo howdy test
        fi
    else
        echo -e "${RED}Failed to add face model${NC}"
        echo -e "${YELLOW}Continuing without facial recognition...${NC}"
        SETUP_FACIAL_RECOGNITION=false
    fi
fi

# Register hardware key
if [ "$SETUP_HARDWARE_KEY" = true ]; then
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
fi  # End hardware key registration

# Ask where to apply authentication
echo -e "\n${CYAN}═══ Authentication Application ═══${NC}\n"

# Update messaging based on what was set up
if [ "$SETUP_HARDWARE_KEY" = true ] && [ "$SETUP_FACIAL_RECOGNITION" = true ]; then
    echo -e "${BLUE}Where do you want to apply authentication (hardware key OR face)?${NC}"
    echo -e "${YELLOW}You can select multiple options (e.g., '1 2 3' for all)${NC}\n"
elif [ "$SETUP_HARDWARE_KEY" = true ]; then
    echo -e "${BLUE}Where do you want to apply hardware key authentication?${NC}"
    echo -e "${YELLOW}You can select multiple options (e.g., '1 2 3' for all)${NC}\n"
else
    echo -e "${BLUE}Where do you want to apply facial recognition?${NC}"
    echo -e "${YELLOW}You can select multiple options (e.g., '1 2 3' for all)${NC}\n"
fi

# Update option descriptions based on what was set up
if [ "$SETUP_HARDWARE_KEY" = true ] && [ "$SETUP_FACIAL_RECOGNITION" = true ]; then
    echo -e "${GREEN}1)${NC} Greeter & Lock Screen"
    echo -e "   ${YELLOW}→ Use face OR hardware key to login/unlock${NC}\n"

    echo -e "${GREEN}2)${NC} Sudo commands (user privilege elevation)"
    echo -e "   ${YELLOW}→ Face OR hardware key OR password for sudo${NC}\n"

    echo -e "${GREEN}3)${NC} Root/su commands (switch to root user)"
    echo -e "   ${YELLOW}→ Face OR hardware key OR password for su${NC}\n"

    echo -e "${GREEN}4)${NC} Skip PAM configuration (manual setup later)"
    echo -e "   ${YELLOW}→ Authentication methods registered but not applied${NC}\n"
elif [ "$SETUP_HARDWARE_KEY" = true ]; then
    echo -e "${GREEN}1)${NC} Greeter & Lock Screen"
    echo -e "   ${YELLOW}→ Requires hardware key to login or unlock screen${NC}"
    echo -e "   ${RED}⚠ You MUST have your key to login/unlock!${NC}\n"

    echo -e "${GREEN}2)${NC} Sudo commands (user privilege elevation)"
    echo -e "   ${YELLOW}→ Hardware key OR password for sudo (flexible)${NC}\n"

    echo -e "${GREEN}3)${NC} Root/su commands (switch to root user)"
    echo -e "   ${YELLOW}→ Hardware key OR password for su (flexible)${NC}\n"

    echo -e "${GREEN}4)${NC} Register keys only (configure manually later)"
    echo -e "   ${YELLOW}→ Keys are registered but not applied to PAM${NC}\n"
else
    echo -e "${GREEN}1)${NC} Greeter & Lock Screen"
    echo -e "   ${YELLOW}→ Use facial recognition to login or unlock screen${NC}\n"

    echo -e "${GREEN}2)${NC} Sudo commands (user privilege elevation)"
    echo -e "   ${YELLOW}→ Face OR password for sudo (flexible)${NC}\n"

    echo -e "${GREEN}3)${NC} Root/su commands (switch to root user)"
    echo -e "   ${YELLOW}→ Face OR password for su (flexible)${NC}\n"

    echo -e "${GREEN}4)${NC} Skip PAM configuration (manual setup later)"
    echo -e "   ${YELLOW}→ Face model registered but not applied to PAM${NC}\n"
fi

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

    # Create system-login config with appropriate authentication methods
    if [ "$SETUP_HARDWARE_KEY" = true ] && [ "$SETUP_FACIAL_RECOGNITION" = true ]; then
        # Both hardware key AND facial recognition
        sudo tee /etc/pam.d/system-login > /dev/null << 'EOF'
#%PAM-1.0

# Facial recognition (if present, no other auth needed)
auth     sufficient pam_python.so /lib/security/howdy/pam.py

# Hardware key authentication (if present, no password needed)
auth     sufficient pam_u2f.so cue origin=pam://$(hostname) appid=pam://$(hostname)

# Password authentication (fallback)
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
    elif [ "$SETUP_HARDWARE_KEY" = true ]; then
        # Hardware key only
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
    else
        # Facial recognition only
        sudo tee /etc/pam.d/system-login > /dev/null << 'EOF'
#%PAM-1.0

# Facial recognition (if present, no password needed)
auth     sufficient pam_python.so /lib/security/howdy/pam.py

# Password authentication (fallback)
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
    fi

    echo -e "${GREEN}✓ Greeter and lock screen configured${NC}"
fi

# Apply to sudo (flexible authentication)
if [ "$APPLY_TO_SUDO" = true ]; then
    echo -e "\n${YELLOW}Configuring sudo with flexible authentication...${NC}"

    # Create sudo config based on authentication methods
    if [ "$SETUP_HARDWARE_KEY" = true ] && [ "$SETUP_FACIAL_RECOGNITION" = true ]; then
        # Both methods available
        sudo tee /etc/pam.d/sudo > /dev/null << 'EOF'
#%PAM-1.0

# Facial recognition (if present, no password needed)
auth     sufficient pam_python.so /lib/security/howdy/pam.py

# Hardware key (if present, no password needed)
auth     sufficient pam_u2f.so cue origin=pam://$(hostname) appid=pam://$(hostname)

# Fall back to password authentication
auth     include    system-auth

account  include    system-auth
session  include    system-auth
EOF
    elif [ "$SETUP_HARDWARE_KEY" = true ]; then
        # Hardware key only
        sudo tee /etc/pam.d/sudo > /dev/null << 'EOF'
#%PAM-1.0

# Hardware key (if present, no password needed)
auth     sufficient pam_u2f.so cue origin=pam://$(hostname) appid=pam://$(hostname)

# Fall back to password authentication
auth     include    system-auth

account  include    system-auth
session  include    system-auth
EOF
    else
        # Facial recognition only
        sudo tee /etc/pam.d/sudo > /dev/null << 'EOF'
#%PAM-1.0

# Facial recognition (if present, no password needed)
auth     sufficient pam_python.so /lib/security/howdy/pam.py

# Fall back to password authentication
auth     include    system-auth

account  include    system-auth
session  include    system-auth
EOF
    fi

    echo -e "${GREEN}✓ Sudo configured with flexible authentication${NC}"
fi

# Apply to su (root access - flexible authentication)
if [ "$APPLY_TO_SU" = true ]; then
    echo -e "\n${YELLOW}Configuring root/su with flexible authentication...${NC}"

    # Create su config based on authentication methods
    if [ "$SETUP_HARDWARE_KEY" = true ] && [ "$SETUP_FACIAL_RECOGNITION" = true ]; then
        # Both methods available
        sudo tee /etc/pam.d/su > /dev/null << 'EOF'
#%PAM-1.0

# Facial recognition (if present, no password needed)
auth     sufficient pam_python.so /lib/security/howdy/pam.py

# Hardware key (if present, no password needed)
auth     sufficient pam_u2f.so cue origin=pam://$(hostname) appid=pam://$(hostname)

# Fall back to password authentication
auth     sufficient pam_rootok.so
auth     required   pam_unix.so

account  required   pam_unix.so
session  required   pam_unix.so
EOF
    elif [ "$SETUP_HARDWARE_KEY" = true ]; then
        # Hardware key only
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
    else
        # Facial recognition only
        sudo tee /etc/pam.d/su > /dev/null << 'EOF'
#%PAM-1.0

# Facial recognition (if present, no password needed)
auth     sufficient pam_python.so /lib/security/howdy/pam.py

# Fall back to password authentication
auth     sufficient pam_rootok.so
auth     required   pam_unix.so

account  required   pam_unix.so
session  required   pam_unix.so
EOF
    fi

    echo -e "${GREEN}✓ Root/su configured with flexible authentication${NC}"
fi

echo -e "\n${GREEN}✓ PAM configuration completed${NC}"

# Summary
echo -e "\n${GREEN}╔═══════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║  Authentication Setup Complete!              ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════════════╝${NC}\n"

echo -e "${CYAN}Configuration Summary:${NC}"

# Show what was registered/configured
if [ "$SETUP_HARDWARE_KEY" = true ]; then
    echo -e "  ${GREEN}✓${NC} Hardware key registered: $HOME/.config/Yubico/u2f_keys"
fi

if [ "$SETUP_FACIAL_RECOGNITION" = true ]; then
    echo -e "  ${GREEN}✓${NC} Facial recognition configured (Howdy)"
fi

# Show where authentication was applied
if [ "$APPLY_TO_LOGIN" = true ]; then
    if [ "$SETUP_HARDWARE_KEY" = true ] && [ "$SETUP_FACIAL_RECOGNITION" = true ]; then
        echo -e "  ${GREEN}✓${NC} Greeter & Lock Screen: Face OR hardware key OR password"
    elif [ "$SETUP_HARDWARE_KEY" = true ]; then
        echo -e "  ${GREEN}✓${NC} Greeter & Lock Screen: Hardware key + password (required)"
    else
        echo -e "  ${GREEN}✓${NC} Greeter & Lock Screen: Face OR password"
    fi
    echo -e "  ${GREEN}✓${NC} GNOME Keyring: Auto-unlocks with password"
fi

if [ "$APPLY_TO_SUDO" = true ]; then
    if [ "$SETUP_HARDWARE_KEY" = true ] && [ "$SETUP_FACIAL_RECOGNITION" = true ]; then
        echo -e "  ${GREEN}✓${NC} Sudo: Face OR hardware key OR password"
    elif [ "$SETUP_HARDWARE_KEY" = true ]; then
        echo -e "  ${GREEN}✓${NC} Sudo: Hardware key OR password"
    else
        echo -e "  ${GREEN}✓${NC} Sudo: Face OR password"
    fi
fi

if [ "$APPLY_TO_SU" = true ]; then
    if [ "$SETUP_HARDWARE_KEY" = true ] && [ "$SETUP_FACIAL_RECOGNITION" = true ]; then
        echo -e "  ${GREEN}✓${NC} Root/su: Face OR hardware key OR password"
    elif [ "$SETUP_HARDWARE_KEY" = true ]; then
        echo -e "  ${GREEN}✓${NC} Root/su: Hardware key OR password"
    else
        echo -e "  ${GREEN}✓${NC} Root/su: Face OR password"
    fi
fi

if [ "$APPLY_TO_LOGIN" = false ] && [ "$APPLY_TO_SUDO" = false ] && [ "$APPLY_TO_SU" = false ]; then
    echo -e "  ${YELLOW}⚠${NC} No PAM configuration applied (authentication methods registered only)"
fi

echo -e ""
echo -e "${YELLOW}Important:${NC}"

if [ "$SETUP_HARDWARE_KEY" = true ]; then
    echo -e "  - Backup your hardware key registration file to a safe location"
    echo -e "  - Consider getting a backup hardware key (~\$25-30)"

    if [ "$APPLY_TO_LOGIN" = true ] && [ "$SETUP_FACIAL_RECOGNITION" = false ]; then
        echo -e "  - ${RED}You MUST have your hardware key to login/unlock${NC}"
    fi
fi

if [ "$SETUP_FACIAL_RECOGNITION" = true ]; then
    echo -e "  - Facial recognition works best in consistent lighting"
    echo -e "  - Add multiple face models for different lighting conditions"
    echo -e "  - Configure Howdy settings: sudo howdy config"
fi

if [ "$APPLY_TO_LOGIN" = true ] || [ "$APPLY_TO_SUDO" = true ] || [ "$APPLY_TO_SU" = true ]; then
    echo -e "  - PAM backups saved: /etc/pam.d/*.backup.*"
fi

if [ "$APPLY_TO_LOGIN" = true ] && [ "$SETUP_HARDWARE_KEY" = true ] && [ "$SETUP_FACIAL_RECOGNITION" = false ]; then
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
