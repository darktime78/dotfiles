-- GoogleTest through neotest (LazyVim test.core gives the <leader>t… keys)
-- Tests need their executable: util/gtest.lua maps them automatically for built projects;
-- <leader>tg configures + builds + maps (also after adding test files).
return {
  {
    "nvim-neotest/neotest",
    dependencies = { "alfaix/neotest-gtest" },
    init = function()
      require("util.gtest").setup() -- first configure for clangd, auto-mapping of tests
    end,
    keys = {
      { "<leader>tg", function() require("util.gtest").setup_project() end, desc = "GoogleTest: configure + build + map tests" },
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
