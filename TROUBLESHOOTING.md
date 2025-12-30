# Troubleshooting Guide

## Installation Script Failure Investigation (Nov 2025)

### Problem Summary

The `install.sh` script failed during initial installation, leaving the system in an incomplete state with missing packages and configurations.

### What Was Missing After Failed Installation

- ❌ `python-dlib` (1 of 4 AUR packages) - Build failure
- ❌ All 14 flatpak applications - Script exited before reaching this step
- ❌ Config symlink (`~/.config/niri`) - Script exited before creating symlink

### What DID Install Successfully

- ✅ paru (AUR helper)
- ✅ All 201 official packages
- ✅ Hardware-specific drivers (auto-detected)
- ✅ 3 of 4 AUR packages (dms-shell-git, visual-studio-code-bin, opcode-bin)
- ✅ SDDM display manager (manually enabled)

### Root Cause Analysis

**Primary Issue**: The script used `set -e` which causes immediate exit on ANY error.

**Failure Point**: `python-dlib` failed to build during AUR package installation.

**Why python-dlib Failed**:
- Build failure with GCC 15.2.1 (CachyOS uses very recent compiler)
- Compiler warnings treated as errors
- Package likely not tested with GCC 15.2.1

**Cascade Effect**:
```
1. AUR package installation starts
2. python-dlib fails to build
3. Script exits immediately (set -e)
4. Flatpak installation never runs
5. Config symlink never created
6. User left with incomplete installation
```

## Fixes Implemented

### 1. Improved Error Handling (install.sh)

**Changes Made**:
- Removed `set -e` to prevent premature exit
- Added error tracking arrays (FAILED_PACKAGES, WARNINGS)
- Install packages one-by-one instead of batch
- Log all errors to `install.log`
- Continue installation even if individual packages fail

**Code Changes**:
```bash
# Before (batch installation, fails on any error):
packages=$(grep -v '^#' "$SCRIPT_DIR/packages-aur.txt" | grep -v '^$' | tr '\n' ' ')
$AUR_HELPER -S --needed --noconfirm $packages

# After (one-by-one with error tracking):
while IFS= read -r package; do
    [[ -z "$package" || "$package" =~ ^# ]] && continue
    if $AUR_HELPER -S --needed --noconfirm "$package" >> "$INSTALL_LOG" 2>&1; then
        echo -e "${GREEN}✓ $package installed successfully${NC}"
    else
        echo -e "${RED}✗ Failed to install $package${NC}"
        FAILED_PACKAGES+=("$package (AUR)")
    fi
done < "$SCRIPT_DIR/packages-aur.txt"
```

**Benefits**:
- Script completes even if some packages fail
- Clear visibility into which packages succeeded/failed
- Detailed error logs for debugging
- More resilient and idempotent

### 2. Disabled python-dlib (packages-aur.txt)

**Change**:
```diff
  dms-shell-git
  opcode-bin
- python-dlib
+ # python-dlib  # DISABLED: Fails to build with GCC 15.2.1 (compilation warnings treated as errors)
  visual-studio-code-bin
```

**Reason**: Package incompatible with GCC 15.2.1 used in CachyOS

### 3. Added Installation Summary

**New Feature**: Script now shows clear summary at completion:
```
=== Installation Complete! ===

⚠ Some packages failed to install:
  ✗ package-name (AUR)
  ✗ another-package (flatpak)

Check the log file for details: /home/chaos/My-Arch-Niri-install/install.log

Next steps:
  1. Reboot your system
  2. SDDM will start automatically
  3. Select 'niri' from the session menu
```

## Test Results

### Script Re-run Test (Nov 23, 2025)

**Command**: `./install.sh`

**Results**:
```
✅ Hardware detection: Successful (Intel CPU, Intel GPU)
✅ Official packages: All installed (using --needed, skipped already installed)
✅ Hardware packages: Installed successfully
✅ AUR packages: 3/3 installed successfully
✅ Flatpak apps: 14/14 installed successfully
✅ Config symlink: Created successfully
   - Old config backed up to: ~/.config/niri.backup.20251123_183132
   - New symlink: ~/.config/niri -> /home/chaos/My-Arch-Niri-install/.config/niri
✅ Error summary: Displayed correctly
✅ Install log: Created with detailed output
```

