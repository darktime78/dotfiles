-- Loaded automatically by LazyVim on VeryLazy
local map = vim.keymap.set
local opts = { noremap = true, silent = true }

-- craftzdog-style basics (from his keymaps.lua) ------------------------------
if vim.g.cowboy then
  require("util.discipline").cowboy()
end

map("n", "x", '"_x', { desc = "Delete char (no yank)" })
map("n", "<C-a>", "gg<S-v>G", { desc = "Select all" })
-- + / - are smart increment via dial.nvim (lua/plugins/coding.lua)

-- tabs (<Tab> / <S-Tab> cycle them through bufferline)
map("n", "te", "<cmd>tabedit<cr>", { desc = "New tab" })
map("n", "tw", "<cmd>tabclose<cr>", { desc = "Close tab" })

-- splits and window moves. Note: these share the `s` prefix with flash.nvim's jump,
-- so plain `s` fires after 'timeoutlen'. Set vim.g.craftzdog_window_keys = false to drop them.
if vim.g.craftzdog_window_keys ~= false then
  map("n", "ss", "<cmd>split<cr>", { desc = "Split below" })
  map("n", "sv", "<cmd>vsplit<cr>", { desc = "Split right" })
  map("n", "sh", "<C-w>h", { desc = "Window left" })
  map("n", "sj", "<C-w>j", { desc = "Window down" })
  map("n", "sk", "<C-w>k", { desc = "Window up" })
  map("n", "sl", "<C-w>l", { desc = "Window right" })
end
map("n", "<C-w><left>", "<C-w><", { desc = "Narrower" })
map("n", "<C-w><right>", "<C-w>>", { desc = "Wider" })
map("n", "<C-w><up>", "<C-w>+", { desc = "Taller" })
map("n", "<C-w><down>", "<C-w>-", { desc = "Shorter" })

-- next diagnostic (compiler / clang-tidy message) with its float
map("n", "<C-j>", function()
  if vim.diagnostic.jump then
    vim.diagnostic.jump({ count = 1, float = true })
  else
    vim.diagnostic.goto_next()
  end
end, { desc = "Next diagnostic" })

-- clangd inlay hints: parameter names and deduced types
map("n", "<leader>i", function()
  local on = vim.lsp.inlay_hint.is_enabled({ bufnr = 0 })
  vim.lsp.inlay_hint.enable(not on, { bufnr = 0 })
end, { desc = "Toggle inlay hints" })

-- Project-wide formatting --------------------------------------------------
local run = require("util.run")

map("n", "<leader>mf", function()
  run.shell([[
set -e
cxx=$(git ls-files -- '*.c' '*.h' '*.cc' '*.cpp' '*.cxx' '*.hpp' '*.hh' '*.hxx' '*.ipp')
[ -z "$cxx" ] || clang-format -i $cxx
cm=$(git ls-files -- '*CMakeLists.txt' '*.cmake')
[ -z "$cm" ] || cmake-format -i $cm
echo "formatted"
]], "Format project", function()
    vim.cmd("checktime")
  end)
end, { desc = "Format project (clang-format + cmake-format)" })

map("n", "<leader>mF", function()
  run.shell("make format", "make format", function()
    vim.cmd("checktime")
  end)
end, { desc = "Run `make format`" })
