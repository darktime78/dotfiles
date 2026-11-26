-- Load our Lua snippets from ~/.config/nvim/luasnippets/<filetype>.lua
return {
  {
    "L3MON4D3/LuaSnip",
    config = function(_, opts)
      local ls = require("luasnip")
      ls.setup(opts)
      require("luasnip.loaders.from_lua").lazy_load({
        paths = { vim.fn.stdpath("config") .. "/luasnippets" },
      })

      -- cycle choice nodes with <C-l> (capture list, typename/class, lambda specifiers …)
      vim.keymap.set({ "i", "s" }, "<C-l>", function()
        if ls.choice_active() then
          ls.change_choice(1)
        end
      end, { desc = "Snippet: next choice" })
    end,
  },
}
