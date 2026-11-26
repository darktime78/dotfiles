#!/usr/bin/env python3
"""Generate the bar configs from ONE place, so sway, i3 and macOS look the same.

    python3 tools/make_bars.py          (run from anywhere; writes into the repo)

Writes:
    wayland/waybar/.config/waybar/config.jsonc     waybar (sway), Pango markup
    i3/polybar/.config/polybar/config.ini          polybar (i3), %{...} format tags
    macos/sketchybar/.config/sketchybar/colors.sh  SketchyBar (macOS) colours + icons

Change colours, icons, or which module sits where here, then run it again.
Hand-written parts that stay as they are: waybar/style.css, sketchybar/sketchybarrc.

Look: "powerline" segments   ◤ icon ◤ text ◤   made of the Nerd Font arrow U+E0B8,
two shades per segment (icon part / text part). Workspaces are parallelograms.
"""
import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BIN = "$HOME/.local/bin"            # the shared scripts (linux/scripts)

# ---------------------------------------------------------------- palette
BG = '#2f343f'      # bar background
ICON = '#000000'    # icon colour
TEXT = '#eef6eb'    # normal text
BAD = '#ff5252'     # warning / critical text
WARN = '#ffcc66'
DIM = '#9aa0a6'     # "off" buttons
ARROW = ''    # nf-ple-lower_left_triangle

GREEN = ('#597262', '#4d504e')
GREY = ('#445d67', '#3b4549')
PLUM = ('#6e4555', '#4e3c43')
OLIVE = ('#8b8367', '#626059')
CLAY = ('#c77a69', '#8e665d')

WS_COLOR = '#64727d'
WS_TEXT = '#c5c8c6'
URGENT = '#eb4d4b'
THIN = ' '          # thin space: keeps workspace buttons narrow
LEDGE = ''         # parallelogram tilted left: upper-right triangle...
REDGE = ''         # ...and lower-left triangle

ICON_FONT = 'Hack Nerd Font Propo'   # icons: proportional, so never cut off
NMTUI = "alacritty --class nmtui -e nmtui"   # floating, see sway / i3 config

# Workspace icons (Nerd Fonts; checked against glyphnames.json)
WS = {
    "1":  "",      # browser    nf-fa-firefox
    "2":  "",      # console    nf-fa-terminal
    "3":  "",      # editors    nf-custom-neovim
    "4":  "",      # steam      nf-fa-steam (docker)
    "5":  "",      # chromium   nf-fa-chrome (docker)
    "6":  "",      # files      nf-fa-folder_open (pcmanfm)
    "7":  "",      # mail       nf-fa-envelope
    "8":  "",      # claude     nf-cod-claude
    "9":  "",      # telegram   nf-fa-telegram
    "10": "\U000f1122",  # video edit nf-md-movie_edit (kdenlive)
}

# icons (Font Awesome 4 code points, all inside the Nerd Fonts)
I = dict(
    vol=['\uf026', '\uf027', '\uf028'], headphone='\uf025', bt_audio='\uf293', mute='\uf026',
    sun=['\uf186', '\uf185'], mem='\uf2db', disk='\uf0a0', cpu='\uf0e4',
    bat=['\uf244', '\uf243', '\uf242', '\uf241', '\uf240'], plug='\uf1e6', charge='\uf0e7',
    lang='\uf1ab', clock='\uf017', cal='\uf073', mode='\uf054\uf105',
    eye_open='\uf06e', eye_closed='\uf070',
    perf='\uf135', balanced='\uf24e', saver='\uf06c',
    play='\uf04b', pause='\uf04c',
    down='\uf063', up='\uf062', wifi='\uf1eb', signal='\uf012', eth='\uf0e8', net_down='\uf1eb',
    total_down='\uf063', total_up='\uf062', bt='\uf294',
    fim='\uf121', router='\uf0ec',
)
SERVICES = (("fim", I['fim'], "FIM"), ("router", I['router'], "Router"))
FLAGS = {"us": "🇺🇸", "gb": "🇬🇧", "ru": "🇷🇺", "ua": "🇺🇦", "de": "🇩🇪",
         "fr": "🇫🇷", "es": "🇪🇸", "it": "🇮🇹", "pl": "🇵🇱", "by": "🇧🇾"}