**Key Improvements Verified**:
1. Script continued despite already-installed packages
2. All flatpaks installed successfully (previously failed)
3. Config symlink created (previously missing)
4. Clear error reporting
5. Idempotent - safe to re-run

## Current System State

### Installed Components
- **Official packages**: 201/201 ✅
- **AUR packages**: 3/3 ✅ (python-dlib intentionally disabled)
- **Flatpak apps**: 14/14 ✅
- **Config symlink**: Created ✅ (bidirectional sync with repo)
- **SDDM**: Enabled ✅

### Configuration
- Config location: `~/.config/niri` (symlinked to repo)
- Config backup: `~/.config/niri.backup.20251123_183132`
- Install log: `/home/chaos/My-Arch-Niri-install/install.log`

## Common Issues & Solutions

### Issue: "sudo: a terminal is required to read the password"

**Cause**: Script requires sudo for package installation but doesn't have terminal access

**Solution**: Run script interactively from a terminal:
```bash
./install.sh
```

### Issue: Flatpak apps not installing

**Cause**: Script exited before reaching flatpak installation step

**Solution**: Fixed in latest version - script now continues even if earlier steps fail

### Issue: Config changes not syncing

**Cause**: `~/.config/niri` is a directory instead of symlink

**Solution**: Script now automatically creates symlink (backs up existing config first)

### Issue: python-dlib build failure

**Cause**: Incompatible with GCC 15.2.1

**Solution**: Package disabled in `packages-aur.txt`. If needed in future:
1. Wait for upstream fix
2. Use older GCC version
3. Patch build warnings

## Monitoring Installation

### Check Installation Log
```bash
tail -f ~/My-Arch-Niri-install/install.log
```

### Verify Installed Packages
```bash
# Check AUR packages
pacman -Q dms-shell-git visual-studio-code-bin opcode-bin

# Check flatpaks
flatpak list --app

# Verify SDDM
systemctl is-enabled sddm
```

### Check Config Symlink
```bash
ls -la ~/.config/niri
# Should show: niri -> /home/chaos/My-Arch-Niri-install/.config/niri
```

## Prevention for Future Installations

### Pre-Installation Checklist
1. ✅ Running on Arch Linux or CachyOS
2. ✅ Internet connection available
3. ✅ User has sudo privileges
4. ✅ Sufficient disk space (at least 5GB free)

### Post-Installation Verification
```bash
# Run this after installation completes
./install.sh  # Should skip already-installed packages
niri validate ~/.config/niri/config.kdl  # Verify config syntax
systemctl is-enabled sddm  # Verify SDDM enabled
```

## Lessons Learned

1. **Don't use `set -e` for installation scripts** - Individual package failures shouldn't abort entire installation
2. **Install packages one-by-one** - Better error tracking and recovery
3. **Always log errors** - Critical for debugging failed installations
4. **Make scripts idempotent** - Safe to re-run without side effects
5. **Test with real compiler versions** - Newer distributions may have incompatible toolchains

## Git Commits

All fixes committed and pushed to GitHub:

**Commit**: `018039e`
**Message**: "fix: improve install script resilience and disable python-dlib"
**Changes**:
- Modified `install.sh` (error handling improvements)
- Modified `packages-aur.txt` (disabled python-dlib)

## Additional Resources

- **Repository**: https://github.com/kernalpanic-nick/My-Arch-Niri-install
- **Install log**: `./install.log` (created during installation)
- **Niri documentation**: https://github.com/YaLTeR/niri
- **CachyOS**: https://cachyos.org/

## Support

If you encounter issues:

