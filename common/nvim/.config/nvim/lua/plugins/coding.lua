-- From craftzdog's coding.lua, tuned for C++
return {
  -- Rename with a live preview of every occurrence (clangd)
  {
    "smjonas/inc-rename.nvim",
    cmd = "IncRename",
    opts = {},
    keys = {
      {
        "<leader>rn",
        function()
          return ":IncRename " .. vim.fn.expand("<cword>")
        end,
        expr = true,
        desc = "Rename symbol (live preview)",
      },
    },
  },

  -- ]x / [x style motions. Targets that LazyVim, diff mode or git-conflict already
  -- own (buffer, comment ]c, conflict ]x, diagnostic ]d, file, quickfix ]q, window, yank) are off.
  {
    "nvim-mini/mini.bracketed",
    event = "BufReadPost",
    opts = {
      buffer = { suffix = "" },
      comment = { suffix = "" },
      conflict = { suffix = "" },
      diagnostic = { suffix = "" },
      file = { suffix = "" },
      quickfix = { suffix = "" },
      window = { suffix = "" },
      yank = { suffix = "" },
      indent = { suffix = "i" }, -- ]i [i  change of indent scope
      jump = { suffix = "j" }, -- ]j [j  jumplist inside the buffer
      location = { suffix = "l" }, -- ]l [l  location list
      oldfile = { suffix = "o" }, -- ]o [o  recently opened files
      treesitter = { suffix = "n" }, -- ]n [n  next / parent syntax node
      undo = { suffix = "u" }, -- ]u [u  undo states
    },
  },

  -- Smarter increment / decrement on + and - (craftzdog used these keys first)
  {
    "monaqa/dial.nvim",
    keys = {
      { "+", function() return require("dial.map").inc_normal() end, expr = true, desc = "Increment / toggle" },
      { "-", function() return require("dial.map").dec_normal() end, expr = true, desc = "Decrement / toggle" },
      { "+", function() return require("dial.map").inc_visual() end, mode = "x", expr = true, desc = "Increment" },
      { "-", function() return require("dial.map").dec_visual() end, mode = "x", expr = true, desc = "Decrement" },
      { "g+", function() return require("dial.map").inc_gvisual() end, mode = "x", expr = true, desc = "Increment sequence" },
    },
    config = function()
      local augend = require("dial.augend")
      local word = function(elements)
        return augend.constant.new({ elements = elements, word = true, cyclic = true })
      end
      local common = {
        augend.integer.alias.decimal_int,
        augend.integer.alias.hex,
        augend.integer.alias.binary,
        augend.constant.alias.bool,
        augend.semver.alias.semver,
        augend.date.alias["%Y-%m-%d"],
      }
      local config = require("dial.config")
      config.augends:register_group({ default = common })
      config.augends:on_filetype({
        cpp = vim.list_extend(vim.deepcopy(common), {
          word({ "public", "protected", "private" }),
          word({ "int8_t", "int16_t", "int32_t", "int64_t" }),
          word({ "uint8_t", "uint16_t", "uint32_t", "uint64_t" }),
          word({ "float", "double" }),
          word({ "unique_ptr", "shared_ptr", "weak_ptr" }),
          word({ "make_unique", "make_shared" }),
          word({ "EXPECT_EQ", "EXPECT_NE", "ASSERT_EQ", "ASSERT_NE" }),
          word({ "EXPECT_TRUE", "EXPECT_FALSE" }),
          word({ "TEST", "TEST_F" }),
          word({ "static_cast", "reinterpret_cast", "const_cast", "dynamic_cast" }),
          augend.constant.new({ elements = { "&&", "||" }, word = false, cyclic = true }),
          augend.constant.new({ elements = { "==", "!=" }, word = false, cyclic = true }),
        }),
        c = vim.list_extend(vim.deepcopy(common), {
          augend.constant.new({ elements = { "&&", "||" }, word = false, cyclic = true }),
        }),
        cmake = vim.list_extend(vim.deepcopy(common), {
          word({ "ON", "OFF" }),
          word({ "Debug", "Release", "RelWithDebInfo", "MinSizeRel" }),
          word({ "PUBLIC", "PRIVATE", "INTERFACE" }),
        }),
      })
    end,
  },

  -- clangd inlay hints (parameter names, deduced `auto` types) off by default like
  -- craftzdog; toggle with <leader>i
  {
    "neovim/nvim-lspconfig",
    opts = { inlay_hints = { enabled = false } },
  },
}
