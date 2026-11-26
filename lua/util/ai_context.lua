-- Extra OpenCode contexts for C++ work, plus git helpers.
--   @hotspots  : the current perf hotspot table (util.perf)
--   @uncovered : lines never executed by the tests (build/coverage/coverage.info)
--   @diff      : uncommitted changes (git diff HEAD)
--   @staged    : staged changes (git diff --cached)
--   @branch    : this branch vs the main branch (git diff <base>...HEAD)
local M = {}

local uv = vim.uv or vim.loop
local MAX = 24000 -- characters per context, keeps prompts reasonable

local function notify(msg, level)
  vim.notify(msg, level or vim.log.levels.INFO, { title = "opencode" })
end

local function git(args)
  local res = vim.system(vim.list_extend({ "git" }, args), { cwd = uv.cwd(), text = true }):wait()
  if res.code ~= 0 then
    return nil
  end
  return res.stdout
end

local function clip(s, what)
  if not s or vim.trim(s) == "" then
    return nil
  end
  if #s > MAX then
    s = s:sub(1, MAX) .. ("\n… (%s truncated at %d characters)"):format(what, MAX)
  end
  return s
end

local function fenced(lang, s)
  return s and ("\n```%s\n%s\n```\n"):format(lang, s) or nil
end

--- origin's default branch (origin/main, origin/master …), or vim.g.git_main_branch
function M.git_base()
  if vim.g.git_main_branch then
    return vim.g.git_main_branch
  end
  local ref = git({ "rev-parse", "--abbrev-ref", "origin/HEAD" })
  ref = ref and vim.trim(ref) or ""
  if ref ~= "" and ref ~= "origin/HEAD" then
    return ref
  end
  for _, b in ipairs({ "origin/main", "origin/master", "main", "master" }) do
    if git({ "rev-parse", "--verify", "--quiet", b }) then
      return b
    end
  end
  return "HEAD~1"
end

function M.staged()
  return fenced("diff", clip(git({ "diff", "--cached", "--no-color" }), "staged diff"))
end

function M.diff()
  local d = git({ "diff", "HEAD", "--no-color" }) or git({ "diff", "--no-color" })
  return fenced("diff", clip(d, "diff"))
end

function M.branch()
  local base = M.git_base()
  local log = git({ "log", "--oneline", "--no-color", base .. "..HEAD" }) or ""
  local d = git({ "diff", "--no-color", base .. "...HEAD" })
  if not d or vim.trim(d) == "" then
    return nil
  end
  return ("Commits since %s:\n%s"):format(base, log) .. fenced("diff", clip(d, "branch diff"))
end

function M.hotspots()
  local ok, perf = pcall(require, "util.perf")
  if not ok or not perf.state.rows or #perf.state.rows == 0 then
    return nil
  end
  local rows = vim.deepcopy(perf.state.rows)
  table.sort(rows, function(a, b)
    return a.self > b.self
  end)
  local lines = {
    ("perf profile: %d samples, filters: %s"):format(perf.state.total, perf.describe_filters()),
    ("%8s %8s  %s"):format("self", "total", "function"),
  }
  for i = 1, math.min(15, #rows) do
    local r = rows[i]
    lines[#lines + 1] = ("%7.2f%% %7.2f%%  %s"):format(r.self_pct, r.total_pct, r.name)
  end
  return fenced("text", table.concat(lines, "\n"))
end

local function read_lines(path)
  local ok, lines = pcall(vim.fn.readfile, path)
  return ok and lines or {}
end

function M.uncovered(ctx)
  local lcov = require("util.coverage").lcov_file()
  if not uv.fs_stat(lcov) then
    return nil
  end
  local by_file, order, cur = {}, {}, nil
  for line in io.lines(lcov) do
    local sf = line:match("^SF:(.*)$")
    if sf then
      cur = sf
    elseif cur then
      local n, hits = line:match("^DA:(%d+),(%d+)")
      if n and hits == "0" then
        if not by_file[cur] then
          by_file[cur] = {}
          order[#order + 1] = cur
        end
        table.insert(by_file[cur], tonumber(n))
      end
    end
  end

  local function abs(sf)
    return vim.fs.normalize(sf:sub(1, 1) == "/" and sf or vim.fs.joinpath(uv.cwd(), sf))
  end

  -- prefer the buffer the prompt was made from, otherwise every file
  local buf = (type(ctx) == "table" and type(ctx.buf) == "number") and ctx.buf or vim.api.nvim_get_current_buf()
  local name = vim.api.nvim_buf_is_valid(buf) and vim.fs.normalize(vim.api.nvim_buf_get_name(buf)) or ""
  local files = vim.tbl_filter(function(sf)
    return abs(sf) == name
  end, order)
  if #files == 0 then
    files = order
  end

  local out = {}
  for _, sf in ipairs(files) do
    local src = read_lines(abs(sf))
    for _, n in ipairs(by_file[sf]) do
      out[#out + 1] = ("%s:%d  %s"):format(vim.fn.fnamemodify(abs(sf), ":."), n, vim.trim(src[n] or ""))
    end
  end
  if #out == 0 then
    return "(every instrumented line is covered)"
  end
  return fenced("text", clip(table.concat(out, "\n"), "uncovered lines"))
end

--- Generate a commit message with `opencode run` and insert it into a gitcommit buffer.
--- Outside a gitcommit buffer the request goes to the OpenCode TUI instead.
function M.commit_message(bufnr)
  bufnr = bufnr or vim.api.nvim_get_current_buf()
  if vim.bo[bufnr].filetype ~= "gitcommit" then
    require("opencode").prompt(
      "Write a Conventional Commits message for these staged changes. Output only the message: @staged"
    )
    return
  end
  if vim.fn.executable("opencode") == 0 then
    notify("`opencode` not found in $PATH", vim.log.levels.ERROR)
    return
  end
  local diff = M.staged()
  if not diff then
    notify("Nothing is staged", vim.log.levels.WARN)
    return
  end
  local prompt = "Write a git commit message for the staged diff below. Conventional Commits format: "
    .. "a subject line of at most 72 characters, a blank line, then a short body that explains why. "
    .. "Output only the message: no code fences, no commentary, do not run any tools.\n"
    .. diff
  local argv = vim.list_extend({ "opencode", "run" }, vim.g.opencode_run_args or {})
  table.insert(argv, prompt)
  notify("Writing commit message …")
  vim.system(argv, { cwd = uv.cwd(), text = true }, function(res)
    vim.schedule(function()
      if res.code ~= 0 then
        notify("opencode run failed:\n" .. (res.stderr or ""), vim.log.levels.ERROR)
        return
      end
      local msg = (res.stdout or ""):gsub("\27%[[%d;]*m", "")
      msg = vim.trim(msg)
      msg = msg:gsub("^```%w*\n", "")
      msg = msg:gsub("\n```$", "")
      if msg == "" or not vim.api.nvim_buf_is_valid(bufnr) then
        return
      end
      vim.api.nvim_buf_set_lines(bufnr, 0, 0, false, vim.split(msg, "\n", { plain = true }))
      notify("Commit message inserted, edit and :wq to commit")
    end)
  end)
end

return M
