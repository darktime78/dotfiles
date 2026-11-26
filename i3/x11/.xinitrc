#!/bin/sh
# startx -> i3 (zsh starts it on tty1 when ~/.config/dotfiles/profile says "i3")

# system snippets: D-Bus, keyring, ... (from the xorg-xinit package)
if [ -d /etc/X11/xinit/xinitrc.d ]; then
	for f in /etc/X11/xinit/xinitrc.d/?*.sh; do
		[ -x "$f" ] && . "$f"
	done
	unset f
fi

export XDG_CURRENT_DESKTOP=i3 XDG_SESSION_TYPE=x11
# notify-send, portals and systemd user services need to know the display
dbus-update-activation-environment --systemd DISPLAY XAUTHORITY XDG_CURRENT_DESKTOP 2>/dev/null

# screens before i3 starts, so the bars see the final layout (same as the sway config).
# Missing outputs are ignored. Machine specific: ~/.xinitrc.local
xrandr --output eDP-1 --mode 2256x1504 --pos 0x0 --output DP-5 --mode 2560x1440 --pos 2256x0 2>/dev/null
# keyboard: us,ru, Win+Space switches (same as sway)
setxkbmap -layout us,ru -option '' -option grp:win_space_toggle
xset r rate 300 30
command -v numlockx >/dev/null && numlockx on
[ -r ~/.xinitrc.local ] && . ~/.xinitrc.local

exec i3
