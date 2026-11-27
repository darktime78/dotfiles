#!/bin/bash
#
# install.sh: put the YubiKey script of this system on your PATH (~/.local/bin).
#   Arch Linux -> yubikey-setup      macOS -> yubikey-setup-mac
#   Windows: no install, run windows\yubikey-setup.ps1 (see README.md)
#
#   ./install.sh            link it (safe to run again)
#   ./install.sh --unlink   remove the link
#
# The dotfiles (github.com/darktime78/dotfiles) do this themselves; this is for using
# the YubiKey scripts alone. You can also run them from here: ./linux/yubikey-setup ...

set -euo pipefail
here=$(cd "$(dirname "$0")" && pwd -P)
case $(uname -s) in
Darwin) src=$here/macos/yubikey-setup-mac ;;
Linux) src=$here/linux/yubikey-setup ;;
*) echo "Windows: run windows\\yubikey-setup.ps1 in an administrator PowerShell" >&2; exit 1 ;;
esac
dst=$HOME/.local/bin/$(basename "$src")

if [[ ${1:-} == --unlink ]]; then
	[[ -L $dst ]] && rm -f "$dst" && echo "removed $dst"
	exit 0
fi

mkdir -p "$(dirname "$dst")"
if [[ -e $dst && ! -L $dst ]]; then
	mv "$dst" "$dst.bak" && echo "kept your old $dst as $dst.bak"
fi
ln -sfn "$src" "$dst"
echo "$(basename "$src") -> $src"
case :$PATH: in *":$HOME/.local/bin:"*) ;; *) echo "add ~/.local/bin to your PATH (e.g. in ~/.zshrc)" ;; esac
echo "Next: read README.md, then  $(basename "$src") status"
