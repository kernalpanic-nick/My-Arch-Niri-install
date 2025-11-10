# Secure Boot Setup with Limine on CachyOS

This guide provides step-by-step instructions for configuring secure boot with the Limine bootloader on CachyOS.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Understanding Limine's Secure Boot Approach](#understanding-limines-secure-boot-approach)
- [Step-by-Step Setup](#step-by-step-setup)
- [Configuration File Protection](#configuration-file-protection)
- [Automated Signing](#automated-signing)
- [Troubleshooting](#troubleshooting)

## Prerequisites

**UEFI Firmware Settings**:
1. Boot into UEFI/BIOS settings (typically F2, Del, or Esc during boot)
2. Enable Secure Boot
3. Set Secure Boot to "Setup Mode" (clear/delete existing keys)
4. Keep Secure Boot mode enabled

**Required Packages**:
```bash
sudo pacman -S sbctl
```

## Understanding Limine's Secure Boot Approach

Limine has a **unique approach** compared to other bootloaders like GRUB or systemd-boot:

- **Only the Limine EFI binary needs to be signed**
- Kernel images do NOT need signing (Limine bypasses EFI chainloading)
- Configuration file integrity is protected via BLAKE2B checksums

This simplifies secure boot significantly compared to other bootloaders.

## Step-by-Step Setup

### Phase 1: Key Generation and Enrollment

**1. Check Current Status**:
```bash
sbctl status
```

Expected output should show:
- Secure Boot: Disabled (we're in Setup Mode)
- Setup Mode: Enabled

**2. Create Custom Keys**:
```bash
sudo sbctl create-keys
```

This creates the key hierarchy in `/var/lib/sbctl/keys/`:
- PK (Platform Key)
- KEK (Key Exchange Key)
- db (Signature Database)

**3. Enroll Keys with Microsoft Certificates**:
```bash
sudo sbctl enroll-keys -m
```

**IMPORTANT**: The `-m` flag includes Microsoft's certificates. This is critical because:
- Some firmware is signed with Microsoft's keys
- Hardware devices may require Microsoft certificates for validation
- Omitting this can brick certain systems

### Phase 2: Signing Limine EFI Binary

**4. Identify Files Requiring Signatures**:
```bash
sudo sbctl verify
```

Typical unsigned files for Limine:
- `/boot/EFI/BOOT/BOOTX64.EFI` (Limine EFI binary)
- Possibly `/boot/EFI/limine/BOOTX64.EFI` (alternative location)

**5. Sign Limine EFI Binary**:
```bash
sudo sbctl sign -s /boot/EFI/BOOT/BOOTX64.EFI
```

The `-s` flag saves the file to the sbctl database for automatic re-signing.

If you have multiple locations:
```bash
sudo sbctl sign -s /boot/EFI/limine/BOOTX64.EFI
```

**6. Verify All Files Are Signed**:
```bash
sudo sbctl verify
```

All listed files should now show as "Signed".

### Phase 3: Enable Secure Boot

**7. Reboot and Enable Secure Boot**:
- Restart your system
- Enter UEFI/BIOS settings
- Ensure Secure Boot is ENABLED (not in Setup Mode)
- Save and exit

**8. Verify Secure Boot Status**:
```bash
sbctl status
```

Expected output:
```
Installed:      ✓ sbctl is installed
Owner GUID:     [your-guid]
Setup Mode:     ✗ Disabled
Secure Boot:    ✓ Enabled
```

## Configuration File Protection

### Automatic Configuration Protection

Limine automatically protects configuration integrity when `ENABLE_VERIFICATION=yes` is set in `/etc/default/limine`. This enables BLAKE2B checksum verification for all loaded files, including the configuration file itself.

No manual enrollment is required - Limine handles this internally.

### Important Configuration Setting

In `/etc/default/limine`, ensure verification is enabled:

```bash
# Edit /etc/default/limine and add/verify:
ENABLE_VERIFICATION=yes
```

After editing, regenerate the configuration:
```bash
sudo mkinitcpio -P && sudo limine-update
```

This enables Limine's built-in BLAKE2B checksum verification for all loaded files.

## Automated Signing

### sbctl Pacman Hook

sbctl automatically re-signs enrolled files when updates occur:

- Pacman hook: `/usr/share/libalpm/hooks/zz-sbctl.hook`
- Triggers on kernel, bootloader, and systemd updates
- Automatically re-signs all enrolled files

**No additional configuration needed** - it works automatically.

### Verification After Updates

After any bootloader or kernel updates:

```bash
# Check what sbctl is tracking
sudo sbctl list-files

# Verify all tracked files are signed
sudo sbctl verify

# Check Secure Boot status
sbctl status
```

## Troubleshooting

### System Won't Boot After Enabling Secure Boot

**Symptoms**: Black screen, "Signature verification failed" error, or boot loop

**Diagnosis**:
```bash
# Boot with Secure Boot disabled, then check:
sudo sbctl status
sudo sbctl verify
```

**Solutions**:

1. **Unsigned Limine Binary**:
   ```bash
   sudo sbctl sign -s /boot/EFI/BOOT/BOOTX64.EFI
   sudo sbctl verify
   ```

2. **Keys Not Enrolled**:
   ```bash
   # Check if keys exist
   ls -la /var/lib/sbctl/keys/

   # Re-enroll if necessary
   sudo sbctl enroll-keys -m
   ```

3. **Wrong Boot Entry**:
   ```bash
   # Check UEFI boot entries
   efibootmgr -v

   # Remove incorrect entry
   sudo efibootmgr -b XXXX -B

   # Create correct entry
   sudo efibootmgr --create --disk /dev/sdX --part Y \
     --label "CachyOS Limine" \
     --loader /EFI/BOOT/BOOTX64.EFI
   ```

### Firmware Doesn't Accept Custom Keys

**Symptoms**: Can't enroll keys, or Secure Boot won't enable

**Solutions**:
1. Set BIOS/UEFI administrator password first
2. Ensure Secure Boot is in "Setup Mode" (not just disabled)
3. Check manufacturer-specific requirements (some boards need specific settings)

### Limine Checksum Verification Failures

**Symptoms**: Boot fails with checksum errors

**Cause**: If you manually signed kernel images, their checksums changed and break Limine's verification

**Solution - Remove Kernel Signatures** (Recommended):
```bash
# Remove kernel signatures (not needed with Limine)
sudo sbctl remove-file /boot/vmlinuz-linux-cachyos
sudo sbctl remove-file /boot/initramfs-linux-cachyos.img

# Keep ENABLE_VERIFICATION=yes in /etc/default/limine
# Only Limine EFI binary should be signed
sudo sbctl list-files  # Should only show BOOTX64.EFI
```

### Emergency Recovery

**From Live USB**:
```bash
# Boot from CachyOS live USB
# Mount your system
sudo mount /dev/sdXY /mnt  # Root partition
sudo mount /dev/sdXZ /mnt/boot  # Boot partition (if separate)

# Arch-chroot into system
sudo arch-chroot /mnt

# Re-sign bootloader
sbctl sign -s /boot/EFI/BOOT/BOOTX64.EFI

# Verify
sbctl verify

# Exit and reboot
exit
sudo umount -R /mnt
sudo reboot
```

## Key Takeaways

**Critical Points**:

1. **Only sign Limine EFI binary** (`/boot/EFI/BOOT/BOOTX64.EFI`)
2. **Do NOT sign kernels** - Limine handles verification via checksums
3. **Always use `-m` flag** when enrolling keys to include Microsoft certificates
4. **Keep `ENABLE_VERIFICATION=yes`** in `/etc/default/limine`

**Complete Workflow**:
```bash
# One-time setup
sbctl create-keys
sbctl enroll-keys -m
sbctl sign -s /boot/EFI/BOOT/BOOTX64.EFI

# Enable Secure Boot in UEFI

# Verify
sbctl status  # Should show Secure Boot: Enabled
```

## Additional Resources

- **CachyOS Wiki**: https://wiki.cachyos.org/
- **Arch Wiki - Secure Boot**: https://wiki.archlinux.org/title/Unified_Extensible_Firmware_Interface/Secure_Boot
- **Arch Wiki - Limine**: https://wiki.archlinux.org/title/Limine
- **sbctl GitHub**: https://github.com/Foxboron/sbctl
