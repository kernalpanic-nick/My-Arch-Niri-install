# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Context

**This Repository:** `/home/chaos/niri-setup/`
- Git remote: https://github.com/kernalpanic-nick/My-Arch-Niri-install
- Complete Arch Linux + Niri installation automation
- Includes configuration files, scripts, and documentation
- Active niri config location: `/home/chaos/.config/niri/` (deployed from this repository)

**Repository Structure:**
```
/home/chaos/niri-setup/
├── .config/niri/           # Niri configuration files
│   ├── config.kdl          # Main niri config (593 lines)
│   ├── dms/                # DMS modular configs
│   └── scripts/            # Helper scripts (monitor config, workspace setup)
├── .config/DankMaterialShell/  # DMS configuration
│   ├── settings.json       # DMS settings (sanitized)
│   ├── plugin_settings.json
│   └── plugins/            # 6 pre-installed plugins
├── wallpapers/             # 11 desktop wallpapers (6MB)
├── etc/                    # System config templates
│   ├── greetd/            # greetd display manager config
│   ├── asusd/             # ASUS laptop configuration
│   ├── systemd/           # Power management configs
│   └── initcpio/          # Custom hibernation resume hooks
├── scripts/
│   └── setup-hibernation.sh  # Hibernation setup automation
├── packages-official.txt   # Official repository packages
├── packages-aur.txt        # AUR packages
├── install.sh              # Main installation script
├── README.md               # User-facing documentation
├── TROUBLESHOOTING.md      # Troubleshooting guide
├── SECURE_BOOT.md          # Secure boot setup guide
└── CLAUDE.md               # This file (AI assistant guidance)
```

## Authentication and Security

### Two-Factor Authentication Setup

**System Login (Greeter/Lock Screen):**
- **YubiKey REQUIRED** - No password-only fallback
- **sudo commands**: YubiKey OR password (either works, flexible authentication)
- **GNOME Keyring**: Auto-unlocked with login password (no separate unlock needed)
- **Backup plan**: Get a second YubiKey and register it

**YubiKey Configuration:**
- Device: YubiKey 5 NFC (Serial: 20451143)
- Registered keys stored in: `/home/chaos/.config/Yubico/u2f_keys`
- PAM module: `pam_u2f.so`
- Origin/AppID: `pam://Chaos-G14-Arch`
- **Important**: YubiKey must be present to login or unlock screen

### Authentication Flows

**Logging in at greeter/lock screen:**
1. Enter username (if needed)
2. Touch YubiKey when prompted
3. Enter regular password
4. Login successful
5. **Without YubiKey**: Login will fail (by design for security)

**Using sudo in terminal:**
- **Option 1**: Touch YubiKey when prompted (if plugged in, no password needed)
- **Option 2**: Enter password (if YubiKey not available)
- Flexible authentication - either method works

### PAM Configuration Files

**System Login (Greeter/TTY/Lock Screen):**
- Config: `/etc/pam.d/system-login`
- Backup: `/etc/pam.d/system-login.backup.*`
- Uses: `pam_u2f.so` (YubiKey required), `pam_gnome_keyring.so` (auto-unlock keyring)

**Sudo:**
- Config: `/etc/pam.d/sudo`
- Backup: `/etc/pam.d/sudo.backup.*`
- Uses: `pam_u2f.so` (sufficient) + `system-auth` (either YubiKey or password works)

**GNOME Keyring:**
- Auto-unlocked via `pam_gnome_keyring.so` in system-login
- Keyring unlocks automatically when you login with your password
- No separate keyring password prompt needed
- Keyring daemon auto-starts via PAM session module

### Emergency Recovery

**If YubiKey is lost or not working:**

1. **Boot from live USB** (or boot to GRUB/bootloader)
2. **Decrypt and mount root filesystem:**
   ```bash
   # Example (adjust device names as needed)
   cryptsetup open /dev/nvme0n1p2 luks
   mount /dev/mapper/luks /mnt
   ```
