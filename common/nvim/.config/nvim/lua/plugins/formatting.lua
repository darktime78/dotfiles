-- conform.nvim: format on save
--   C / C++  -> clang-format  (uses the nearest .clang-format)
--   CMake    -> cmake-format  (cmakelang, uses .cmake-format.yaml)
--   Makefile -> mbake         (pipx install mbake)
return {
  {
    "stevearc/conform.nvim",
    opts = {
      formatters_by_ft = {
        c = { "clang-format" },
        cpp = { "clang-format" },
        cmake = { "cmake_format" },
        make = { "bake" },
      },
      formatters = {
        ["clang-format"] = { prepend_args = { "--fallback-style=Google" } },
      },
    },
  },
}
