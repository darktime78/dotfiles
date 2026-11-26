-- Debugging with GDB's native DAP (gdb >= 14):
--   * breakpoints in the source (F9 / <leader>db, conditional <leader>dB)
--   * dap-ui: Scopes (Locals + *Registers* from gdb), Call stack, Watches,
--     Breakpoints, REPL (accepts raw gdb commands), program console, Disassembly
--   * :GdbDashboard -> classic gdb-dashboard in a terminal tab
local function program()
  return require("util.target").program_path() or require("dap").ABORT
end

local function cwd()
  return "${workspaceFolder}"
end

return {
  {
    "mfussenegger/nvim-dap",
    opts = function()
      local dap = require("dap")

      dap.adapters.gdb = {
        type = "executable",
        command = "gdb",
        -- -nh: skip ~/.gdbinit so gdb-dashboard does not write into the DAP stream
        args = { "--interpreter=dap", "-q", "-nh", "--eval-command", "set print pretty on" },
      }

      local gdb_configs = {
        {
          name = "GDB: Launch (CMake launch target)",
          type = "gdb",
          request = "launch",
          program = program,
          args = {},
          cwd = cwd(),
          stopAtBeginningOfMainSubprogram = false,
        },
        {
          name = "GDB: Launch with arguments",
          type = "gdb",
          request = "launch",
          program = program,
          args = function()
            return vim.split(vim.fn.input("Arguments: "), "%s+", { trimempty = true })
          end,
          cwd = cwd(),
        },
        {
          name = "GDB: Launch and stop at main",
          type = "gdb",
          request = "launch",
          program = program,
          cwd = cwd(),
          stopAtBeginningOfMainSubprogram = true,
        },
        {
          name = "GDB: Attach to process",
          type = "gdb",
          request = "attach",
          pid = function()
            return require("dap.utils").pick_process()
          end,
          cwd = cwd(),
        },
        {
          name = "GDB: Attach to gdbserver :1234",
          type = "gdb",
          request = "attach",
          target = "localhost:1234",
          program = program,
          cwd = cwd(),
        },
      }

      -- GDB configs first; keep codelldb configs from the clangd extra after them
      for _, lang in ipairs({ "c", "cpp" }) do
        dap.configurations[lang] = vim.list_extend(vim.deepcopy(gdb_configs), dap.configurations[lang] or {})
      end
    end,
    keys = {
      -- Visual Studio / CLion style function keys
      { "<F5>", function() require("dap").continue() end, desc = "Debug: Start / Continue" },
      { "<S-F5>", function() require("dap").terminate() end, desc = "Debug: Stop" },
      { "<F17>", function() require("dap").terminate() end, desc = "Debug: Stop (S-F5)" },
      { "<F9>", function() require("dap").toggle_breakpoint() end, desc = "Debug: Toggle breakpoint" },
      { "<F10>", function() require("dap").step_over() end, desc = "Debug: Step over" },
      { "<F11>", function() require("dap").step_into() end, desc = "Debug: Step into" },
      { "<F12>", function() require("dap").step_out() end, desc = "Debug: Step out" },

      -- raw gdb views, printed into the dap-ui REPL
      { "<leader>dR", function() require("dap").repl.execute("info registers") end, desc = "GDB: registers" },
      { "<leader>dS", function() require("dap").repl.execute("bt") end, desc = "GDB: backtrace" },
      {
        "<leader>dM",
        function()
          local addr = vim.fn.input("Examine memory at: ", "$sp")
          if addr ~= "" then
            require("dap").repl.execute("x/32xb " .. addr)
          end
        end,
        desc = "GDB: examine memory",
      },
      { "<leader>dD", "<cmd>DapDisasm<cr>", desc = "Disassembly view" },
      { "<leader>dG", "<cmd>GdbDashboard<cr>", desc = "gdb-dashboard (terminal tab)" },
      {
        "<leader>dF",
        function()
          require("dapui").float_element("scopes", { enter = true, width = 90, height = 40 })
        end,
        desc = "Float scopes (locals + registers)",
      },
    },
  },

  {
    "rcarriga/nvim-dap-ui",
    dependencies = {
      "nvim-neotest/nvim-nio",
      { url = "https://codeberg.org/Jorenar/nvim-dap-disasm.git", name = "nvim-dap-disasm" },
    },
    opts = {
      floating = { border = "rounded" },
      controls = { enabled = true, element = "repl" },
      layouts = {
        {
          position = "left",
          size = 50,
          elements = {
            { id = "scopes", size = 0.50 }, -- Locals + Registers (gdb)
            { id = "stacks", size = 0.25 }, -- call stack / threads
            { id = "watches", size = 0.15 },
            { id = "breakpoints", size = 0.10 },
          },
        },
        {
          position = "bottom",
          size = 14,
          elements = {
            { id = "repl", size = 0.35 }, -- type gdb commands here: x/8xg $sp, info frame …
            { id = "console", size = 0.25 },
            { id = "disassembly", size = 0.40 },
          },
        },
      },
    },
    config = function(_, opts)
      local dap, dapui = require("dap"), require("dapui")

      local ok_disasm, disasm = pcall(require, "dap-disasm")
      if not ok_disasm then
        ok_disasm, disasm = pcall(require, "nvim-dap-disasm")
      end
      if not ok_disasm then
        for _, layout in ipairs(opts.layouts) do
          layout.elements = vim.tbl_filter(function(e)
            return e.id ~= "disassembly"
          end, layout.elements)
        end
      end

      dapui.setup(opts)
      if ok_disasm then
        -- must be set up after dap-ui so it can register its element
        disasm.setup({ dapui_register = true, dapview_register = false, repl_commands = true })
      end

      dap.listeners.after.event_initialized["dapui_config"] = function()
        dapui.open({})
      end
      dap.listeners.before.event_terminated["dapui_config"] = function()
        dapui.close({})
      end
      dap.listeners.before.event_exited["dapui_config"] = function()
        dapui.close({})
      end
    end,
  },
}
