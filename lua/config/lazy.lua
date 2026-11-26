local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
  local out = vim.fn.system({
    "git", "clone", "--filter=blob:none", "--branch=stable",
    "https://github.com/folke/lazy.nvim.git", lazypath,
  })
  if vim.v.shell_error ~= 0 then
    vim.api.nvim_echo({ { "Failed to clone lazy.nvim:\n", "ErrorMsg" }, { out, "WarningMsg" } }, true, {})
    vim.fn.getchar()
    os.exit(1)
  end
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
  spec = {
    { "LazyVim/LazyVim", import = "lazyvim.plugins", opts = { colorscheme = "solarized-osaka" } },

    -- LazyVim extras used as the base of the C++ layer
    { import = "lazyvim.plugins.extras.lang.clangd" }, -- clangd + clangd_extensions
    { import = "lazyvim.plugins.extras.lang.cmake" }, -- neocmakelsp, cmakelint, cmake-tools.nvim
    { import = "lazyvim.plugins.extras.dap.core" }, -- nvim-dap, dap-ui, virtual text
    { import = "lazyvim.plugins.extras.test.core" }, -- neotest
    { import = "lazyvim.plugins.extras.coding.luasnip" }, -- LuaSnip as snippet engine
    { import = "lazyvim.plugins.extras.util.mini-hipatterns" },
    { import = "lazyvim.plugins.extras.lang.git" }, -- gitcommit / gitignore / git_rebase support
    { import = "lazyvim.plugins.extras.lang.json" }, -- SchemaStore: validates CMakePresets.json etc.
    { import = "lazyvim.plugins.extras.editor.inc-rename" }, -- <leader>cr with live preview (craftzdog)
    -- { import = "lazyvim.plugins.extras.ai.copilot" }, -- craftzdog uses Copilot inline completion
    -- { import = "lazyvim.plugins.extras.lang.markdown" }, -- render-markdown for READMEs / docs
    -- { import = "lazyvim.plugins.extras.util.octo" }, -- GitHub PRs & issues (needs the `gh` CLI)

    -- our own overrides (lua/plugins/*.lua)
    { import = "plugins" },
  },
  defaults = { lazy = false, version = false },
  install = { colorscheme = { "solarized-osaka", "habamax" } },
  checker = { enabled = true, notify = false },
  performance = {
    rtp = { disabled_plugins = { "gzip", "tarPlugin", "tohtml", "tutor", "zipPlugin" } },
  },
})
