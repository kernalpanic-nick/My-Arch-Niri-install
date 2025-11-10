# Niri Setup for CachyOS

Easy-to-deploy niri configuration and application setup for CachyOS installations.

This setup includes:
- **205** official repository packages
- **6** AUR packages (including dms-shell-git)
- **9** flatpak applications
- Complete niri configuration with modular config files
- Limine bootloader with secure boot support

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

# Run the installer (installs Niri, DMS, and all packages)
./install.sh
```

## What This Does

The install script will:

1. **Install AUR Helper**: Sets up `paru` if you don't have `paru` or `yay` installed
2. **Install Official Packages**: Installs packages from official CachyOS/Arch repos (including Niri, Wayland essentials)
3. **Install AUR Packages**: Installs packages from the AUR (including dms-shell-git)
4. **Install Flatpaks**: Installs flatpak applications from Flathub
5. **Setup Configs**: Symlinks `.config/niri` to your home directory with full Niri + DMS configuration

## File Structure

```
.
├── install.sh              # Main installation script
├── packages-official.txt   # Official repository packages (205 packages)
├── packages-aur.txt        # AUR packages (6 packages)
├── flatpaks.txt            # Flatpak applications (9 apps)
├── .config/
│   └── niri/
│       ├── config.kdl      # Main niri configuration
│       └── dms/            # Modular config files
│           ├── binds.kdl
│           ├── colors.kdl
│           ├── layout.kdl
│           └── wpblur.kdl
└── README.md
```

## Customization

### Adding/Removing Packages

Edit the appropriate file to add or remove packages:
- `packages-official.txt` - Official Arch repository packages
- `packages-aur.txt` - AUR packages
- `flatpaks.txt` - Flatpak applications

Lines starting with `#` are comments and will be ignored.

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

# Run installation script
./install.sh

# Log out from TTY
logout

# Start Niri session
# Either from display manager (if installed) or run: niri
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

## DMS (DankMaterialShell) Integration

This setup uses **DMS** (dms-shell-git from AUR) as the desktop shell for Niri:

**DMS Provides**:
- Panel/status bar
- Spotlight launcher (`Super + Space`)
- Clipboard manager
- Process list
- Settings/control center
- Notifications
- Lock screen

**Auto-startup**: DMS is configured to start automatically in `config.kdl:132` via `spawn-at-startup "dms" "run"`

**Note**: Most keybindings in this config use `dms ipc call` commands. If DMS is not installed, these keybindings won't work.

## Manual Steps

After installation, you may want to:

- Configure display settings in `.config/niri/config.kdl` (especially monitor setup)
- Adjust DMS theming and settings
- Configure your terminal emulator
- Set up wallpaper (via DMS settings or swaybg)

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
