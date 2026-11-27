#!/bin/bash
# nvim-repo.sh push|pull: the Neovim config as its own repository (darktime78/nvim-cpp).
# Kept for the old name; the same as  tools/subrepo.sh push|pull nvim  (see there).
[[ -n ${NVIM_REPO:-} ]] && export REPO_URL=$NVIM_REPO
exec "$(dirname "$(readlink -f "$0")")/subrepo.sh" "${1:-}" nvim
