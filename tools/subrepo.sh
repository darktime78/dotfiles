#!/bin/bash
#
# subrepo.sh: folders of the dotfiles that are also their own repositories.
#
#   tools/subrepo.sh push NAME    send the folder, with its history, to its repository
#   tools/subrepo.sh pull NAME    bring back changes that were made over there
#   tools/subrepo.sh list         the folders and their repositories
#
#   NAME     folder                       repository
#   nvim     common/nvim/.config/nvim     darktime78/nvim-cpp       (Neovim config)
#   yubikey  yubikey                      darktime78/yubikey-setup  (YubiKey scripts)
#
# The dotfiles stay the main copy; each repository gets only its folder, at its top.
# Create the repository empty on GitHub first. Another URL: REPO_URL=... tools/subrepo.sh push NAME
# Uses git subtree (part of git on Arch, Ubuntu and Homebrew).

set -euo pipefail

declare -A PREFIX=([nvim]=common/nvim/.config/nvim [yubikey]=yubikey)
declare -A URL=([nvim]=git@github.com:darktime78/nvim-cpp.git [yubikey]=git@github.com:darktime78/yubikey-setup.git)
BRANCH=${BRANCH:-master}

usage() { sed -n '3,/^$/p' "$0" | sed 's/^# \{0,1\}//'; exit "${1:-0}"; }

cd "$(dirname "$(readlink -f "$0")")/.."
[[ -x "$(git --exec-path)/git-subtree" ]] || { echo "git subtree is missing (it comes with git; Ubuntu: apt install git)" >&2; exit 1; }

cmd=${1:-}
name=${2:-}
if [[ $cmd == list ]]; then
	for n in "${!PREFIX[@]}"; do printf '%-8s %-26s %s\n' "$n" "${PREFIX[$n]}" "${URL[$n]}"; done
	exit 0
fi
[[ $cmd == push || $cmd == pull ]] || usage 2
[[ -n $name && -n ${PREFIX[$name]:-} ]] || { echo "NAME: ${!PREFIX[*]}" >&2; exit 2; }
prefix=${PREFIX[$name]}
remote=sub-$name
[[ $name == nvim ]] && remote=nvim-cpp # the remote name older versions used

# remote for this folder: add it, or follow REPO_URL if it was given
if ! git remote get-url "$remote" >/dev/null 2>&1; then
	git remote add "$remote" "${REPO_URL:-${URL[$name]}}"
elif [[ -n ${REPO_URL:-} ]]; then
	git remote set-url "$remote" "$REPO_URL"
fi

# uncommitted changes: git subtree needs a clean tree (--rejoin adds a commit)
dirty() { git status --porcelain --untracked-files=no -- "$@"; }

case $cmd in
push)
	if [[ -n $(dirty "$prefix") ]]; then
		echo "Uncommitted changes in $prefix; commit them first so they are pushed:" >&2
		dirty "$prefix" | sed 's/^/  /' >&2
		echo "  git add $prefix && git commit -m '$name: ...'" >&2
		exit 1
	fi
	if [[ -n $(dirty) ]]; then
		# other files: put aside during the push, back afterwards
		echo "(your other uncommitted changes are put aside for the push and come back)"
		git stash push -q -m "subrepo.sh push" || exit 1
		trap 'git stash pop -q || echo "your changes are in: git stash list" >&2' EXIT
	fi
	echo "$prefix -> $(git remote get-url "$remote") ($BRANCH)"
	# --rejoin: a small merge commit here remembers what the repository has, so later
	# pushes are quick and "pull" can merge changes made over there
	git subtree push --rejoin --prefix="$prefix" "$remote" "$BRANCH"
	;;
pull)
	if [[ -n $(dirty) ]]; then
		echo "Commit or stash your changes first (git subtree needs a clean tree):" >&2
		dirty | sed 's/^/  /' >&2
		exit 1
	fi
	git subtree pull --prefix="$prefix" "$remote" "$BRANCH" -m "$name: changes from its repository"
	;;
esac
