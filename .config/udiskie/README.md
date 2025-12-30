# Udiskie Automount Configuration

Udiskie is a front-end for udisks that allows automatic mounting of removable media (USB drives, external hard drives, SD cards, etc.).

## Configuration

### config.yml
Main configuration file for udiskie behavior:

**Program Options:**
- **tray**: Show system tray icon for easy access
- **notify**: Show desktop notifications on mount/unmount
- **automount**: Automatically mount new devices when connected
- **password_cache**: Cache passwords for encrypted devices (30 seconds)
- **password_prompt**: Use libsecret for password management

**Notification Settings:**
- Mount/unmount notifications with 5-second timeout
- Critical priority for failed operations
- Low priority for device add/remove events

**Device Mount Options:**
- **noatime**: Don't update access times (improves performance)
- **nosuid**: Disallow setuid binaries (security)
- **nodev**: Don't interpret device files (security)
- **noexec**: Don't allow execution of binaries (security)

These security options prevent malicious code on removable media from being executed automatically.

## Systemd Service

### udiskie.service
Systemd user service that manages the udiskie daemon:

**Service Configuration:**
- Starts after graphical session is ready
- Auto-restarts on failure (5-second delay)
- Runs as user service (not system-wide)
- Enabled by default (starts on login)

## Usage

**Check service status:**
```bash
systemctl --user status udiskie
```

**Restart service:**
```bash
systemctl --user restart udiskie
```

**View logs:**
```bash
journalctl --user -u udiskie -f
```

**Manual mount/unmount:**
```bash
# List devices
udiskie-info

# Mount specific device
udiskie-mount /dev/sdb1

# Unmount specific device
udiskie-umount /dev/sdb1

# Unmount all
udiskie-umount --all
```

## Integration with Niri

Udiskie is managed by systemd user service instead of being spawned by niri at startup. This provides:
- Better process management
- Automatic restart on failure
- Proper dependency ordering
- Centralized logging

The tray icon will appear in compatible system trays and show connected devices.

## Encrypted Devices

For LUKS-encrypted removable media:
1. Connect the device
2. Udiskie will prompt for the password
3. Password is cached for 30 seconds
4. Device is automatically mounted after unlock

Passwords are stored securely using libsecret (GNOME Keyring).

## Customization

**To change mount options:**
Edit `config.yml` and modify the `options` section under `device_config`.

**To disable automount:**
Set `automount: false` in the `program_options` section.

**To hide notifications:**
Set `notify: false` or adjust timeout values in the `notifications` section.

## Troubleshooting

**Udiskie not auto-mounting devices:**
1. Check service is running: `systemctl --user status udiskie`
2. Check logs: `journalctl --user -u udiskie -f`
3. Verify udisks2 is installed: `pacman -Q udisks2`

**Tray icon not showing:**
- Ensure you have a compatible system tray (DMS panel should support it)
- Check if udiskie is running with --tray option: `ps aux | grep udiskie`

**Permission errors:**
- User should be in the `storage` group: `groups | grep storage`
- Add to group if needed: `sudo usermod -aG storage $USER` (logout/login required)
