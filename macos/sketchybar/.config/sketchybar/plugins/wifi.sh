#!/bin/bash
# Wi-Fi name and IP. macOS 15+ hides the name from apps without Location access;
# then only the IP is shown.
source "$CONFIG_DIR/colors.sh"
dev=$(networksetup -listallhardwareports | awk '/Wi-Fi/ {getline; print $2; exit}')
ip=$(ipconfig getifaddr "${dev:-en0}" 2>/dev/null)
ssid=$(ipconfig getsummary "${dev:-en0}" 2>/dev/null | awk -F' SSID : ' '/ SSID : / {print $2; exit}')
if [[ -z $ip ]]; then
	sketchybar --set "$NAME" icon="$ICON_NET_DOWN" label="down"
elif [[ -n $ssid && $ssid != "<redacted>" ]]; then
	sketchybar --set "$NAME" icon="$ICON_WIFI" label="$ssid - $ip"
else
	sketchybar --set "$NAME" icon="$ICON_WIFI" label="$ip"
fi
