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
