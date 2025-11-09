# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is an Arch Linux installation automation repository with Niri window manager configuration. It provides a reproducible setup for fresh Arch installations with 205 official packages, 6 AUR packages, and 9 flatpak applications.

## Core Architecture

**Installation Flow:**
The `install.sh` script follows a sequential installation process:
1. Checks for Arch Linux environment (`/etc/arch-release`)
2. Installs AUR helper (paru or yay) if not present
3. Installs packages from three sources: official repos, AUR, flatpak
4. Creates symlinks from `.config/niri/` to `~/.config/niri`

**Configuration Structure:**
- **Main config**: `.config/niri/config.kdl` - Primary niri configuration (KDL format)
- **Modular configs**: `.config/niri/dms/` - Separated configuration modules (binds, colors, layout, wpblur)
- **Package lists**: Three text files with one package per line (comments start with `#`)

**Key Dependencies:**
- **dms-shell-git** (AUR): Custom shell/panel system integrated throughout the niri config
  - Used for: spotlight launcher, clipboard manager, process list, settings, notifications, lock screen
  - All `dms ipc call` commands depend on this being installed and running
- **Multi-monitor setup**: Config hardcoded for 3 monitors (DP-3, HDMI-A-1, DP-2)

## Running Commands

### Installation
```bash
# Full system installation (interactive, requires confirmation)
./install.sh

# The script handles:
# - AUR helper installation (paru)
# - Package installation (official + AUR + flatpak)
# - Config symlink creation (backs up existing ~/.config/niri)
```

### Testing Configuration
```bash
# Validate niri config syntax (run inside niri session)
niri validate ~/.config/niri/config.kdl

# List outputs/monitors for configuration
niri msg outputs

# Check niri logs for errors
journalctl --user -u niri

# Reload niri configuration
niri msg action reload-config
```

### Managing Packages
Package lists use simple text format (one per line, `#` for comments):
- Edit `packages-official.txt`, `packages-aur.txt`, or `flatpaks.txt`
- Re-run `./install.sh` to sync changes
- The `--needed` flag prevents reinstalling existing packages

## Important Configuration Details

**Monitor Configuration (`.config/niri/config.kdl:9-24`):**
- Triple monitor setup is hardcoded
- When deploying to different hardware, update output names and positions
- Find output names with: `niri msg outputs`

**DMS Integration:**
- Most keybindings spawn `dms ipc call` commands
- If dms-shell-git is not installed, keybindings will fail silently
- The system depends on `spawn-at-startup "dms" "run"` (line 132)

**Symlink Behavior:**
- Config changes in `~/.config/niri/` reflect in this repo (bidirectional)
- Original configs backed up to `~/.config/niri.backup.YYYYMMDD_HHMMSS`
- Script removes old symlinks before creating new ones

## Repository Workflow

This repo is designed for:
1. **Fresh installs**: Clone repo → run install.sh → log into niri
2. **Syncing machines**: Pull changes → run install.sh
3. **Config management**: Edit configs anywhere → commit → pull on other machines

The installation script is idempotent - safe to run multiple times.
