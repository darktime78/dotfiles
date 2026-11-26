-- Classic gdb-dashboard workflow inside Neovim:
--   ┌──────────────────────────────────────────┐
--   │ dashboard: registers, stack, source, asm │  <- terminal whose pty receives
--   │ variables, expressions, threads …        │     `dashboard -output <pty>`
--   ├──────────────────────────────────────────┤
--   │ (gdb) prompt                             │  <- interactive gdb
--   └──────────────────────────────────────────┘
-- Requires https://github.com/cyrus-and/gdb-dashboard installed as ~/.gdbinit
local M = {}

local function open_term(cmd, opts)
  opts = opts or {}
  if vim.fn.has("nvim-0.11") == 1 then
    opts.term = true
    return vim.fn.jobstart(cmd, opts)
  end
  return vim.fn.termopen(cmd, opts)
end

-- Copy nvim-dap breakpoints into gdb `-ex "break file:line [if cond]"` args
local function breakpoint_args()
  local args = {}
  if not package.loaded["dap"] then
    return args
  end
  local ok, bps = pcall(require, "dap.breakpoints")
  if not ok then
    return args
  end
  for bufnr, list in pairs(bps.get()) do
    local file = vim.api.nvim_buf_get_name(bufnr)
    for _, bp in ipairs(list) do
      local cmd = ("break %s:%d"):format(file, bp.line)
      if bp.condition and bp.condition ~= "" then
        cmd = cmd .. " if " .. bp.condition
      end
      vim.list_extend(args, { "-ex", cmd })
    end
  end
  return args
end

function M.open(opts)
  opts = opts or {}
  if vim.fn.executable("gdb") == 0 then
    vim.notify("gdb not found in $PATH", vim.log.levels.ERROR)
    return
  end
  local program = opts.program or require("util.target").program_path()
  if not program then
    return
  end

  vim.cmd("tabnew")
  local tab = vim.api.nvim_get_current_tabpage()

  -- 1) dashboard pane: an idle process whose pty gdb-dashboard writes into
  local dash_job = open_term({ "sh", "-c", "while :; do sleep 3600; done" })
  local pty = vim.api.nvim_get_chan_info(dash_job).pty

  -- 2) gdb pane
  local gdb_cmd = { "gdb", "-q" }
  if pty then
    vim.list_extend(gdb_cmd, { "-ex", "dashboard -output " .. pty })
  end
  vim.list_extend(gdb_cmd, breakpoint_args())
  if opts.run then
    vim.list_extend(gdb_cmd, { "-ex", "run" })
  end
  vim.list_extend(gdb_cmd, { "--args", program })
  vim.list_extend(gdb_cmd, opts.args or {})

  vim.cmd("botright 15split")
  vim.cmd("enew")
  open_term(gdb_cmd, {
    on_exit = function()
      pcall(vim.fn.jobstop, dash_job)
      vim.schedule(function()
        if vim.api.nvim_tabpage_is_valid(tab) then
          pcall(vim.cmd, vim.api.nvim_tabpage_get_number(tab) .. "tabclose")
        end
      end)
    end,
  })
  vim.cmd("startinsert")
end

return M