1. Check `install.log` for detailed error messages
2. Review this troubleshooting guide
3. Ensure all prerequisites are met
4. Try re-running the script (it's idempotent)
5. Report issues on GitHub with log file attached

## greetd Display Manager Issues

### greetd Service Won't Start

**Symptoms**:
- System boots to TTY instead of graphical greeter
- `systemctl status greetd` shows failed or inactive

**Checks**:
```bash
# Check greetd service status
systemctl status greetd

# Check greetd logs
journalctl -u greetd -b

# Verify greetd configuration
cat /etc/greetd/config.toml

# Check if greeter user exists
id greeter
```

**Common Fixes**:
1. **Greeter user doesn't exist**:
   ```bash
   sudo useradd -M -G video greeter
   sudo systemctl restart greetd
   ```

2. **Configuration file missing**:
   ```bash
   sudo cp ~/niri-setup/etc/greetd/config.toml /etc/greetd/
   sudo systemctl restart greetd
   ```

3. **DMS greeter not installed**:
   ```bash
   paru -S greetd-dms-greeter-git
   sudo systemctl restart greetd
   ```

### DMS Greeter Shows Black Screen

**Checks**:
```bash
# Check if niri is installed
which niri

# Check DMS greeter logs
journalctl -u greetd -b | grep dms-greeter

# Verify video group membership
groups greeter | grep video
```

**Fix**:
```bash
# Add greeter to video group if missing
sudo usermod -a -G video greeter
sudo systemctl restart greetd
```

## Hibernation Issues

### Hibernation Not Available

**Symptoms**:
- `systemctl hibernate` fails
- `/sys/power/state` doesn't include "disk"

**Checks**:
```bash
# Check if resume device is set
cat /sys/power/resume  # Should show major:minor (e.g., 253:0), NOT 0:0

# Check resume offset
cat /sys/power/resume_offset  # Should show swap file offset

# Check available power states
cat /sys/power/state  # Should include: freeze mem disk

# Check boot parameters
cat /proc/cmdline | grep resume

# Check swap status
swapon --show

# Check if resume-manual hook is in initramfs
lsinitcpio /boot/initramfs-linux-cachyos.img | grep resume-manual
```

**Common Fixes**:

1. **Resume device not set** (`/sys/power/resume` shows `0:0`):
   - Run hibernation setup script again:
     ```bash
     sudo ~/niri-setup/scripts/setup-hibernation.sh
     ```
   - Reboot to load new initramfs

2. **Swap file not created**:
   ```bash
   # Verify swap file exists
   ls -lh /swap/swapfile
   # Should be 40GB, owned by root with 600 permissions
   ```

3. **Resume hook missing from initramfs**:
   ```bash
   # Check mkinitcpio.conf
   grep "^HOOKS=" /etc/mkinitcpio.conf | grep resume-manual
   # Should include resume-manual after encrypt hook
   
   # If missing, regenerate initramfs
   sudo mkinitcpio -P
   ```

### Hibernation Image Not Found on Resume

**Symptoms**:
- System hibernates successfully
- On boot, system doesn't resume (normal boot instead)
- Kernel log shows "PM: Image not found (code -16)"

**Root Cause**: Swap activated too early, destroying hibernation image

**Checks**:
```bash
# Check if swap is marked as noauto in fstab
grep swap /etc/fstab  # Should show "noauto"

# Check if swapon-after-resume service exists and is enabled
systemctl status swapon-after-resume.service

# Check boot logs for swap activation
journalctl -b | grep -i "swap\|hibernat"
```

**Fix**:
```bash
# Ensure swap is noauto in fstab
sudo sed -i 's|/swap/swapfile.*|/swap/swapfile none swap noauto 0 0|' /etc/fstab

# Create and enable swapon-after-resume service
sudo cp ~/niri-setup/etc/systemd/system/swapon-after-resume.service /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable swapon-after-resume.service

# Reboot and test again
```

### Test Hibernation

After fixing issues, test hibernation:

```bash
# 1. Save all work and close applications

# 2. Hibernate
systemctl hibernate

# 3. Power on system

# 4. Check if session resumed
# - All applications should still be open
# - Terminal history preserved
# - No login prompt (direct resume)

# 5. Verify logs
journalctl -b -1 | grep -i "hibernat\|resume"
```

## ASUS Laptop Issues

### RGB/Fan Controls Not Working (Permission Denied)

**Symptom**: `asusctl` commands fail with permission errors or don't change settings

**Cause**: User not in `asus-users` group

**Fix**:
```bash
# Check if user is in asus-users group
groups | grep asus-users

# If not, add user to group
sudo usermod -aG asus-users $USER

# Log out and back in for changes to take effect
# Or use newgrp to activate group temporarily:
newgrp asus-users

# Verify group membership
groups
```

**Note**: The install script automatically adds users to the `asus-users` group, but you need to log out/in for it to take effect.

### asusctl Service Won't Start

**Checks**:
```bash
# Check asusd service status
systemctl status asusd

# Check logs
journalctl -u asusd -b

# Verify asusctl is installed
which asusctl
asusctl --version

# Ensure asus-users group exists
getent group asus-users
```

**Common Fixes**:
1. **Service not enabled**:
   ```bash
   sudo systemctl enable --now asusd
   ```

2. **Configuration issues**:
   ```bash
   # Reset to default config
   sudo cp ~/niri-setup/etc/asusd/asusd.ron /etc/asusd/
   sudo systemctl restart asusd
   ```

### RGB Keyboard Controls Not Working

**Symptoms**:
- `Mod+F4` doesn't cycle RGB modes
- `asusctl` commands fail

**Checks**:
```bash
# Test asusctl manually
asusctl aura -n

# Check if asusd is running
systemctl status asusd

# Check device permissions
ls -l /sys/class/leds/
```

**Fix**:
```bash
# Restart asusd service
sudo systemctl restart asusd

# Test RGB control
asusctl aura static -c ff0000  # Should show red

# If still not working, check dmesg for errors
dmesg | grep -i asus
```

### ROG Control Center Won't Launch

**Checks**:
```bash
# Verify installation
which rog-control-center

# Try launching from terminal to see errors
rog-control-center

# Check dependencies
paru -Q rog-control-center
```

**Fix**:
```bash
# Reinstall if needed
paru -S rog-control-center

# Ensure asusd is running
sudo systemctl start asusd
```

## DMS Plugin Issues

### Plugins Not Loading

**Symptoms**:
- Plugins don't appear in DMS bar
- Plugin settings show as disabled

**Checks**:
```bash
# Verify plugins directory
ls -la ~/.config/DankMaterialShell/plugins/

# Check plugin_settings.json
cat ~/.config/DankMaterialShell/plugin_settings.json

# Check DMS logs
journalctl --user -u dms -b
```

**Fix**:
```bash
# Re-deploy DMS configuration
cp -r ~/niri-setup/.config/DankMaterialShell/* ~/.config/DankMaterialShell/

# Restart DMS
systemctl --user restart dms
```

### ASUS Control Center Plugin Not Working

**Specific to asusControlCenter plugin**:

**Checks**:
```bash
# Verify asusd is running
systemctl status asusd

# Check plugin exists
ls ~/.config/DankMaterialShell/plugins/asusControlCenter/

# Ensure plugin is enabled
grep -A2 asusControlCenter ~/.config/DankMaterialShell/plugin_settings.json
```

**Fix**:
```bash
# Enable plugin if disabled
# Edit ~/.config/DankMaterialShell/plugin_settings.json
# Set "asusControlCenter": { "enabled": true }

# Restart DMS
systemctl --user restart dms
```

## General Debugging Commands

### Check All Critical Services

```bash
# Display manager
systemctl status greetd

# Niri compositor
systemctl --user status niri

# DMS shell
systemctl --user status dms

# ASUS control (if ASUS laptop)
systemctl status asusd
```

### View Recent Logs

```bash
# System boot log
journalctl -b

# Specific service logs
journalctl -u greetd -b
journalctl --user -u niri -b
journalctl --user -u dms -b
journalctl -u asusd -b

# Hibernation/resume logs
journalctl -b | grep -i "hibernat\|resume"
```

### Configuration Files to Check

```bash
# greetd
/etc/greetd/config.toml

# Niri
~/.config/niri/config.kdl

# DMS
~/.config/DankMaterialShell/settings.json
~/.config/DankMaterialShell/plugin_settings.json

# ASUS
/etc/asusd/asusd.ron

# Hibernation
/etc/fstab (swap noauto)
/etc/mkinitcpio.conf (resume-manual hook)
/boot/limine.conf (resume parameters)
/etc/systemd/logind.conf.d/power-management.conf
/etc/systemd/sleep.conf.d/hibernate-delay.conf
```