3. **Temporarily disable U2F requirement:**
   ```bash
   # Edit the PAM config
   nano /mnt/etc/pam.d/system-login
   # Comment out the pam_u2f.so line by adding # at the start
   # Save and exit
   ```
4. **Reboot and log in** with regular password only
5. **Register new YubiKey** or restore from backup
6. **Re-enable U2F** by uncommenting the line in system-login

**To register additional YubiKeys (RECOMMENDED - do this soon!):**
```bash
# With the new YubiKey inserted (and current YubiKey working)
sudo -u chaos pamu2fcfg -o pam://Chaos-G14-Arch -i pam://Chaos-G14-Arch >> /home/chaos/.config/Yubico/u2f_keys

# Verify both keys are registered
cat /home/chaos/.config/Yubico/u2f_keys
# Should show two lines starting with "chaos:"
```

**Backup your U2F keys file:**
```bash
# Copy to a safe location (encrypted USB drive, cloud storage, etc.)
cp /home/chaos/.config/Yubico/u2f_keys ~/backup-u2f-keys.txt
```

### Important Security Notes

- **YubiKey required for**: System login (greeter), lock screen, TTY login
- **YubiKey optional for**: sudo (can use password instead)
- **No password-only fallback for login**: YubiKey must be present to unlock/login
- **GNOME Keyring**: Automatically unlocks with login password (no manual unlock needed)
- **Backup your YubiKey registration**: Keep a copy of `/home/chaos/.config/Yubico/u2f_keys` in a safe place
- **CRITICAL: Get a second YubiKey**: Register a backup key (~$25-30) and store it separately from your primary key
- **Emergency access**: If YubiKey is lost, you'll need to boot from live USB to recover access

## Working with the Niri Configuration

### Configuration Locations

**Active Configuration:**
- `/home/chaos/.config/niri/` - Currently active niri configuration
  - `config.kdl` - Main niri config (~550 lines, KDL format)
  - `dms/` - DMS modular configs (binds, colors, layout, wpblur)
  - `scripts/configure-monitors.sh` - Auto monitor configuration

**Source Repository:**
- `/home/chaos/niri-setup/.config/niri/` - Original source configs
- Configuration files were copied from here to active location
- Can be used as reference or for updates

### Key Commands

**Reload Niri Configuration:**
```bash
niri msg action load-config-file
```

**Validate Configuration:**
```bash
cd ~/.config/niri && niri validate
```

**View Connected Monitors:**
```bash
niri msg outputs
```

**Reconfigure Monitors:**
```bash
~/.config/niri/scripts/configure-monitors.sh
# Or use keybinding: Mod+Shift+M
```

**Check Niri Logs:**
```bash
journalctl --user -u niri
```

**Test DMS IPC:**
```bash
dms ipc call spotlight toggle
dms ipc call clipboard toggle
dms ipc call processlist toggle
```

### Architecture Overview

**Niri Window Manager:**
- Scrollable-tiling Wayland compositor
- KDL-based configuration
- Configured at `/home/chaos/.config/niri/config.kdl`

**DMS (DankMaterialShell) Integration:**
- Desktop shell providing panel, launcher, clipboard, notifications, lock screen
- Started via systemd user service: `/usr/lib/systemd/user/dms.service` (enabled)
- **NOT** started via spawn-at-startup (this would create duplicate instances)
- All system functions delegated via `dms ipc call` commands
- Package: `dms-shell-bin` (installed)

**Configuration Structure:**
```
~/.config/niri/
├── config.kdl           # Main config with includes
├── dms/                 # Modular DMS configs
│   ├── binds.kdl       # DMS keybindings (IPC calls)
│   ├── colors.kdl      # Color scheme
│   ├── layout.kdl      # Layout settings (gaps, borders)
│   └── wpblur.kdl      # Wallpaper blur layer rules
└── scripts/
    ├── configure-monitors.sh  # Interactive monitor configuration
    ├── identify-monitor.sh    # Visual monitor identification helper
    └── setup-workspaces.sh    # Workspace & app configuration wizard
```

### Helper Scripts

