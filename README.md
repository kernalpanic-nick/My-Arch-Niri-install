# Niri Setup for CachyOS

Easy-to-deploy niri configuration and application setup for CachyOS installations.

This setup includes:
- **202** official repository packages (system-agnostic) including greetd
- **Hardware-specific drivers** (GPU/CPU microcode - automatically detected!)
- **4** AUR packages (including dms-shell-git and greetd-dms-greeter-git)
- **14** flatpak applications
- **greetd + DMS greeter** (beautiful graphical greeter with niri compositor)
- Complete niri configuration with named workspaces and auto-launched applications
- **DMS configuration with 6 pre-installed plugins**
- **11 desktop wallpapers** included
- Limine bootloader with secure boot support
- **Automatic hardware detection** (GPU/CPU drivers, ASUS laptops)
- **Automatic monitor configuration** (first-run + manual keybinding)
- **Optional hibernation support** (40GB swap file with custom resume hooks)
- **DMS lock screen** (manual + auto-lock + YubiKey 2FA support)

## Prerequisites

1. **CachyOS CLI Installation**: Install CachyOS as a minimal CLI system using the CachyOS installer
2. **Limine Bootloader**: Select Limine as your bootloader during installation
3. **Secure Boot** (Optional): See [SECURE_BOOT.md](SECURE_BOOT.md) for detailed secure boot setup

## Quick Start

After completing CachyOS CLI installation and booting into your minimal system:

```bash
# Clone this repo (replace URL with your repository address)
git clone https://github.com/yourusername/yourrepo.git ~/niri-setup
cd ~/niri-setup

# Run the installer - it will automatically detect and install drivers!
./install.sh
```

The installer will automatically detect your CPU (AMD/Intel) and GPU(s) (NVIDIA/AMD/Intel) and install the appropriate drivers with your confirmation.

## What This Does

The install script will:

1. **Install AUR Helper**: Sets up `paru` if you don't have `paru` or `yay` installed
2. **Install Official Packages**: Installs packages from official CachyOS/Arch repos (including Niri, Wayland essentials, greetd)
3. **Detect & Install Hardware Drivers**: Automatically detects CPU/GPU and installs appropriate drivers
4. **Install AUR Packages**: Installs packages from the AUR (including dms-shell-git, greetd-dms-greeter-git)
5. **Install Flatpaks**: Installs flatpak applications from Flathub
6. **Configure greetd**: Sets up greetd with DMS greeter for beautiful graphical login
7. **Setup Configs**: Symlinks `.config/niri` to your home directory with full Niri + DMS configuration
8. **Deploy DMS Configuration**: Copies DMS settings and pre-installed plugins
9. **Deploy Wallpapers**: Copies 11 desktop wallpapers to ~/Pictures/Wallpaper
10. **ASUS Laptop Support** (optional): Auto-detects ASUS laptops and offers to install asusctl, rog-control-center
11. **Hibernation Setup** (optional): Prompts to configure hibernation with 40GB swap file

On first niri login:
12. **Auto-Configure Monitors**: Automatically detects and configures all connected displays

## File Structure

```
.
├── install.sh                # Main installation script
├── packages-official.txt     # Official packages (201 packages, system-agnostic)
├── packages-hardware.txt     # Hardware-specific drivers (GPU/CPU - auto-detected!)
├── packages-aur.txt          # AUR packages (4 packages)
├── flatpaks.txt              # Flatpak applications (14 apps)
├── .config/
│   ├── niri/
│   │   ├── config.kdl        # Main niri configuration with named workspaces
│   │   ├── scripts/
│   │   │   └── configure-monitors.sh  # Automatic monitor configuration
│   │   └── dms/              # Modular config files
│   │       ├── alttab.kdl    # Alt-tab window switcher styling
│   │       ├── binds.kdl     # DMS keybindings
│   │       ├── colors.kdl    # Color scheme
│   │       ├── layout.kdl    # Layout settings
│   │       └── wpblur.kdl    # Wallpaper blur rules
│   └── DankMaterialShell/    # DMS configuration
│       ├── settings.json     # DMS settings (sanitized)
│       ├── plugin_settings.json  # Plugin configuration
│       └── plugins/          # 6 pre-installed plugins
├── etc/                      # System configuration templates
│   ├── greetd/              # greetd configuration
│   ├── asusd/               # ASUS laptop configuration
│   ├── systemd/             # Power management & hibernation config
│   └── initcpio/            # Custom hibernation resume hooks
├── scripts/
│   └── setup-hibernation.sh  # Optional hibernation setup script
├── wallpapers/              # 11 desktop wallpapers (6MB)
├── CLAUDE.md                # Repository guidance for AI assistants
├── SECURE_BOOT.md           # Detailed secure boot setup guide
├── TROUBLESHOOTING.md       # Troubleshooting guide
└── README.md                # This file
```

