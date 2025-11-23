#!/bin/bash
#
# Automatic Monitor Configuration for Niri
# Detects connected monitors and generates niri output configuration
#

CONFIG_FILE="$HOME/.config/niri/config.kdl"
MONITOR_CONFIG_START="// === OUTPUT CONFIGURATION ==="
MONITOR_CONFIG_END="// See: https://github.com/YaLTeR/niri/wiki/Configuration:-Outputs"
FIRST_RUN_MARKER="$HOME/.config/niri/.monitor-configured"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Check if running under niri
if ! pgrep -x niri >/dev/null; then
    echo -e "${RED}Error: This script must be run inside a niri session${NC}"
    exit 1
fi

# Get monitor information
echo -e "${YELLOW}Detecting monitors...${NC}"
monitor_data=$(niri msg outputs)

if [ -z "$monitor_data" ]; then
    echo -e "${RED}Error: Could not detect monitors${NC}"
    exit 1
fi

# Parse monitor information and generate config
generate_config() {
    local output_lines=""
    local x_position=0
    local connector=""
    local mode=""
    local width=""

    # Regex patterns stored in variables to avoid bash parsing issues
    local output_pattern='^Output.*\(([^)]+)\)$'
    local mode_pattern='Current mode: ([0-9]+)x([0-9]+) @ ([0-9.]+)'

    # Parse niri msg outputs line by line
    # Format: Output "Name" (connector)
    #           Current mode: WIDTHxHEIGHT @ REFRESH Hz
    while IFS= read -r line; do
        # Match output line: Output "Full Name" (connector)
        if [[ $line =~ $output_pattern ]]; then
            connector="${BASH_REMATCH[1]}"
            mode=""
            width=""
        # Match current mode line
        elif [[ $line =~ $mode_pattern ]]; then
            width="${BASH_REMATCH[1]}"
            height="${BASH_REMATCH[2]}"
            refresh="${BASH_REMATCH[3]}"
            mode="${width}x${height}@${refresh}"

            # Generate output block when we have both connector and mode
            if [ -n "$connector" ] && [ -n "$mode" ]; then
                output_lines+="output \"$connector\" {\n"
                output_lines+="    mode \"$mode\"\n"
                if [ $x_position -gt 0 ]; then
                    output_lines+="    position x=$x_position y=0\n"
                fi
                output_lines+="}\n\n"

                x_position=$((x_position + width))
                connector=""
            fi
        fi
    done <<< "$monitor_data"

    echo -e "$output_lines"
}

# Generate new monitor configuration
new_config=$(generate_config)

if [ -z "$new_config" ]; then
    echo -e "${RED}Error: Could not generate monitor configuration${NC}"
    echo -e "${YELLOW}Debug: Monitor data:${NC}"
    echo "$monitor_data" | head -20
    exit 1
fi

echo -e "${GREEN}Detected monitors:${NC}"
echo "$monitor_data" | grep "^Output" | sed 's/Output /  - /'

# Show what will be configured
echo -e "\n${GREEN}Generated configuration:${NC}"
echo -e "$new_config"

# Ask for confirmation (skip if first run marker doesn't exist)
if [ -f "$FIRST_RUN_MARKER" ]; then
    read -p "Apply this configuration? [Y/n] " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        echo "Configuration cancelled"
        exit 0
    fi
fi

# Backup current config
backup_file="${CONFIG_FILE}.backup.$(date +%Y%m%d_%H%M%S)"
cp "$CONFIG_FILE" "$backup_file"
echo -e "${YELLOW}Backed up config to: $backup_file${NC}"

# Create temporary file with new config
temp_file=$(mktemp)

# Extract everything before monitor config section
awk -v start="$MONITOR_CONFIG_START" '
    {
        print
        if ($0 ~ start) {
            exit
        }
    }
' "$CONFIG_FILE" > "$temp_file"

# Add new monitor configuration
echo "" >> "$temp_file"
echo -e "$new_config" >> "$temp_file"

# Add everything after monitor config section
awk -v end="$MONITOR_CONFIG_END" '
    found {
        print
    }
    $0 ~ end {
        found = 1
        print
    }
' "$CONFIG_FILE" >> "$temp_file"

# Replace config file
mv "$temp_file" "$CONFIG_FILE"

echo -e "${GREEN}✓ Monitor configuration updated${NC}"

# Reload niri configuration
echo -e "${YELLOW}Reloading niri configuration...${NC}"
niri msg action load-config-file

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Niri configuration reloaded successfully${NC}"

    # Create first-run marker
    touch "$FIRST_RUN_MARKER"
else
    echo -e "${RED}Error: Failed to reload niri configuration${NC}"
    echo -e "${YELLOW}Restoring backup...${NC}"
    mv "$backup_file" "$CONFIG_FILE"
    exit 1
fi

echo -e "\n${GREEN}Monitor configuration complete!${NC}"
echo -e "You can re-run this script anytime with: Mod+Shift+M"
