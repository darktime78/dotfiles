-- perf profiling for C/C++ in Neovim
--
--   record  : perf record -F <freq> --call-graph <mode> -- <launch target> [args]
--   collapse: perf script | inferno-collapse-perf --all   (or stackcollapse-perf.pl)
--   filter  : process / focus / include / exclude / hide-frames / kernel / recursion
--   render  : inferno-flamegraph (or flamegraph.pl) -> SVG opened in the browser
--   report  : hotspot table (self % / total %) with hot/warm highlighting
--   diff    : perf.data.old vs perf.data -> differential flamegraph
local M = {}

local uv = vim.uv or vim.loop
local INFO, WARN, ERROR = vim.log.levels.INFO, vim.log.levels.WARN, vim.log.levels.ERROR

M.state = { filters = nil, last_args = "", sort = "self", rows = {}, total = 0, raw = 0, header = 0 }

M.DEFAULTS = {
  process = "", -- regex on the process (first frame), e.g. ^demo_app$
  focus = "", -- re-root every stack at the first frame matching this
  include = "", -- keep only stacks matching (after the steps above)
  exclude = "", -- drop stacks matching
  hide = "", -- remove frames matching; their time goes to the caller
  hide_kernel = true, -- drop "_[k]" frames
  merge_recursion = false, -- f;f;f -> f
  reverse = false, -- leaf -> root (merges by hottest leaf)
  inverted = false, -- icicle layout
  minwidth = 0.1, -- flamegraph: omit frames narrower than this (px)
  colors = "hot", -- flamegraph palette
  min_percent = 0.5, -- hotspot table: hide functions below this %
}

local function notify(msg, level)
  vim.notify(msg, level or INFO, { title = "perf" })
end

local function root()
  return uv.cwd()
end

local function perf_dir()
  return vim.fs.joinpath(root(), vim.g.perf_dir or "build/perf")
end

local function out(name)
  return vim.fs.joinpath(perf_dir(), name)
end

function M.data_file()
  return vim.fs.joinpath(root(), "perf.data") -- perf's default, so perfanno finds it too
end

local function signature(p)
  local st = uv.fs_stat(p)
  return st and ("%d:%d:%d"):format(st.mtime.sec, st.mtime.nsec, st.size) or nil
end

local function open_term(cmd, opts)
  opts = opts or {}
  if vim.fn.has("nvim-0.11") == 1 then
    opts.term = true
    return vim.fn.jobstart(cmd, opts)
  end
  return vim.fn.termopen(cmd, opts)
end

---------------------------------------------------------------------------
-- filters (persisted in build/perf/filters.json)
---------------------------------------------------------------------------
function M.filters()
  if not M.state.filters then
    local f = vim.deepcopy(M.DEFAULTS)
    local p = out("filters.json")
    if uv.fs_stat(p) then
      local ok, saved = pcall(vim.json.decode, table.concat(vim.fn.readfile(p), "\n"))
      if ok and type(saved) == "table" then
        f = vim.tbl_extend("force", f, saved)
      end
    end
    M.state.filters = f
  end
  return M.state.filters
end

local function save_filters()
  vim.fn.mkdir(perf_dir(), "p")
  vim.fn.writefile({ vim.json.encode(M.filters()) }, out("filters.json"))
end

local function rx(pattern)
  if pattern == nil or pattern == "" then
    return nil
  end
  local ok, r = pcall(vim.regex, "\\v" .. pattern)
  if not ok then
    notify("Invalid regex: " .. pattern, ERROR)
    return false
  end
  return r
end

local function hit(r, s)
  return r and r:match_str(s) ~= nil
end