# ---------------------------------------------------------------- segments
# A segment is a list of parts: (background, foreground, text, kind)
# kind: "arrow", "icon" or "text". Rendered for waybar or polybar below.
def seg(colors, ic, text, fg=TEXT):
    """◤ icon ◤ text ◤"""
    a, b = colors
    return [(a, BG, ARROW, 'arrow'), (a, ICON, ic, 'icon'), (b, a, ARROW, 'arrow'),
            (b, fg, text, 'text'), (BG, b, ARROW, 'arrow')]


def seg2(colors, ic1, t1, ic2, t2):
    """◤ icon ◤ text ◤ icon ◤ text ◤"""
    a, b = colors
    return [(a, BG, ARROW, 'arrow'), (a, ICON, ic1, 'icon'), (b, a, ARROW, 'arrow'),
            (b, TEXT, t1, 'text'), (a, b, ARROW, 'arrow'), (a, ICON, ic2, 'icon'),
            (b, a, ARROW, 'arrow'), (b, TEXT, t2, 'text'), (BG, b, ARROW, 'arrow')]


def seg1(colors, ic):
    """◤ icon ◤"""
    a, _ = colors
    return [(a, BG, ARROW, 'arrow'), (a, ICON, ic, 'icon'), (BG, a, ARROW, 'arrow')]


def pango(parts):
    out = ''
    for bg, fg, text, kind in parts:
        font = f" font_family='{ICON_FONT}'" if kind == 'icon' else ''
        out += f"<span background='{bg}' foreground='{fg}'{font}>{text}</span>"
    return out


# polybar fonts (see [bar/base]): T1 text, T2 icons, T3 flags, T4 arrows
def poly(parts):
    out = ''
    for bg, fg, text, kind in parts:
        t = {'icon': 2, 'arrow': 4}.get(kind)
        body = f"%{{T{t}}}{text}%{{T-}}" if t else text
        out += f"%{{B{bg}}}%{{F{fg}}}{body}"
    return out + "%{B- F-}"


def blend(fg, bg, alpha):
    """colour fg drawn with opacity alpha over bg (polybar has no opacity)"""
    f = [int(fg[i:i + 2], 16) for i in (1, 3, 5)]
    b = [int(bg[i:i + 2], 16) for i in (1, 3, 5)]
    return '#' + ''.join(f'{round(x * alpha + y * (1 - alpha)):02x}' for x, y in zip(f, b))


# ================================================================ waybar
def parallelogram(text, c=WS_COLOR):
    """\\ body \\  - text colour comes from style.css, so state styling still works"""
    return (f"<span foreground='{c}'>{LEDGE}</span>"
            f"<span background='{c}'>{THIN}{text}{THIN}</span>"
            f"<span foreground='{c}'>{REDGE}</span>")


