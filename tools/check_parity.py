#!/usr/bin/env python3
"""Check that the i3 config matches the sway config.

    python3 tools/check_parity.py

Compares every key binding (key -> command) and which workspaces get window rules.
Differences that are on purpose (X11 has other tools) are listed in SAME below.
Exit code 1 if something differs.
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SWAY = os.path.join(ROOT, "wayland/sway/.config/sway/config")
I3 = os.path.join(ROOT, "i3/i3/.config/i3/config")

# sway command -> i3 command that does the same
SAME = {
    "makoctl dismiss -a": "dunstctl close-all",
    "makoctl restore": "dunstctl history-pop",
    "reload": "restart",
}


def bindings(path):
    out, mode = {}, "default"
    for line in open(path, encoding="utf-8"):
        line = line.strip()
        m = re.match(r'mode "([^"]+)" \{', line)
        if m:
            mode = m.group(1)
            continue
        if line == "}":
            mode = "default"
            continue
        if not line.startswith("bindsym "):
            continue
        words = line.split()[1:]
        flags = {w for w in words if w.startswith("--")}
        words = [w for w in words if not w.startswith("--")]
        key, cmd = words[0], " ".join(words[1:])
        cmd = cmd.replace("exec --no-startup-id ", "exec ")
        cmd = re.sub(r"^exec ", "", cmd)
        cmd = SAME.get(cmd, cmd)
        out[(mode, key, "--release" in flags)] = cmd
    return out


def workspaces(path):
    return sorted({m.group(1) for m in re.finditer(r'^assign \[.*\] \$wspace(\d+)',
                                                    open(path, encoding="utf-8").read(), re.M)},
                  key=int)


def main():
    s, i = bindings(SWAY), bindings(I3)
    bad = 0
    for k in sorted(set(s) | set(i)):
        name = f"{k[1]}{' (release)' if k[2] else ''}" + (f" [mode {k[0]}]" if k[0] != "default" else "")
        if k not in i:
            print(f"only in sway: {name} -> {s[k]}"); bad += 1
        elif k not in s:
            print(f"only in i3:   {name} -> {i[k]}"); bad += 1
        elif s[k] != i[k]:
            print(f"differs: {name}\n  sway: {s[k]}\n  i3:   {i[k]}"); bad += 1
    ws, wi = workspaces(SWAY), workspaces(I3)
    if ws != wi:
        print(f"window rules for workspaces differ: sway {ws}, i3 {wi}"); bad += 1
    print(f"{len(s)} bindings compared, workspaces with rules: {' '.join(ws)}; "
          + ("same" if not bad else f"{bad} difference(s)"))
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main())