**configure-monitors.sh** - Interactive Monitor Configuration
- **Location**: `~/.config/niri/scripts/configure-monitors.sh`
- **Keybinding**: `Mod+Shift+M`
- **Features**:
  - Auto-detects all connected monitors
  - Visual monitor identification (shows large numbers on each monitor)
  - Two configuration modes:
    - **Quick setup [1]**: Auto-selects best settings (highest resolution/refresh)
    - **Custom setup [2]**: Interactive per-monitor configuration
  - Configurable per monitor: resolution, refresh rate, scale factor
  - Monitor ordering (left-to-right physical arrangement)
  - Validates all input with sensible defaults
  - Backs up config before applying changes
  - Automatically reloads niri configuration
- **Visual Identification**: For multi-monitor setups, especially useful with identical monitors
  - Shows large numbered identifier on each monitor for 3 seconds
  - Displays monitor number, connector name, and model
  - Uses kitty terminal with 48pt green text on black background
  - Automatically positions windows on correct monitors

**setup-workspaces.sh** - Workspace & Application Configuration Wizard
- **Location**: `~/.config/niri/scripts/setup-workspaces.sh`
- **Purpose**: Interactive setup of named workspaces and auto-launching applications
- **Features**:
  - Configure 1-10 named workspaces with custom names
  - Set up auto-launching applications with workspace assignments
  - Collects app commands, app-ids, and workspace placement
  - Generates proper KDL configuration snippets
  - Outputs to `~/workspace-setup.kdl` for manual integration
  - Validates all user input with helpful examples
- **Use Case**: Perfect for setting up workspace-based workflows (browser, dev, chat workspaces)

**identify-monitor.sh** - Standalone Monitor Identifier
- **Location**: `~/.config/niri/scripts/identify-monitor.sh`
- **Usage**: `./identify-monitor.sh <monitor_number> <connector_name>`
- **Purpose**: Quick visual identification of a specific monitor
- **Used By**: configure-monitors.sh for multi-monitor identification

**Key Configuration Sections:**
- **Named Workspaces** (lines 10-12): browser, dev, chat (Mod+1, Mod+2, Mod+3)
- **Startup commands** (lines 136-151): polkit, keyring, swayidle, auto-start apps
- **Environment** (lines 152-160): Wayland/Qt/Electron variables, TERMINAL=kitty, EDITOR=nvim
- **Window rules** (lines 196-367): App-specific floating, opacity, workspace assignments
- **Keybindings** (lines 369+): 100+ organized by category
- **Animations**: Spring-based smooth transitions
- **Input**: Touchpad scroll-factor set to 10 (slower scrolling)

### Common Tasks

**Edit Keybindings:**
1. Edit `/home/chaos/.config/niri/config.kdl` (lines 327-526) or
2. Edit `/home/chaos/.config/niri/dms/binds.kdl` for DMS-specific binds
3. Reload: `niri msg action load-config-file`

**Add New Application Rules:**
1. Find app-id: Run app, then `niri msg windows | grep -i "app_name"`
2. Add window-rule block to config.kdl
3. Reload config

**Change Color Scheme:**
1. Edit `/home/chaos/.config/niri/dms/colors.kdl`
2. Reload config

**Modify Layout (gaps, borders):**
1. Edit `/home/chaos/.config/niri/dms/layout.kdl`
2. Reload config

**Update Startup Applications:**
1. Edit spawn-at-startup lines in config.kdl (lines 145-151)
2. Reload config (or restart niri session)

### Named Workspaces and Auto-start Applications

**Current Workspace Setup:**
- **browser** (workspace 1): Vivaldi, Protonmail
- **dev** (workspace 2): Kitty (terminal), Zed (editor)
- **chat** (workspace 3): Signal, Discord

**Auto-start applications** are configured with workspace assignments using `open-on-workspace` window rules:
```kdl
window-rule {
    match at-startup=true app-id=r#"^vivaldi-stable$"#
    open-on-workspace "browser"
}
```

