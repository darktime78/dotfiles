-- Show gcov/gcovr (lcov) coverage of the GoogleTest run in the sign column
return {
  {
    "andythigpen/nvim-coverage",
    version = "*",
    dependencies = { "nvim-lua/plenary.nvim" },
    cmd = {
      "Coverage", "CoverageLoad", "CoverageLoadLcov", "CoverageShow", "CoverageHide",
      "CoverageToggle", "CoverageClear", "CoverageSummary",
    },
    opts = {
      commands = true,
      auto_reload = true,
      summary = { min_coverage = 80.0 },
      signs = {
        covered = { hl = "CoverageCovered", text = "▎" },
        uncovered = { hl = "CoverageUncovered", text = "▎" },
        partial = { hl = "CoveragePartial", text = "▎" },
      },
    },
    keys = {
      { "<leader>tC", function() require("util.coverage").run() end, desc = "Coverage: build + test + load" },
      { "<leader>tL", function() require("util.coverage").load() end, desc = "Coverage: load last report" },
      { "<leader>tc", "<cmd>CoverageToggle<cr>", desc = "Coverage: toggle signs" },
      { "<leader>tv", "<cmd>CoverageSummary<cr>", desc = "Coverage: summary" },
      { "<leader>tX", "<cmd>CoverageClear<cr>", desc = "Coverage: clear" },
    },
  },
}
