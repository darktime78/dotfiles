#!/bin/bash
# 1 min load average; red above 90 % of the cores (as on Linux)
source "$CONFIG_DIR/colors.sh"
load=$(sysctl -n vm.loadavg | awk '{print $2}')
cores=$(sysctl -n hw.ncpu)
color=$TEXT_COLOR
awk -v l="$load" -v c="$cores" 'BEGIN{exit !(l > c * 0.9)}' && color=$BAD_COLOR
sketchybar --set "$NAME" label="$load" label.color=$color