**Important Notes:**
- Named workspaces are defined at the top of config.kdl (lines 10-12) in order: browser, dev, chat
- **Workspace numbering**: Workspaces are numbered in the order they're defined (Mod+1=browser, Mod+2=dev, Mod+3=chat)
- **Changing workspace order**: Workspace numbers are assigned at session start - reloading config won't renumber them
  - To apply workspace order changes, you must restart niri (logout/login)
- Workspace assignments only trigger at startup (`at-startup=true`)
- To add new auto-start apps: Add `spawn-at-startup` command + window rule with workspace assignment
- Named workspaces always exist, even when empty
- Applications spawn in order, workspace assignments place them correctly

**Finding App-IDs:**
```bash
niri msg windows | grep -i "app_name"
# Or check desktop files:
grep "StartupWMClass=" /usr/share/applications/*.desktop
```

### DMS Features & Keybindings

- **Mod+Space** - Application launcher (spotlight)
- **Mod+V** - Clipboard manager
- **Mod+M** - Task manager (process list)
- **Mod+Comma** - Settings
- **Mod+N** - Notification center
- **Mod+Y** - Wallpaper browser
- **Mod+Shift+N** - Notepad
- **Mod+Alt+L** - Lock screen
- **XF86 keys** - Audio/brightness control (via DMS)

### RGB/Aura Keyboard Lighting (ASUS ROG)

**Important**: User must be in the `asus-users` group to control ASUS hardware features.
- The install script automatically adds users to this group during installation
- **You must log out and back in** after installation for group membership to take effect
- Check membership: `groups | grep asus-users`
- Manual add: `sudo usermod -aG asus-users $USER`

**Keyboard Backlight Brightness:**
- **Fn+F2** - Decrease keyboard brightness
- **Fn+F3** - Increase keyboard brightness

**RGB Mode Cycling:**
- **Mod+F4** - Cycle through RGB modes/colors

**Manual RGB Control (Terminal):**
```bash
# Static colors
asusctl aura static -c ff0000  # Red
asusctl aura static -c 00ff00  # Green
asusctl aura static -c 0000ff  # Blue
asusctl aura static -c ff00ff  # Purple
asusctl aura static -c 00ffff  # Cyan
asusctl aura static -c ffffff  # White

# Effects
asusctl aura rainbow-cycle      # Rainbow cycling
asusctl aura breathe -c ff0000  # Breathing effect (red)
asusctl aura pulse -c ff00ff    # Pulsing effect (purple)

# Cycle modes
asusctl aura -n  # Next mode
asusctl aura -p  # Previous mode

# Keyboard brightness
asusctl -k off   # Turn off
asusctl -k low   # Low brightness
asusctl -k med   # Medium brightness
asusctl -k high  # High brightness
```

**Configuration:**
- Package: `asusctl` (installed)
- Daemon: `asusd.service` (running)
- Control center: `rog-control-center` (installed, GUI app)

### Important Notes

**DMS Dependency:**
- Most keybindings require DMS running
- DMS auto-starts via systemd user service (`dms.service`)
- If DMS not running, IPC calls fail silently
- Check DMS status: `systemctl --user status dms`

**Monitor Configuration:**
- Auto-configured on first niri startup
- Manual reconfiguration: Mod+Shift+M
- Script backs up config before changes

**Configuration Files:**
- Active config at `~/.config/niri/` is NOT symlinked
- Files were copied from `/home/chaos/niri-setup/`
- Changes must be manually synced if needed
- **CRITICAL**: Config files must be owned by user `chaos:chaos` with at least `644` permissions
- If niri can't read config.kdl, it runs with fallback config and keybindings won't work

**greetd Display Manager with DMS Greeter:**
- Enabled and running (`systemctl status greetd`)
- Uses DMS greeter for graphical login
- Automatically starts niri session
- Configuration: `/etc/greetd/config.toml`
- DMS greeter package: `greetd-dms-greeter-git` (AUR)

### Troubleshooting

**Keybindings not working:**
1. **Check config file permissions** (most common issue):
   ```bash
   ls -la ~/.config/niri/config.kdl
   # Should show: -rw-r--r-- 1 chaos chaos
   # If owned by root, fix with:
   sudo chown chaos:chaos ~/.config/niri/config.kdl
   sudo chmod 644 ~/.config/niri/config.kdl
   niri msg action load-config-file
   ```
