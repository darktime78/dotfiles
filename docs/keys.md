# Keys

The same on sway (Wayland) and i3 (X11): `tools/check_parity.py` checks it.
`$mod` is the Windows key on Linux and **Option (⌥)** on macOS (AeroSpace).
The last column says what macOS does instead, if it differs.

## Windows and workspaces

| Key | Does | macOS |
|---|---|---|
| `$mod+j` `k` `i` `l` | focus left / down / up / right | |
| `$mod+Shift+j` `k` `i` `l` | move the window | |
| `$mod+Ctrl+Shift+j` / `l` | move the workspace to the left / right screen | |
| `$mod+1` … `$mod+0` | workspace 1 … 10 | |
| `$mod+Shift+1` … `0` | move the window to workspace 1 … 10 | |
| `$mod+h` / `$mod+v` | next window opens beside / below | joins with the window left / above |
| `$mod+f` | fullscreen | |
| `$mod+w` | tabbed | accordion |
| `$mod+e` | toggle split direction | |
| `$mod+Shift+space` | floating on / off | |
| `$mod+Tab` | focus between floating and tiled | – |
| `$mod+Shift+minus` / `$mod+minus` | to the scratchpad / show it | – |
| `$mod+r` | resize mode: `j k i l` by 10, arrows by 1, Enter / Esc to leave | |
| `Ctrl+Shift+q` | close the window | |

Workspaces: 1 browser · 2 terminal · 3 editors (Neovim, Sublime, VS Code) · 4 games (Steam, Wine) ·
5 Chromium · 6 files · 7 mail · 8 Claude · 9 Telegram / Discord · 10 video editing.
Apps open on their workspace by themselves (window rules in the sway / i3 / AeroSpace
config).

## Apps

| Key | Does | macOS |
|---|---|---|
| `Ctrl+Alt+t` | terminal (Alacritty; Ghostty on macOS) | |
| `$mod+d`, `Alt+F2` | app launcher (rofi) | `Cmd+Space` |
| `$mod+Shift+d` | run a command | – |
| `Alt+Tab` | switch to an open window | `Cmd+Tab` |
| `$mod+c` | Docker apps: start / stop (rofi-docker) | – |
| `$mod+period` | emoji picker | `Ctrl+Cmd+Space` |
| `$mod+equal` | calculator | – |

## Session

| Key | Does | macOS |
|---|---|---|
| `$mod+Shift+e` | power menu: lock, suspend, log out, reboot, power off | – |
| `Ctrl+Alt+Shift+l` | lock | screen off (asks the password) |
| `Ctrl+Alt+Shift+s` | suspend | sleep |
| `$mod+Shift+r` | reload the config (i3: restart in place) | |
| `$mod+m` / `$mod+Shift+m` | hide or show the bars / restart them | SketchyBar |
| `$mod+n` | do not disturb on / off | – |
| `Ctrl+Shift+space` / `$mod+Shift+n` | dismiss all notifications / bring the last back | – |
| `F12` / `Shift+F12` / `Ctrl+F12` | screenshot: screen / window / area (`~/Screenshots` + clipboard) | `Cmd+Shift+3/4/5` |
| `$mod+space` | next keyboard layout (us, ru) | `Ctrl+Space` |

## Media

| Key | Does |
|---|---|
| volume keys, mic mute | volume ±5 %, mute (also on the lock screen on sway) |
| brightness keys | ±5 %, never fully dark |
| `Ctrl+space`, `Ctrl+PgUp` / `PgDn` | music (mpd): play / pause, previous / next |

## Bars (sway, i3)

Top: workspaces · eye (auto lock on / off) · volume · brightness · free memory · free
disk · power profile · battery · load · keyboard layout · time · tray.
Bottom: FIM / Router (LocalAI on / off) · music · network speed · Wi-Fi · traffic since
reset · Bluetooth · date.

| Click | Does |
|---|---|
| volume | mixer (right click: mute; on i3 left click mutes, right click opens the mixer) |
| memory, load | htop |
| power profile | next profile |
| layout | next layout |
| network | nmtui |
| traffic | right click: reset |
| Bluetooth | bluetoothctl |
| FIM / Router | start / stop that service (`~/.config/dotfiles/services.conf`) |
| date | calendar (sway: hover, scroll for other months; i3: click) |

Idle, the same on sway and i3: 4 min dim, 5 min lock, 5.5 min screen off, 15 min
suspend (only on battery). Locked before every suspend.
