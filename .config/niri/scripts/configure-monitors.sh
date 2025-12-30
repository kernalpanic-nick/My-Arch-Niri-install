#!/bin/bash
#
# Interactive Monitor Configuration for Niri
# Detects connected monitors and allows customization of settings
# Supports: resolution, refresh rate, scale, position
#

CONFIG_FILE="$HOME/.config/niri/config.kdl"
MONITOR_CONFIG_START="// === OUTPUT CONFIGURATION ==="
MONITOR_CONFIG_END="// See: https://github.com/YaLTeR/niri/wiki/Configuration:-Outputs"
FIRST_RUN_MARKER="$HOME/.config/niri/.monitor-configured"

# Colors for output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
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
declare -A MONITOR_SELECTED_MODE
declare -A MONITOR_SCALE

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

echo -e "${GREEN}Detected $num_monitors monitor(s):${NC}"
for i in "${!CONNECTORS[@]}"; do
    idx=$((i + 1))
    connector="${CONNECTORS[$i]}"
    name="${MONITORS[$i]}"
    best_mode=$(find_best_mode "$connector")
    echo -e "  ${YELLOW}[$idx]${NC} $connector - $name (Best: ${GREEN}$best_mode${NC})"
done

# Visual monitor identification for multi-monitor setups
if [ "$num_monitors" -gt 1 ]; then
    echo -e "\n${BLUE}Multiple monitors detected!${NC}"
    echo -e "${YELLOW}Would you like to visually identify each monitor?${NC}"
    echo -e "This will show a large number on each monitor to help you identify them."
    read -p "Identify monitors? [Y/n]: " -n 1 -r
    echo

    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        echo -e "${GREEN}Identifying monitors (3 seconds each)...${NC}\n"

        for i in "${!CONNECTORS[@]}"; do
            idx=$((i + 1))
            connector="${CONNECTORS[$i]}"
            name="${MONITORS[$i]}"

            echo -e "${YELLOW}Showing identifier on Monitor $idx: $connector${NC}"

            # Use kitty to show monitor number (with specific position for each monitor)
            (
                WAYLAND_DISPLAY=$WAYLAND_DISPLAY kitty \
                    --class "monitor-id-$idx" \
                    --title "Monitor $idx" \
                    -o font_size=48 \
                    -o background='#000000' \
                    -o foreground='#00ff00' \
                    -o background_opacity=0.95 \
                    bash -c "
                        clear
                        echo ''
                        echo '  ╔════════════════════════════════╗'
                        echo '  ║                                ║'
                        echo '  ║        MONITOR  $idx             ║'
                        echo '  ║                                ║'
                        echo '  ║        $connector              ║'
                        echo '  ║                                ║'
                        echo '  ║        $name                   ║'
                        echo '  ║                                ║'
                        echo '  ╚════════════════════════════════╝'
                        echo ''
                        echo '  This window will close in 3 seconds...'
                        sleep 3
                    " &
                pid=$!

                # Wait for window to appear
                sleep 0.5

                # Move window to the correct monitor using niri msg
                # Find the window and move it
                window_id=$(niri msg windows | grep -A5 "monitor-id-$idx" | grep "id:" | head -1 | awk '{print $2}')
                if [ -n "$window_id" ]; then
                    niri msg action move-window-to-output --output "$connector" --window "$window_id" 2>/dev/null || true
                fi

                wait $pid
            ) &

            sleep 3.5
        done

        wait
        echo -e "\n${GREEN}Monitor identification complete!${NC}\n"
    fi
fi

# Ask for configuration mode
echo -e "\n${BLUE}Configuration Options:${NC}"
echo -e "  ${YELLOW}[1]${NC} Quick setup - Use best settings for all monitors (automatic)"
echo -e "  ${YELLOW}[2]${NC} Custom setup - Choose resolution, refresh rate, and scale per monitor"
echo ""
read -p "Select mode [1/2]: " -n 1 -r config_mode
echo

if [[ ! $config_mode =~ ^[12]$ ]]; then
    config_mode=1
    echo -e "${YELLOW}Using quick setup (default)${NC}"
fi