2. Check if DMS is running: `ps aux | grep dms`
3. Check niri logs for permission errors: `journalctl --user -u niri | grep -i "permission\|error"`
4. Test IPC manually: `dms ipc call spotlight toggle`

**Monitor issues:**
- Re-run configure script: `~/.config/niri/scripts/configure-monitors.sh`
- Or use keybinding: Mod+Shift+M
- Check outputs: `niri msg outputs`

**Configuration errors:**
- Validate: `cd ~/.config/niri && niri validate`
- Check logs: `journalctl --user -u niri`
- Backup available at: `~/.config/niri.backup.*`
- **Common config constraints:**
  - `scroll-factor` must be between 0-100 (not negative values, currently set to 10)
  - All spawn commands must use valid paths in `$PATH`

## Power Management

### Idle and Sleep Configuration

**Idle Management (via swayidle):**
- **5 min idle**: Lock screen (`dms ipc call lock lock`)
- **10 min idle**: Turn off monitors (`niri msg action power-off-monitors`)
- **15 min idle**: Suspend-then-hibernate (`systemctl suspend-then-hibernate`)
- **On resume**: Turn monitors back on
- **Before sleep**: Lock screen

**Lid Closure Behavior:**
- Configured via `/etc/systemd/logind.conf.d/power-management.conf`
- **Lid close**: suspend-then-hibernate
- **Lid close on AC power**: suspend-then-hibernate
- **Lid close when docked**: ignored

**Suspend-then-Hibernate:**
- Configured via `/etc/systemd/sleep.conf.d/hibernate-delay.conf`
- System suspends first (fast, low power)
- After **2 hours** in suspend, automatically hibernates (zero power, persists to disk)
- This provides quick resume for short breaks, full hibernation for long periods

**Configuration Files:**
```bash
# Logind configuration (lid behavior)
/etc/systemd/logind.conf.d/power-management.conf

# Sleep configuration (hibernate delay)
/etc/systemd/sleep.conf.d/hibernate-delay.conf

# Swayidle configuration (in niri config.kdl, line ~142)
spawn-at-startup "swayidle" "-w" ...
```

**Testing Power Management:**
```bash
# Test suspend-then-hibernate
systemctl suspend-then-hibernate

# Check logind configuration
systemd-analyze cat-config systemd/logind.conf

# Check sleep configuration
systemd-analyze cat-config systemd/sleep.conf
```

### Editor Configuration

**Default Editors:**
- **Terminal/CLI**: `EDITOR=nvim` (set in config.kdl environment)
- **File Manager**: Zed (`dev.zed.Zed.desktop` is default for text/plain MIME type)

**Verify editor settings:**
```bash
# Check terminal editor
echo $EDITOR  # Should show: nvim

# Check file manager default
xdg-mime query default text/plain  # Should show: dev.zed.Zed.desktop
```

## Swap and Hibernation

### Swap Configuration

The system has **78GB total swap** configured for optimal performance and hibernation support:

1. **40GB swap file** at `/swap/swapfile` (priority -2)
   - Located on btrfs subvolume `/swap`
   - Sized to support hibernation (≥ 38GB RAM)
   - Resume offset: `5252352`

2. **38.4GB zram0** (priority 100)
   - Compressed RAM-based swap
   - Higher priority, used first for better performance
   - Configured via systemd-zram-setup

### Hibernation Status

**✅ Hibernation is NOW WORKING** with the following configuration:

**Boot Configuration:**
- Bootloader: Limine (EFI)
- Config: `/boot/limine.conf`
- Resume device: `/dev/mapper/luks-f49af5cd-8582-479e-abbf-1e70d28d8725` (dm-0, major:minor 253:0)
- Resume offset: `5252352`
- Kernel parameters include: `resume=/dev/mapper/luks-f49af5cd-8582-479e-abbf-1e70d28d8725 resume_offset=5252352`
- **IMPORTANT**: Uses device path (not UUID) for reliable resume from encrypted swap