def waybar():
    P = lambda *a, **k: pango(seg(*a, **k))
    top = {
        "layer": "top",
        "position": "top",
        "height": 12,
        "reload_style_on_change": True,
        "modules-left": ["sway/workspaces", "sway/mode", "sway/scratchpad"],
        "modules-right": ["idle_inhibitor", "pulseaudio", "backlight", "memory", "disk",
                          "power-profiles-daemon", "battery", "cpu", "sway/language",
                          "clock#time", "tray"],

        # Parallelogram buttons, tilted left. The colour is fixed in the markup;
        # focused / urgent / other workspaces differ by style.css (opacity + text colour).
        "sway/workspaces": {
            "disable-scroll": True,
            "format": parallelogram("{value}{icon}"),  # {value} = workspace name
            "format-icons": {**{k: f"{THIN}<span font_family='{ICON_FONT}'>{v}</span>"
                                for k, v in WS.items()}, "default": ""},
        },
        "sway/mode": {"format": I['mode'] + " {}"},
        "sway/scratchpad": {
            "format": "{icon} {count}", "show-empty": False,
            "format-icons": ["", ""], "tooltip-format": "{app}: {title}",
        },
        "idle_inhibitor": {
            "format": "{icon}",
            "format-icons": {"activated": pango(seg1(CLAY, I['eye_open'])),
                             "deactivated": pango(seg1(GREY, I['eye_closed']))},
            "tooltip-format-activated": "Screen stays on (auto lock off)",
            "tooltip-format-deactivated": "Auto lock / screen off on",
        },
        "pulseaudio": {
            "format": P(GREEN, "{icon}", "{volume}%"),
            "format-bluetooth": P(GREEN, I['bt_audio'], "{volume}%"),
            "format-muted": P(GREEN, I['mute'], "MUTE"),
            "format-icons": {"headphone": I['headphone'], "default": I['vol']},
            "scroll-step": 5, "max-volume": 100,
            "tooltip-format": "{desc}\nClick: mixer, right click: mute, scroll: volume",
            "on-click": "pavucontrol",
            "on-click-right": "pamixer -t",
        },
        "backlight": {
            "format": P(GREEN, "{icon}", "{percent}%"),
            "format-icons": I['sun'],
            "scroll-step": 5, "tooltip": False,
        },
        "memory": {
            "interval": 10,
            "format": P(GREY, I['mem'], "{avail:0.1f}G"),
            "format-critical": P(GREY, I['mem'], "{avail:0.1f}G", BAD),
            "states": {"critical": 90},
            "tooltip-format": "Used {used:0.1f}G of {total:0.1f}G\nSwap {swapUsed:0.1f}G",
            "on-click": "alacritty -e htop",
        },
        "disk": {
            "interval": 120,
            "path": "/home",
            "format": P(GREY, I['disk'], "{free}"),
            "format-alt": P(GREY, I['disk'], "{percentage_used}%"),
            "format-alt-click": "click-right",
            "format-critical": P(GREY, I['disk'], "{free}", BAD),
            "states": {"critical": 90},
            "tooltip-format": "{path}: {used} of {total} used",
        },
        "power-profiles-daemon": {
            "format": "{icon}",
            "format-icons": {
                "default": pango(seg1(GREEN, I['balanced'])),
                "performance": pango(seg1(CLAY, I['perf'])),
                "balanced": pango(seg1(GREEN, I['balanced'])),
                "power-saver": pango(seg1(GREEN, I['saver'])),
            },
            "tooltip-format": "Power profile: {profile}\nClick to change",
        },
        "battery": {
            "interval": 30,
            "states": {"warning": 25, "critical": 10},
            "format": P(GREEN, "{icon}", "{capacity}%"),
            "format-warning": P(GREEN, "{icon}", "{capacity}%", WARN),
            "format-critical": P(GREEN, "{icon}", "{capacity}%", BAD),
            "format-charging": P(GREEN, I['charge'], "{capacity}%"),
            "format-plugged": P(GREEN, I['plug'], "{capacity}%"),
            "format-full": P(GREEN, I['plug'], "{capacity}%"),
            "format-icons": I['bat'],
            "tooltip-format": "{timeTo}\nDrain: {power:0.1f} W",
        },
        "cpu": {
            "interval": 10,
            "format": P(GREY, I['cpu'], "{load:0.2f}"),
            "format-critical": P(GREY, I['cpu'], "{load:0.2f}", BAD),
            "states": {"critical": 90},
            "tooltip-format": "CPU usage: {usage}%",
            "on-click": "alacritty -e htop",
        },
        # Flags need a colour emoji font (noto-fonts-emoji); the layout name is in the
        # tooltip. min-length = width of the block, so it is never squeezed to "...".
        "sway/language": {
            "format": P(OLIVE, I['lang'], "{flag}"),
            "min-length": 7,
            "align": 0.5,
            "tooltip-format": "{long}  (click: next layout)",
            "on-click": "swaymsg input type:keyboard xkb_switch_layout next",
        },
        "clock#time": {
            "format": P(CLAY, I['clock'], "{:%H:%M}"),
            "interval": 60,
            "tooltip": False,
        },
        "tray": {"icon-size": 12, "spacing": 6},
    }

    bottom = {
        "layer": "bottom",
        "position": "bottom",
        "height": 12,
        "modules-left": [f"custom/{n}" for n, _, _ in SERVICES],
        "modules-right": ["mpd", "network#speed", "network#wifi", "custom/downloaded",
                          "bluetooth", "clock#date"],
        # LocalAI on/off buttons (~/.config/dotfiles/services.conf).
        # Bright when running, grey when stopped. Click = start / stop.
        **{f"custom/{name}": {
            "exec": f"{BIN}/bar-service {name}",
            "return-type": "json",
            "interval": 30,
            "signal": 9,
            "format": "{icon}",
            "format-icons": {"on": P(CLAY, ic, label), "off": P(GREY, ic, label, DIM)},
            "on-click": f"{BIN}/bar-service {name} toggle",
        } for name, ic, label in SERVICES},
        # native module: waits for MPD events, no polling
        "mpd": {
            "format": P(GREEN, "{stateIcon}", "{artist} - {title}"),
            "state-icons": {"playing": I['play'], "paused": I['pause']},
            "format-stopped": "",
            "format-disconnected": "",
            "max-length": 40,
            "tooltip-format": "{album}\n{elapsedTime:%M:%S} / {totalTime:%M:%S}",
            "on-click": "mpc -q toggle",
            "on-scroll-up": "mpc -q prev",
            "on-scroll-down": "mpc -q next",
        },
        # follows the default route
        "network#speed": {
            "on-click": NMTUI,
            "interval": 5,
            "format": pango(seg2(PLUM, I['down'], "{bandwidthDownBytes}",
                                 I['up'], "{bandwidthUpBytes}")),
            "format-disconnected": "",
            "tooltip": False,
        },
        "network#wifi": {
            "on-click": NMTUI,
            "interval": 10,
            "format-wifi": pango(seg2(PLUM, I['wifi'], "{essid} - {ipaddr}",
                                      I['signal'], "{signalStrength}%")),
            "format-ethernet": P(PLUM, I['eth'], "{ipaddr}"),
            "format-linked": P(PLUM, I['eth'], "no IP"),
            "format-disconnected": P(PLUM, I['net_down'], "down"),
            "tooltip-format": "{ifname}: {ipaddr}/{cidr} via {gwaddr}",
            "tooltip-format-wifi": "{essid} {frequency} GHz\n{ifname}: {ipaddr}/{cidr} via {gwaddr}",
        },
        # traffic since the last reset (right click = reset), every 30 s
        "custom/downloaded": {
            "exec": f"{BIN}/net-total",
            "signal": 8,  # net-total-reset refreshes it at once
            "return-type": "json",
            "interval": 30,
            "format": pango(seg2(PLUM, I['total_down'], "{}", I['total_up'], "{alt}")),
            "on-click-right": f"{BIN}/net-total-reset",
        },
        # D-Bus events, no polling
        "bluetooth": {
            "format": P(PLUM, I['bt'], "on"),
            "format-off": P(PLUM, I['bt'], "down"),
            "format-disabled": P(PLUM, I['bt'], "down"),
            "format-connected": P(PLUM, I['bt'], "Con: {num_connections}"),
            "format-no-controller": "",
            "tooltip-format": "Bluetooth {status}",
            "tooltip-format-connected": "{device_enumerate}",
            "tooltip-format-enumerate-connected": "{device_alias}",
            "on-click": "alacritty --class bluetoothctl -e bluetoothctl",
        },
        # calendar: hover = month, scroll = other months, right click = year
        "clock#date": {
            "format": P(CLAY, I['cal'], "{:%a %d %b}"),
            "interval": 60,
            "tooltip-format": "<tt><small>{calendar}</small></tt>",
            "calendar": {
                "mode": "month", "mode-mon-col": 1, "weeks-pos": "right", "on-scroll": 1,
                "format": {
                    "months": "<span color='#ffead3'><b>{}</b></span>",
                    "days": "<span color='#ecc6d9'><b>{}</b></span>",
                    "weeks": "<span color='#99ffdd'><b>W{}</b></span>",
                    "weekdays": "<span color='#ffcc66'><b>{}</b></span>",
                    "today": "<span color='#ff6699'><b><u>{}</u></b></span>",
                },
            },
            "actions": {"on-click-right": "mode", "on-scroll-up": "shift_up",
                        "on-scroll-down": "shift_down"},
        },
    }
    header = ("// Waybar (sway): two bars (top + bottom) in ONE waybar process.\n"
              "// GENERATED by tools/make_bars.py - edit that file, not this one.\n"
              "// Powerline segments are Pango markup; all modules are native (event driven\n"
              "// or slow polling), only the FIM/Router buttons and the traffic counter run\n"
              "// a tiny script, every 30 s.\n")
    return header + json.dumps([top, bottom], indent=2, ensure_ascii=True) + "\n"


