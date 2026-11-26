-- craftzdog's "cowboy" habit breaker: holding h/j/k/l more than 10 times in a row
-- warns you to use a real motion (w, }, f, ;s, flash `s`, relative numbers …).
-- Enable with vim.g.cowboy = true in lua/config/options.lua.
local M = {}

function M.cowboy()
  for _, key in ipairs({ "h", "j", "k", "l" }) do
    local count = 0
    local plain = (key == "j" or key == "k") and ("g" .. key) or key -- keep LazyVim's wrapped-line moves
    local timer = assert(vim.uv.new_timer())
    vim.keymap.set("n", key, function()
      if vim.v.count > 0 then
        count = 0
      end
      if count >= 10 and vim.bo.buftype ~= "nofile" then
        local ok = pcall(vim.notify, "Hold it Cowboy!", vim.log.levels.WARN, {
          icon = "🤠",
          id = "cowboy",
          keep = function()
            return count >= 10
          end,
        })
        if not ok then
          return plain
        end
      else
        count = count + 1
        timer:start(2000, 0, function()
          count = 0
        end)
        return vim.v.count > 0 and key or plain
      end
    end, { expr = true, silent = true })
  end
end

return M
