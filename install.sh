#!/usr/bin/env bash
#
# install.sh: set up these dotfiles on Arch, Ubuntu (24.04+) or macOS.
#
#   ./install.sh                      sway + waybar on Linux, AeroSpace + SketchyBar on macOS
#   ./install.sh --profile i3         i3 + polybar (X11), the same look and keys as sway
#   ./install.sh --profile terminal   only zsh, tmux, vim / nvim, git (servers, WSL)
#
# Options
#   --os arch|ubuntu|macos   don't detect the system
#   --links-only             no packages, no downloads: only link the config files
#   --yes                    no questions (git name/email stay a template)
#   --dry-run                show what would be done, change nothing
#   --unlink                 remove every link into this folder (backups stay)
#
# Config files are linked one by one (~/.config/sway/config -> this folder), never
# whole folders, so programs that write into ~/.config never write into git.
# Anything in the way is moved to ~/.local/state/dotfiles/backup-DATE/.
# Safe to run again (after git pull, too): it only does what is missing.
# Works with the old bash 3.2 of macOS.

set -uo pipefail

REPO=$(cd "$(dirname "$0")" && pwd -P)
ME=$(id -un) # not $USER: under runuser / sudo it can still be root
STATE=$HOME/.local/state/dotfiles
OLD_NAMES="My_linux_settings" # earlier names of this repo (any upper / lower case):
                              # their old links get cleaned up
BACKUP=$STATE/backup-$(date +%Y%m%d-%H%M%S)
OS="" PROFILE="" LINKS_ONLY=0 YES=0 DRY=0 UNLINK=0

c_b=$'\e[1;34m' c_y=$'\e[1;33m' c_r=$'\e[1;31m' c_g=$'\e[1;32m' c_0=$'\e[0m'
step() { printf '\n%s==> %s%s\n' "$c_b" "$*" "$c_0"; }
info() { printf '    %s\n' "$*"; }
warn() { printf '%swarning:%s %s\n' "$c_y" "$c_0" "$*" >&2; WARNINGS+=("$*"); }
die() { printf '%serror:%s %s\n' "$c_r" "$c_0" "$*" >&2; exit 1; }
have() { command -v "$1" >/dev/null 2>&1; }
# run CMD...: run it, or only print it with --dry-run
run() { if ((DRY)); then printf '    [dry-run] %s\n' "$*"; else "$@"; fi; }
WARNINGS=()

usage() { sed -n '3,/^$/p' "$0" | sed 's/^# \{0,1\}//'; exit "${1:-0}"; }

while (($#)); do
	case $1 in
	--os) OS=${2:-}; shift ;;
	--profile) PROFILE=${2:-}; shift ;;
	--links-only) LINKS_ONLY=1 ;;
	--yes | -y) YES=1 ;;
	--dry-run | -n) DRY=1 ;;
	--unlink) UNLINK=1 ;;
	-h | --help) usage ;;
	*) echo "unknown option: $1" >&2; usage 2 ;;
	esac
	shift
done

# ---------------------------------------------------------------- system and profile
if [[ -z $OS ]]; then
	if [[ $(uname -s) == Darwin ]]; then
		OS=macos
	elif [[ -r /etc/os-release ]]; then
		# shellcheck source=/dev/null
		id=$(. /etc/os-release; echo "${ID:-} ${ID_LIKE:-}")
		case " $id " in
		*" arch "*) OS=arch ;;
		*" ubuntu "* | *" debian "*) OS=ubuntu ;;
		esac
	fi
	[[ -n $OS ]] || die "unknown system: use --os arch|ubuntu|macos"
fi
case $OS in arch | ubuntu | macos) ;; *) die "--os: arch, ubuntu or macos" ;; esac

if [[ -z $PROFILE ]]; then
	if [[ $OS == macos ]]; then PROFILE=macos
	elif [[ -r $HOME/.config/dotfiles/profile ]]; then PROFILE=$(cat "$HOME/.config/dotfiles/profile")
	else PROFILE=wayland; fi
