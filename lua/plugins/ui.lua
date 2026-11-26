-- From craftzdog's ui.lua
return {
  -- skip clangd's "No information available" on K, and send notifications to the
  -- desktop while Neovim is in the background (long builds, coverage, perf, OpenCode)
  {
    "folke/noice.nvim",
    opts = function(_, opts)
      opts.routes = opts.routes or {}
      table.insert(opts.routes, {
        filter = { event = "notify", find = "No information available" },
        opts = { skip = true },
      })
      local focused = true
      vim.api.nvim_create_autocmd("FocusGained", { callback = function() focused = true end })
      vim.api.nvim_create_autocmd("FocusLost", { callback = function() focused = false end })
      table.insert(opts.routes, 1, {
        filter = { cond = function() return not focused end },
        view = "notify_send",
        opts = { stop = false },
      })
      opts.commands = opts.commands or {}
      opts.commands.all = { view = "split", opts = { enter = true, format = "details" }, filter = {} }
      opts.presets = opts.presets or {}
      opts.presets.lsp_doc_border = true
    end,
  },

  -- tabs instead of buffers in the top line (the gdb-dashboard tab shows up here)
  {
    "akinsho/bufferline.nvim",
    keys = {
      { "<Tab>", "<cmd>BufferLineCycleNext<cr>", desc = "Next tab" },
      { "<S-Tab>", "<cmd>BufferLineCyclePrev<cr>", desc = "Prev tab" },
    },
    opts = {
      options = { mode = "tabs", show_buffer_close_icons = false, show_close_icon = false },
    },
  },

  -- floating file name in the top-right corner of every window, plus error / warning
  -- counts: handy with dap-ui, test summary and diff splits open
  {
    "b0o/incline.nvim",
    dependencies = { "craftzdog/solarized-osaka.nvim" },
    event = "BufReadPre",
    priority = 1200,
    config = function()
      local ok, palette = pcall(function()
        return require("solarized-osaka.colors").setup()
      end)
      local c = ok and palette or { magenta500 = "#d33682", base04 = "#002b36", violet500 = "#6c71c4", base03 = "#002b36" }
      require("incline").setup({
        highlight = {
          groups = {
            InclineNormal = { guibg = c.magenta500, guifg = c.base04 },
            InclineNormalNC = { guifg = c.violet500, guibg = c.base03 },
          },
        },
        window = { margin = { vertical = 0, horizontal = 1 } },
        hide = { cursorline = true },
        render = function(props)
          local filename = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(props.buf), ":t")
          if filename == "" then
            filename = "[No Name]"
          end
          if vim.bo[props.buf].modified then
            filename = "[+] " .. filename
          end
          local icon, color = require("nvim-web-devicons").get_icon_color(filename)
          local parts = { { icon or "", guifg = color }, { " " }, { filename } }
          local counts = vim.diagnostic.count(props.buf)
          local E, W = vim.diagnostic.severity.ERROR, vim.diagnostic.severity.WARN
          if (counts[E] or 0) > 0 then
            table.insert(parts, { "  " .. counts[E], guifg = "#dc322f" })
          end
          if (counts[W] or 0) > 0 then
            table.insert(parts, { "  " .. counts[W], guifg = "#b58900" })
          end
          return parts
        end,
      })
    end,
  },

  { "nvim-lualine/lualine.nvim", opts = { options = { theme = "solarized_dark" } } },

  -- start screen with the C++ workflow on single keys
  {
    "folke/snacks.nvim",
    opts = {
      dashboard = {
        preset = {
          header = [[
 ██████╗    ██╗      ██╗
██╔════╝    ██║      ██║
██║      ████████╗████████╗     n e o v i m
██║      ╚══██╔══╝╚══██╔══╝     c++ workbench
╚██████╗    ╚═╝      ╚═╝
 ╚═════╝]],
          keys = {
            { icon = " ", key = "f", desc = "Find file", action = ":lua Snacks.dashboard.pick('files')" },
            { icon = " ", key = "g", desc = "Grep", action = ":lua Snacks.dashboard.pick('live_grep')" },
            { icon = " ", key = "r", desc = "Recent files", action = ":lua Snacks.dashboard.pick('oldfiles')" },
            { icon = "󰣪 ", key = "b", desc = "CMake build", action = ":CMakeBuild" },
            { icon = "󰙨 ", key = "t", desc = "Run all tests", action = ":lua require('neotest').run.run(vim.uv.cwd())" },
            { icon = " ", key = "G", desc = "Lazygit", action = ":lua Snacks.lazygit()" },
            { icon = "󰚩 ", key = "o", desc = "OpenCode", action = ":lua require('snacks.terminal').toggle('opencode', { win = { position = 'right', width = 0.4 } })" },
            { icon = " ", key = "s", desc = "Restore session", section = "session" },
            { icon = " ", key = "c", desc = "Config", action = ":lua Snacks.dashboard.pick('files', { cwd = vim.fn.stdpath('config') })" },
            { icon = "󰒲 ", key = "l", desc = "Lazy", action = ":Lazy" },
            { icon = " ", key = "q", desc = "Quit", action = ":qa" },
          },
        },
      },
    },
  },
}