## Automatic Hardware Detection

The installation script automatically detects your hardware and installs the appropriate drivers:

**What gets detected:**
- **CPU**: AMD or Intel (installs appropriate microcode)
- **GPU(s)**: NVIDIA, AMD, and/or Intel (installs appropriate drivers)
- **Hybrid setups**: Automatically handles systems with multiple GPUs (e.g., Intel iGPU + NVIDIA dGPU)

**During installation:**
1. The script detects your hardware
2. Shows you what will be installed
3. Asks for confirmation before installing drivers
4. You can skip automatic detection and manually configure if needed

**Manual Override (if needed):**
If automatic detection fails or you want manual control, you can edit `packages-hardware.txt` to uncomment specific drivers, and the script will respect your manual selection.

## Automatic Monitor Configuration

The setup includes automatic monitor detection and configuration:

**First Run (Automatic):**
- On your first niri login, monitors are automatically detected
- Configuration is generated based on your displays
- Applied automatically (no confirmation needed on first run)

**Manual Re-configuration (Keybinding):**
- Press **Mod+Shift+M** to detect and reconfigure monitors anytime
- Useful when:
  - Connecting/disconnecting external displays
  - Changing monitor arrangement
  - Updating refresh rates
- Shows what will be configured and asks for confirmation

**What it does:**
- Detects all connected monitors via `niri msg outputs`
- Generates appropriate output configuration with correct resolutions and refresh rates
- Positions monitors side-by-side automatically
- Backs up your config before applying changes
- Reloads niri configuration automatically

**Manual Configuration (if needed):**
If you prefer manual control, you can still edit `~/.config/niri/config.kdl` (lines 9-32) and the auto-configuration will be skipped after first run.

## Customization

### Adding/Removing Packages

Edit the appropriate file to add or remove packages:
- `packages-official.txt` - Official Arch repository packages (system-agnostic)
- `packages-hardware.txt` - Hardware-specific GPU/CPU drivers (reference/manual override only - auto-detected by default!)
- `packages-aur.txt` - AUR packages
- `flatpaks.txt` - Flatpak applications

Lines starting with `#` are comments and will be ignored.

**Note:** Hardware drivers are automatically detected during installation, so you don't need to edit `packages-hardware.txt` unless you want to manually override the automatic detection.

### Modifying Configs

Your niri config is symlinked from this repo, so you can:

1. Edit configs in this directory
2. Commit and push changes
3. Pull on other machines and configs update automatically

Or edit at `~/.config/niri/` and changes will reflect here.

## Fresh Install Workflow

### 1. CachyOS CLI Installation