**Initramfs Configuration:**
- `/etc/mkinitcpio.conf` includes custom `resume-manual` hook
- Hook order: `... encrypt resume-manual filesystems ...` (resume MUST be after encrypt)
- Custom hook bypasses systemd-hibernate-resume for direct control

**Swap File Activation:**
- `/etc/fstab`: Swap marked as `noauto` to prevent automatic activation
- `/etc/systemd/system/swapon-after-resume.service`: Activates swap only after resume check
- This prevents swap activation from destroying the hibernation image

**Critical Fixes Applied:**

**Fix #1: Resume device configuration (2025-12-18 morning):**
- Created `/etc/systemd/system/setup-resume.service` to set `/sys/power/resume` at boot
- This fixed the issue where systemd-hibernate-resume doesn't properly configure the resume device
- Service sets `253:0` (dm-0 device) to `/sys/power/resume` at boot time
- **Status**: Later replaced by Fix #3 (initramfs-based resume)

**Fix #2: Resume parameter format (2025-12-18 afternoon):**
- Changed boot parameter from `resume=UUID=...` to `resume=/dev/mapper/luks-...`
- **Issue**: With encrypted swap, UUID resolution during early boot was unreliable
- **Symptom**: Kernel error "PM: Image not found (code -16)" during boot
- **Root Cause**: Resume hook couldn't find hibernation image using UUID before device fully initialized
- **Solution**: Use device mapper path directly, which is available after encrypt hook runs
- Updated `/boot/limine.conf` for both linux-cachyos and linux-cachyos-lts kernels

**Fix #3: Prevent swap from destroying hibernation image (2025-12-18 evening):**
- **Issue**: `swapon` was destroying the hibernation image before kernel could resume from it
- **Symptom**: Log showed "swapon: /swap/swapfile: software suspend data detected. Rewriting the swap signature."
- **Root Cause**: Swap was being activated too early during boot, overwriting the hibernation signature
- **Solution**:
  - Created custom initramfs hooks: `/etc/initcpio/hooks/resume-manual` and `/etc/initcpio/install/resume-manual`
  - Modified `/etc/fstab` to mark swap as `noauto`
  - Created `swapon-after-resume.service` to activate swap after boot completes
  - Updated initramfs to use `resume-manual` hook instead of default `resume`
  - Disabled `setup-resume.service` (no longer needed)

**How Resume Works Now:**
1. Initramfs loads and unlocks encrypted device (encrypt hook)
2. `resume-manual` hook sets `/sys/power/resume_offset` and `/sys/power/resume`
3. Kernel checks for hibernation image and resumes if found
4. Boot completes and `swapon-after-resume.service` activates swap
5. Swap activation happens AFTER resume, so hibernation image is preserved

**Verification (2025-12-18):**
- ✅ `/sys/power/resume` correctly shows `253:0`
- ✅ `/sys/power/resume_offset` shows `5252352`
- ✅ `/sys/power/state` includes `disk` mode
- ✅ `/sys/power/disk` shows available hibernation modes
- ✅ `resume-manual` hook present in initramfs
- ✅ Swap marked as `noauto` in fstab
- ✅ `swapon-after-resume.service` enabled
- ✅ Hibernation is fully functional

### Using Hibernation

**Hibernate the system:**
```bash
systemctl hibernate
```

**Or via DMS power menu:**
- Access power menu and select hibernate option
- Note: DMS must be running for this to work

**Verify hibernation is configured:**
```bash
# Check boot parameters include resume
cat /proc/cmdline | grep resume

# Check resume device is set (should show 253:0, NOT 0:0)
cat /sys/power/resume

# Check available power states (should show: freeze mem disk)
cat /sys/power/state

# Check swap is active
swapon --show
```

**Important Notes:**
- Resume happens in initramfs via custom `resume-manual` hook
- Swap file is NOT activated during early boot to preserve hibernation image
- Swap activation is delayed until after resume check completes
- After hibernating, the system will resume from the encrypted swap file

**Troubleshooting hibernation:**

