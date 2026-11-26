-- Git on top of LazyVim's defaults (gitsigns hunks, lazygit via Snacks, git pickers):
--   * diffview.nvim   : side-by-side diffs, file/line/repo history, 3-way merge tool, branch review
--   * git-conflict.nvim: pick ours/theirs/both in conflict markers
--   * gitsigns extras : inline blame + word diff toggles
return {
  {
    "lewis6991/gitsigns.nvim",
    opts = {
      current_line_blame = false,
      current_line_blame_opts = { delay = 400, virt_text_pos = "eol" },
      current_line_blame_formatter = "<author>, <author_time:%Y-%m-%d> · <summary>",
      preview_config = { border = "rounded" },
    },
    keys = {
      { "<leader>gT", function() require("gitsigns").toggle_current_line_blame() end, desc = "Toggle inline blame" },
      { "<leader>gW", function() require("gitsigns").toggle_word_diff() end, desc = "Toggle word diff" },
    },
  },

  {
    "sindrets/diffview.nvim",
    cmd = {
      "DiffviewOpen", "DiffviewClose", "DiffviewFileHistory", "DiffviewToggleFiles",
      "DiffviewFocusFiles", "DiffviewRefresh",
    },
    opts = {
      enhanced_diff_hl = true,
      view = {
        merge_tool = { layout = "diff3_mixed", disable_diagnostics = true },
      },
    },
    keys = {
      { "<leader>gv", "<cmd>DiffviewOpen<cr>", desc = "Diffview: working tree" },
      { "<leader>gV", "<cmd>DiffviewClose<cr>", desc = "Diffview: close" },
      { "<leader>gH", "<cmd>DiffviewFileHistory %<cr>", desc = "Diffview: file history" },
      { "<leader>gH", ":DiffviewFileHistory<cr>", mode = "x", desc = "Diffview: history of selected lines" },
      { "<leader>gR", "<cmd>DiffviewFileHistory<cr>", desc = "Diffview: repo history" },
      {
        "<leader>gM",
        function()
          vim.cmd("DiffviewOpen " .. require("util.ai_context").git_base() .. "...HEAD")
        end,
        desc = "Diffview: branch vs main (PR review)",
      },
    },
  },

  {
    "akinsho/git-conflict.nvim",
    version = "*",
    event = "LazyFile",
    -- in a conflicted file: co ours · ct theirs · cb both · c0 none · ]x / [x next / prev conflict
    opts = { default_mappings = true, disable_diagnostics = true },
    keys = {
      { "<leader>gx", "<cmd>GitConflictListQf<cr>", desc = "List conflicts (quickfix)" },
    },
  },
}
