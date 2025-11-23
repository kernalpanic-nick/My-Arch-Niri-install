# Niri Setup for CachyOS

Easy-to-deploy niri configuration and application setup for CachyOS installations.

This setup includes:
- **202** official repository packages (system-agnostic)
- **Hardware-specific drivers** (GPU/CPU microcode - configured per system)
- **4** AUR packages (including dms-shell-git)
- **14** flatpak applications
- Complete niri configuration with modular config files (no hardware-specific settings)
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

# IMPORTANT: Configure your hardware drivers first!
# Edit packages-hardware.txt and uncomment lines for YOUR GPU/CPU
nano packages-hardware.txt  # or use vim, micro, etc.

# Run the installer (installs Niri, DMS, and all packages)
./install.sh
```

**Critical First Step:** Before running `install.sh`, you MUST edit `packages-hardware.txt` to select your GPU and CPU drivers. See [Configuring Hardware Drivers](#configuring-hardware-drivers) below.

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
├── install.sh                # Main installation script
├── packages-official.txt     # Official packages (202 packages, system-agnostic)
├── packages-hardware.txt     # Hardware-specific drivers (GPU/CPU - YOU MUST EDIT THIS!)
├── packages-aur.txt          # AUR packages (4 packages)
├── flatpaks.txt              # Flatpak applications (14 apps)
├── .config/
│   └── niri/
│       ├── config.kdl        # Main niri configuration (generic, no hardcoded monitors)
│       └── dms/              # Modular config files
│           ├── binds.kdl
│           ├── colors.kdl
│           ├── layout.kdl
│           └── wpblur.kdl
├── CLAUDE.md                 # Repository guidance for AI assistants
├── SECURE_BOOT.md            # Detailed secure boot setup guide
└── README.md                 # This file
```

## Configuring Hardware Drivers

**CRITICAL:** Before running the installation script, you MUST configure your hardware-specific drivers.

### Step 1: Identify Your Hardware

```bash
# Check your CPU vendor (AMD or Intel)
cat /proc/cpuinfo | grep vendor | head -1

# Check your GPU(s)
lspci | grep -E "VGA|3D"
```

### Step 2: Edit packages-hardware.txt

Open the file and uncomment (remove the `#` from) the lines matching your hardware:

```bash
nano packages-hardware.txt
```

**Example for AMD CPU + NVIDIA GPU:**
```
# Uncomment this line:
amd-ucode

# Uncomment these lines:
nvidia-utils
lib32-nvidia-utils
opencl-nvidia
lib32-opencl-nvidia
libva-nvidia-driver
nvidia-settings
linux-cachyos-nvidia-open
linux-cachyos-lts-nvidia-open
```

**Example for Intel CPU + AMD GPU:**
```
# Uncomment this line:
intel-ucode

# Uncomment these lines:
vulkan-radeon
lib32-vulkan-radeon
xf86-video-amdgpu
```

### Step 3: Run Installation

After configuring your hardware drivers, run the installation script:
```bash
./install.sh
```

## Customization

### Adding/Removing Packages

Edit the appropriate file to add or remove packages:
- `packages-official.txt` - Official Arch repository packages (system-agnostic)
- `packages-hardware.txt` - Hardware-specific GPU/CPU drivers (MUST be configured!)
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

# STEP 1: Configure your hardware drivers
# Identify your CPU (AMD or Intel)
cat /proc/cpuinfo | grep vendor | head -1

# Identify your GPU(s) (NVIDIA, AMD, or Intel)
lspci | grep -E "VGA|3D"

# STEP 2: Edit packages-hardware.txt
# Uncomment lines matching YOUR hardware (see instructions in the file)
nano packages-hardware.txt

# STEP 3: Run installation script
./install.sh

# STEP 4: Configure monitor setup (REQUIRED!)
# The config has NO monitor configuration by default
# You MUST add your monitor configuration before starting niri
nano .config/niri/config.kdl
# See lines 9-32 for examples and instructions
# You'll configure this after installation when you can run: niri msg outputs

# STEP 5: Log out from TTY
logout

# STEP 6: Start Niri session
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

## Post-Installation Configuration

### REQUIRED: Monitor Setup

The niri configuration has **NO monitor configuration by default**. You MUST configure your displays:

**Before first login** (recommended):
1. Edit `~/.config/niri/config.kdl` (or `.config/niri/config.kdl` in this repo)
2. See lines 9-32 for examples and uncomment/modify for your setup
3. Common single monitor: just uncomment and edit the single monitor example

**After starting Niri** (if you skipped the above):
1. **Start Niri** (will use default display settings)
2. **Open a terminal** (Mod+T, usually Super+T)
3. **Find your monitor names:**
   ```bash
   niri msg outputs
   ```
4. **Edit the config:**
   ```bash
   nano ~/.config/niri/config.kdl
   ```
5. **Add your monitor configuration** (see examples in lines 9-32)
6. **Reload configuration:**
   ```bash
   niri msg action reload-config
   ```

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
