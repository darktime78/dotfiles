#!/bin/bash
#
# nvim-repo.sh: the Neovim config (common/nvim/.config/nvim) also as its own repository,
# for machines that need only Neovim:  git clone <that repo> ~/.config/nvim
#
#   tools/nvim-repo.sh push    send the config, with its history, to the nvim repo
#   tools/nvim-repo.sh pull    bring back changes that were made in the nvim repo
#
# The dotfiles stay the main copy; the nvim repo gets only that one folder, at its top.
# Default repo: git@github.com:darktime78/nvim-cpp.git (create it empty on GitHub first).
# Another one: NVIM_REPO=git@github.com:you/nvim.git tools/nvim-repo.sh push
# Uses git subtree (part of git on Arch, Ubuntu and Homebrew).

set -euo pipefail

PREFIX=common/nvim/.config/nvim
REMOTE=nvim-cpp
URL=${NVIM_REPO:-git@github.com:darktime78/nvim-cpp.git}
BRANCH=${NVIM_BRANCH:-master}

cd "$(dirname "$(readlink -f "$0")")/.."
[[ -x "$(git --exec-path)/git-subtree" ]] || { echo "git subtree is missing (it comes with git; Ubuntu: apt install git)" >&2; exit 1; }

# remote "nvim-cpp": add it, or follow NVIM_REPO if it was given
if ! git remote get-url "$REMOTE" >/dev/null 2>&1; then
	git remote add "$REMOTE" "$URL"
elif [[ -n ${NVIM_REPO:-} ]]; then
	git remote set-url "$REMOTE" "$URL"
fi

# uncommitted changes: git subtree needs a clean tree (--rejoin adds a commit)
dirty() { git status --porcelain --untracked-files=no -- "$@"; }

case ${1:-} in
push)
	if [[ -n $(dirty "$PREFIX") ]]; then
		echo "Uncommitted changes in the Neovim config; commit them first so they are pushed:" >&2
		dirty "$PREFIX" | sed 's/^/  /' >&2
		echo "  git add $PREFIX && git commit -m 'nvim: ...'" >&2
		exit 1
	fi
	if [[ -n $(dirty) ]]; then
		# other files: put aside during the push, back afterwards
		echo "(your other uncommitted changes are put aside for the push and come back)"
		git stash push -q -m "nvim-repo.sh push" || exit 1
		trap 'git stash pop -q || echo "your changes are in: git stash list" >&2' EXIT
	fi
	echo "Neovim config -> $(git remote get-url "$REMOTE") ($BRANCH)"
	# --rejoin: a small merge commit here remembers what the nvim repo has, so later
	# pushes are quick and "pull" can merge changes made over there
	git subtree push --rejoin --prefix="$PREFIX" "$REMOTE" "$BRANCH"
	;;
pull)
	if [[ -n $(dirty) ]]; then
		echo "Commit or stash your changes first (git subtree needs a clean tree):" >&2
		dirty | sed 's/^/  /' >&2
		exit 1
	fi
	git subtree pull --prefix="$PREFIX" "$REMOTE" "$BRANCH" \
		-m "nvim: changes from the $REMOTE repository"
	;;
*)
	sed -n '3,/^$/p' "$0" | sed 's/^# \{0,1\}//'
	exit 2
	;;
esac
