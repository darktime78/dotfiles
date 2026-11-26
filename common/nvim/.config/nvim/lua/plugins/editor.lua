-- From craftzdog's editor.lua. His Telescope keys are mapped onto Snacks (LazyVim's
-- picker); Telescope is only pulled in for his `sf` file browser.
local function buffer_dir()
  local name = vim.api.nvim_buf_get_name(0)
  if name == "" or vim.bo.buftype ~= "" then
    return vim.uv.cwd()
  end
  return vim.fn.fnamemodify(name, ":p:h")
end

return {
  {
    "folke/snacks.nvim",
    keys = {
      { ";f", function() Snacks.picker.files({ hidden = true }) end, desc = "Find files (incl. hidden)" },
      { ";r", function() Snacks.picker.grep({ hidden = true }) end, desc = "Live grep" },
      { "\\\\", function() Snacks.picker.buffers() end, desc = "Buffers" },
      { ";t", function() Snacks.picker.help() end, desc = "Help tags" },
      { ";;", function() Snacks.picker.resume() end, desc = "Resume last picker" },
      { ";e", function() Snacks.picker.diagnostics() end, desc = "Diagnostics (all buffers)" },
      { ";s", function() Snacks.picker.lsp_symbols() end, desc = "Symbols in file (clangd)" },
      { ";S", function() Snacks.picker.lsp_workspace_symbols() end, desc = "Symbols in project" },
      { ";c", function() Snacks.picker.lsp_incoming_calls() end, desc = "Who calls this function" },
      { ";o", function() Snacks.picker.lsp_outgoing_calls() end, desc = "What this function calls" },
      { ";q", function() Snacks.picker.qflist() end, desc = "Quickfix (build errors)" },
      { ";h", "<cmd>LspClangdSwitchSourceHeader<cr>", desc = "Switch header / source" },
      { "<leader>go", function() Snacks.gitbrowse() end, desc = "Open in browser (git remote)", mode = { "n", "x" } },
      { "<leader>z", function() Snacks.zen() end, desc = "Zen mode" },
    },
  },

  -- craftzdog's floating file browser: sf opens at the current file's directory
  {
    "nvim-telescope/telescope.nvim",
    cmd = "Telescope",
    dependencies = { "nvim-lua/plenary.nvim", "nvim-telescope/telescope-file-browser.nvim" },
    keys = {
      {
        "sf",
        function()
          require("telescope").extensions.file_browser.file_browser({
            path = "%:p:h",
            cwd = buffer_dir(),
            respect_gitignore = false,
            hidden = true,
            grouped = true,
            previewer = false,
            initial_mode = "normal",
            layout_config = { height = 40 },
          })
        end,
        desc = "File browser (current dir)",
      },
    },
    config = function()
      local telescope = require("telescope")
      local actions = require("telescope.actions")
      local fb_actions = require("telescope._extensions.file_browser.actions")
      telescope.setup({
        defaults = {
          wrap_results = true,
          layout_strategy = "horizontal",
          layout_config = { prompt_position = "top" },
          sorting_strategy = "ascending",
          winblend = 0,
        },
        extensions = {
          file_browser = {
            theme = "dropdown",
            hijack_netrw = false, -- Snacks explorer keeps that job
            mappings = {
              n = {
                ["N"] = fb_actions.create, -- new file, or folder when the name ends with /
                ["r"] = fb_actions.rename,
                ["d"] = fb_actions.remove,
                ["h"] = fb_actions.goto_parent_dir,
                ["."] = fb_actions.toggle_hidden,
                ["/"] = function()
                  vim.cmd("startinsert")
                end,
                ["<C-u>"] = function(bufnr)
                  for _ = 1, 10 do
                    actions.move_selection_previous(bufnr)
                  end
                end,
                ["<C-d>"] = function(bufnr)
                  for _ = 1, 10 do
                    actions.move_selection_next(bufnr)
                  end
                end,
              },
            },
          },
        },
      })
      telescope.load_extension("file_browser")
    end,
  },

  -- close many buffers at once (stepping into std:: headers while debugging opens a lot)
  {
    "kazhala/close-buffers.nvim",
    keys = {
      { "<leader>bh", function() require("close_buffers").delete({ type = "hidden" }) end, desc = "Close hidden buffers" },
      { "<leader>bu", function() require("close_buffers").delete({ type = "nameless" }) end, desc = "Close nameless buffers" },
    },
  },
}
