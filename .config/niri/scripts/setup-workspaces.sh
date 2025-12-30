#!/bin/bash
#
# Interactive Workspace & Application Setup for Niri
# Configure named workspaces and auto-launching applications
#

CONFIG_FILE="$HOME/.config/niri/config.kdl"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}╔═══════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║  Niri Workspace & Application Setup Wizard   ║${NC}"
echo -e "${CYAN}╚═══════════════════════════════════════════════╝${NC}\n"

# Ask for number of workspaces
echo -e "${YELLOW}How many named workspaces do you want? [1-10]${NC}"
read -p "Number of workspaces [3]: " num_workspaces

if [ -z "$num_workspaces" ]; then
    num_workspaces=3
fi

if [[ ! "$num_workspaces" =~ ^[0-9]+$ ]] || [ "$num_workspaces" -lt 1 ] || [ "$num_workspaces" -gt 10 ]; then
    echo -e "${RED}Invalid number, using 3${NC}"
    num_workspaces=3
fi

# Collect workspace names
declare -a WORKSPACE_NAMES
echo -e "\n${GREEN}Configure workspace names:${NC}"
for i in $(seq 1 $num_workspaces); do
    echo -e "${YELLOW}Workspace $i name:${NC}"
    echo -e "  Examples: browser, dev, chat, email, media, gaming"
    read -p "Name: " ws_name
    
    if [ -z "$ws_name" ]; then
        ws_name="workspace-$i"
    fi
    
    WORKSPACE_NAMES+=("$ws_name")
    echo -e "${GREEN}✓ Workspace $i: $ws_name${NC}"
done

# Ask about auto-launching applications
echo -e "\n${BLUE}═══ Auto-Launching Applications ═══${NC}"
echo -e "Configure applications that should start automatically\n"

declare -a APP_COMMANDS
declare -a APP_WORKSPACES
declare -a APP_IDS

echo -e "${YELLOW}How many applications should auto-start? [0-10]${NC}"
read -p "Number of apps [0]: " num_apps

if [ -z "$num_apps" ]; then
    num_apps=0
fi

if [[ ! "$num_apps" =~ ^[0-9]+$ ]] || [ "$num_apps" -lt 0 ] || [ "$num_apps" -gt 10 ]; then
    echo -e "${RED}Invalid number, using 0${NC}"
    num_apps=0
fi

# Collect application information
for i in $(seq 1 $num_apps); do
    echo -e "\n${CYAN}─── Application $i ───${NC}"
    
    # Application command
    echo -e "${YELLOW}Enter the command to launch this application:${NC}"
    echo -e "  Examples:"
    echo -e "    vivaldi-stable"
    echo -e "    kitty"
    echo -e "    flatpak run org.signal.Signal"
    echo -e "    discord"
    read -p "Command: " app_cmd
    
    if [ -z "$app_cmd" ]; then
        echo -e "${RED}Skipping empty command${NC}"
        continue
    fi
    
    # Application ID (for window rules)
    echo -e "\n${YELLOW}Enter the app-id for window matching:${NC}"
    echo -e "  Common app-ids:"
    echo -e "    vivaldi-stable"
    echo -e "    kitty"
    echo -e "    org.signal.Signal"
    echo -e "    discord"
    echo -e "    zed"
    echo -e "  (Run 'niri msg windows' to find app-ids)"
    read -p "App ID: " app_id
    
    if [ -z "$app_id" ]; then
        # Try to guess from command
        app_id=$(echo "$app_cmd" | awk '{print $NF}')
        echo -e "${YELLOW}Using guessed app-id: $app_id${NC}"
    fi
    
    # Workspace assignment
    echo -e "\n${YELLOW}Which workspace should this app open on?${NC}"
    for j in "${!WORKSPACE_NAMES[@]}"; do
        ws_num=$((j + 1))
        echo -e "  ${GREEN}[$ws_num]${NC} ${WORKSPACE_NAMES[$j]}"
    done
    read -p "Workspace number [1]: " ws_num
    
    if [ -z "$ws_num" ]; then
        ws_num=1
    fi
    
    if [[ ! "$ws_num" =~ ^[0-9]+$ ]] || [ "$ws_num" -lt 1 ] || [ "$ws_num" -gt "${#WORKSPACE_NAMES[@]}" ]; then
        echo -e "${RED}Invalid workspace, using 1${NC}"
        ws_num=1
    fi
    
    ws_idx=$((ws_num - 1))
    ws_name="${WORKSPACE_NAMES[$ws_idx]}"
    
    APP_COMMANDS+=("$app_cmd")
    APP_IDS+=("$app_id")
    APP_WORKSPACES+=("$ws_name")
    
    echo -e "${GREEN}✓ $app_cmd → workspace '$ws_name'${NC}"
