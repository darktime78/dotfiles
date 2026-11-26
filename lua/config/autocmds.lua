local au = vim.api.nvim_create_autocmd

au("FileType", {
  pattern = { "c", "cpp" },
  callback = function()
    vim.opt_local.shiftwidth = 4
    vim.opt_local.tabstop = 4
    vim.opt_local.softtabstop = 4
    vim.opt_local.commentstring = "// %s"
  end,
})

-- Makefiles need real tabs
au("FileType", {
  pattern = "make",
  callback = function()
    vim.opt_local.expandtab = false
  end,
})

-- :GdbDashboard[!] [args]  -> classic gdb + gdb-dashboard in a new tab
-- (!) starts the program immediately; nvim-dap breakpoints are copied over.
vim.api.nvim_create_user_command("GdbDashboard", function(cmd)
  require("util.gdb_dashboard").open({ run = cmd.bang, args = cmd.fargs })
end, { bang = true, nargs = "*", desc = "gdb + gdb-dashboard in a terminal tab" })

-- In a commit message buffer: <localleader>m lets OpenCode write the message from the staged diff
au("FileType", {
  pattern = "gitcommit",
  callback = function(ev)
    vim.keymap.set("n", "<localleader>m", function()
      require("util.ai_context").commit_message(ev.buf)
    end, { buffer = ev.buf, desc = "OpenCode: write commit message" })
  end,
})