**Common Issue #1: Resume device not set (FIXED)**
- **Problem**: `/sys/power/resume` shows `0:0` instead of `253:0`
- **Symptom**: `systemctl hibernate` fails, "disk" not in `/sys/power/state`
- **Root Cause**: systemd-hibernate-resume only clears EFI variable, doesn't set resume device
- **Solution**: Custom `resume-manual` initramfs hook now handles this in early boot
- **Fix Applied**: 2025-12-18 evening (Fix #3)

**Common Issue #2: Resume image not found (FIXED)**
- **Problem**: System hibernates successfully but doesn't resume properly on boot
- **Symptom**: Kernel log shows "PM: Image not found (code -16)" during early boot
- **Root Cause**: Using `resume=UUID=...` doesn't work reliably with encrypted swap
- **Solution**: Changed to `resume=/dev/mapper/luks-...` in bootloader configuration
- **Fix Applied**: 2025-12-18 afternoon (Fix #2)

**Common Issue #3: Swap destroys hibernation image (FIXED)**
- **Problem**: Hibernation image is destroyed before kernel can resume
- **Symptom**: "swapon: software suspend data detected. Rewriting the swap signature."
- **Root Cause**: Swap was activated too early during boot
- **Solution**: Swap marked as `noauto` in fstab, activated only after boot completes
- **Fix Applied**: 2025-12-18 evening (Fix #3)

**If hibernation still doesn't work:**

1. **Check if resume device and offset are set:**
   ```bash
   cat /sys/power/resume         # Should show: 253:0
   cat /sys/power/resume_offset  # Should show: 5252352
   ```

2. **Verify resume hook is in initramfs:**
   ```bash
   lsinitcpio /boot/initramfs-linux-cachyos.img | grep resume-manual
   # Should show: hooks/resume-manual
   ```

3. **Check swap configuration:**
   ```bash
   grep swap /etc/fstab  # Should show "noauto"
   systemctl status swapon-after-resume.service
   swapon --show  # Should show /swap/swapfile and /dev/zram0
   ```

4. **Check available power states:**
   ```bash
   cat /sys/power/state  # Should include: freeze mem disk
   cat /sys/power/disk   # Should show hibernation modes
   ```

5. **Other checks:**
   - Ensure swap file offset is correct: `btrfs inspect-internal map-swapfile -r /swap/swapfile`
   - Check resume hook in mkinitcpio: `cat /etc/mkinitcpio.conf | grep HOOKS`
   - Verify boot parameters: `cat /proc/cmdline`
   - Check for errors: `journalctl -b -0 | grep -i "hibernat\|resume"`
   - If initramfs was updated, reboot to load new initramfs

## User UID/GID Selection During CachyOS Installation

**Important Consideration Before Installing CachyOS:**

During CachyOS installation, you'll create a user account with an assigned UID (User ID) and GID (Group ID). The default is typically 1000:1000 for the first user, but there are scenarios where choosing a custom UID/GID is beneficial.

### Why UID/GID Matters

- **File Ownership**: UIDs determine ownership of files on the filesystem
- **Network Shares (NFS/SMB)**: Consistent UIDs across systems prevent permission issues
- **Multi-boot Systems**: Shared /home partitions require matching UIDs across installations
- **Containers/VMs**: Matching UIDs between host and containers simplifies bind mounts and permissions
- **Backup Restoration**: Consistent UIDs make cross-system backups easier to restore

### Current System Configuration

This system uses: `uid=1000(chaos) gid=1000(chaos)`

### UID/GID Selection Guidelines

**Use Default (1000:1000)** if:
- Single system, no network shares
- First Linux installation
- No specific requirements

**Use Custom UID** if:
- Managing multiple systems (use same UID everywhere, e.g., 1001)
- NFS/SMB file server expects specific UIDs
- Shared /home partition across multiple OS installations
- Corporate/institutional UID ranges assigned
- UID 1000 conflicts on existing network

**Common UID Ranges:**
- **0**: root (never use for regular users)
- **1-999**: System accounts (avoid)
- **1000-1999**: User accounts (standard range)
- **5000-9999**: Common in enterprise environments

### Changing UID/GID Post-Installation

**Warning**: Changing UID/GID after installation is complex and risky.

If absolutely necessary:
```bash
# Must be done as root, user must be logged out
sudo usermod -u NEW_UID username
sudo groupmod -g NEW_GID username

# Fix all file ownership (may take hours on large filesystems)
sudo find / -user OLD_UID -exec chown -h NEW_UID {} \;
sudo find / -group OLD_GID -exec chgrp -h NEW_GID {} \;
```

**Best Practice**: Choose the correct UID during initial CachyOS installation. Changing it later can break:
- File permissions
- systemd user services
- Application configurations
- SSH authorized_keys
- LUKS encryption metadata

### Verifying UID/GID

```bash
# Check current user's UID/GID
id

# Check specific user
id username

# List all users with UIDs
getent passwd | awk -F: '{print $1, $3, $4}'
```

## Installation Automation (install.sh)

The repository includes a comprehensive installation script (`install.sh`) that automates the entire setup process:

**Installation Flow:**
1. **Prerequisites Check** - Validates running on Arch Linux
2. **AUR Helper** - Installs paru or yay
3. **Official Packages** - Installs packages from packages-official.txt
4. **Hardware Detection** - Auto-detects CPU (Intel/AMD), GPU (Intel/NVIDIA/AMD), and ASUS laptops
5. **AUR Packages** - Installs packages from packages-aur.txt
6. **Flatpak Applications** - Installs flatpak apps
7. **greetd Configuration** - Sets up greetd with DMS greeter
8. **Config Deployment** - Copies niri configuration to ~/.config/niri/
9. **DMS Deployment** - Copies DMS settings and 6 plugins to ~/.config/DankMaterialShell/
10. **Wallpaper Deployment** - Copies 11 wallpapers to ~/Pictures/Wallpaper/
11. **ASUS Packages** (optional) - If ASUS laptop detected, offers to install asusctl, rog-control-center, supergfxctl
12. **Hibernation Setup** (optional) - Prompts to configure hibernation with auto-sized swap file

**Key Features:**
- **Automatic hardware detection** using DMI and PCI queries
- **ASUS laptop support** with automatic group membership (asus-users)
- **Error handling** with detailed logging to install.log
- **Backup creation** before applying configurations
- **Non-interactive mode** available with sensible defaults
- **Idempotent** - Safe to run multiple times

**ASUS Laptop Installation:**
- Auto-detects ASUS laptops via `/sys/class/dmi/id/sys_vendor`
- Creates `asus-users` group if needed
- Adds user to `asus-users` group (required for hardware control)
- Enables `asusd.service`
- Optionally copies ASUS configuration template

**Hibernation Setup:**
- Auto-detects RAM size from `/proc/meminfo`
- Creates swap file sized at RAM + 10% (minimum 2GB buffer)
- Configures custom initramfs hooks for LUKS encrypted swap resume
- Updates bootloader configuration with resume parameters
- Sets up suspend-then-hibernate with 2-hour delay

## Repository Maintenance

**When updating configuration:**
1. Test changes in active config (`~/.config/niri/`)
2. Copy working config back to repository
3. Update documentation (CLAUDE.md, README.md, TROUBLESHOOTING.md)
4. Commit with descriptive message
5. Push to GitHub

**Git workflow:**
```bash
cd /home/chaos/niri-setup
git add <changed_files>
git commit -m "descriptive message"
git push origin main
```

## Reference Documentation

**This Repository Documentation:**
- `README.md` - User-facing installation and feature documentation
- `CLAUDE.md` - This file (AI assistant guidance)
- `TROUBLESHOOTING.md` - Comprehensive troubleshooting guide
- `SECURE_BOOT.md` - Secure boot setup guide

**Configuration Files:**
- `.config/niri/config.kdl` - Main niri configuration
- `.config/DankMaterialShell/settings.json` - DMS configuration
- `etc/greetd/config.toml` - Display manager configuration
- `etc/asusd/asusd.ron` - ASUS laptop configuration
- `scripts/setup-hibernation.sh` - Hibernation automation script
