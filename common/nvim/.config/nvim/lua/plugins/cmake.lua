-- cmake-tools.nvim: configure / build / run / debug CMake targets & presets
return {
  {
    "Civitasv/cmake-tools.nvim",
    opts = {
      cmake_command = "cmake",
      ctest_command = "ctest",
      cmake_use_preset = true, -- uses CMakePresets.json when present
      cmake_regenerate_on_save = true,
      cmake_generate_options = { "-DCMAKE_EXPORT_COMPILE_COMMANDS=1" },
      cmake_build_options = {},
      cmake_build_directory = "build/${variant:buildType}", -- used when there are no presets
      -- symlink compile_commands.json into the project root for clangd
      cmake_compile_commands_options = { action = "soft_link", target = vim.uv.cwd },
      -- :CMakeDebug starts the launch target under GDB (native DAP, gdb >= 14)
      cmake_dap_configuration = {
        name = "cpp (gdb)",
        type = "gdb",
        request = "launch",
        stopAtBeginningOfMainSubprogram = false,
      },
      cmake_executor = { name = "quickfix", opts = {} }, -- build output -> quickfix (errors jumpable)
      cmake_runner = { name = "terminal", opts = {} }, -- program output -> terminal
      cmake_virtual_text_support = true,
    },
    keys = {
      { "<leader>mg", "<cmd>CMakeGenerate<cr>", desc = "Generate (configure)" },
      { "<leader>mb", "<cmd>CMakeBuild<cr>", desc = "Build" },
      { "<leader>mB", "<cmd>CMakeBuild!<cr>", desc = "Clean + build" },
      { "<leader>mr", "<cmd>CMakeRun<cr>", desc = "Run launch target" },
      { "<leader>md", "<cmd>CMakeDebug<cr>", desc = "Debug launch target (gdb)" },
      { "<leader>ma", ":CMakeLaunchArgs ", desc = "Set launch args", silent = false },
      { "<leader>mt", "<cmd>CMakeSelectBuildTarget<cr>", desc = "Select build target" },
      { "<leader>ml", "<cmd>CMakeSelectLaunchTarget<cr>", desc = "Select launch target" },
      { "<leader>my", "<cmd>CMakeSelectBuildType<cr>", desc = "Select build type" },
      { "<leader>mp", "<cmd>CMakeSelectConfigurePreset<cr>", desc = "Select configure preset" },
      { "<leader>mP", "<cmd>CMakeSelectBuildPreset<cr>", desc = "Select build preset" },
      { "<leader>mT", "<cmd>CMakeRunTest<cr>", desc = "Run CTest" },
      { "<leader>mc", "<cmd>CMakeClean<cr>", desc = "Clean" },
      { "<leader>ms", "<cmd>CMakeTargetSettings<cr>", desc = "Target settings" },
      { "<leader>mS", "<cmd>CMakeSettings<cr>", desc = "Project settings" },
      { "<leader>mo", "<cmd>CMakeOpenExecutor<cr>", desc = "Open build output" },
      { "<leader>mq", "<cmd>CMakeStopExecutor<cr>", desc = "Stop build" },
    },
  },

  -- show preset / build type + launch target in the statusline
  {
    "nvim-lualine/lualine.nvim",
    optional = true,
    opts = function(_, opts)
      table.insert(opts.sections.lualine_x, 1, {
        function()
          local cmake = require("cmake-tools")
          local cfg = (cmake.has_cmake_preset and cmake.has_cmake_preset() and cmake.get_configure_preset())
            or (cmake.get_build_type and cmake.get_build_type())
            or "?"
          local target = cmake.get_launch_target and cmake.get_launch_target() or nil
          return (" %s%s"):format(cfg, target and ("  " .. target) or "")
        end,
        cond = function()
          local ok, cmake = pcall(require, "cmake-tools")
          return package.loaded["cmake-tools"] ~= nil and ok and cmake.is_cmake_project()
        end,
      })
    end,
  },
}