# ================================================================ polybar
def polybar():
    def Q(s):
        """one shell argument (markup has no single quotes)"""
        assert "'" not in s
        return f"'{s}'"

    def act(fmt, **clicks):
        """wrap a format in click actions: act(fmt, A1='cmd', A3='cmd')"""
        for btn, cmd in clicks.items():
            fmt = f"%{{{btn}:{cmd.replace(':', chr(92) + ':')}:}}{fmt}%{{A}}"
        return fmt

    def status(every, *args):
        """custom/script fed by bar-status (prints again at once on bar-status refresh)"""
        return {"type": "custom/script", "tail": "true",
                "exec": f"exec {BIN}/bar-status --every {every} " + " ".join(args)}

    def ws_label(text_col, ws_col):
        return (f"%{{F{ws_col}}}%{{T4}}{LEDGE}%{{T-}}%{{B{ws_col}}}%{{F{text_col}}}"
                f"{THIN}%name%%{{T2}}%icon%%{{T-}}{THIN}%{{B-}}%{{F{ws_col}}}%{{T4}}{REDGE}%{{T-}}%{{F-}}")

    S = lambda *a, **k: poly(seg(*a, **k))
    mods = {}
    mods['i3'] = {
        "type": "internal/i3",
        "pin-workspaces": "true",      # each monitor shows its own workspaces
        "index-sort": "true",
        "enable-scroll": "false",
        "wrapping-scroll": "false",
        **{f"ws-icon-{n}": f"{k};{THIN}{v}" for n, (k, v) in enumerate(WS.items())},
        "ws-icon-default": "",
        "format": "<label-state> <label-mode>",
        "label-focused": ws_label('#ffffff', WS_COLOR),
        "label-visible": ws_label(blend(WS_TEXT, WS_COLOR, .75), blend(WS_COLOR, BG, .75)),
        "label-unfocused": ws_label(blend(WS_TEXT, WS_COLOR, .55), blend(WS_COLOR, BG, .55)),
        "label-urgent": ws_label(BAD, WS_COLOR),
        "label-mode": f" {I['mode']} %mode% ",
        "label-mode-background": URGENT,
    }
    mods['idle'] = status(30, "idle", Q(poly(seg1(CLAY, I['eye_open']))),
                          Q(poly(seg1(GREY, I['eye_closed']))))
    mods['idle']["click-left"] = f"{BIN}/wm-idle toggle"
    mods['pulseaudio'] = {
        "type": "internal/pulseaudio",
        "use-ui-max": "false", "interval": 5,
        "format-volume": S(GREEN, "<ramp-volume>", "<label-volume>"),
        "label-volume": "%percentage%%",
        **{f"ramp-volume-{i}": v for i, v in enumerate(I['vol'])},
        "format-muted": S(GREEN, I['mute'], "MUTE"),
        "click-right": "pavucontrol",   # left click: mute, scroll: volume
    }
    mods['backlight'] = {
        "type": "internal/backlight",
        "card": "${env:BAR_BACKLIGHT:intel_backlight}",   # set by wm-bar
        "use-actual-brightness": "true", "enable-scroll": "true",
        "format": S(GREEN, "<ramp>", "<label>"),
        "label": "%percentage%%",
        **{f"ramp-{i}": v for i, v in enumerate(I['sun'])},
    }
    mods['memory'] = {
        "type": "internal/memory", "interval": 10, "warn-percentage": 90,
        "format": act(S(GREY, I['mem'], "<label>"), A1="alacritty -e htop"),
        "format-warn": act(S(GREY, I['mem'], "<label-warn>", BAD), A1="alacritty -e htop"),
        "label": "%gb_free%", "label-warn": "%gb_free%",
    }
    mods['disk'] = {
        "type": "internal/fs", "interval": 120, "warn-percentage": 90,
        "mount-0": "${env:BAR_DISK:/}",                   # /home if it is its own disk
        "format-mounted": S(GREY, I['disk'], "<label-mounted>"),
        "format-warn": S(GREY, I['disk'], "<label-warn>", BAD),
        "label-mounted": "%free%", "label-warn": "%free%",
        "format-unmounted": "",
    }
    mods['power'] = status(30, "power", Q(poly(seg1(CLAY, I['perf']))),
                           Q(poly(seg1(GREEN, I['balanced']))), Q(poly(seg1(GREEN, I['saver']))))
    mods['power']["click-left"] = f"{BIN}/bar-status power-next"
    mods['battery'] = {
        "type": "internal/battery",
        "battery": "${env:BAR_BATTERY:BAT0}", "adapter": "${env:BAR_ADAPTER:AC}",
        "full-at": 99, "low-at": 10, "poll-interval": 30,
        "format-discharging": S(GREEN, "<ramp-capacity>", "<label-discharging>"),
        "format-low": S(GREEN, "<ramp-capacity>", "<label-low>", BAD),
        "format-charging": S(GREEN, I['charge'], "<label-charging>"),
        "format-full": S(GREEN, I['plug'], "<label-full>"),
        "label-discharging": "%percentage%%", "label-low": "%percentage%%",
        "label-charging": "%percentage%%", "label-full": "%percentage%%",
        **{f"ramp-capacity-{i}": v for i, v in enumerate(I['bat'])},
    }
    mods['load'] = status(10, "load", Q(S(GREY, I['cpu'], "@LOAD@")),
                          Q(S(GREY, I['cpu'], "@LOAD@", BAD)))
    mods['load']["click-left"] = "alacritty -e htop"
    mods['language'] = {
        "type": "internal/xkeyboard",
        "blacklist-0": "num lock", "blacklist-1": "scroll lock",
        "format": S(OLIVE, I['lang'], " <label-layout> "),   # click: next layout
        "label-layout": "%{T3}%icon%%{T-}",
        **{f"layout-icon-{n}": f"{k};{v}" for n, (k, v) in enumerate(FLAGS.items())},
        "layout-icon-default": "%layout%",
        "label-indicator-on": "",
    }
    mods['time'] = {
        "type": "internal/date", "interval": 30, "time": "%H:%M",
        "format": S(CLAY, I['clock'], "<label>"), "label": "%time%",
    }
    mods['tray'] = {"type": "internal/tray", "tray-size": "70%", "tray-spacing": 6,
                    "tray-background": BG}
    for name, ic, label in SERVICES:
        mods[name] = status(30, "service", name, Q(S(CLAY, ic, label)),
                            Q(S(GREY, ic, label, DIM)))
        mods[name]["click-left"] = f"{BIN}/bar-service {name} toggle"
    mods['mpd'] = {
        "type": "internal/mpd", "interval": 2,
        "format-online": act(S(GREEN, "<toggle>", "<label-song>"),
                             A4="mpc -q prev", A5="mpc -q next"),
        "format-stopped": " ", "format-offline": " ",
        "label-song": "%artist% - %title%", "label-song-maxlen": 40,
        "label-song-ellipsis": "true",
        # <toggle> shows icon-play while paused: same look as waybar's state icon
        "icon-play": I['pause'], "icon-pause": I['play'],
    }
    mods['speed'] = {
        "type": "internal/network", "interface-type": "wireless", "interval": 5,
        "format-connected": act(poly(seg2(PLUM, I['down'], "%downspeed%", I['up'], "%upspeed%")),
                                A1=NMTUI),
        "format-disconnected": "",
    }
    mods['wifi'] = {
        "type": "internal/network", "interface-type": "wireless", "interval": 10,
        "format-connected": act(poly(seg2(PLUM, I['wifi'], "%essid% - %local_ip%",
                                          I['signal'], "%signal%%")), A1=NMTUI),
        "format-disconnected": act(S(PLUM, I['net_down'], "down"), A1=NMTUI),
    }
    mods['eth'] = {
        "type": "internal/network", "interface-type": "wired", "interval": 10,
        "format-connected": act(S(PLUM, I['eth'], "%local_ip%"), A1=NMTUI),
        "format-disconnected": "",
    }
    mods['traffic'] = status(30, "traffic", Q(poly(seg2(PLUM, I['total_down'], "@DOWN@",
                                                         I['total_up'], "@UP@"))))
    mods['traffic']["click-right"] = f"{BIN}/net-total-reset"
    mods['bluetooth'] = status(15, "bluetooth", Q(S(PLUM, I['bt'], "down")),
                               Q(S(PLUM, I['bt'], "on")), Q(S(PLUM, I['bt'], "Con: @N@")))
    mods['bluetooth']["click-left"] = "alacritty --class bluetoothctl -e bluetoothctl"
    mods['date'] = {
        "type": "internal/date", "interval": 60, "date": "%a %d %b",
        "format": act(S(CLAY, I['cal'], "<label>"),
                      A1='notify-send -t 15000 Calendar "$(cal)"'),
        "label": "%date%",
    }

    bars = {
        "bar/base": {
            "monitor": "${env:MONITOR:}",
            "width": "100%", "height": 16,
            "background": BG, "foreground": TEXT,
            "line-size": 0, "padding": 0, "module-margin": 0,
            # T1 text, T2 icons (proportional: never cut off), T3 flags, T4 arrows.
            # Gaps above/below the arrows? Change the pixelsize of font-3 or the height.
            "font-0": "Hack Nerd Font:pixelsize=12;2",
            "font-1": f"{ICON_FONT}:pixelsize=12;2",
            "font-2": "Noto Color Emoji:scale=10;2",
            "font-3": "Hack Nerd Font:pixelsize=15;3",
            "enable-ipc": "true",
            "cursor-click": "pointer",
            "wm-restack": "i3", "override-redirect": "false",
        },
        "bar/top": {
            "inherit": "bar/base", "bottom": "false",
            "modules-left": "i3",
            "modules-right": "idle pulseaudio backlight memory disk power battery load language time tray",
        },
        "bar/bottom": {
            "inherit": "bar/base", "bottom": "true",
            "modules-left": " ".join(n for n, _, _ in SERVICES),
            "modules-right": "mpd speed wifi eth traffic bluetooth date",
        },
        "settings": {"screenchange-reload": "true", "pseudo-transparency": "false"},
    }

    def ini_val(v):
        v = str(v)
        return f'"{v}"' if v != v.strip() or v == '' else v

    out = ["; Polybar (i3): the same two bars as waybar on sway.",
           "; GENERATED by tools/make_bars.py - edit that file, not this one.",
           "; Started by wm-bar (one top and one bottom bar per monitor).", ""]
    for name, sect in list(bars.items()) + [(f"module/{k}", v) for k, v in mods.items()]:
        out.append(f"[{name}]")
        out += [f"{k} = {ini_val(v)}" for k, v in sect.items()]
        out.append("")
    return "\n".join(out)


