# Niri Setup for Arch Linux

Easy-to-deploy niri configuration and application setup for fresh Arch Linux installations.

This setup includes:
- **205** official repository packages
- **6** AUR packages
- **9** flatpak applications
- Complete niri configuration with modular config files

## Quick Start

```bash
# Clone this repo
git clone <your-repo-url> ~/niri-setup
cd ~/niri-setup

# Run the installer
./install.sh
```

## What This Does

The install script will:

1. **Install AUR Helper**: Sets up `paru` if you don't have `paru` or `yay` installed
2. **Install Official Packages**: Installs packages from official Arch repos
3. **Install AUR Packages**: Installs packages from the AUR
4. **Install Flatpaks**: Installs flatpak applications from Flathub
5. **Setup Configs**: Symlinks `.config/niri` to your home directory

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

1. Install base Arch Linux
2. Install git: `sudo pacman -S git`
3. Clone this repo
4. Run `./install.sh`
5. Log out and select niri from your display manager

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

## Manual Steps

After installation, you may want to:

- Configure display settings in `.config/niri/config.kdl`
- Set up waybar if using it
- Configure your terminal emulator
- Set up wallpaper/theming

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
