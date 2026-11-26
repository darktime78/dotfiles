-- clangd + treesitter + mason tools for C/C++
return {
  {
    "nvim-treesitter/nvim-treesitter",
    opts = { ensure_installed = { "c", "cpp", "cmake", "make", "doxygen", "asm" } },
  },

  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        clangd = {
          cmd = {
            "clangd",
            "--background-index",
            "--clang-tidy",
            "--header-insertion=iwyu",
            "--completion-style=detailed",
            "--function-arg-placeholders",
            "--fallback-style=Google",
            "--pch-storage=memory",
          },
        },
      },
    },
  },

  {
    "mason-org/mason.nvim",
    opts = { ensure_installed = { "clangd", "clang-format", "cmakelang", "cmakelint" } },
  },

  {
    "folke/which-key.nvim",
    opts = {
      spec = {
        { "<leader>m", group = "cmake / make", icon = { icon = " ", color = "blue" } },
      },
    },
  },
}
