-- Local Qwen servers of arch-local-ai: ports, up/down state, running `localai`.
-- Works the same on the host and in the nvim-cpp container: there `localai` is a small
-- client that runs the command on the host through localai-ctl.service.
local M = {}
local uv = vim.uv or vim.loop

-- ---------------------------------------------------------------- ports
local function conf_port(key, default)
  local f = io.open(vim.fn.expand("~/.config/localai/localai.conf"), "r")
  if not f then
    return default
  end
  local port = default
  for line in f:lines() do
    local v = line:match("^%s*" .. key .. "%s*=%s*[\"']?(%d+)")
    if v then
      port = tonumber(v)
    end
  end
  f:close()
  return port
end

-- LOCALAI_FIM_URL / LOCALAI_URL (set by the container) win over localai.conf
local function endpoint(env, key, default)
  local u = os.getenv(env)
  if u and u ~= "" then
    local host, port = u:match("^https?://([^:/]+):(%d+)")
    if host then
      return (host == "localhost" and "127.0.0.1" or host), tonumber(port)
    end
  end
  return "127.0.0.1", conf_port(key, default)
end

M.fim_host, M.fim_port = endpoint("LOCALAI_FIM_URL", "FIM_PORT", 8012)
M.router_host, M.router_port = endpoint("LOCALAI_URL", "ROUTER_PORT", 8080)
M.fim_url = ("http://%s:%d"):format(M.fim_host, M.fim_port)
M.router_url = ("http://%s:%d"):format(M.router_host, M.router_port)

-- ---------------------------------------------------------------- up / down
-- A TCP connect instead of curl: no process is started every few seconds.
M.state = { fim = false, router = false }

local function probe(host, port, cb)
  local tcp, timer = uv.new_tcp(), uv.new_timer()
  local done = false
  local function finish(ok)
    if done then
      return
    end
    done = true
    timer:stop()
    timer:close()
    if not tcp:is_closing() then
      tcp:close()
    end
    cb(ok)
  end
  timer:start(1000, 0, function()
    finish(false)
  end)
  local ok = pcall(tcp.connect, tcp, host, port, function(err)
    finish(err == nil)
  end)
  if not ok then
    finish(false)
  end
end

function M.refresh(cb)
  local pending = 2
  local function one(key, host, port)
    probe(host, port, function(up)
      M.state[key] = up
      pending = pending - 1
      if pending == 0 then
        vim.schedule(function()
          pcall(vim.cmd.redrawstatus)
          if cb then
            cb(M.state)
          end
        end)
      end
    end)
  end
  one("fim", M.fim_host, M.fim_port)
  one("router", M.router_host, M.router_port)
end

function M.start_polling(ms)
  if M._timer then
    return
  end
  M._timer = uv.new_timer()
  M._timer:start(0, ms or 15000, function()
    M.refresh()
  end)
end

-- statusline: 󰚩 fim● qwen●  green = both up, yellow = one, grey = none
function M.statusline()
  return ("󰚩 fim%s qwen%s"):format(M.state.fim and "●" or "○", M.state.router and "●" or "○")
end

function M.statusline_color()
  local n = (M.state.fim and 1 or 0) + (M.state.router and 1 or 0)
  return { fg = n == 2 and "#859900" or n == 1 and "#b58900" or "#586e75" }
end

-- ---------------------------------------------------------------- running localai
local function exe()
  if vim.fn.executable("localai") == 1 then
    return "localai"
  end
  local p = vim.fn.expand("~/.local/bin/localai")
  if vim.fn.executable(p) == 1 then
    return p
  end
  vim.notify("`localai` not found: install arch-local-ai on the host", vim.log.levels.ERROR, { title = "LocalAI" })
end

-- short commands (start, stop, load …): result as a notification
function M.run(args, on_exit)
  local bin = exe()
  if not bin then
    return
  end
  vim.system(vim.list_extend({ bin }, args), { text = true }, function(r)
    local out = vim.trim((r.stdout or "") .. "\n" .. (r.stderr or "")):gsub("\27%[[%d;]*m", "")
    vim.schedule(function()
      vim.notify(out ~= "" and out or ("localai " .. table.concat(args, " ")), r.code == 0 and vim.log.levels.INFO
        or vim.log.levels.WARN, { title = "LocalAI" })
      M.refresh()
      if on_exit then
        on_exit(r)
      end
    end)
  end)
end

-- long output (status, doctor, logs, bench): floating terminal, q closes it
function M.term(args)
  local bin = exe()
  if not bin then
    return
  end
  Snacks.terminal.open(vim.list_extend({ bin }, args), {
    auto_close = false,
    win = { style = "float", border = "rounded", title = " localai " .. table.concat(args, " ") .. " " },
  })
end

-- OpenCode needs the router: start the servers when it is down
function M.ensure_router()
  M.refresh(function(state)
    if not state.router then
      vim.notify("Router is down, starting the local servers…", vim.log.levels.INFO, { title = "LocalAI" })
      M.run({ "start" })
    end
  end)
end

-- ---------------------------------------------------------------- :LocalAI
local SUB = {
  status = {}, models = {}, devices = {}, doctor = {}, stop = {}, restart = {}, chat = {},
  start = { "dev", "battery" },
  load = { "qwen-agent", "qwen-chat", "qwen-code" },
  unload = { "qwen-agent", "qwen-chat", "qwen-code" },
  gpu = { "fim", "intel", "agent", "all", "off" },
  logs = { "router", "fim" },
  bench = { "agent", "chat", "fim" },
}
local QUICK = { start = true, stop = true, restart = true, load = true, unload = true, chat = true }

function M.command(args)
  if #args == 0 then
    args = { "status" }
  end
  if QUICK[args[1]] or (args[1] == "gpu" and args[2]) then
    M.run(args)
  else
    M.term(args)
  end
end

function M.setup()
  vim.api.nvim_create_user_command("LocalAI", function(o)
    M.command(o.fargs)
  end, {
    nargs = "*",
    desc = "Control the local Qwen servers (localai)",
    complete = function(lead, line)
      local words = vim.split(line, "%s+", { trimempty = true })
      local n = #words + (line:match("%s$") and 1 or 0)
      local list = n <= 2 and vim.tbl_keys(SUB) or (SUB[words[2]] or {})
      table.sort(list)
      return vim.tbl_filter(function(s)
        return s:find(lead, 1, true) == 1
      end, list)
    end,
  })
  M.start_polling(15000)
end

return M