# ================================================================ sketchybar
def sketchybar():
    c = lambda h: '0xff' + h[1:]
    lines = ["#!/bin/bash",
             "# SketchyBar colours and icons, the same as waybar / polybar.",
             "# GENERATED by tools/make_bars.py - edit that file, not this one.", "",
             f"BAR_COLOR={c(BG)}", f"ICON_COLOR={c(ICON)}", f"TEXT_COLOR={c(TEXT)}",
             f"BAD_COLOR={c(BAD)}", f"WARN_COLOR={c(WARN)}", f"DIM_COLOR={c(DIM)}",
             f"WS_COLOR={c(WS_COLOR)}", f"WS_TEXT={c(WS_TEXT)}", ""]
    for name, (a, b) in dict(GREEN=GREEN, GREY=GREY, PLUM=PLUM, OLIVE=OLIVE, CLAY=CLAY).items():
        lines += [f"{name}_A={c(a)}  # icon part", f"{name}_B={c(b)}  # text part"]
    # plain variables: macOS /bin/bash is 3.2, without associative arrays
    lines += ["", f'ICON_FONT="{ICON_FONT}"', "", "# workspace icons (AeroSpace workspaces 1..10)"]
    lines += [f'WS_ICON_{k}="{v}"' for k, v in WS.items()]
    lines += [""]
    lines += [f'ICON_{k.upper()}="{v if isinstance(v, str) else " ".join(v)}"' for k, v in I.items()]
    return "\n".join(lines) + "\n"


def write(rel, text, mode=0o644):
    path = os.path.join(ROOT, rel)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, 'w', encoding='utf-8') as f:
        f.write(text)
    os.chmod(path, mode)
    print("wrote", rel)


if __name__ == '__main__':
    write("wayland/waybar/.config/waybar/config.jsonc", waybar())
    write("i3/polybar/.config/polybar/config.ini", polybar())
    write("macos/sketchybar/.config/sketchybar/colors.sh", sketchybar(), 0o755)
