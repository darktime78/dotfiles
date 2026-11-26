-- Run a shell command asynchronously and report the result with vim.notify
local M = {}

function M.shell(cmd, title, on_success, filter)
  vim.notify(title .. " …", vim.log.levels.INFO, { title = title })
  vim.system({ "sh", "-c", cmd }, { cwd = vim.uv.cwd(), text = true }, function(res)
    vim.schedule(function()
      local out = vim.trim((res.stdout or "") .. "\n" .. (res.stderr or ""))
      if res.code == 0 then
        local msg = filter and filter(out) or out
        vim.notify(msg ~= "" and msg or "done", vim.log.levels.INFO, { title = title })
        if on_success then
          on_success(res)
        end
      else
        vim.notify(out, vim.log.levels.ERROR, { title = title .. " failed" })
      end
    end)
  end)
end

return M
