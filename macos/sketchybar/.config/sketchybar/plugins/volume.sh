#!/bin/bash
source "$CONFIG_DIR/colors.sh"
vol=${INFO:-$(osascript -e 'output volume of (get volume settings)')}
read -ra icons <<<"$ICON_VOL"
if [[ $(osascript -e 'output muted of (get volume settings)') == true ]]; then
	sketchybar --set "$NAME" icon="$ICON_MUTE" label="MUTE"
else
	i=$((vol >= 66 ? 2 : vol >= 33 ? 1 : 0))
	sketchybar --set "$NAME" icon="${icons[$i]}" label="$vol%"
fi