1. Boot from CachyOS installation media
2. Run the CachyOS CLI installer
3. **SKIP** desktop environment selection (we'll install Niri manually)
4. Select **Limine** as your bootloader
5. Complete base system installation
6. Reboot into your minimal CLI system

### 2. Optional: Configure Secure Boot

See [SECURE_BOOT.md](SECURE_BOOT.md) for detailed instructions on setting up secure boot with Limine.

### 3. Install Niri + DMS

```bash
# Ensure git is installed (should be from base install)
sudo pacman -S --needed git

# Clone this repo
git clone <your-repo-url> ~/niri-setup
cd ~/niri-setup

# STEP 1: Run installation script (hardware auto-detected!)
./install.sh
# The script will:
# - Detect your CPU and GPU(s)
# - Show you what drivers will be installed
# - Ask for confirmation before installing
# - Configure greetd with DMS greeter
# - Optionally set up hibernation and ASUS laptop support

# STEP 2: Reboot your system
reboot

# STEP 3: greetd with DMS greeter starts automatically
# Beautiful graphical login screen powered by DMS and niri
# Simply log in and niri will start

# STEP 4: Monitors configured automatically!
# On first login, monitors will be detected and configured automatically
# Use Mod+Shift+M anytime to re-detect and reconfigure monitors
```

## Syncing to New Machine

```bash
cd ~/niri-setup
git pull
./install.sh
```

The script will:
- Skip packages already installed
- Update symlinks if needed
- Backup existing configs before replacing

## Optional Features

### Hibernation Support

The installer offers optional hibernation setup with:
- **Auto-sized swap file** (RAM + 10% buffer) on btrfs subvolume
- **Custom initramfs hooks** for reliable resume from encrypted swap
- **Suspend-then-hibernate** (2 hour delay)
- **Lid closure integration**
- **Power management** optimized for laptops

**Requirements**: LUKS encryption, Limine bootloader, sufficient free disk space

To set up hibernation later:
```bash
sudo ~/niri-setup/scripts/setup-hibernation.sh
```

### ASUS Laptop Support

The installer auto-detects ASUS ROG laptops and offers to install:
- **asusctl** - ASUS control utility (RGB keyboard, fan profiles, etc.)
- **rog-control-center** - GUI for ASUS settings
- **supergfxctl** - GPU switching control

Includes pre-configured settings for optimal power management and RGB control via `Mod+F4` keybinding.

### Desktop Wallpapers

11 high-quality wallpapers (6MB total) are included and deployed to `~/Pictures/Wallpaper/`.

**Browse wallpapers**: Press `Mod+Y` to open the DMS wallpaper browser and select from the included wallpapers or add your own.

## DMS (DankMaterialShell) Integration

This setup uses **DMS** (dms-shell-git from AUR) as the desktop shell for Niri:

**DMS Provides**:
- Panel/status bar
- Spotlight launcher (`Super + Space`)
- Clipboard manager
- Process list
- Settings/control center
- Notifications
- Lock screen (manual + auto-lock)

**Lock Screen**:
- **Manual Lock**: Press `Mod+Alt+L` to lock immediately
- **Auto-lock**: Automatically locks after 10 minutes of inactivity
- **Before Sleep**: Automatically locks before system suspend/sleep
- Managed by `swayidle` + DMS lock integration

**Auto-startup**: DMS is managed by systemd user service (dms.service) for reliable startup

**DMS Configuration**: The installer deploys:
- Sanitized settings.json with recommended defaults
- 6 pre-installed plugins (asusControlCenter, calculator, commandRunner, etc.)
- Plugin configuration ready to use

**Note**: Most keybindings in this config use `dms ipc call` commands. If DMS is not installed, these keybindings won't work.

## Post-Installation Features

### Automatic Monitor Configuration

Monitors are configured automatically on first login! No manual configuration needed.

**Keybindings:**
- **Mod+Shift+M**: Detect and reconfigure monitors anytime
  - Useful when connecting/disconnecting displays
  - Automatically detects resolution and refresh rate
  - Positions monitors side-by-side

**Manual configuration (optional):**
If you prefer to manually configure monitors, edit `~/.config/niri/config.kdl` (lines 9-32).

### Optional Customizations

After installation, you may also want to:

- Adjust DMS theming and settings (Mod+Comma for settings)
- Configure your terminal emulator (default: kitty)
- Set up wallpaper (via DMS settings: Mod+Y)
- Review and customize keybindings in `~/.config/niri/config.kdl`

## Backup

Your original niri config (if any) is backed up to:
```
~/.config/niri.backup.YYYYMMDD_HHMMSS
```

## Troubleshooting

**niri won't start**: Check logs with `journalctl --user -u niri`

**Missing packages**: Ensure AUR helper is working: `paru --version`

**Config not updating**: Check symlink: `ls -la ~/.config/niri`

## Repository Setup

To track this as a git repository:

```bash
cd ~/niri-setup
git init
git add .
git commit -m "Initial niri setup"
git remote add origin <your-git-url>
git push -u origin main
```

## License

Feel free to use and modify as needed.
