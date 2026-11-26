# zsh: Linux (sway / i3) and macOS
is_darwin=0
[[ $(uname -s) == Darwin ]] && is_darwin=1

# ------------------------------------------------------------------ PATH
[[ -x /opt/homebrew/bin/brew ]] && eval "$(/opt/homebrew/bin/brew shellenv)"
typeset -U path
path=("$HOME/.local/bin" $path "$HOME/go/bin")

# ------------------------------------------------------------------ oh-my-zsh
# Installed by install.sh (git clone); themes and plugins live in ~/.config/zsh.
ZSH=$HOME/.local/share/oh-my-zsh
ZSH_CUSTOM=$HOME/.config/zsh
ZSH_CACHE_DIR=$HOME/.cache/oh-my-zsh
ZSH_THEME="bira_mode_mygit"
DISABLE_AUTO_UPDATE="true"
plugins=(zsh-syntax-highlighting)
[[ -d $ZSH_CUSTOM/plugins/zsh-autosuggestions ]] && plugins+=(zsh-autosuggestions)
mkdir -p "$ZSH_CACHE_DIR" /tmp/mytmp

if [[ -r $ZSH/oh-my-zsh.sh ]]; then
	source "$ZSH/oh-my-zsh.sh"
else
	PROMPT='%F{green}%n@%m%f %F{blue}%~%f %# '
	echo "oh-my-zsh not installed: run install.sh from your dotfiles"
fi

# ------------------------------------------------------------------ settings
if (( $+commands[nvim] )); then export EDITOR=nvim; else export EDITOR=vim; fi
export VISUAL=$EDITOR

alias ll='ls -hlF' lla='ls -hAlF' lsa='ls -AF' la='ls -AF' l='ls -CF'
alias tmux='tmux -2'
alias aria2c='aria2c --summary-interval=0 --continue'
alias yt-dlp='yt-dlp --retries infinite'

unsetopt sharehistory
setopt APPEND_HISTORY HIST_IGNORE_ALL_DUPS HIST_IGNORE_SPACE HIST_REDUCE_BLANKS

# ------------------------------------------------------------------ graphical session
# On tty1, start the session install.sh set up (~/.config/dotfiles/profile):
# wayland -> sway, i3 -> startx. Without the file: sway if it is installed.
if (( !is_darwin )) && [[ $(tty) == /dev/tty1 && -z $DISPLAY && -z $WAYLAND_DISPLAY ]]; then
	profile=$(cat ~/.config/dotfiles/profile 2>/dev/null)
	case ${profile:-wayland} in
	i3) (( $+commands[startx] )) && { echo "Starting i3..."; exec startx; } ;;
	*) (( $+commands[sway] )) && { echo "Starting sway..."; exec sway 2>/dev/null; } ;;
	esac
fi

# ------------------------------------------------------------------ tmux
# Y: new session, a: attach, n: plain shell
if [[ $- == *i* && -z $TMUX && -z $SSH_CONNECTION && \
	-z $INTELLIJ_ENVIRONMENT_READER && -z $VSCODE_RESOLVING_ENVIRONMENT && -z $NVIM ]]; then
	echo -n 'Start tmux? [Y/n/a]: '
	read answer
	case $answer in
	a | A) exec tmux -2 attach ;;
	n | N) ;;
	*) exec tmux -2 ;;
	esac
fi

# ------------------------------------------------------------------ docker apps (Linux)
if (( !is_darwin )); then
	for f in ~/.config/docker/dockerfunc ~/.config/docker/dockerfunc_extra; do
		[[ -r $f ]] && source "$f"
	done
fi

# machine-specific additions, not in git
[[ -r ~/.zshrc.local ]] && source ~/.zshrc.local
