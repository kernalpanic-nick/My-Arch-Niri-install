#!/bin/bash
#
# Automatic Monitor Configuration for Niri
# Detects connected monitors and generates niri output configuration
# Selects highest resolution and refresh rate for each monitor
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

# Parse monitor information into arrays
declare -a MONITORS
declare -a CONNECTORS
declare -A MONITOR_MODES

output_pattern='^Output.*\(([^)]+)\)$'

current_connector=""
current_name=""
in_available_modes=0

while IFS= read -r line; do
    # Match output line to get connector
    if [[ $line =~ $output_pattern ]]; then
        current_connector="${BASH_REMATCH[1]}"
        # Extract display name from quotes
        current_name=$(echo "$line" | sed -n 's/^Output "\(.*\)" (.*/\1/p')
        CONNECTORS+=("$current_connector")
        MONITORS+=("$current_name")
        MONITOR_MODES["$current_connector"]=""
        in_available_modes=0
    elif [[ $line =~ "Available modes:" ]]; then
        in_available_modes=1
    elif [[ $in_available_modes == 1 && $line =~ ^[[:space:]]+([0-9]+x[0-9]+@[0-9.]+) ]]; then
        # Extract mode (e.g., "1920x1080@144.000")
        mode=$(echo "$line" | sed -n 's/^[[:space:]]*\([0-9]*x[0-9]*@[0-9.]*\).*/\1/p')
        if [ -n "$mode" ] && [ -n "$current_connector" ]; then
            MONITOR_MODES["$current_connector"]+="$mode "
        fi
    elif [[ $in_available_modes == 1 && ! $line =~ ^[[:space:]] ]]; then
        in_available_modes=0
    fi
done <<< "$monitor_data"

# Find best mode (highest resolution, then highest refresh rate)
find_best_mode() {
    local connector="$1"
    local modes="${MONITOR_MODES[$connector]}"
    local best_mode=""
    local best_pixels=0
    local best_refresh=0

    for mode in $modes; do
        if [[ $mode =~ ([0-9]+)x([0-9]+)@([0-9.]+) ]]; then
            local width="${BASH_REMATCH[1]}"
            local height="${BASH_REMATCH[2]}"
            local refresh="${BASH_REMATCH[3]}"
            local pixels=$((width * height))

            # Convert refresh to integer by removing decimal point
            local refresh_int=$(echo "$refresh" | tr -d '.')

            # Compare: first by resolution (pixels), then by refresh rate
            if [ $pixels -gt $best_pixels ]; then
                best_mode="$mode"
                best_pixels=$pixels
                best_refresh=$refresh_int
            elif [ $pixels -eq $best_pixels ] && [ $refresh_int -gt $best_refresh ]; then
                best_mode="$mode"
                best_refresh=$refresh_int
            fi
        fi
    done

    echo "$best_mode"
}

# Display detected monitors
num_monitors="${#CONNECTORS[@]}"

if [ "$num_monitors" -eq 0 ]; then
    echo -e "${RED}Error: No monitors detected${NC}"
    exit 1
fi

echo -e "${GREEN}Detected monitors:${NC}"
for i in "${!CONNECTORS[@]}"; do
    idx=$((i + 1))
    connector="${CONNECTORS[$i]}"
    name="${MONITORS[$i]}"
    best_mode=$(find_best_mode "$connector")
    echo -e "  ${YELLOW}[$idx]${NC} $connector - $name"
    echo -e "      Best mode: ${GREEN}$best_mode${NC}"
done

# Ask for monitor order
declare -a MONITOR_ORDER
if [ ! -f "$FIRST_RUN_MARKER" ]; then
    # First run - use default order (as detected)
    echo -e "\n${YELLOW}First run: Using default left-to-right order${NC}"
    for i in "${!CONNECTORS[@]}"; do
        MONITOR_ORDER+=("$i")
    done
else
    # Ask user for order
    echo -e "\n${YELLOW}Specify monitor order from left to right${NC}"
    echo -e "Enter monitor numbers separated by spaces (e.g., '1 3 2' or '2 1 3')"
    echo -e "Or press Enter to use default order"
    read -p "Order: " -r user_order

    # Parse user input
    if [ -z "$user_order" ]; then
        echo -e "${YELLOW}Using default order${NC}"
        for i in "${!CONNECTORS[@]}"; do
            MONITOR_ORDER+=("$i")
        done
    else
        for num in $user_order; do
            idx=$((num - 1))
            if [ "$idx" -ge 0 ] && [ "$idx" -lt "$num_monitors" ]; then
                MONITOR_ORDER+=("$idx")
            else
                echo -e "${RED}Error: Invalid monitor number: $num${NC}"
                exit 1
            fi
        done

        if [ "${#MONITOR_ORDER[@]}" -ne "$num_monitors" ]; then
            echo -e "${RED}Error: You must specify all $num_monitors monitors${NC}"
            exit 1
        fi
    fi
fi

# Generate configuration with user-specified order
output_lines=""
x_position=0

for order_idx in "${MONITOR_ORDER[@]}"; do
    connector="${CONNECTORS[$order_idx]}"
    best_mode=$(find_best_mode "$connector")

    if [ -z "$best_mode" ]; then
        echo -e "${RED}Error: Could not find mode for $connector${NC}"
        exit 1
    fi

    # Extract width from mode
    if [[ $best_mode =~ ([0-9]+)x([0-9]+)@ ]]; then
        width="${BASH_REMATCH[1]}"

        output_lines+="output \"$connector\" {\n"
        output_lines+="    mode \"$best_mode\"\n"
        output_lines+="    position x=$x_position y=0\n"
        output_lines+="}\n\n"

        x_position=$((x_position + width))
    fi
done

if [ -z "$output_lines" ]; then
    echo -e "${RED}Error: Could not generate monitor configuration${NC}"
    exit 1
fi

# Show what will be configured
echo -e "\n${GREEN}Generated configuration:${NC}"
echo -e "$output_lines"

# Ask for confirmation
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
echo -e "$output_lines" >> "$temp_file"

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