done

# Generate configuration
echo -e "\n${BLUE}═══ Generating Configuration ═══${NC}\n"

# Generate workspace definitions
workspace_config=""
for ws_name in "${WORKSPACE_NAMES[@]}"; do
    workspace_config+="workspace \"$ws_name\"\n"
done

# Generate spawn-at-startup commands
startup_config=""
for i in "${!APP_COMMANDS[@]}"; do
    cmd="${APP_COMMANDS[$i]}"
    # Split command into parts
    startup_config+="spawn-at-startup"
    for part in $cmd; do
        startup_config+=" \"$part\""
    done
    startup_config+="\n"
done

# Generate window rules for workspace assignment
window_rules=""
for i in "${!APP_IDS[@]}"; do
    app_id="${APP_IDS[$i]}"
    ws_name="${APP_WORKSPACES[$i]}"
    
    window_rules+="window-rule {\n"
    window_rules+="    match at-startup=true app-id=r#\"^${app_id}\$\"#\n"
    window_rules+="    open-on-workspace \"$ws_name\"\n"
    window_rules+="}\n\n"
done

# Show generated configuration
echo -e "${GREEN}Generated workspace definitions:${NC}"
echo -e "$workspace_config"

if [ -n "$startup_config" ]; then
    echo -e "${GREEN}Generated startup commands:${NC}"
    echo -e "$startup_config"
fi

if [ -n "$window_rules" ]; then
    echo -e "${GREEN}Generated window rules:${NC}"
    echo -e "$window_rules"
fi

# Ask for confirmation
echo -e "\n${YELLOW}Apply this configuration to $CONFIG_FILE?${NC}"
read -p "[Y/n]: " -n 1 -r
echo

if [[ $REPLY =~ ^[Nn]$ ]]; then
    echo -e "${YELLOW}Configuration not applied. Saving to workspace-config.txt instead${NC}"
    {
        echo "# Workspace Definitions"
        echo -e "$workspace_config"
        echo ""
        echo "# Startup Commands"
        echo -e "$startup_config"
        echo ""
        echo "# Window Rules"
        echo -e "$window_rules"
    } > ~/workspace-config.txt
    echo -e "${GREEN}Saved to ~/workspace-config.txt${NC}"
    exit 0
fi

# Backup current config
backup_file="${CONFIG_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
cp "$CONFIG_FILE" "$backup_file"
echo -e "${YELLOW}Backed up config to: $backup_file${NC}"

# Apply configuration (this is complex - we need to find and replace the right sections)
# For now, let's output instructions for manual edit
echo -e "\n${CYAN}═══ Manual Configuration Instructions ═══${NC}\n"
echo -e "${YELLOW}To complete the setup, edit $CONFIG_FILE:${NC}\n"

echo -e "${GREEN}1. Add workspace definitions at the top (after config-notification):${NC}"
echo -e "$workspace_config\n"

if [ -n "$startup_config" ]; then
    echo -e "${GREEN}2. Add startup commands in the spawn-at-startup section:${NC}"
    echo -e "$startup_config\n"
fi

if [ -n "$window_rules" ]; then
    echo -e "${GREEN}3. Add window rules in the window rules section:${NC}"
    echo -e "$window_rules\n"
fi

echo -e "${YELLOW}Configuration template saved to: ~/workspace-setup.kdl${NC}"
{
    echo "// Generated by workspace setup wizard"
    echo "// Add these to your config.kdl"
    echo ""
    echo "// === WORKSPACE DEFINITIONS (add near top of config) ==="
    echo -e "$workspace_config"
    echo ""
    echo "// === STARTUP COMMANDS (add in spawn-at-startup section) ==="
    echo -e "$startup_config"
    echo ""
    echo "// === WINDOW RULES (add in window-rule section) ==="
    echo -e "$window_rules"
} > ~/workspace-setup.kdl

echo -e "\n${GREEN}✓ Workspace setup complete!${NC}"
echo -e "Review the generated config and manually add it to your config.kdl"
echo -e "Then reload niri: ${YELLOW}niri msg action load-config-file${NC}"