# Configure each monitor
for i in "${!CONNECTORS[@]}"; do
    idx=$((i + 1))
    connector="${CONNECTORS[$i]}"
    name="${MONITORS[$i]}"

    if [ "$config_mode" = "1" ]; then
        # Quick setup - auto select best mode
        best_mode=$(find_best_mode "$connector")
        MONITOR_SELECTED_MODE["$connector"]="$best_mode"
        MONITOR_SCALE["$connector"]="1.0"
        echo -e "${GREEN}[$idx] $connector: $best_mode @ 1.0x scale${NC}"
    else
        # Custom setup - interactive selection
        echo -e "\n${BLUE}=== Configuring Monitor $idx: $connector ($name) ===${NC}"

        # Show available modes
        echo -e "${YELLOW}Available modes:${NC}"
        modes_array=()
        mode_num=1
        for mode in ${MONITOR_MODES[$connector]}; do
            modes_array+=("$mode")
            # Parse mode to show resolution and refresh rate nicely
            if [[ $mode =~ ([0-9]+)x([0-9]+)@([0-9.]+) ]]; then
                width="${BASH_REMATCH[1]}"
                height="${BASH_REMATCH[2]}"
                refresh="${BASH_REMATCH[3]}"
                # Round refresh rate for display
                refresh_rounded=$(printf "%.0f" "$refresh")
                echo -e "  ${YELLOW}[$mode_num]${NC} ${width}x${height} @ ${refresh_rounded}Hz"
            fi
            mode_num=$((mode_num + 1))
        done

        # Get best mode index
        best_mode=$(find_best_mode "$connector")
        best_idx=1
        for idx_check in "${!modes_array[@]}"; do
            if [ "${modes_array[$idx_check]}" = "$best_mode" ]; then
                best_idx=$((idx_check + 1))
                break
            fi
        done

        echo -e "\n${GREEN}Recommended: [$best_idx]${NC}"
        read -p "Select mode (or press Enter for recommended): " selected_mode_num

        if [ -z "$selected_mode_num" ]; then
            selected_mode_num=$best_idx
        fi

        # Validate selection
        if [[ ! "$selected_mode_num" =~ ^[0-9]+$ ]] || [ "$selected_mode_num" -lt 1 ] || [ "$selected_mode_num" -gt "${#modes_array[@]}" ]; then
            echo -e "${RED}Invalid selection, using recommended mode${NC}"
            selected_mode_num=$best_idx
        fi

        selected_mode="${modes_array[$((selected_mode_num - 1))]}"
        MONITOR_SELECTED_MODE["$connector"]="$selected_mode"

        # Ask for scale
        echo -e "\n${YELLOW}Scale factor (1.0 = native, 1.5 = 150%, 2.0 = 200%):${NC}"
        echo -e "  Common values: ${GREEN}1.0${NC} (native), ${GREEN}1.25${NC}, ${GREEN}1.5${NC}, ${GREEN}2.0${NC}"
        read -p "Scale [1.0]: " scale_factor

        if [ -z "$scale_factor" ]; then
            scale_factor="1.0"
        fi

        # Validate scale (basic check)
        if [[ ! "$scale_factor" =~ ^[0-9]+\.?[0-9]*$ ]]; then
            echo -e "${RED}Invalid scale, using 1.0${NC}"
            scale_factor="1.0"
        fi

        MONITOR_SCALE["$connector"]="$scale_factor"

        echo -e "${GREEN}✓ Configured: $selected_mode @ ${scale_factor}x scale${NC}"
    fi
done

# Ask for monitor order if multiple monitors
declare -a MONITOR_ORDER
if [ "$num_monitors" -gt 1 ]; then
    if [ ! -f "$FIRST_RUN_MARKER" ]; then
        # First run - use default order (as detected)
        echo -e "\n${YELLOW}First run: Using default left-to-right order${NC}"
        for i in "${!CONNECTORS[@]}"; do
            MONITOR_ORDER+=("$i")
        done
    else
        # Ask user for order
        echo -e "\n${YELLOW}Specify monitor order from left to right${NC}"
        echo -e "Enter monitor numbers separated by spaces (e.g., '1 2' or '2 1')"
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
                order_idx=$((num - 1))
                if [ "$order_idx" -ge 0 ] && [ "$order_idx" -lt "$num_monitors" ]; then
                    MONITOR_ORDER+=("$order_idx")
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
else
    # Single monitor, no ordering needed
    MONITOR_ORDER=("0")
fi

# Generate configuration with user-specified order
output_lines=""
x_position=0

for order_idx in "${MONITOR_ORDER[@]}"; do
    connector="${CONNECTORS[$order_idx]}"
    selected_mode="${MONITOR_SELECTED_MODE[$connector]}"
    scale="${MONITOR_SCALE[$connector]}"

    if [ -z "$selected_mode" ]; then
        echo -e "${RED}Error: No mode selected for $connector${NC}"
        exit 1
    fi

    # Extract width from mode
    if [[ $selected_mode =~ ([0-9]+)x([0-9]+)@ ]]; then
        width="${BASH_REMATCH[1]}"

        output_lines+="output \"$connector\" {\n"
        output_lines+="    mode \"$selected_mode\"\n"

        # Add scale if not 1.0
        if [ "$scale" != "1.0" ]; then
            output_lines+="    scale $scale\n"
        fi

        output_lines+="    position x=$x_position y=0\n"
        output_lines+="}\n\n"

        # Calculate next position (accounting for scale)
        if [ "$scale" != "1.0" ]; then
            scaled_width=$(echo "$width / $scale" | bc)
            x_position=$((x_position + scaled_width))
        else
            x_position=$((x_position + width))
        fi
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
if [ -f "$FIRST_RUN_MARKER" ] || [ "$config_mode" = "2" ]; then
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
echo -e "You can re-run this script anytime with: ${YELLOW}Mod+Shift+M${NC}"
