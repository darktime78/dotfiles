-- GoogleTest through neotest (LazyVim test.core gives the <leader>t… keys)
-- Tests need their executable: util/gtest.lua maps them automatically for built projects;
-- <leader>tg configures + builds + maps (also after adding test files).
return {
  {
    "nvim-neotest/neotest",
    dependencies = { "alfaix/neotest-gtest" },
    init = function()
      require("util.gtest").setup() -- first configure for clangd, auto-mapping of tests
      -- :GtestMissing [list|stubs|ai]: tests the coverage report says are missing
      vim.api.nvim_create_user_command("GtestMissing", function(o)
        require("util.missing_tests").run(o.args ~= "" and o.args or nil)
      end, {
        nargs = "?",
        desc = "Missing GoogleTest tests from coverage",
        complete = function()
          return { "list", "stubs", "ai" }
        end,
      })
    end,
    keys = {
      { "<leader>tg", function() require("util.gtest").setup_project() end, desc = "GoogleTest: configure + build + map tests" },
      { "<leader>tm", function() require("util.missing_tests").run() end, desc = "Missing tests (from coverage)" },
    },
    opts = function(_, opts)
      opts.adapters = opts.adapters or {}
      table.insert(
        opts.adapters,
        require("neotest-gtest").setup({
          debug_adapter = "gdb", -- <leader>td debugs the nearest TEST() in gdb
          history_size = 3,
          -- C in the summary window: pick the executable for the marked tests by hand
          -- (:ConfigureGtestAll there maps all of them through ctest)
          mappings = { configure = "C" },
        })
      )
    end,
  },
}
