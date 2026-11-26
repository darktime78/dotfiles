#!/bin/bash
# keyboard layout as a flag (like sway / i3). Ctrl+Space switches.
name=$(defaults read ~/Library/Preferences/com.apple.HIToolbox.plist AppleSelectedInputSources 2>/dev/null |
	sed -n 's/.*"KeyboardLayout Name" = "\{0,1\}\([^";]*\)"\{0,1\};/\1/p' | head -1)
case $name in
*Russian*) flag="🇷🇺" ;;
*Ukrainian*) flag="🇺🇦" ;;
*British*) flag="🇬🇧" ;;
*German*) flag="🇩🇪" ;;
*French*) flag="🇫🇷" ;;
U.S. | ABC | US*) flag="🇺🇸" ;;
*) flag=${name:-?} ;;
esac
sketchybar --set "$NAME" label="$flag"
