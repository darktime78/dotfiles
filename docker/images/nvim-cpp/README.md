# nvim-cpp: your Neovim C/C++ IDE in Docker, on the local Qwen servers

Contents: your LazyVim config (`common/nvim`, the same one the desktop uses) plus
`lua/plugins/localai.lua` + `lua/util/localai.lua` (llama.vim autocomplete,
`<leader>a…`, statusline), and clang/clangd, CMake, Ninja, GDB + gdb-dashboard,
perf + FlameGraph, gcovr, lazygit and OpenCode.

The AI servers are **not** in the container. They stay on the host (arch-local-ai:
`localai-fim` on 8012, `localai-router` on 8080), and the container uses them:

```
 container (--net host)                         │  host
 llama.vim     → 127.0.0.1:8012/infill ─────────┼→ localai-fim     (Qwen2.5-Coder, MX350)
 OpenCode      → 127.0.0.1:8080/v1 ─────────────┼→ localai-router  (qwen-agent / qwen-chat)
 localai CMD   → /run/localai-ctl/ctl.sock ─────┼→ localai-ctl → localai CMD (allowlist)
 read-only     ← ~/.config/localai, ~/.config/opencode, ~/.local/bin/cpp-report
```

## Setup

On the host, with the updated arch-local-ai:

```sh
cd arch-local-ai && ./install.sh          # adds and enables localai-ctl.service
localai status                            # shows a localai-ctl row with the socket
```

Build the image (once, and after config changes):

```sh
docker-images-update nvim-cpp      # builds archlinux -> my/base -> my/nvim-cpp
```

The build runs from the root of the dotfiles (`# build-context: repo` in the
Dockerfile), so a change in `common/nvim` is in the next image.

Start: `$mod+c` → `nvimcpp`, rofi → "Neovim C++ + LocalAI (Docker)", or `nvimcpp`
in zsh. The window goes to workspace 3. Inside, `localai-check` tests everything.

Nothing to configure: the ports come from `~/.config/localai/localai.conf`, OpenCode
uses your `~/.config/opencode` (agents, permissions, `/test` `/build` `/cover`
`/review`). Overrides, if ever needed: `~/.config/docker/localai.env`.

## In Neovim (same keys on the host)

| Key | Action |
|---|---|
| typing in insert mode | ghost text; `Tab` accepts all, `Shift-Tab` one line, `Ctrl-Right` one word, `Ctrl-F` asks now |
| `<leader>at` | autocomplete on/off |
| `<leader>aa` / `<leader>ad` | status / doctor (floating window) |
| `<leader>as` / `<leader>aS` | start everything / battery mode |
| `<leader>ax` / `<leader>ar` | stop / restart |
| `<leader>ag` / `<leader>ac` | preload qwen-agent / qwen-chat |
| `<leader>al` / `<leader>aL` | router / autocomplete log |
| `<leader>ab` | benchmark |
| `<leader>aw` | browser chat (opens on the host) |
| `<leader>ae` (visual) | edit the selection with an instruction (qwen-agent) |
| `:LocalAI …` | any of the above, with completion |
| `<leader>o…` | OpenCode; starts the router first if it is down |

Statusline: `󰚩 fim● qwen●`, green = both up, yellow = one, grey = none (checked
every 15 s with a TCP connect, no extra processes). `Tab` should jump in snippets
instead: `vim.g.localai_fim_accept = "<M-a>"` in `lua/config/options.lua`.

`localai …` in the container's terminal works too, for: `status models devices doctor
start [dev|battery] stop restart load|unload qwen-agent|qwen-chat|qwen-code gpu [MODE]
logs [fim|router] bench [agent|chat|fim] chat`. Other commands (`pull`, `uninstall`)
only on the host.

## Storage

| Where | What |
|---|---|
| `~/Projects` ↔ `/home/user/Projects` | your code (start directory) |
| volume `nvim-cpp-data` | plugins, Mason tools (clangd …), Tree-sitter parsers |
| volume `nvim-cpp-state`, `nvim-cpp-opencode` | Neovim history, OpenCode sessions |
| `~/.config/nvim-cpp` (optional) | edit the config live: `ln -s ~/.config/nvim ~/.config/nvim-cpp` |

After rebuilding the image with new plugins: `docker volume rm nvim-cpp-data`.

## Notes

* OpenCode in the image must be v2 (your config uses the v2 format). The container
  warns at start otherwise; rebuild to update.
* gdb and perf work through `--cap-add SYS_PTRACE --cap-add PERFMON` and
  `seccomp=unconfined`. perf also needs on the host: `sudo sysctl kernel.perf_event_paranoid=1`.
* No browser inside: opening a flamegraph copies its host path to the clipboard.
* First start installs Mason tools and Tree-sitter parsers (network, ~1 minute).