local function summary(f)
  local parts = {}
  for _, k in ipairs({ "process", "focus", "include", "exclude", "hide" }) do
    if f[k] ~= "" then
      parts[#parts + 1] = k .. "=" .. f[k]
    end
  end
  if f.hide_kernel then
    parts[#parts + 1] = "no-kernel"
  end
  if f.merge_recursion then
    parts[#parts + 1] = "merge-recursion"
  end
  return #parts > 0 and table.concat(parts, "  ") or "no filters"
end

--- Apply filters to collapsed ("folded") stacks.
--- @return table<string, integer>|nil map stack -> samples, integer kept, integer total
function M.apply_filters(lines, f)
  local r = {
    process = rx(f.process),
    focus = rx(f.focus),
    include = rx(f.include),
    exclude = rx(f.exclude),
    hide = rx(f.hide),
  }
  for _, v in pairs(r) do
    if v == false then
      return nil
    end
  end

  local result, kept, total = {}, 0, 0
  for _, line in ipairs(lines) do
    local stack, count = line:match("^(.*) (%d+)$")
    if stack then
      count = tonumber(count)
      total = total + count
      local frames = vim.split(stack, ";", { plain = true })
      local keep = (r.process == nil) or hit(r.process, frames[1])

      if keep and f.hide_kernel then
        frames = vim.tbl_filter(function(fr)
          return not fr:find("_[k]", 1, true)
        end, frames)
        keep = #frames > 0
      end

      if keep and r.focus then
        local idx
        for k, fr in ipairs(frames) do
          if hit(r.focus, fr) then
            idx = k
            break
          end
        end
        if idx then
          frames = vim.list_slice(frames, idx)
        else
          keep = false
        end
      end

      if keep and r.hide then
        local visible = vim.tbl_filter(function(fr)
          return not hit(r.hide, fr)
        end, frames)
        frames = #visible > 0 and visible or { "[hidden]" }
      end

      if keep and f.merge_recursion then
        local merged = {}
        for _, fr in ipairs(frames) do
          if merged[#merged] ~= fr then
            merged[#merged + 1] = fr
          end
        end
        frames = merged
      end

      if keep then
        local joined = table.concat(frames, ";")
        if r.include and not hit(r.include, joined) then
          keep = false
        elseif r.exclude and hit(r.exclude, joined) then
          keep = false
        end
        if keep then
          result[joined] = (result[joined] or 0) + count
          kept = kept + count
        end
      end
    end
  end
  return result, kept, total
end

local function to_lines(map)
  local keys = vim.tbl_keys(map)
  table.sort(keys)
  local lines = {}
  for _, k in ipairs(keys) do
    lines[#lines + 1] = k .. " " .. map[k]
  end
  return lines
end

---------------------------------------------------------------------------
-- external tools
---------------------------------------------------------------------------
local function find_tool(names)
  local dir = vim.g.flamegraph_dir and vim.fn.expand(vim.g.flamegraph_dir) or nil
  for _, n in ipairs(names) do
    if dir and vim.fn.executable(dir .. "/" .. n) == 1 then
      return dir .. "/" .. n
    end
    if vim.fn.executable(n) == 1 then
      return n
    end
  end
end

local function tools()
  local t = {
    collapse = find_tool({ "inferno-collapse-perf", "stackcollapse-perf.pl" }),
    flame = find_tool({ "inferno-flamegraph", "flamegraph.pl" }),
    diff = find_tool({ "inferno-diff-folded", "difffolded.pl" }),
  }
  if not (t.collapse and t.flame) then
    notify(
      "Flamegraph tools not found: `cargo install inferno`, or clone brendangregg/FlameGraph "
        .. "and set vim.g.flamegraph_dir",
      ERROR
    )
    return nil
  end
  return t
end

-- perf.data -> folded stacks, cached until perf.data changes
local function ensure_folded(data, folded, cb)
  local sig = signature(data)
  if not sig then
    notify("No " .. vim.fs.basename(data) .. " yet. Record first (<leader>pr).", WARN)
    return
  end
  local sig_file = folded .. ".sig"
  if uv.fs_stat(folded) and uv.fs_stat(sig_file) and vim.fn.readfile(sig_file)[1] == sig then
    return cb(folded)
  end
  local t = tools()
  if not t then
    return
  end
  vim.fn.mkdir(perf_dir(), "p")
  notify("Collapsing stacks of " .. vim.fs.basename(data) .. " …")
  local cmd = ("perf script -i %s 2>/dev/null | %s --all > %s"):format(
    vim.fn.shellescape(data),
    vim.fn.shellescape(t.collapse),
    vim.fn.shellescape(folded)
  )
  vim.system({ "sh", "-c", cmd }, { text = true }, function(res)
    vim.schedule(function()
      local st = uv.fs_stat(folded)
      if res.code ~= 0 or not st or st.size == 0 then
        notify("Stack collapse failed:\n" .. (res.stderr or ""), ERROR)
        return
      end
      vim.fn.writefile({ sig }, sig_file)
      cb(folded)
    end)
  end)
end

local function render(folded_text, svg, title, subtitle, f)
  local t = tools()
  if not t then
    return
  end
  local argv = {
    t.flame, "--title", title, "--subtitle", subtitle,
    "--colors", f.colors, "--minwidth", tostring(f.minwidth), "--hash",
  }
  if f.reverse then
    argv[#argv + 1] = "--reverse"
  end
  if f.inverted then
    argv[#argv + 1] = "--inverted"
  end
  vim.system(argv, { stdin = folded_text, text = true }, function(res)
    vim.schedule(function()
      if res.code ~= 0 or (res.stdout or "") == "" then
        notify("Flamegraph rendering failed:\n" .. (res.stderr or ""), ERROR)
        return
      end
      local fd = assert(io.open(svg, "w"))
      fd:write(res.stdout)
      fd:close()
      notify("Flamegraph written: " .. svg)
      if vim.g.perf_open_svg ~= false then
        vim.ui.open(svg)
      end
    end)
  end)
end

local function load_filtered(data, folded, cb)
  ensure_folded(data, folded, function(path)
    local f = M.filters()
    local map, kept, total = M.apply_filters(vim.fn.readfile(path), f)
    if not map then
      return
    end
    if kept == 0 then
      notify("The current filters removed every sample (" .. summary(f) .. ")", WARN)
      return
    end
    cb(map, kept, total, f)
  end)
end

---------------------------------------------------------------------------
-- public actions
---------------------------------------------------------------------------
function M.record(args, opts)
  opts = opts or {}
  if vim.fn.executable("perf") == 0 then
    notify("`perf` not found in $PATH", ERROR)
    return
  end
  local argv = {
    "perf", "record",
    "-F", tostring(vim.g.perf_frequency or 499),
    "--call-graph", vim.g.perf_call_graph or "dwarf",
    "-o", M.data_file(),
  }
  if opts.pid then
    vim.list_extend(argv, { "-p", tostring(opts.pid), "--", "sleep", tostring(opts.seconds or 10) })
  else
    local program = require("util.target").program_path()
    if not program then
      return
    end
    vim.list_extend(argv, { "--", program })
    vim.list_extend(argv, vim.split(args or "", "%s+", { trimempty = true }))
  end

  local before = signature(M.data_file())
  vim.cmd("botright 12split")
  vim.cmd("enew")
  open_term(argv, {
    cwd = root(),
    on_exit = function(_, code)
      vim.schedule(function()
        M.after_record(code, before)
      end)
    end,
  })
  vim.cmd("startinsert")
end

function M.after_record(code, before)
  local now = signature(M.data_file())
  if not now or now == before then
    notify(
      ("perf record produced no data (exit %d).\nCheck `sysctl kernel.perf_event_paranoid` (needs <= 2)."):format(code),
      ERROR
    )
    return
  end
  notify(("perf.data recorded (exit %d)\n<leader>ph hotspots · <leader>pf flamegraph · <leader>pl annotate source"):format(code))
  local after = vim.g.perf_after_record
  if after == nil then
    after = "hotspots"
  end
  if after == "hotspots" then
    M.hotspots()
  elseif after == "flamegraph" then
    M.flamegraph()
  elseif after == "annotate" then
    vim.cmd("PerfLoadCallGraph")
  end
end

function M.record_prompt()
  vim.ui.input({ prompt = "perf record — program arguments: ", default = M.state.last_args }, function(v)
    if v == nil then
      return
    end
    M.state.last_args = v
    M.record(v)
  end)
end

function M.attach_prompt()
  local default = ""
  local ok, cmake = pcall(require, "cmake-tools")
  if ok and cmake.is_cmake_project() then
    local ok_t, target = pcall(cmake.get_launch_target)
    if ok_t and target then
      local res = vim.system({ "pgrep", "-n", target:sub(1, 15) }, { text = true }):wait()
      default = vim.trim(res.stdout or "")
    end
  end
  vim.ui.input({ prompt = "PID to profile: ", default = default }, function(pid)
    if not pid or pid == "" then
      return
    end
    vim.ui.input({ prompt = "Seconds: ", default = "10" }, function(sec)
      if not sec then
        return
      end
      M.record(nil, { pid = tonumber(pid), seconds = tonumber(sec) or 10 })
    end)
  end)
end

--- opts.hot_leaves: reversed icicle graph (hottest leaf functions on top)
function M.flamegraph(opts)
  opts = opts or {}
  load_filtered(M.data_file(), out("perf.folded"), function(map, kept, total, f)
    local lines = to_lines(map)
    vim.fn.writefile(lines, out("perf.filtered.folded"))
    local rf = vim.deepcopy(f)
    if opts.hot_leaves then
      rf.reverse, rf.inverted = true, true
    end
    render(
      table.concat(lines, "\n") .. "\n",
      out(opts.hot_leaves and "hot-leaves.svg" or "flamegraph.svg"),
      (opts.hot_leaves and "Hot leaves — " or "Flame graph — ") .. vim.fs.basename(root()),
      ("%s  |  %.1f%% of %d samples"):format(summary(f), 100 * kept / total, total),
      rf
    )
  end)
end

--- Differential flamegraph: perf.data.old (previous recording) -> perf.data
--- red = more samples now, blue = fewer
function M.diff()
  local t = tools()
  if not t then
    return
  end
  if not t.diff then
    notify("inferno-diff-folded / difffolded.pl not found", ERROR)
    return
  end
  load_filtered(M.data_file() .. ".old", out("perf.old.folded"), function(old_map)
    load_filtered(M.data_file(), out("perf.folded"), function(new_map, _, _, f)
      local a, b = out("perf.old.filtered.folded"), out("perf.filtered.folded")
      vim.fn.writefile(to_lines(old_map), a)
      vim.fn.writefile(to_lines(new_map), b)
      vim.system({ t.diff, a, b }, { text = true }, function(res)
        vim.schedule(function()
          if res.code ~= 0 then
            notify("Diff failed:\n" .. (res.stderr or ""), ERROR)
            return
          end
          render(res.stdout, out("diff.svg"), "Diff: previous → current recording",
            "red = more samples, blue = fewer  |  " .. summary(f), f)
        end)
      end)
    end)
  end)
end

---------------------------------------------------------------------------
-- hotspot table
---------------------------------------------------------------------------
local ns = vim.api.nvim_create_namespace("perf_hotspots")

function M.hotspots()
  load_filtered(M.data_file(), out("perf.folded"), function(map, kept, total, f)
    local self_, incl = {}, {}
    for stack, count in pairs(map) do
      local frames = vim.split(stack, ";", { plain = true })
      local leaf = frames[#frames]
      self_[leaf] = (self_[leaf] or 0) + count
      local seen = {}
      for _, fr in ipairs(frames) do
        if not seen[fr] then
          seen[fr] = true
          incl[fr] = (incl[fr] or 0) + count
        end
      end
    end
    local rows = {}
    for name, inc in pairs(incl) do
      local s = self_[name] or 0
      local sp, tp = 100 * s / kept, 100 * inc / kept
      if math.max(sp, tp) >= (f.min_percent or 0) then
        rows[#rows + 1] = { name = name, self = s, total = inc, self_pct = sp, total_pct = tp }
      end
    end
    M.state.rows, M.state.total, M.state.raw = rows, kept, total
    M.show_hotspots()
  end)
end

function M.goto_symbol(name)
  local q = name:gsub("_%[%a%]$", "")
  q = q:gsub("%(.*$", "")
  q = q:gsub("%b<>", "")
  q = q:match("([%w_~]+)$") or q
  local win = M.state.origin
  if win and vim.api.nvim_win_is_valid(win) then
    vim.api.nvim_set_current_win(win)
  else
    vim.cmd("wincmd p")
  end
  if #vim.lsp.get_clients({ bufnr = 0 }) > 0 then
    vim.lsp.buf.workspace_symbol(q)
  else
    vim.cmd("silent grep! -w " .. vim.fn.shellescape(q))
    vim.cmd("copen")
  end
end

function M.show_hotspots()
  local rows = M.state.rows or {}
  local key = M.state.sort
  table.sort(rows, function(a, b)
    if a[key] ~= b[key] then
      return a[key] > b[key]
    end
    return a.name < b.name
  end)

  local f = M.filters()
  local hot, warm = vim.g.perf_hot_percent or 5, vim.g.perf_warm_percent or 1
  local lines = {
    ("perf hotspots — %d of %d samples (%.1f%%), sorted by %s"):format(
      M.state.total, M.state.raw, M.state.raw > 0 and 100 * M.state.total / M.state.raw or 0, key),
    "filters: " .. summary(f),
    "<CR> symbol · a ask AI · s/t sort · f filters · F flamegraph · H hot leaves · r refresh · q close",
    "",
    ("%8s  %8s  %10s  %s"):format("self", "total", "self smp", "function"),
  }
  local header = #lines
  for _, r in ipairs(rows) do
    lines[#lines + 1] = ("%7.2f%%  %7.2f%%  %10d  %s"):format(r.self_pct, r.total_pct, r.self, r.name)
  end

  local buf = M.state.buf
  if not (buf and vim.api.nvim_buf_is_valid(buf)) then
    buf = vim.api.nvim_create_buf(false, true)
    M.state.buf = buf
    vim.bo[buf].bufhidden = "hide"
    vim.bo[buf].filetype = "perfhotspots"
    pcall(vim.api.nvim_buf_set_name, buf, "perf://hotspots")
    local function bmap(lhs, fn, desc)
      vim.keymap.set("n", lhs, fn, { buffer = buf, nowait = true, silent = true, desc = desc })
    end
    bmap("q", function() vim.cmd("close") end, "Close")
    bmap("s", function() M.state.sort = "self"; M.show_hotspots() end, "Sort by self")
    bmap("t", function() M.state.sort = "total"; M.show_hotspots() end, "Sort by total")
    bmap("r", M.hotspots, "Refresh")
    bmap("f", M.filter_menu, "Filters")
    bmap("F", function() M.flamegraph() end, "Flamegraph")
    bmap("H", function() M.flamegraph({ hot_leaves = true }) end, "Hot leaves")
    bmap("a", function()
      local row = M.state.rows[vim.api.nvim_win_get_cursor(0)[1] - M.state.header]
      local ok, opencode = pcall(require, "opencode")
      if not (row and ok) then
        return
      end
      opencode.prompt(("`%s` takes %.1f%% self / %.1f%% total CPU in this profile: @hotspots "
        .. "Find it in the code, explain why it is slow and propose a faster implementation that "
        .. "keeps the tests passing."):format(row.name, row.self_pct, row.total_pct))
    end, "Ask OpenCode to optimize")
    bmap("<CR>", function()
      local row = M.state.rows[vim.api.nvim_win_get_cursor(0)[1] - M.state.header]
      if row then
        M.goto_symbol(row.name)
      end
    end, "Go to symbol")
  end

  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
  M.state.header = header

  vim.api.nvim_buf_clear_namespace(buf, ns, 0, -1)
  vim.api.nvim_buf_set_extmark(buf, ns, 0, 0, { line_hl_group = "Title" })
  vim.api.nvim_buf_set_extmark(buf, ns, 1, 0, { line_hl_group = "Comment" })
  vim.api.nvim_buf_set_extmark(buf, ns, 2, 0, { line_hl_group = "Comment" })
  vim.api.nvim_buf_set_extmark(buf, ns, header - 1, 0, { line_hl_group = "Bold" })
  for i, r in ipairs(rows) do
    local p = key == "self" and r.self_pct or r.total_pct
    local hl = (p >= hot and "DiagnosticError") or (p >= warm and "DiagnosticWarn") or nil
    if hl then
      vim.api.nvim_buf_set_extmark(buf, ns, header + i - 1, 0, { line_hl_group = hl })
    end
  end

  local win = vim.fn.bufwinid(buf)
  if win == -1 then
    M.state.origin = vim.api.nvim_get_current_win()
    vim.cmd("botright 18split")
    vim.api.nvim_win_set_buf(0, buf)
    vim.wo.number, vim.wo.relativenumber, vim.wo.wrap, vim.wo.cursorline = false, false, false, true
  else
    vim.api.nvim_set_current_win(win)
  end
  pcall(vim.api.nvim_win_set_cursor, 0, { header + 1, 0 })

  local top = rows[1]
  if top then
    notify(("Hottest by %s: %s (%.1f%% self, %.1f%% total)"):format(key, top.name, top.self_pct, top.total_pct))
  end
end

---------------------------------------------------------------------------
-- filter menu
---------------------------------------------------------------------------
M.PRESETS = {
  {
    label = "Preset: only my code (hide std/libc/kernel, time goes to callers)",
    apply = function(f)
      f.hide = vim.g.perf_hide_regex
        or [[^(std|__gnu_cxx|__cxxabiv1)::|^_?_?libc|^_dl_|^_start$|^\[unknown\]$]]
      f.include = vim.g.perf_project_regex or ""
      f.hide_kernel = true
    end,
  },
  {
    label = "Preset: hot leaves (reverse + icicle: who burns the CPU)",
    apply = function(f)
      f.reverse, f.inverted = true, true
    end,
  },
  {
    label = "Preset: recursion merged",
    apply = function(f)
      f.merge_recursion = true
    end,
  },
  {
    label = "Reset all filters",
    apply = function(f)
      for k, v in pairs(M.DEFAULTS) do
        f[k] = v
      end
    end,
  },
}

local TEXT_FIELDS = {
  { "process", "Process (first frame) regex" },
  { "focus", "Focus: re-root stacks at frame" },
  { "include", "Include stacks matching" },
  { "exclude", "Exclude stacks matching" },
  { "hide", "Hide frames (time -> caller)" },
  { "colors", "Flamegraph palette", "string" },
  { "minwidth", "Flamegraph min frame width (px)", "number" },
  { "min_percent", "Hotspots: min % shown", "number" },
}
local BOOL_FIELDS = {
  { "hide_kernel", "Hide kernel frames" },
  { "merge_recursion", "Merge recursive frames" },
  { "reverse", "Reverse stacks (leaf -> root)" },
  { "inverted", "Icicle layout" },
}

function M.set_filter(key, value)
  local f = M.filters()
  if M.DEFAULTS[key] == nil then
    notify("Unknown filter: " .. key, ERROR)
    return false
  end
  local default = M.DEFAULTS[key]
  if type(default) == "boolean" then
    value = value == true or value == "true" or value == "1" or value == "on"
  elseif type(default) == "number" then
    value = tonumber(value) or default
  else
    value = value or ""
    if key ~= "colors" and rx(value) == false then
      return false
    end
  end
  f[key] = value
  save_filters()
  return true
end

function M.filter_menu()
  local f = M.filters()
  local items = {}
  for _, it in ipairs(TEXT_FIELDS) do
    local v = f[it[1]]
    items[#items + 1] = { kind = "text", key = it[1], label = ("%-34s %s"):format(it[2], v == "" and "—" or tostring(v)) }
  end
  for _, it in ipairs(BOOL_FIELDS) do
    items[#items + 1] = { kind = "bool", key = it[1], label = ("%-34s [%s]"):format(it[2], f[it[1]] and "x" or " ") }
  end
  for _, p in ipairs(M.PRESETS) do
    items[#items + 1] = { kind = "preset", label = p.label, apply = p.apply }
  end
  items[#items + 1] = { kind = "action", label = "▶ Show hotspots", run = M.hotspots }
  items[#items + 1] = { kind = "action", label = "▶ Open flamegraph", run = M.flamegraph }
  items[#items + 1] = { kind = "action", label = "▶ Open hot-leaves graph", run = function() M.flamegraph({ hot_leaves = true }) end }
  items[#items + 1] = { kind = "action", label = "▶ Diff vs previous recording", run = M.diff }

  vim.ui.select(items, {
    prompt = "perf filters (" .. summary(f) .. ")",
    format_item = function(i)
      return i.label
    end,
  }, function(choice)
    if not choice then
      return
    end
    if choice.kind == "text" then
      vim.ui.input({ prompt = choice.key .. " (\\v regex, empty = off): ", default = tostring(f[choice.key]) }, function(v)
        if v ~= nil then
          M.set_filter(choice.key, v)
        end
        M.filter_menu()
      end)
    elseif choice.kind == "bool" then
      M.set_filter(choice.key, not f[choice.key])
      M.filter_menu()
    elseif choice.kind == "preset" then
      choice.apply(f)
      save_filters()
      M.filter_menu()
    else
      choice.run()
    end
  end)
end

function M.describe_filters()
  return summary(M.filters())
end

function M.filter_keys()
  return vim.tbl_keys(M.DEFAULTS)
end

return M