fi
case $OS:$PROFILE in
macos:macos | macos:terminal | arch:wayland | arch:i3 | arch:terminal | ubuntu:wayland | ubuntu:i3 | ubuntu:terminal) ;;
*) die "profile $PROFILE does not work on $OS (Linux: wayland, i3, terminal; macOS: macos, terminal)" ;;
esac

# which folders get linked into $HOME
PKGS="common/zsh common/tmux common/vim common/git common/clang-format common/nvim"
case $PROFILE in
wayland | i3)
	PKGS+=" common/alacritty common/ghostty linux/rofi linux/fontconfig linux/ncmpcpp"
	PKGS+=" linux/scripts linux/systemd linux/docker"
	;;
macos) PKGS+=" common/alacritty common/ghostty macos/aerospace macos/sketchybar" ;;
terminal) [[ $OS != macos ]] && PKGS+=" linux/scripts linux/systemd linux/docker" ;;
esac
case $PROFILE in
wayland) PKGS+=" wayland/sway wayland/waybar wayland/mako" ;;
i3) PKGS+=" i3/i3 i3/polybar i3/dunst i3/picom i3/x11" ;;
esac
DESKTOP=0
[[ $PROFILE == wayland || $PROFILE == i3 ]] && DESKTOP=1

# ---------------------------------------------------------------- links
# absolute path a link points to (relative stow links too), folders resolved
abs_target() {
	local t d
	t=$(readlink "$1") || return 1
	case $t in /*) ;; *) t=$(dirname "$1")/$t ;; esac
	if d=$(cd "$(dirname "$t")" 2>/dev/null && pwd -P); then echo "$d/$(basename "$t")"; else echo "$t"; fi
}
# inside this repo, or inside an old clone of it (~/My_linux_settings)?
in_tree() { # absolute path
	local n hit=1
	[[ $1/ == "$REPO/"* ]] && return 0
	shopt -s nocasematch # ~/My_linux_Settings is an old clone too
	for n in $OLD_NAMES; do [[ $1/ == *"/$n/"* ]] && hit=0; done
	shopt -u nocasematch
	return $hit
}
# a link of ours: points into this repo (or an old clone of it)
ours() { local t; t=$(abs_target "$1") || return 1; in_tree "$t"; }
# a path that is (through links) inside this repo or an old clone
in_repo() {
	local d
	d=$(cd "$(dirname "$1")" 2>/dev/null && pwd -P) || return 1
	in_tree "$d"
}

# where links can be: $HOME itself, and below every top-level name the packages use
# (.config, .local, .vim, .ncmpcpp ...), not the whole home
scan_links() {
	local top
	find "$HOME" -maxdepth 1 -type l 2>/dev/null
	for top in .config .local $(cd "$REPO" && ls -A common/* linux/* wayland/* i3/* macos/* 2>/dev/null | grep '^\.' | sort -u); do
		[[ -d $HOME/$top && ! -L $HOME/$top ]] && find "$HOME/$top" -maxdepth 6 -type l 2>/dev/null
	done | sort -u
}

# broken links left by an older layout or name of these dotfiles (stow, makelinks.sh,
# My_linux_settings): e.g. ../My_linux_settings/sway/sway that points to nothing now
remove_stale() {
	local l t abs n=0 name
	name=$(basename "$REPO")
	while IFS= read -r l; do
		t=$(readlink "$l") || continue
		case $t in /*) abs=$t ;; *) abs=$(dirname "$l")/$t ;; esac
		if [[ -e $l ]]; then
			# working link into an old clone (~/My_linux_settings): the new links replace it
			abs=$(abs_target "$l")
			[[ $abs != "$REPO/"* ]] && in_tree "$abs" || continue
		elif ! { [[ $abs == *"/$name/"* ]] || in_tree "$abs"; }; then
			continue
		fi
		run rm -f "$l"; n=$((n + 1))
	done < <(scan_links)
	((n)) && info "removed $n old link(s) (old layout or old folder)"
	return 0
}

backup() { # path relative-name
	run mkdir -p "$(dirname "$BACKUP/$2")"
	run mv "$1" "$BACKUP/$2"
	info "backup: ~/$2 -> ${BACKUP/#$HOME/~}/$2"
}

# a folder on the way to a link must be a real folder, not a link into this repo
# (stow "folded" whole folders: writing there would write into git)
real_dirs() { # relative path of the file
	local d=$HOME part rest=$1 r=""
	while [[ $rest == */* ]]; do
		part=${rest%%/*}; rest=${rest#*/}
		d=$d/$part r=${r:+$r/}$part
		if [[ -L $d ]] && ours "$d"; then
			run rm -f "$d"            # old folder link into this repo / an old clone
		elif [[ -L $d && ! -d $d ]]; then
			backup "$d" "$r"          # broken folder link, or a link to a file
		elif [[ -e $d && ! -d $d ]]; then
			backup "$d" "$r"          # a file where a folder must be
		fi
	done
	run mkdir -p "$(dirname "$HOME/$1")"
}

