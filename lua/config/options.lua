-- Loaded automatically by LazyVim before plugins start
vim.g.mapleader = " "
vim.g.maplocalleader = "\\"

local opt = vim.opt
opt.encoding = "utf-8"
opt.fileencoding = "utf-8"
opt.number = true
opt.relativenumber = true
opt.title = true
opt.scrolloff = 10
opt.inccommand = "split"
opt.ignorecase = true
opt.smartcase = true
opt.wrap = false
opt.splitbelow = true
opt.splitright = true
opt.cursorline = true
opt.colorcolumn = "100"
opt.path:append({ "**" })
opt.wildignore:append({ "*/build/*", "*/.cache/*" })

vim.g.autoformat = true
vim.g.lazyvim_picker = "snacks" -- telescope is only used for the `sf` file browser
vim.g.cowboy = false -- true: craftzdog's "Hold it Cowboy!" warning when spamming h/j/k/l
vim.g.craftzdog_window_keys = true -- ss / sv / sh / sj / sk / sl window keys -- format on save (clang-format / cmake-format / mbake)

-- Build dir of the "coverage" CMake preset (see project-template/CMakePresets.json)
vim.g.cpp_coverage_build_dir = "build/coverage"

-- perf / flamegraphs (lua/util/perf.lua) -------------------------------------
vim.g.perf_frequency = 499 -- samples per second
vim.g.perf_call_graph = "dwarf" -- "fp" is cheaper if everything has -fno-omit-frame-pointer
vim.g.perf_after_record = "hotspots" -- "hotspots" | "flamegraph" | "annotate" | "none"
vim.g.perf_hot_percent = 5 -- red rows in the hotspot table
vim.g.perf_warm_percent = 1 -- yellow rows
-- vim.g.perf_project_regex = "^demo::"   -- "only my code" preset keeps stacks touching this
-- vim.g.flamegraph_dir = "~/FlameGraph"  -- if you use Brendan Gregg's perl scripts

-- git / OpenCode -------------------------------------------------------------
-- vim.g.git_main_branch = "origin/main"  -- base for <leader>gM and @branch (auto-detected)
-- vim.g.opencode_run_args = { "--model", "provider/model" }  -- extra args for `opencode run`
