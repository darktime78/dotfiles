# Neovim C/C++ IDE (your LazyVim config) + the local Qwen servers of arch-local-ai
#
#   docker-images-update nvim-cpp
#   (by hand, from the root of the dotfiles:
#    docker build -t my/nvim-cpp -f docker/images/nvim-cpp/Dockerfile .)
#
# build-context: repo
# The build runs from the root of the dotfiles, so the image gets the same Neovim
# config as your desktop (common/nvim). Dockerfile.dockerignore keeps the rest out.
#
# Needs my/base (../base, built with your UID/GID so files in ~/Projects
# stay yours). Start it with `nvimcpp` (dockerfunc_extra) or from rofi.

FROM my/base

# Toolchain, debugger, profiler, git, AI tools
RUN pacman --cachedir /tmp -Syu --noconfirm \
		neovim git lazygit ripgrep fd tree-sitter-cli \
		base-devel clang cmake ninja gdb perf \
		python python-pipx python-pygments \
		nodejs npm curl jq unzip wget wl-clipboard less socat && \
	pacman --cachedir /tmp -Scc --noconfirm && \
	rm -rf /tmp/*

# OpenCode (AI agent used by opencode.nvim)
RUN npm install -g opencode-ai && npm cache clean --force

# Flamegraph scripts (stackcollapse-perf.pl, flamegraph.pl, difffolded.pl)
RUN git clone --depth 1 https://github.com/brendangregg/FlameGraph /opt/FlameGraph

# Helpers: container start, `localai` (runs on the host through localai-ctl),
# localai-check, xdg-open shim
COPY docker/images/nvim-cpp/entrypoint.sh /usr/local/bin/nvim-cpp-entrypoint
COPY docker/images/nvim-cpp/localai docker/images/nvim-cpp/localai-check \
	docker/images/nvim-cpp/xdg-open /usr/local/bin/
RUN chmod 755 /usr/local/bin/nvim-cpp-entrypoint /usr/local/bin/localai /usr/local/bin/localai-check \
		/usr/local/bin/xdg-open && \
	mkdir -p /home/user/Projects && chown user:users /home/user/Projects

USER user
WORKDIR /home/user
ENV SHELL=/bin/bash \
	PATH=/home/user/.local/bin:/opt/FlameGraph:$PATH

# gcovr (coverage) and mbake (Makefile formatter)
RUN pipx install gcovr && pipx install mbake

# gdb-dashboard
RUN curl -fsSL -o /home/user/.gdbinit \
		https://github.com/cyrus-and/gdb-dashboard/raw/master/.gdbinit

# Your Neovim config: common/nvim (the same one as on the desktop)
COPY --chown=user:users common/nvim/.config/nvim /home/user/.config/nvim
RUN mkdir -p /home/user/.gdbinit.d && \
	cp /home/user/.config/nvim/extras/gdbinit.d/init /home/user/.gdbinit.d/init

# Install all plugins now, so the first start is fast.
# (Mason tools and Tree-sitter parsers still install on the first start.)
RUN nvim --headless "+Lazy! sync" +qa && \
	mkdir -p /home/user/.local/state/nvim /home/user/.local/share/opencode

WORKDIR /home/user/Projects
ENTRYPOINT [ "/usr/local/bin/nvim-cpp-entrypoint" ]
CMD [ "nvim" ]