LINKED=0
link_pkg() { # folder of this repo
	local src rel dst
	while IFS= read -r src; do
		rel=${src#"$REPO/$1/"}
		dst=$HOME/$rel
		if [[ -L $dst && $(readlink "$dst") == "$src" ]]; then continue; fi
		if ! real_dirs "$rel"; then warn "could not create the folder for ~/$rel"; continue; fi
		# never move or replace a file of this repo (a folder link we could not undo)
		if ((!DRY)) && in_repo "$dst"; then die "~/$rel is inside $REPO (a link to a folder?): remove that link and run again"; fi
		if [[ -L $dst ]] && ours "$dst"; then
			run rm -f "$dst" # our own link from an older layout or clone: just replace it
		elif [[ -e $dst || -L $dst ]]; then
			backup "$dst" "$rel"
		fi
		if run ln -s "$src" "$dst"; then LINKED=$((LINKED + 1)); else warn "could not link ~/$rel"; fi
	done < <(find "$REPO/$1" \( -type f -o -type l \) ! -name '.DS_Store' | sort)
}

if ((UNLINK)); then
	step "Removing the links into $REPO"
	n=0
	while IFS= read -r l; do
		if ours "$l"; then run rm -f "$l"; n=$((n + 1)); fi
	done < <(scan_links)
	info "$n link(s) removed. Backups: $STATE/"
	exit 0
fi

# ---------------------------------------------------------------- packages
read_list() { # file: package names without comments
	sed -e 's/#.*//' -e 's/[[:space:]]//g' "$1" | grep -v '^$'
}

packages_arch() {
	local f p want=() repo=() aur=()
	for f in arch.txt; do want+=($(read_list "$REPO/install/packages/$f")); done
	if ((DESKTOP)); then
		want+=($(read_list "$REPO/install/packages/arch-desktop.txt"))
		want+=($(read_list "$REPO/install/packages/arch-$PROFILE.txt"))
	fi
	for p in "${want[@]}"; do
		if pacman -Si "$p" >/dev/null 2>&1 || pacman -Sg "$p" >/dev/null 2>&1; then repo+=("$p"); else aur+=("$p"); fi
	done
	info "pacman: ${#repo[@]} packages (also updates the system: Arch has no partial upgrades)"
	local confirm=()
	((YES)) && confirm=(--noconfirm)
	run sudo pacman -Syu --needed "${confirm[@]}" "${repo[@]}" || warn "pacman failed"
	if ((${#aur[@]})); then
		if have yay; then
			info "AUR (yay): ${aur[*]}"
			for p in "${aur[@]}"; do
				run yay -S --needed --noconfirm --answerdiff None --answerclean None "$p" ||
					warn "AUR package $p not installed"
			done
		else
			warn "not in the repos, install from the AUR: ${aur[*]}"
		fi
	fi
}

packages_ubuntu() {
	local p want=() ok=() missing=()
	want+=($(read_list "$REPO/install/packages/ubuntu.txt"))
	if ((DESKTOP)); then
		want+=($(read_list "$REPO/install/packages/ubuntu-desktop.txt"))
		want+=($(read_list "$REPO/install/packages/ubuntu-$PROFILE.txt"))
	fi
	run sudo apt-get update -q
	for p in "${want[@]}"; do
		if apt-cache show "$p" >/dev/null 2>&1; then ok+=("$p"); else missing+=("$p"); fi
	done
	((${#missing[@]})) && warn "not in your apt sources: ${missing[*]} (most are in \"universe\": sudo add-apt-repository universe, then run this again)"
	info "apt: ${#ok[@]} packages"
	local confirm=()
	((YES)) && confirm=(-y)
	run sudo apt-get install --no-install-recommends "${confirm[@]}" "${ok[@]}" || warn "apt-get failed"

	# Debian names fd "fdfind"
	if have fdfind && ! have fd; then run mkdir -p "$HOME/.local/bin"; run ln -sf "$(command -v fdfind)" "$HOME/.local/bin/fd"; fi

	# Alacritty: the config is TOML, which needs 0.13+ (Ubuntu 24.04 has 0.12)
	if ((DESKTOP)); then
		local v
		v=$(apt-cache policy alacritty 2>/dev/null | awk '/Candidate:/ {print $2}')
		if [[ -n $v && $v != "(none)" ]] && dpkg --compare-versions "$v" ge 0.13; then
			run sudo apt-get install "${confirm[@]}" alacritty
		elif have alacritty; then
			info "alacritty: already installed"
		elif have snap; then
			info "alacritty: apt has ${v:-none}, the config needs 0.13+: installing the snap"
			run sudo snap install alacritty --classic || warn "snap install alacritty failed"
		else
			warn "install Alacritty 0.13 or newer by hand (the apt one is too old)"
		fi
	fi
	fonts_download
}

# Hack Nerd Font from the nerd-fonts releases (Ubuntu has no package for it)
fonts_download() {
	local dir=$HOME/.local/share/fonts/HackNerdFont tmp
	if fc-list 2>/dev/null | grep -q 'Hack Nerd Font'; then return 0; fi
	info "Hack Nerd Font -> $dir"
	((DRY)) && return 0
	tmp=$(mktemp -d)
	if curl -fsSL -o "$tmp/Hack.tar.xz" https://github.com/ryanoasis/nerd-fonts/releases/latest/download/Hack.tar.xz &&
		mkdir -p "$dir" && tar -xJf "$tmp/Hack.tar.xz" -C "$dir"; then
		fc-cache -f "$dir" >/dev/null
	else
		warn "could not download Hack Nerd Font (https://www.nerdfonts.com/font-downloads)"
	fi
	rm -rf "$tmp"
}

packages_macos() {
	if ! have brew; then
		[[ -x /opt/homebrew/bin/brew ]] && eval "$(/opt/homebrew/bin/brew shellenv)"
	fi
	have brew || die 'install Homebrew first: /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
	if [[ $PROFILE == terminal ]]; then
		run brew install git neovim vim tmux jq ripgrep fd fzf htop
	else
		run brew bundle --file "$REPO/install/packages/Brewfile" || warn "brew bundle: some packages failed"
	fi
}

# ---------------------------------------------------------------- shell
setup_zsh() {
	local omz=$HOME/.local/share/oh-my-zsh plugins=$HOME/.config/zsh/plugins p
	if [[ ! -d $omz ]]; then
		info "oh-my-zsh -> ${omz/#$HOME/~}"
		run git clone -q --depth 1 https://github.com/ohmyzsh/ohmyzsh.git "$omz" || warn "oh-my-zsh: clone failed"
	fi
	for p in zsh-syntax-highlighting zsh-autosuggestions; do
		[[ -d $plugins/$p ]] && continue
		info "zsh plugin $p"
		run git clone -q --depth 1 "https://github.com/zsh-users/$p.git" "$plugins/$p" || warn "$p: clone failed"
	done
	local zsh
	zsh=$(command -v zsh) || return 0
	if [[ $(basename "${SHELL:-}") != zsh ]]; then
		info "login shell -> $zsh"
		if ((YES)); then run sudo chsh -s "$zsh" "$ME" || warn "chsh failed: chsh -s $zsh"
		else run chsh -s "$zsh" || warn "chsh failed: chsh -s $zsh"; fi
	fi
}

# ---------------------------------------------------------------- files that stay local
# write FILE once (never overwritten: they are yours)
local_file() { # path content
	[[ -e $1 ]] && return 0
	info "new: ${1/#$HOME/~}"
	((DRY)) && return 0
	mkdir -p "$(dirname "$1")"
	printf '%s\n' "$2" >"$1"
}

local_files() {
	local name="" email=""
	if [[ ! -e $HOME/.gitconfig.local ]] && ((!YES)) && [[ -t 0 ]]; then
		read -r -p "    git user name (empty: later): " name
		[[ -n $name ]] && read -r -p "    git email: " email
	fi
	if [[ -n $name ]]; then
		local_file "$HOME/.gitconfig.local" "$(printf '[user]\n\tname = %s\n\temail = %s' "$name" "$email")"
	else
		local_file "$HOME/.gitconfig.local" "$(printf '# your git identity (included by ~/.gitconfig, not in git)\n#[user]\n#\tname = Your Name\n#\temail = you@example.com')"
	fi

	if [[ $OS == macos ]]; then
		local_file "$HOME/.config/alacritty/local.toml" "$(printf '# this Mac only\n[font]\nsize = 14.0\n\n[window]\noption_as_alt = "Both"')"
		local_file "$HOME/.config/ghostty/local" "$(printf '# this Mac only\nfont-size = 14')"
	else
		local_file "$HOME/.config/alacritty/local.toml" "# this machine only, e.g. [font] size = 12.0"
		local_file "$HOME/.config/ghostty/local" "# this machine only, e.g. font-size = 12"
	fi
	[[ $PROFILE == wayland ]] && local_file "$HOME/.config/sway/config.local" "# this machine only (outputs, input), included by ~/.config/sway/config"
	[[ $PROFILE == i3 ]] && local_file "$HOME/.config/i3/config.local" "# this machine only, included by ~/.config/i3/config"
	if ((DESKTOP)); then
		if [[ $(cat "$HOME/.config/dotfiles/profile" 2>/dev/null) != "$PROFILE" ]]; then
			info "session on tty1: $PROFILE (~/.config/dotfiles/profile)"
			((DRY)) || { mkdir -p "$HOME/.config/dotfiles"; echo "$PROFILE" >"$HOME/.config/dotfiles/profile"; }
		fi
	fi
	return 0
}

# ---------------------------------------------------------------- Linux desktop extras
linux_extras() {
	local bin=$HOME/.local/bin

	if [[ $PROFILE == wayland ]] && [[ ! -x $bin/sway_independent_layouts ]]; then
		if have go && ((!LINKS_ONLY)); then
			info "keyboard layout per window: sway_independent_layouts (go install)"
			run env GOBIN="$bin" go install github.com/HardDie/sway_independent_layouts@latest ||
				warn "sway_independent_layouts did not build"
		else
			info "skipped sway_independent_layouts (needs go)"
		fi
	fi

	if [[ $PROFILE == i3 ]] && ((!LINKS_ONLY)) &&
		! cmp -s "$REPO/i3/system/30-touchpad.conf" /etc/X11/xorg.conf.d/30-touchpad.conf; then
		info "touchpad tap-to-click: /etc/X11/xorg.conf.d/30-touchpad.conf"
		run sudo install -Dm644 "$REPO/i3/system/30-touchpad.conf" /etc/X11/xorg.conf.d/30-touchpad.conf
	fi

	# wallpaper and lock screen picture
	local wp=$HOME/.wallpapers/wallpaper.png f
	if [[ ! -e $wp ]]; then
		for f in /usr/share/backgrounds/sway/*.png /usr/share/backgrounds/*.png /usr/share/backgrounds/*/*.png; do
			[[ -f $f ]] || continue
			info "wallpaper: $f (change: ~/.wallpapers/wallpaper.png)"
			run mkdir -p "$HOME/.wallpapers"
			run cp "$f" "$wp"
			break
		done
	fi
	if [[ -e $wp && ! -e $HOME/.wallpapers/lockscreen.png ]] && { have magick || have convert; }; then
		run "$REPO/linux/scripts/.local/bin/make-lockscreen" >/dev/null 2>&1 || true
	fi
	if have fc-cache && ((!DRY)); then fc-cache >/dev/null 2>&1; fi
}

linux_docker() {
	have docker || return 0
	if ! id -nG "$ME" | tr ' ' '\n' | grep -qx docker; then
		info "adding $ME to the docker group (log in again to use it)"
		run sudo usermod -aG docker "$ME" || warn "usermod -aG docker failed"
	fi
	((DESKTOP)) && run "$REPO/linux/scripts/.local/bin/docker-launchers" >/dev/null

	# weekly image updates
	local units=$HOME/.config/systemd/user
	[[ -e $units/docker-update.timer ]] || return 0
	if systemctl --user show-environment >/dev/null 2>&1; then
		run systemctl --user daemon-reload
		systemctl --user -q is-enabled docker-update.timer 2>/dev/null ||
			{ info "docker-update.timer: weekly Docker image updates"; run systemctl --user enable --now docker-update.timer; }
	elif [[ ! -e $units/timers.target.wants/docker-update.timer ]]; then
		# no user systemd here (arch-chroot): enable it the way systemctl would
		info "docker-update.timer: weekly Docker image updates"
		run mkdir -p "$units/timers.target.wants"
		run ln -sf ../docker-update.timer "$units/timers.target.wants/docker-update.timer"
	fi
}

macos_extras() {
	[[ $PROFILE == macos ]] || return 0
	info "start AeroSpace (it starts SketchyBar and the borders): open -a AeroSpace"
	info "recommended: System Settings > Desktop & Dock > \"Displays have separate Spaces\" off,"
	info "             and \"Automatically hide and show the menu bar\": Always"
}

# ================================================================ main
step "Dotfiles: $REPO"
info "system $OS, profile $PROFILE$( ((DRY)) && echo ', dry run')$( ((LINKS_ONLY)) && echo ', links only')"

if ((!LINKS_ONLY)); then
	step "Packages"
	[[ $OS != macos ]] && ((!DRY)) && { sudo -v || die "needs sudo for the packages (or use --links-only)"; }
	"packages_$OS"
fi

step "Links"
remove_stale
for p in $PKGS; do link_pkg "$p"; done
info "$LINKED new link(s)"

step "Local files (not in git)"
local_files

if ((!LINKS_ONLY)); then
	step "Shell"
	setup_zsh
fi

if [[ $OS != macos ]]; then
	if ((DESKTOP)); then step "Desktop extras"; linux_extras; fi
	if ((!LINKS_ONLY)); then step "Docker"; linux_docker; fi
else
	step "macOS"
	macos_extras
fi

step "Done"
case $PROFILE in
wayland) info "log in on tty1 (or choose \"Sway\" at the login screen): sway starts with waybar" ;;
i3) info "log in on tty1 (or choose \"i3\" at the login screen): i3 starts with polybar" ;;
esac
info "keys: $REPO/docs/keys.md"
if ((${#WARNINGS[@]})); then
	printf '\n%sThings to check:%s\n' "$c_y" "$c_0"
	printf '    - %s\n' "${WARNINGS[@]}"
fi
printf '%sok%s\n' "$c_g" "$c_0"
