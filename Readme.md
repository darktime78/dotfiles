# dotfiles

One look on three systems: **sway** (Wayland) and **i3** (X11) on Arch or Ubuntu, and
**AeroSpace + SketchyBar** on macOS. Same keys, same workspaces, same bar colours,
same shell, tmux, Vim / Neovim and git setup everywhere.
Based on [HardDie/My_linux_settings](https://github.com/HardDie/My_linux_settings)
(this repo was My_linux_settings before; `install.sh` cleans up the old links).

## Install

```sh
git clone https://github.com/darktime78/dotfiles ~/.dotfiles
cd ~/.dotfiles
./install.sh                     # Linux: sway + waybar   macOS: AeroSpace + SketchyBar
./install.sh --profile i3        # Linux: i3 + polybar instead (same look and keys)
./install.sh --profile terminal  # only zsh, tmux, vim / nvim, git (servers, WSL)
```

| System | What install.sh does |
|---|---|
| Arch | pacman packages from `install/packages/arch*.txt`, missing ones from the AUR (yay) |
| Ubuntu 24.04+ | apt packages from `install/packages/ubuntu*.txt`, Hack Nerd Font download, Alacritty snap if apt's is too old |
| macOS | `brew bundle` with `install/packages/Brewfile` (needs Homebrew) |

Then on every system: links the config files, installs oh-my-zsh and its plugins,
makes zsh the login shell, writes the local files (below). Linux desktop: the keyboard
layout helper, rofi entries for the Docker apps, the weekly Docker image update timer,
a wallpaper and the lock screen picture.

* `--links-only`: no packages, no downloads. `--dry-run`: only show. `--unlink`: remove the links.
* The folder can have any name and place (`~/.dotfiles` here). To move it later:
  `mv ~/.dotfiles ~/somewhere && ~/somewhere/install.sh --links-only`; the links into the
  old place are replaced.
* Safe to run again, after every `git pull` too. Files in the way are moved to
  `~/.local/state/dotfiles/backup-DATE/`; broken links of the old stow layout are removed.
* Links are made per file, never per folder, so programs writing into `~/.config` never
  write into git.
* Start: on Linux log in on tty1 and sway / i3 starts (zsh reads
  `~/.config/dotfiles/profile`), or pick the session at a login screen. On macOS:
  `open -a AeroSpace` (it starts SketchyBar and the window borders).

### New Arch install, from the ISO

Encrypted disk (LUKS2, optional YubiKey to unlock it), then the base system, then
everything else:

```sh
curl -LO https://raw.githubusercontent.com/darktime78/dotfiles/master/install/arch-disk.sh
bash arch-disk.sh        # wipes one disk: EFI + LUKS2 (btrfs or ext4), mounted on /mnt
pacstrap -K /mnt base linux linux-firmware
curl -LO https://raw.githubusercontent.com/darktime78/dotfiles/master/install/arch-bootstrap.sh
bash arch-bootstrap.sh
```

Your own partitioning works too: mount root on `/mnt` and the EFI partition on
`/mnt/boot`, then `pacstrap` and the bootstrap. Details, YubiKey:
[yubikey/README.md](yubikey/README.md#a-new-encrypted-arch-install-with-the-yubikey).

It asks everything first (hostname, user, passwords, timezone, desktop: wayland / i3 /
none), then installs without stopping: fstab, pacman, locale, microcode and GPU drivers
(NVIDIA Pascal / Maxwell like the MX350 get the 580xx driver from the AUR), the
bootloader (systemd-boot or GRUB; LUKS, LVM, btrfs detected), the user, services, yay,
and runs `install.sh` for the desktop. Log: `/var/log/install_arch.log`.

## Layout

```
common/    every system: zsh, tmux, vim, nvim, git, alacritty, ghostty, clang-format
linux/     sway and i3: rofi, fontconfig, docker functions, systemd timer, ncmpcpp,
           scripts/.local/bin (lock, power menu, screenshots, bars, Docker apps ...)
wayland/   sway, waybar, mako
i3/        i3, polybar, dunst, picom, .xinitrc, system/ (touchpad, copied to /etc)
macos/     AeroSpace, SketchyBar
docker/    images/ (one folder per app) and update.sh
install/   arch-disk.sh, arch-bootstrap.sh, packages/ (lists per system and profile)
tools/     make_bars.py, check_parity.py, sync_upstream.py, subrepo.sh
docs/      keys.md, wine-games.md
yubikey/   YubiKey scripts for Arch, macOS, Windows (also its own repository)
```

Each folder in `common/ linux/ wayland/ i3/ macos/` mirrors `$HOME`:
`wayland/sway/.config/sway/config` becomes `~/.config/sway/config`.

## Keys

All keys, bars and clicks: [docs/keys.md](docs/keys.md). The most used: `$mod+d`
launcher, `$mod+c` Docker apps, `$mod+1…0` workspaces, `$mod+Shift+e` power menu,
`$mod+m` hide the bars, `F12` screenshots. `$mod` is the Windows key (Option on macOS).

## Changing things

| What | Where |
|---|---|
| bar colours, icons, which module where (all three bars) | `tools/make_bars.py`, then run it: writes waybar, polybar and SketchyBar configs |
| keys and window rules | `wayland/sway/.config/sway/config` **and** `i3/i3/.config/i3/config`; `python3 tools/check_parity.py` tells you what differs |
| this machine only (screens, input) | `~/.config/sway/config.local`, `~/.config/i3/config.local`, `~/.xinitrc.local` |
| font size of this machine | `~/.config/alacritty/local.toml`, `~/.config/ghostty/local` |
| your git name and email | `~/.gitconfig.local` (install.sh asks) |
| LocalAI buttons on the bar | `~/.config/dotfiles/services.conf` |
| Docker apps | `~/.config/docker/dockerfunc`, then `docker-launchers` for rofi |
| what opens files on double-click (PCManFM, xdg-open) | `default-apps zed` (default if installed), `nvim`, `sublime`, `code`; `default-apps --show` |
| Zed editor settings | `~/.config/zed/settings.json`: written once from `install/templates/zed/`, then yours (Zed edits it too) |
| folder icons in PCManFM, file dialogs, rofi | `folder-color green` (default), `teal`, `'#5fa86f'`; `--dark` for a dark PCManFM |

Sway and i3 differ only where X11 needs other tools: polybar for waybar, dunst for mako,
`wm-idle` (xss-lock, xset, xautolock) for swayidle, picom for transparency. The scripts in
`~/.local/bin` (`wm-lock`, `wm-power-menu`, `wm-screenshot`, `wm-dnd`, `wm-bar` …) work
in both.

## Docker apps

`$mod+c` lists every app in `~/.config/docker/dockerfunc`: Enter starts it, or stops a
running one. They are also in the normal launcher (`docker-launchers`).

```sh
docker-images-update --list                         # what would be built, in order
docker-images-update base firefox chromium telegram # build these (and their parents)
docker-images-update nvim-cpp                       # Neovim C++ IDE + LocalAI (docker/images/nvim-cpp)
```

The `docker-update.timer` rebuilds the images you have once a week, on AC power only.

### Old Windows games (Wine)

```sh
docker-images-update wine                      # once
wine-game install homm3 ~/Downloads/HoMM3.iso  # disc -> drive D:, runs its setup
wine-game run homm3                            # or "homm3 (Wine)" in the launcher
```

Each game lives in `~/Games/NAME` with its own Wine prefix. Discs, patches, mods, window
mode, Russian editions: [docs/wine-games.md](docs/wine-games.md).

## YubiKey

Disk unlock and login with a YubiKey: `yubikey-setup` (Arch: LUKS2 at boot, login, lock
screen, sudo), `yubikey-setup-mac` (macOS login, FileVault on Apple silicon),
`yubikey/windows/yubikey-setup.ps1` (Windows 11: what Windows allows). They don't encrypt
a disk; they add the key to one that is encrypted already. Read
[yubikey/README.md](yubikey/README.md) first: two keys, and keep the passwords.
The folder is also its own repository (`tools/subrepo.sh push yubikey`, below).

## Folders that are their own repositories

`tools/subrepo.sh push NAME` sends a folder, with its history, to its own repository
(create it empty on GitHub first); `pull NAME` brings back changes made over there.

| NAME | Folder | Repository | Use it alone |
|---|---|---|---|
| `nvim` | `common/nvim/.config/nvim` | darktime78/nvim-cpp | `git clone …/nvim-cpp ~/.config/nvim` |
| `yubikey` | `yubikey` | darktime78/yubikey-setup | `git clone …/yubikey-setup && yubikey-setup/install.sh` |

Run `push` after changing the folder. (`tools/nvim-repo.sh` is the old name for `nvim`.)

## Only the Neovim config

The config lives in `common/nvim/.config/nvim` (also used by the nvim-cpp container).
For a machine that needs only Neovim, either:

* **its own repository**: `tools/subrepo.sh push nvim` (above), then anywhere:
  `git clone https://github.com/darktime78/nvim-cpp ~/.config/nvim`.
* **no second repository**: check out only that folder of the dotfiles:

  ```sh
  git clone --filter=blob:none --sparse https://github.com/darktime78/dotfiles ~/.dotfiles
  git -C ~/.dotfiles sparse-checkout set common/nvim
  ln -s ~/.dotfiles/common/nvim/.config/nvim ~/.config/nvim   # git pull keeps it up to date
  ```

## Upstream

New commits of HardDie's repo are brought into this layout with

```sh
python3 tools/sync_upstream.py --list   # what is new, and where each file goes here
python3 tools/sync_upstream.py          # apply them (git am -3, one commit each)
```

It rewrites the old paths (`zsh/dot-zshrc` → `common/zsh/.zshrc` …) and skips files
that have no place here. The last synced commit is in `.upstream-sync`.

## Checks

```sh
python3 tools/make_bars.py && git diff --stat   # generated bars up to date?
python3 tools/check_parity.py                   # sway and i3 the same?
./install.sh --dry-run                          # what install.sh would do here
```
