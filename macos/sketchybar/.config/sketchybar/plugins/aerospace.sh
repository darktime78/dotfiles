#!/bin/bash
# Workspace button: bright when focused, dimmed otherwise (like style.css on sway);
# empty workspaces are hidden, as on sway / i3.
source "$CONFIG_DIR/colors.sh"
sid=$1
focused=${FOCUSED_WORKSPACE:-$(aerospace list-workspaces --focused)}

if [[ $sid == "$focused" ]]; then
	sketchybar --set "$NAME" drawing=on background.color=$WS_COLOR \
		icon.color=0xffffffff label.color=0xffffffff
elif [[ -n $(aerospace list-windows --workspace "$sid" 2>/dev/null) ]]; then
	sketchybar --set "$NAME" drawing=on background.color=0x8c${WS_COLOR:4} \
		icon.color=$WS_TEXT label.color=$WS_TEXT
else
	sketchybar --set "$NAME" drawing=off
fi
