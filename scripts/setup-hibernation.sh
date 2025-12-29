#!/bin/bash
#
# Hibernation Setup Script for CachyOS/Arch Linux with LUKS and Limine
#
# This script automates hibernation configuration with:
# - 40GB swap file on btrfs subvolume
# - Custom initramfs hooks for reliable resume
# - Limine bootloader parameter updates
# - Systemd configuration for suspend-then-hibernate
#
# Requirements:
# - LUKS-encrypted root filesystem
# - Limine bootloader
# - btrfs filesystem
# - Sufficient disk space (40GB+)
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"

echo -e "${GREEN}=== Hibernation Setup Script ===${NC}\n"

# Check if running as root
if [ "$(id -u)" -ne 0 ]; then
    echo -e "${RED}Error: This script must be run as root${NC}"
    echo "Usage: sudo $0"
    exit 1
fi

# Check for LUKS encryption
echo -e "${BLUE}Checking system requirements...${NC}"
if ! lsblk -f | grep -q "crypto_LUKS"; then
    echo -e "${RED}Error: No LUKS-encrypted filesystem detected${NC}"
    echo "Hibernation requires LUKS encryption for swap file resume."
    exit 1
fi
echo -e "${GREEN}✓ LUKS encryption detected${NC}"

# Check for Limine bootloader
if [ ! -f /boot/limine.conf ]; then
    echo -e "${RED}Error: Limine bootloader configuration not found${NC}"
    echo "This script is designed for Limine. For other bootloaders, manual configuration is required."
    exit 1
fi
echo -e "${GREEN}✓ Limine bootloader detected${NC}"

# Check for btrfs
if ! findmnt -n -o FSTYPE / | grep -q "btrfs"; then
    echo -e "${YELLOW}Warning: Root filesystem is not btrfs${NC}"
    echo "This script is optimized for btrfs. Continue anyway? [y/N]"
    read -r response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        exit 0
    fi
fi

# Check available disk space
available_space=$(df -BG / | awk 'NR==2 {print $4}' | sed 's/G//')
if [ "$available_space" -lt 45 ]; then
    echo -e "${YELLOW}Warning: Less than 45GB free space available${NC}"
    echo "Available: ${available_space}GB (Recommended: 45GB+)"
    echo "Continue anyway? [y/N]"
    read -r response
    if [[ ! "$response" =~ ^[Yy]$ ]]; then
        exit 0
    fi
fi

echo -e "\n${YELLOW}=== Hibernation Setup Configuration ===${NC}"
echo "This will:"
echo "  1. Create a 40GB swap file at /swap/swapfile"
echo "  2. Configure custom initramfs hooks for resume"
echo "  3. Update Limine bootloader configuration"
echo "  4. Configure suspend-then-hibernate (2 hour delay)"
echo "  5. Set up power management (lid closure behavior)"
echo ""
echo -e "${YELLOW}Continue? [y/N]${NC}"
read -r response
if [[ ! "$response" =~ ^[Yy]$ ]]; then
    echo "Setup cancelled"
    exit 0
fi

# Step 1: Create swap subvolume and swap file
echo -e "\n${BLUE}Step 1: Creating swap file...${NC}"

if [ -f /swap/swapfile ]; then
    echo -e "${YELLOW}Swap file already exists at /swap/swapfile${NC}"
    echo "Skip swap creation? [Y/n]"
    read -r response
    if [[ ! "$response" =~ ^[Nn]$ ]]; then
        echo "Skipping swap file creation"
    else
        rm /swap/swapfile
        echo "Removed existing swap file"
    fi
fi

if [ ! -f /swap/swapfile ]; then
    # Create swap subvolume if needed
    if [ ! -d /swap ]; then
        mkdir -p /swap
        # Disable CoW for swap directory
        chattr +C /swap 2>/dev/null || true
    fi

    # Create 40GB swap file
    echo "Creating 40GB swap file (this may take a few minutes)..."
    fallocate -l 40G /swap/swapfile
    chmod 600 /swap/swapfile
    mkswap /swap/swapfile
    echo -e "${GREEN}✓ Swap file created${NC}"
fi

# Step 2: Add swap to fstab with noauto flag
echo -e "\n${BLUE}Step 2: Configuring fstab...${NC}"

if ! grep -q "/swap/swapfile" /etc/fstab; then
    echo "/swap/swapfile none swap noauto 0 0" >> /etc/fstab
    echo -e "${GREEN}✓ Added swap to fstab with noauto flag${NC}"
else
    # Update existing entry to include noauto if missing
    if ! grep "/swap/swapfile" /etc/fstab | grep -q "noauto"; then
        sed -i 's|/swap/swapfile.*|/swap/swapfile none swap noauto 0 0|' /etc/fstab
        echo -e "${GREEN}✓ Updated fstab entry with noauto flag${NC}"
    else
        echo -e "${GREEN}✓ Fstab already configured correctly${NC}"
    fi
fi

