-- GoogleTest through neotest (LazyVim test.core gives the <leader>t… keys)
return {
  {
    "nvim-neotest/neotest",
    dependencies = { "alfaix/neotest-gtest" },
    opts = function(_, opts)
      opts.adapters = opts.adapters or {}
      table.insert(
        opts.adapters,
        require("neotest-gtest").setup({
          debug_adapter = "gdb", -- <leader>td debugs the nearest TEST() in gdb
          history_size = 3,
        })
      )
    end,
  },
}
