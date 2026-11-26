# Neovim C/C++ IDE (LazyVim, craftzdog style)

A LazyVim-based config like [craftzdog/dotfiles-public](https://github.com/craftzdog/dotfiles-public)
(solarized-osaka, transparent, same basic keymaps) extended into a C++ workbench:

| Feature | Plugins / tools |
|---|---|
| LSP, clang-tidy, header/source switch | clangd + clangd_extensions (LazyVim `lang.clangd`) |
| CMake configure / build / run / debug, presets, targets | cmake-tools.nvim (LazyVim `lang.cmake`) |
| Debugging with breakpoints, registers, stack, disassembly | nvim-dap + GDB native DAP, nvim-dap-ui, nvim-dap-disasm |
| Classic gdb-dashboard | `:GdbDashboard` (gdb + dashboard in a terminal tab) |
| GoogleTest runner / debug a single test | neotest + neotest-gtest |
| Coverage of the tests in the gutter | gcov → gcovr (lcov) → nvim-coverage |
| Formatting on save | conform.nvim: clang-format, cmake-format, mbake |
| Snippets: classes, lambdas, templates, gtest | LuaSnip (`luasnippets/cpp.lua`) |
| Profiling: flamegraphs with filters, hotspot table, diff | perf + inferno / FlameGraph (`lua/util/perf.lua`) |
| Hot source lines highlighted in the editor | perfanno.nvim |
| Git: hunks, blame, lazygit, diffs, history, merge conflicts, branch review | gitsigns, Snacks lazygit, diffview.nvim, git-conflict.nvim |
| AI pair programming with build / test / coverage / perf / git context | OpenCode + opencode.nvim |

## Layout

```
~/.config/nvim
├── init.lua
├── lua/config/{lazy,options,keymaps,autocmds}.lua
├── lua/plugins/{colorscheme,coding,editor,ui,cpp,cmake,dap,test,coverage,formatting,snippets,perf,git,opencode}.lua
├── lua/util/{run,target,gdb_dashboard,coverage,perf,ai_context,discipline}.lua
├── luasnippets/cpp.lua
└── extras/gdbinit.d/init          -> copy to ~/.gdbinit.d/init
project-template/                   -> sample CMake + GTest project to try everything
```

## Install

System packages (Debian/Ubuntu names; adjust for your distro):

```sh
sudo apt install neovim git ripgrep fd-find build-essential clang cmake ninja-build gdb python3-pip pipx
pipx install gcovr      # >= 7 (needs --lcov)
pipx install mbake      # Makefile formatter (optional)
pip install --user pygments   # syntax highlighting inside gdb-dashboard

# profiling
sudo apt install linux-tools-common linux-tools-$(uname -r)   # perf (Debian: linux-perf, Arch/Fedora: perf)
cargo install inferno           # inferno-collapse-perf / inferno-flamegraph / inferno-diff-folded
# or: git clone https://github.com/brendangregg/FlameGraph ~/FlameGraph
#     and set vim.g.flamegraph_dir = "~/FlameGraph" in lua/config/options.lua

# allow perf for normal users (persist it in /etc/sysctl.d/ if you like)
sudo sysctl kernel.perf_event_paranoid=1
sudo sysctl kernel.kptr_restrict=0     # only needed for kernel symbols

# git + AI
sudo apt install lazygit               # or: brew install lazygit / pacman -S lazygit
curl -fsSL https://opencode.ai/install | bash   # or: npm i -g opencode-ai
opencode auth login                    # pick a provider once
```

Requirements worth checking: **Neovim ≥ 0.10** (0.11 recommended), **gdb ≥ 14** (`gdb --version`;
the DAP interpreter appeared in 14), CMake ≥ 3.21 for the presets, and a Nerd Font in your terminal.
clangd, clang-format, cmake-format (cmakelang) and cmakelint are installed by Mason automatically.

```sh
mv ~/.config/nvim ~/.config/nvim.bak 2>/dev/null
cp -r nvim-cpp ~/.config/nvim

# gdb-dashboard
wget -P ~ https://github.com/cyrus-and/gdb-dashboard/raw/master/.gdbinit
mkdir -p ~/.gdbinit.d && cp ~/.config/nvim/extras/gdbinit.d/init ~/.gdbinit.d/init

nvim   # lazy.nvim bootstraps and installs everything; then run :checkhealth
```

## Try it on the sample project

```sh
cp -r ~/.config/nvim/project-template ~/demo && cd ~/demo && git init && nvim src/main.cpp
```

1. `<leader>mp` → pick the **debug** preset, `<leader>mg` to configure (compile_commands.json is
   symlinked into the root so clangd works), `<leader>mb` to build.
2. `<leader>ml` → choose `demo_app` as launch target, `<leader>mr` runs it.
3. Put the cursor on the `calc.push(...)` line, press **F9**, then **F5** (or `<leader>md` which
   builds first). dap-ui opens: Scopes (expand **Registers**), call stack, watches, breakpoints,
   REPL, console and disassembly. **F11** into `factorial` and watch the stack grow.
4. In the REPL you can type raw gdb commands: `info registers rip rsp`, `x/8xg $sp`, `info frame`.
5. `:GdbDashboard` (or `<leader>dG`) opens the classic gdb-dashboard in a new tab with your
   breakpoints copied over; `:GdbDashboard!` also runs the program.
6. Open `tests/calculator_test.cpp`, `<leader>tt` runs the file, `<leader>tr` the nearest test,
   `<leader>td` debugs it in gdb, `<leader>ts` opens the summary.
7. `<leader>tC` builds the **coverage** preset, runs the tests, writes
   `build/coverage/coverage.info` (+ HTML in `build/coverage/coverage-html/`) and shows covered /
   uncovered lines in the gutter. The `b == 0` branch of `divide` shows as uncovered.
8. Profiling: `<leader>mp` → **profile** preset (RelWithDebInfo + frame pointers), `<leader>mb`,
   then `<leader>pr` and enter `--bench` as arguments. perf runs in a split; when it finishes the
   hotspot table opens and `count_primes_naive` is at the top in red.
9. `<leader>pf` opens the flamegraph SVG in your browser (click to zoom, Ctrl-F to search).
   `<leader>pi` shows the "hot leaves" icicle view, where the widest boxes on top are the
   functions that actually burn CPU.
10. `<leader>pF` → *Preset: only my code*. `std::sort` internals and libc disappear and their time is
    charged to `bench()`, so you see which of *your* functions cause the load.
11. `<leader>pl` loads the call graph into perfanno: hot lines in `calculator.cpp` get a red
    background gradient and a percentage; `<leader>pH` jumps between the hottest lines.
12. Change the code (e.g. call the sieve instead), rebuild, `<leader>pr` again, then `<leader>pd`
    for a differential flamegraph: red got slower, blue got faster.

## Keymaps

`<leader>` is Space. Everything from LazyVim still works (`<leader>ch` switches header/source,
`<leader>cf` formats, `gd`, `K`, …).

**CMake / make**

| Key | Action |
|---|---|
| `<leader>mg` | Generate (configure) |
| `<leader>mb` / `<leader>mB` | Build / clean + build |
| `<leader>mr` / `<leader>md` | Run / debug launch target (gdb) |
| `<leader>ma` | Set launch arguments |
| `<leader>mt` / `<leader>ml` | Select build target / launch target |
| `<leader>my` | Select build type (no presets) |
| `<leader>mp` / `<leader>mP` | Select configure preset / build preset |
| `<leader>mT` | Run CTest |
| `<leader>mc` | Clean |
| `<leader>ms` / `<leader>mS` | Target settings / project settings |
| `<leader>mo` / `<leader>mq` | Open build output / stop build |
| `<leader>mf` | Format whole project (clang-format + cmake-format on git files) |
| `<leader>mF` | Run `make format` |

**Debugging** (plus LazyVim's `<leader>d…`: `db` breakpoint, `dB` conditional, `dC` run to cursor,
`du` toggle UI, `de` eval, `dr` REPL, `dt` terminate)

| Key | Action |
|---|---|
| `F5` / `Shift-F5` | Start-continue / stop |
| `F9` | Toggle breakpoint |
| `F10` / `F11` / `F12` | Step over / into / out |
| `<leader>dR` | `info registers` into the REPL |
| `<leader>dS` | Backtrace into the REPL |
| `<leader>dM` | Examine memory (`x/32xb <addr>`, default `$sp`) |
| `<leader>dF` | Floating Scopes window (locals + registers) |
| `<leader>dD` | Disassembly view |
| `<leader>dG` | gdb-dashboard tab |

**Tests and coverage** (plus LazyVim's `tt` file, `tr` nearest, `tT` all, `td` debug nearest,
`ts` summary, `to` output, `tw` watch)

| Key | Action |
|---|---|
| `<leader>tC` | Build coverage preset, run tests, load lcov |
| `<leader>tL` | Load the last coverage report |
| `<leader>tc` | Toggle coverage signs |
| `<leader>tv` | Coverage summary popup |
| `<leader>tX` | Clear coverage |

**Profiling** (`<leader>p`)

| Key | Action |
|---|---|
| `<leader>pr` | `perf record` the launch target (asks for arguments) |
| `<leader>pA` | `perf record -p PID` for N seconds (attach to a running process) |
| `<leader>ph` | Hotspot table (self % / total %, red ≥ 5 %, yellow ≥ 1 %) |
| `<leader>pf` | Filtered flamegraph → SVG in the browser |
| `<leader>pi` | Hot leaves: reversed icicle graph |
| `<leader>pd` | Differential flamegraph, previous recording → current |
| `<leader>pF` / `<leader>pX` | Filter menu / reset filters |
| `<leader>pl` / `<leader>pL` | perfanno: load call graph / flat profile into the source |
| `<leader>pt` | Toggle source annotations |
| `<leader>pa` | Annotate current function (visual: selection) |
| `<leader>pH` / `<leader>ps` | Hottest source lines / hottest symbols picker |
| `<leader>pc` | Hottest callers of the current function |
| `<leader>pe` / `<leader>pn` | Pick perf event / cycle percent ↔ sample counts |

In the hotspot table: `<CR>` jumps to the function (LSP workspace symbol), `s`/`t` sort by
self/total, `f` filters, `F` flamegraph, `H` hot leaves, `r` refresh, `q` close.

## Profiling filters

Filters apply to the hotspot table and all flamegraphs. They are saved per project in
`build/perf/filters.json`. Set them from the menu (`<leader>pF`) or directly, e.g.
`:PerfFilter hide ^std::` or `:PerfFilter focus ^demo::Calculator::` (Tab completes keys).
Regexes are Vim very-magic (`\v`), so `|`, `()`, `+`, `?` work without backslashes, and a literal
`<` or `>` needs a backslash.

They run in this order on every sampled stack:

| Filter | Effect | Typical use |
|---|---|---|
| `process` | keep stacks whose process (first frame) matches | `^demo_app$` when attaching to a busy system |
| `hide_kernel` | drop kernel frames | on by default |
| `focus` | re-root stacks at the first matching frame, drop the rest | `^bench` to zoom into one code path |
| `hide` | remove matching frames; their time goes to the caller | `^std::` to charge STL time to your code |
| `merge_recursion` | collapse `f;f;f` into `f` | recursive algorithms |
| `include` / `exclude` | keep / drop whole stacks matching | `include ^demo::`, `exclude malloc` |
| `reverse`, `inverted` | leaf→root order, icicle layout | find the leaf functions that burn CPU |
| `minwidth`, `colors` | flamegraph pruning (px) and palette | `minwidth 1` for huge profiles |
| `min_percent` | hide small rows in the hotspot table | default 0.5 % |

Presets in the menu: **only my code** (hides `std::`, `__gnu_cxx::`, libc, loader and kernel
frames; set `vim.g.perf_project_regex = "^demo::"` to also require your namespace), **hot leaves**,
**recursion merged** and **reset**.

Options in `lua/config/options.lua`: `vim.g.perf_frequency` (499 Hz), `vim.g.perf_call_graph`
(`dwarf`; `fp` is much cheaper when the whole program has frame pointers), `vim.g.perf_after_record`
(`hotspots`, `flamegraph`, `annotate` or `none`), `vim.g.perf_hot_percent` / `perf_warm_percent`.

Files: `perf.data` (and `perf.data.old`, kept by perf for the diff) live in the project root so
perfanno finds them; collapsed stacks and SVGs go to `build/perf/`.

**Git** (LazyVim already gives you `]h`/`[h` hunks, `<leader>gh…` stage/reset/preview hunk,
`<leader>gb` blame line, `<leader>gg` lazygit, `<leader>gs` status, `<leader>gl` log, `<leader>gB` open in browser)

| Key | Action |
|---|---|
| `<leader>gv` / `<leader>gV` | Diffview of the working tree / close it |
| `<leader>gH` | File history (in visual mode: history of the selected lines) |
| `<leader>gR` | Repository history |
| `<leader>gM` | Branch vs main in Diffview, for reviewing a PR before pushing |
| `<leader>gx` | List merge conflicts in quickfix |
| `co` `ct` `cb` `c0`, `]x` `[x` | In a conflicted file: take ours / theirs / both / none, next / previous conflict |
| `<leader>gT` / `<leader>gW` | Toggle inline blame / word diff |

During a merge, `:DiffviewOpen` shows a 3-way merge view (ours · result · theirs).

**OpenCode** (`<leader>o`)

| Key | Action |
|---|---|
| `<leader>oa` | Ask about the cursor position or selection (`@this`) |
| `<leader>oA` / `<leader>os` | Free-form ask / pick from all prompts and commands |
| `<leader>ot`, `Ctrl-.` | Toggle the OpenCode split |
| `go{motion}`, `goo`, visual `go` | Send a range / the line to the prompt (dot-repeatable) |
| `<leader>oe` / `<leader>or` | Explain this / review it as modern C++ (UB, lifetimes, copies, const) |
| `<leader>ob` | Fix the errors of the last CMake build (`@quickfix`) |
| `<leader>oT` | Write GoogleTests for this function or selection |
| `<leader>oc` | Write tests for lines the coverage report marks as never executed (`@uncovered`) |
| `<leader>op` | Optimize this using the perf profile (`@hotspots`) |
| `<leader>od` / `<leader>oB` | Review uncommitted changes (`@diff`) / the whole branch vs main (`@branch`) |
| `<leader>om` | Commit message from the staged diff (`@staged`) |
| `<leader>on` `oS` `ou` `oU` `oi` | New session · select session · undo · redo · interrupt |

In the perf hotspot table, `a` asks OpenCode to optimize the function under the cursor. In a
`gitcommit` buffer (`git commit` with Neovim as editor), `<localleader>m` runs `opencode run`
and inserts the generated message at the top; review it, then `:wq`.

When OpenCode wants to edit a file, the proposed change opens as a diff: `da` accepts all,
`dr` rejects, `]c`/`[c` move between changes, `q` closes. Accepted edits reload the buffer.

Context placeholders you can type in any ask (Tab completes them):

| Placeholder | Content |
|---|---|
| `@this`, `@buffer`, `@buffers`, `@visible` | cursor / selection, current buffer, open buffers, visible text |
| `@diagnostics`, `@quickfix` | clangd / clang-tidy diagnostics, build errors from cmake-tools |
| `@hotspots` | top 15 rows of the perf hotspot table with the active filters |
| `@uncovered` | never-executed lines from `build/coverage/coverage.info` (current file, else all) |
| `@diff`, `@staged`, `@branch` | `git diff HEAD`, `git diff --cached`, `git diff <main>...HEAD` + commit list |

Typical loops: build fails → `<leader>ob`; tests pass but coverage has red bars → `<leader>oc`;
profile shows a red hotspot → `a` in the table or `<leader>op` on the function; before pushing →
`<leader>oB`, then `<leader>gM` to read the diff yourself.

## craftzdog's plugins and how they are used here

`lua/plugins/coding.lua`, `editor.lua` and `ui.lua` follow the files of the same name in
craftzdog's config. His Telescope keys are mapped onto Snacks, LazyVim's built-in picker, so
there is one fast picker everywhere; Telescope is only loaded for his `sf` file browser.

| Plugin (his file) | What it does | Daily use | Here |
|---|---|---|---|
| LazyVim + lazy.nvim | Distribution and plugin manager | `:Lazy` update/sync, `:LazyExtras` toggle extras | Base of this config |
| solarized-osaka.nvim | His theme, transparent | — | Same |
| snacks.nvim | Picker, dashboard, lazygit, zen, notifier, terminal | `;f` `;r` `\\` `;;` `;e` `;s` | His keys + C++ ones (below) |
| telescope + file-browser (editor) | Fuzzy finder and floating file manager | `sf`, then `N` new, `r` rename, `d` delete, `h` parent, `.` hidden, `/` filter | Only `sf` |
| flash.nvim (LazyVim) | Jump anywhere with labels | `s` + 2 chars, `S` select a Tree-sitter node (a whole `if`, class, lambda), `r` remote in operator mode | Default |
| inc-rename.nvim (coding) | LSP rename with live preview | `<leader>rn` (or `<leader>cr`) on a symbol, type the new name | Added, works with clangd across files |
| mini.bracketed (coding) | More `]`/`[` motions | `]n`/`[n` syntax node, `]i` indent scope, `]j` jumps, `]o` old files, `]u` undo states | Added; targets already owned by LazyVim, diff mode and git-conflict are off |
| dial.nvim (coding) | Smart increment | `+`/`-` on numbers, hex, dates, `true` | Added with C++ and CMake cycles: `public/protected/private`, `int8_t…int64_t`, `unique_ptr/shared_ptr`, `EXPECT_EQ/ASSERT_EQ`, `TEST/TEST_F`, `&&`/`\|\|`, `==`/`!=`, `ON/OFF`, build types |
| close-buffers.nvim (editor) | Delete many buffers | `<leader>bh` hidden, `<leader>bu` nameless | Added (his keys were `<leader>t…`, taken by tests) |
| git.nvim (editor) | Blame window, open on GitHub | `<leader>gb`, `<leader>go` | Covered by gitsigns / Snacks: `<leader>gb` blame line, `<leader>go` open in browser |
| noice.nvim (ui) | Cmdline, messages, notifications UI | `:Noice` history | His routes: hide clangd's "No information available"; desktop notifications while Neovim is unfocused (long builds, coverage, perf, OpenCode) |
| bufferline.nvim (ui) | Top line | `<Tab>`/`<S-Tab>` | Tabs mode like his, so the gdb-dashboard tab is visible |
| incline.nvim (ui) | Floating file name per window | — | Added, plus error/warning counts per window |
| lualine.nvim (ui) | Statusline | — | `solarized_dark`, plus CMake target and OpenCode status |
| zen-mode.nvim (ui) | Distraction-free view | `<leader>z` | Same key, via `Snacks.zen()` |
| render-markdown.nvim (ui) | Pretty Markdown | — | Optional: uncomment the markdown extra in `lazy.lua` |
| copilot.lua (coding) | Inline AI completion | `<Tab>` accept | Optional extra in `lazy.lua`; OpenCode covers AI here |
| blink.cmp, mason, treesitter, lspconfig | Completion, tool installer, syntax, LSP | — | Same, configured for clangd / CMake |
| mini.hipatterns (extra) | Highlights hex colours and TODO/FIXME | — | Same |
| nvim-highlight-colors (editor) | Colour previews in CSS | — | Skipped, web-only |
| eslint, prettier, typescript, tailwind, rust extras | His web/Rust stack | — | Skipped; `lang.json` kept because SchemaStore validates `CMakePresets.json` |
| `craftzdog.discipline` (his module) | Warns when you hold `h/j/k/l` | — | `lua/util/discipline.lua`, opt-in with `vim.g.cowboy = true` |

His keymaps and where they landed:

| Keys | Action | Notes |
|---|---|---|
| `;f` `;r` | Find files (with hidden) / live grep | |
| `\\` | Buffers | |
| `;;` | Resume the last picker | Great after a grep: jump to a result, `;;`, next result |
| `;e` | Diagnostics of all buffers | |
| `;t` | Help tags | |
| `;s` / `;S` | Symbols in file / project (clangd) | His `;s` used Tree-sitter; clangd symbols are better for C++ |
| `;c` / `;o` | Incoming / outgoing calls | C++ call hierarchy from clangd |
| `;q` | Quickfix list (build errors) | New |
| `;h` | Switch header / source | New |
| `sf` | File browser at the current file | |
| `te` / `tw`, `<Tab>` / `<S-Tab>` | New tab / close tab, cycle tabs | |
| `ss` / `sv`, `sh` `sj` `sk` `sl` | Split, move between windows | Share the `s` prefix with flash, so plain `s` waits `timeoutlen`; `vim.g.craftzdog_window_keys = false` removes them |
| `<C-w>` + arrows | Resize window | |
| `<C-j>` | Next diagnostic with float | |
| `<leader>i` | Toggle inlay hints | Off by default like his; shows parameter names and deduced `auto` types |
| `x` | Delete char without yanking | |
| `<C-a>` | Select all | |
| `<leader>z` | Zen mode | |

Not ported because they clash with the C++ groups: his `<leader>d`/`<leader>c` (delete/change
without yank) would break `<leader>d…` debug and `<leader>c…` code, and `<leader>p` (paste
register 0) is the profiling group. Use built-in `P` in visual mode to paste without losing the
register. His `dw` remap (delete word backwards) is also left out, as it changes a core motion.
With `;` mapped as a prefix, repeat `f`/`t` jumps by pressing `f`/`t` again (flash does this).

## Snippets (`luasnippets/cpp.lua`)

Expand with Tab, jump with Tab/Shift-Tab, cycle choices with **Ctrl-l**. Class names default to
the file name in PascalCase (`my_widget.hpp` → `MyWidget`).

| Trigger | Expands to |
|---|---|
| `class`, `classr5`, `classmo`, `iface`, `struct` | class, rule-of-five, move-only, abstract interface, struct |
| `tclass`, `tfn`, `tvar`, `tspec` | class template, function template, variadic + forwarding, specialization |
| `concept`, `treq` | C++20 concept, constrained template |
| `lam`, `laml`, `glam`, `tlam`, `iife`, `sortl` | lambda (capture and specifier are choices), named, generic, template lambda, IIFE, sort comparator |
| `main`, `ns`, `once`, `forr`, `fori` | misc |
| `test`, `testf`, `fixture`, `gtmain` | GoogleTest |

## Formatting

On save: `.c/.cpp/.h/.hpp` → clang-format (nearest `.clang-format`, else Google style), `CMakeLists.txt` /
`*.cmake` → cmake-format (`.cmake-format.yaml`), `Makefile` → mbake. Toggle autoformat with
`<leader>uf`. The template also has `format` / `format-check` CMake targets and a `Makefile` with
`make format` for CI or for `<leader>mF`.

## Notes

* Start Neovim in the project root: cmake-tools, the coverage helper and gcovr's relative paths
  all use the current directory.
* The DAP adapter starts gdb with `-nh` so `~/.gdbinit` (gdb-dashboard) does not write into the
  DAP stream. Pretty printers for the STL still load through gdb's auto-load.
* neotest-gtest needs the test executable built. If it cannot work out which binary belongs to a
  test file, open the summary (`<leader>ts`), put the cursor on the file or directory and run
  `:ConfigureGtest` to point it at `build/debug/unit_tests`. `TEST_P` is not supported by the adapter.
* Coverage with Clang works too: the template switches gcovr to `llvm-cov gcov` automatically.
* perf with `--call-graph dwarf` records large files and `perf script` takes a while on long
  runs; the collapsed stacks are cached until `perf.data` changes, so changing filters is instant.
  Lower `vim.g.perf_frequency` or switch to `fp` with the profile preset for long runs.
* If stacks stop at libstdc++/libc with `fp`, that library was built without frame pointers; use
  `dwarf`.
* opencode.nvim's `main` branch targets OpenCode v2. If you run OpenCode v1, uncomment
  `version = "*"` in `lua/plugins/opencode.lua`. Run `:checkhealth opencode` after setup.
* OpenCode reads files from disk, so save before asking. `@diff`/`@staged`/`@branch` are capped at
  24 000 characters each.
* `Ctrl-.` is not sent by every terminal; `<leader>ot` always works.
* `<leader>gM` and `@branch` diff against `origin/HEAD` (or `origin/main`, `main`, `master`); set
  `vim.g.git_main_branch` to override.
* The codelldb configurations from LazyVim's clangd extra are still available below the GDB
  ones in the F5 picker if you ever want LLDB.
