#!/bin/bash
# free space on the data volume
source "$CONFIG_DIR/colors.sh"
read -r free used < <(df -H /System/Volumes/Data | awk 'NR==2 {print $4, $5}')
color=$TEXT_COLOR
((${used%\%} >= 90)) && color=$BAD_COLOR
sketchybar --set "$NAME" label="$free" label.color=$color
