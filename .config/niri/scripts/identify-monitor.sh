#!/bin/bash
#
# Visual Monitor Identification Helper
# Shows a large colored identifier on each monitor
#

if [ -z "$1" ]; then
    echo "Usage: $0 <monitor_number> <connector_name>"
    exit 1
fi

MONITOR_NUM="$1"
CONNECTOR="$2"

# Create a temporary window that shows the monitor number
# Using kitty to display a large number
kitty --class "monitor-identifier-$MONITOR_NUM" \
      --title "Monitor $MONITOR_NUM" \
      -o font_size=200 \
      -o background_opacity=0.95 \
      -o background='#000000' \
      -o foreground='#00ff00' \
      bash -c "
clear
tput cup 5 5
echo '╔════════════════════╗'
tput cup 6 5
echo '║                    ║'
tput cup 7 5
echo '║   MONITOR  $MONITOR_NUM      ║'
tput cup 8 5
echo '║                    ║'
tput cup 9 5
echo '║   $CONNECTOR    ║'
tput cup 10 5
echo '║                    ║'
tput cup 11 5
echo '╚════════════════════╝'
sleep 3
" &