# Step 3: Calculate swap file offset
echo -e "\n${BLUE}Step 3: Calculating swap file offset...${NC}"

SWAP_OFFSET=$(btrfs inspect-internal map-swapfile -r /swap/swapfile)
echo "Swap file offset: $SWAP_OFFSET"

# Step 4: Get LUKS device path
echo -e "\n${BLUE}Step 4: Detecting LUKS device...${NC}"

LUKS_DEVICE=$(findmnt -n -o SOURCE / | sed 's/\[.*\]//')
echo "LUKS device: $LUKS_DEVICE"

# Get device major:minor for /sys/power/resume
DEVICE_MAJOR_MINOR=$(stat -L -c '%t:%T' "$LUKS_DEVICE" | awk -F: '{printf "0x%s 0x%s\n", $1, $2}' | xargs printf '%d:%d\n')
echo "Device major:minor: $DEVICE_MAJOR_MINOR"

# Step 5: Copy initramfs hooks
echo -e "\n${BLUE}Step 5: Installing custom initramfs hooks...${NC}"

if [ -f "$REPO_DIR/etc/initcpio/hooks/resume-manual" ]; then
    cp "$REPO_DIR/etc/initcpio/hooks/resume-manual" /etc/initcpio/hooks/
    cp "$REPO_DIR/etc/initcpio/install/resume-manual" /etc/initcpio/install/
    echo -e "${GREEN}✓ Copied custom resume hooks${NC}"
else
    echo -e "${YELLOW}Warning: Custom hooks not found in repository${NC}"
    echo "Creating hooks from system templates..."

    # Create hooks directory
    mkdir -p /etc/initcpio/hooks /etc/initcpio/install

    # Create resume-manual hook
    cat > /etc/initcpio/hooks/resume-manual << 'EOF'
#!/usr/bin/ash
# Manual resume hook that bypasses systemd-hibernate-resume
# and directly sets /sys/power/resume

run_hook() {
    local resumedev resume rootdelay resume_offset

    # Check for noresume parameter
    noresume="$(getarg noresume)"
    if [ -n "$noresume" ]; then
        return 0
    fi

    # Get resume device and offset from kernel parameters
    resume="$(getarg resume)"
    resume_offset="$(getarg resume_offset)"

    if [ -z "$resume" ]; then
        return 0
    fi

    if [ ! -e /sys/power/resume ]; then
        err 'resume: no hibernation support found'
        return 1
    fi

    # Wait for device to be ready
    rootdelay="$(getarg rootdelay)"
    if resumedev="$(resolve_device "$resume" "$rootdelay")"; then
        # Get major:minor numbers
        # shellcheck disable=SC3001
        read -r major minor < <(stat -Lc '0x%t 0x%T' "$resumedev")

        # Set resume_offset if provided
        if [ -n "$resume_offset" ] && [ -e /sys/power/resume_offset ]; then
            printf '%s' "$resume_offset" > /sys/power/resume_offset
        fi

        # Trigger resume by writing to /sys/power/resume
        printf '%d:%d' "$major" "$minor" > /sys/power/resume
        return 0
    fi

    err "resume: hibernation device '$resume' not found"
    return 1
}

# vim: set ft=sh ts=4 sw=4 et:
EOF

    # Create install hook
    cat > /etc/initcpio/install/resume-manual << 'EOF'
#!/bin/bash
# Installation hook for manual resume

build() {
    add_runscript
}

help() {
    cat <<HELPEOF
This hook provides hibernation resume support, bypassing systemd-hibernate-resume
to directly control /sys/power/resume in the initramfs.
HELPEOF
}

# vim: set ft=sh ts=4 sw=4 et:
EOF

    chmod +x /etc/initcpio/hooks/resume-manual
    chmod +x /etc/initcpio/install/resume-manual
    echo -e "${GREEN}✓ Created custom resume hooks${NC}"
fi

# Step 6: Update mkinitcpio.conf
echo -e "\n${BLUE}Step 6: Updating mkinitcpio configuration...${NC}"

if grep -q "^HOOKS=.*resume-manual" /etc/mkinitcpio.conf; then
    echo -e "${GREEN}✓ mkinitcpio.conf already configured${NC}"
else
    # Backup current config
    cp /etc/mkinitcpio.conf /etc/mkinitcpio.conf.backup.$(date +%Y%m%d_%H%M%S)

    # Replace 'resume' with 'resume-manual' in HOOKS
    sed -i 's/\(HOOKS=.*\)resume\(.*\)/\1resume-manual\2/' /etc/mkinitcpio.conf

    # If resume-manual not in HOOKS, add it after encrypt
    if ! grep -q "resume-manual" /etc/mkinitcpio.conf; then
        sed -i 's/\(HOOKS=.*encrypt\)/\1 resume-manual/' /etc/mkinitcpio.conf
    fi

    echo -e "${GREEN}✓ Updated mkinitcpio.conf with resume-manual hook${NC}"
fi

# Step 7: Create swapon-after-resume service
echo -e "\n${BLUE}Step 7: Creating swapon-after-resume service...${NC}"

