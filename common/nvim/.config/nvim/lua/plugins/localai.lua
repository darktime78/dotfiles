-- Local Qwen (arch-local-ai) in Neovim: autocomplete with llama.vim, <leader>a… to control
-- the servers, status in the statusline. Same on the host and in the nvim-cpp container.
--
--   ghost text while typing   Tab accepts it all, Shift-Tab one line, Ctrl-Right one word,
--                             Ctrl-F asks for a suggestion now
--   <leader>ae (visual)       edit the selection with an instruction (qwen-agent)
--
-- Tab clashes with snippet jumps? In lua/config/options.lua:
--   vim.g.localai_fim_accept = "<M-a>"
local L = require("util.localai")
local accept = vim.g.localai_fim_accept or "<Tab>"

local function run(...)
  local args = { ... }
  return function()
    L.run(args)
  end
end
local function term(...)
  local args = { ... }
  return function()
    L.term(args)
  end
end

return {
  {
    "ggml-org/llama.vim",
    event = "VeryLazy",
    init = function()
      vim.g.llama_config = {
        endpoint_fim = L.fim_url .. "/infill", -- localai-fim (Qwen2.5-Coder, MX350)
        endpoint_inst = L.router_url .. "/v1/chat/completions", -- localai-router
        model_inst = "qwen-agent",
        auto_fim = vim.g.localai_fim ~= false, -- options.lua: false = only on Ctrl-F
        show_info = 0,
        keymap_fim_trigger = "<C-f>",
        keymap_fim_accept_full = accept,
        keymap_fim_accept_line = "<S-Tab>",
        keymap_fim_accept_word = "<C-Right>",
        -- llama.vim's defaults start with <leader>l, which is LazyVim's :Lazy
        keymap_inst_trigger = "<leader>ae",
        keymap_inst_rerun = "<leader>aE",
        keymap_inst_continue = "<leader>ak",
        keymap_debug_toggle = "",
        -- context and time limits: the MX350 is slow, so give it time but cap it
        n_prefix = 192, -- lines before the cursor
        n_suffix = 64, -- lines after the cursor
        n_predict = 96, -- max tokens per suggestion
        t_max_prompt_ms = 600,
        t_max_predict_ms = 1500,
      }

      -- suggestion colours that fit solarized-osaka (old and new highlight names)
      local function hl()
        for _, g in ipairs({ "llama_hl_hint", "llama_hl_fim_hint" }) do
          vim.api.nvim_set_hl(0, g, { fg = "#657b83", italic = true })
        end
        for _, g in ipairs({ "llama_hl_info", "llama_hl_fim_info" }) do
          vim.api.nvim_set_hl(0, g, { fg = "#859900" })
        end
      end
      hl()
      vim.api.nvim_create_autocmd("ColorScheme", { callback = hl })
    end,
    config = function()
      L.setup()
    end,
    keys = {
      { "<leader>at", "<cmd>LlamaToggle<cr>", desc = "Autocomplete on/off" },
      { "<leader>aa", term("status"), desc = "Status (servers, models, RAM, GPU)" },
      { "<leader>ad", term("doctor"), desc = "Doctor (autocomplete on the MX350?)" },
      { "<leader>as", run("start"), desc = "Start everything" },
      { "<leader>aS", run("start", "battery"), desc = "Battery mode (no autocomplete)" },
      { "<leader>ax", run("stop"), desc = "Stop all" },
      { "<leader>ar", run("restart"), desc = "Restart" },
      { "<leader>ag", run("load", "qwen-agent"), desc = "Preload the 4B agent" },
      { "<leader>ac", run("load", "qwen-chat"), desc = "Preload the 9B chat" },
      { "<leader>al", term("logs", "router"), desc = "Router log" },
      { "<leader>aL", term("logs", "fim"), desc = "Autocomplete log" },
      { "<leader>ab", term("bench"), desc = "Benchmark CPU / iGPU / MX350" },
      { "<leader>aw", run("chat"), desc = "Browser chat (web UI)" },
    },
  },

  {
    "nvim-lualine/lualine.nvim",
    optional = true,
    opts = function(_, opts)
      table.insert(opts.sections.lualine_x, 1, {
        L.statusline,
        color = L.statusline_color,
        cond = function()
          return vim.g.localai_statusline ~= false
        end,
      })
    end,
  },

  {
    "folke/which-key.nvim",
    opts = { spec = { { "<leader>a", group = "local AI (Qwen)", icon = { icon = "󰚩 ", color = "green" } } } },
  },
}
