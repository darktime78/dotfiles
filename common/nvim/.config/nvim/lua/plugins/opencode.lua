-- OpenCode (https://opencode.ai) inside Neovim via nickjvandyke/opencode.nvim
--   * auto-connects to an `opencode` running in Neovim's cwd, or starts one in a right split
--   * sends editor context: @this @buffer @diagnostics @quickfix … plus our C++ contexts
--     @hotspots @uncovered @diff @staged @branch  (lua/util/ai_context.lua)
--   * edits made by OpenCode reload the buffers; edit permissions open as a diff (da / dr)
local OC_CMD = "opencode"
local TERM_OPTS = { win = { position = "right", width = 0.4, enter = false } }

local P = {
  cpp_review = "Review @this as modern C++ (C++20): undefined behaviour, object lifetimes and dangling "
    .. "references, exception safety, const-correctness, needless copies and API misuse. Propose minimal, "
    .. "concrete fixes.",
  fix_build = "Fix the compiler and linker errors from the last CMake build: @quickfix",
  gtest = "Write GoogleTest cases (TEST / TEST_F) for @this in the tests/ directory, following the style of "
    .. "the existing tests. Cover edge cases and error paths; register new test files in CMakeLists.txt.",
  cover_uncovered = "These lines are never executed by the GoogleTest suite (gcovr report): @uncovered "
    .. "Write GoogleTest cases in tests/ that exercise them.",
  optimize_hotspots = "Profile of the program from perf: @hotspots Explain why the hottest functions are "
    .. "slow and optimize @this without changing behaviour. The existing tests must keep passing.",
  review_diff = "Review my uncommitted changes for bugs, C++ pitfalls and missing tests: @diff",
  review_branch = "Review this branch against the main branch like a pull request: @branch",
  commit_message = "Write a Conventional Commits message for these staged changes. Output only the message: @staged",
}

local function oc()
  return require("opencode")
end

local function send(text)
  return function()
    oc().prompt(text)
  end
end

-- OpenCode talks to the local router (arch-local-ai): start it first if it is down
local function ensure_router()
  pcall(function()
    require("util.localai").ensure_router()
  end)
end

local function toggle()
  ensure_router()
  require("snacks.terminal").toggle(OC_CMD, TERM_OPTS)
end

return {
  {
    "nickjvandyke/opencode.nvim",
    -- main targets OpenCode v2. Still on OpenCode v1? use the latest stable release instead:
    -- version = "*",
    event = "VeryLazy",
    dependencies = { "folke/snacks.nvim" },
    init = function()
      ---@type opencode.Opts
      vim.g.opencode_opts = {
        select = { prompts = P }, -- added to the built-in explain / fix / optimize / review / test …
      }
    end,
    config = function()
      local opts = require("opencode.config").opts
      local ctx = require("util.ai_context")

      -- Lua functions go straight into the merged options (vim.g can't hold them reliably)
      opts.contexts["@hotspots"] = ctx.hotspots
      opts.contexts["@uncovered"] = ctx.uncovered
      opts.contexts["@diff"] = ctx.diff
      opts.contexts["@staged"] = ctx.staged
      opts.contexts["@branch"] = ctx.branch
      opts.server.start = function()
        ensure_router()
        require("snacks.terminal").open(OC_CMD, TERM_OPTS)
      end

      -- bring the OpenCode split forward when it starts working
      vim.api.nvim_create_autocmd("User", {
        pattern = "OpencodeEvent:session.execution.started",
        callback = function()
          local win = require("snacks.terminal").get(OC_CMD, { create = false })
          if win then
            win:show()
          end
        end,
      })
    end,
    keys = {
      { "<leader>oa", function() oc().ask("@this: ") end, mode = { "n", "x" }, desc = "Ask about this…" },
      { "<leader>oA", function() oc().ask() end, desc = "Ask…" },
      { "<leader>os", function() oc().select() end, mode = { "n", "x" }, desc = "Select prompt / command…" },
      { "<leader>ot", toggle, desc = "Toggle OpenCode split" },
      { "<C-.>", toggle, mode = { "n", "t" }, desc = "Toggle OpenCode split" },
      { "go", function() return oc().operator("@this") end, mode = { "n", "x" }, expr = true, desc = "Send range to OpenCode" },
      { "goo", function() return oc().operator("@this") .. "_" end, expr = true, desc = "Send line to OpenCode" },

      -- C++ workflow prompts
      { "<leader>oe", send("Explain @this and its context"), mode = { "n", "x" }, desc = "Explain this" },
      { "<leader>or", send(P.cpp_review), mode = { "n", "x" }, desc = "C++ review this" },
      { "<leader>ob", send(P.fix_build), desc = "Fix build errors (@quickfix)" },
      { "<leader>oT", send(P.gtest), mode = { "n", "x" }, desc = "Write GoogleTests for this" },
      { "<leader>oc", send(P.cover_uncovered), desc = "Tests for uncovered lines" },
      { "<leader>op", send(P.optimize_hotspots), mode = { "n", "x" }, desc = "Optimize with perf hotspots" },

      -- git
      { "<leader>od", send(P.review_diff), desc = "Review uncommitted changes" },
      { "<leader>oB", send(P.review_branch), desc = "Review branch vs main" },
      { "<leader>om", function() require("util.ai_context").commit_message() end, desc = "Commit message" },

      -- sessions
      { "<leader>on", function() oc().command("session.new") end, desc = "New session" },
      { "<leader>oS", function() oc().command("session.select") end, desc = "Select session" },
      { "<leader>ou", function() oc().command("session.undo") end, desc = "Undo last action" },
      { "<leader>oU", function() oc().command("session.redo") end, desc = "Redo" },
      { "<leader>oi", function() oc().command("session.interrupt") end, desc = "Interrupt" },
    },
  },

  -- completions for @contexts inside the Ask input
  {
    "saghen/blink.cmp",
    optional = true,
    opts = { sources = { per_filetype = { opencode_ask = { "lsp", "buffer" } } } },
  },

  -- connected server + status in the statusline
  {
    "nvim-lualine/lualine.nvim",
    optional = true,
    opts = function(_, opts)
      table.insert(opts.sections.lualine_x, 1, {
        function()
          return require("opencode").statusline()
        end,
        cond = function()
          return package.loaded["opencode"] ~= nil
        end,
      })
    end,
  },

  {
    "folke/which-key.nvim",
    opts = { spec = { { "<leader>o", group = "opencode (AI)", icon = { icon = "󰚩 ", color = "purple" } } } },
  },
}