if [ -f "$REPO_DIR/etc/systemd/system/swapon-after-resume.service" ]; then
    cp "$REPO_DIR/etc/systemd/system/swapon-after-resume.service" /etc/systemd/system/
else
    cat > /etc/systemd/system/swapon-after-resume.service << 'EOF'
[Unit]
Description=Activate swap after hibernation resume
After=systemd-hibernate-resume.service
Before=swap.target
DefaultDependencies=no

[Service]
Type=oneshot
ExecStart=/usr/bin/swapon /swap/swapfile
RemainAfterExit=yes

[Install]
WantedBy=swap.target
EOF
fi

systemctl enable swapon-after-resume.service
echo -e "${GREEN}✓ Created and enabled swapon-after-resume.service${NC}"

# Step 8: Update Limine configuration
echo -e "\n${BLUE}Step 8: Updating Limine bootloader configuration...${NC}"

# Backup Limine config
cp /boot/limine.conf /boot/limine.conf.backup.$(date +%Y%m%d_%H%M%S)

# Add resume parameters to kernel command line
RESUME_PARAMS="resume=$LUKS_DEVICE resume_offset=$SWAP_OFFSET"

# Update both kernel entries if they exist
for kernel in "linux-cachyos" "linux-cachyos-lts"; do
    if grep -q ":$kernel:" /boot/limine.conf; then
        # Check if resume parameters already exist
        if ! grep -A5 ":$kernel:" /boot/limine.conf | grep "CMDLINE=" | grep -q "resume="; then
            # Add resume parameters to CMDLINE
            sed -i "/^:$kernel:/,/^CMDLINE=/ s|CMDLINE=\(.*\)|CMDLINE=\1 $RESUME_PARAMS|" /boot/limine.conf
            echo -e "${GREEN}✓ Updated $kernel entry${NC}"
        else
            echo -e "${GREEN}✓ $kernel entry already has resume parameters${NC}"
        fi
    fi
done

# Step 9: Configure power management
echo -e "\n${BLUE}Step 9: Configuring power management...${NC}"

# Create systemd config directories
mkdir -p /etc/systemd/logind.conf.d
mkdir -p /etc/systemd/sleep.conf.d

# Copy or create power management config
if [ -f "$REPO_DIR/etc/systemd/logind.conf.d/power-management.conf" ]; then
    cp "$REPO_DIR/etc/systemd/logind.conf.d/power-management.conf" /etc/systemd/logind.conf.d/
else
    cat > /etc/systemd/logind.conf.d/power-management.conf << 'EOF'
[Login]
HandleLidSwitch=suspend-then-hibernate
HandleLidSwitchExternalPower=suspend-then-hibernate
HandleLidSwitchDocked=ignore
EOF
fi
echo -e "${GREEN}✓ Configured lid closure behavior${NC}"

# Configure hibernate delay
if [ -f "$REPO_DIR/etc/systemd/sleep.conf.d/hibernate-delay.conf" ]; then
    cp "$REPO_DIR/etc/systemd/sleep.conf.d/hibernate-delay.conf" /etc/systemd/sleep.conf.d/
else
    cat > /etc/systemd/sleep.conf.d/hibernate-delay.conf << 'EOF'
[Sleep]
HibernateDelaySec=2h
EOF
fi
echo -e "${GREEN}✓ Configured hibernate delay (2 hours)${NC}"

# Step 10: Regenerate initramfs
echo -e "\n${BLUE}Step 10: Regenerating initramfs...${NC}"

mkinitcpio -P

echo -e "\n${GREEN}=== Hibernation Setup Complete! ===${NC}"
echo ""
echo -e "${YELLOW}Important Information:${NC}"
echo "  • Swap file: /swap/swapfile (40GB)"
echo "  • Resume device: $LUKS_DEVICE"
echo "  • Resume offset: $SWAP_OFFSET"
echo "  • Device major:minor: $DEVICE_MAJOR_MINOR"
echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo "  1. Reboot your system to load the new initramfs"
echo "  2. After reboot, verify hibernation is configured:"
echo "     cat /sys/power/resume  # Should show: ${DEVICE_MAJOR_MINOR}"
echo "     cat /sys/power/resume_offset  # Should show: ${SWAP_OFFSET}"
echo "     cat /sys/power/state  # Should include: disk"
echo "  3. Test hibernation: systemctl hibernate"
echo ""
echo -e "${YELLOW}Power Management:${NC}"
echo "  • Lid closure: suspend-then-hibernate"
echo "  • Hibernate delay: 2 hours in suspend"
echo "  • Swayidle configured for 5/10/15 minute timeouts"
echo ""
echo -e "${YELLOW}Troubleshooting:${NC}"
echo "  • Check kernel logs: journalctl -b -0 | grep -i 'hibernat\\|resume'"
echo "  • Verify boot parameters: cat /proc/cmdline"
echo "  • Check swap status: swapon --show"
echo ""
