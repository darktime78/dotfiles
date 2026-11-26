#!/bin/bash
# battery: hidden on desktops; yellow below 25 %, red below 10 %
source "$CONFIG_DIR/colors.sh"
info=$(pmset -g batt)
pct=$(grep -Eo '[0-9]+%' <<<"$info" | head -1 | tr -d %)
[[ -z $pct ]] && { sketchybar --set "$NAME" drawing=off; exit 0; }

read -ra icons <<<"$ICON_BAT"
if grep -q 'AC Power' <<<"$info"; then
	icon=$ICON_PLUG
	grep -q 'charging;' <<<"$info" && icon=$ICON_CHARGE
else
	icon=${icons[$((pct * 5 / 101))]}
fi
color=$TEXT_COLOR
((pct < 25)) && color=$WARN_COLOR
((pct < 10)) && color=$BAD_COLOR
sketchybar --set "$NAME" drawing=on icon="$icon" label="$pct%" label.color=$color
