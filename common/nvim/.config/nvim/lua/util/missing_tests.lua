-- Missing GoogleTest tests, found from the last coverage report (<leader>tC makes it).
--
--   <leader>tm  /  :GtestMissing [list|stubs|ai]
--     list   functions the tests never call + lines they never run -> quickfix
--     stubs  a TEST() per uncalled function in the matching test file (GTEST_SKIP until
--            you write it, so it shows as "skipped" in the test summary)
--     ai     ask OpenCode (local Qwen, or your model) to write the tests
-- No argument: pick one. No coverage report yet: it runs the coverage first.
local M = {}

-- ---------------------------------------------------------------- pure helpers
-- (no vim API: tested with plain Lua)

---Parse an lcov file (gcovr / lcov 1.x FN+FNDA, lcov 2.2 FNL+FNA).
---@param lines fun():string? iterator over the lines
---@param keep fun(path:string):string? returns the absolute path to keep a file, nil to skip
---@return table[] files { path, fns = {{name,line,last,hits}}, da = {[line]=hits} }
function M.parse_lcov(lines, keep)
  local files, cur, idx = {}, nil, {}
  for line in lines do
    local sf = line:match("^SF:(.*)$")
    if sf then
      local path = keep(sf)
      cur = path and { path = path, fns = {}, byname = {}, da = {} } or false
      idx = {}
      if cur then
        files[#files + 1] = cur
      end
    elseif cur then
      local a, b, c = line:match("^FN:(%d+),(%d+),(.+)$")
      if not a then
        a, c = line:match("^FN:(%d+),(.+)$")
      end
      if a then
        local f = { name = c, line = tonumber(a), last = tonumber(b), hits = 0 }
        cur.fns[#cur.fns + 1] = f
        cur.byname[c] = f
      else
        local h, n = line:match("^FNDA:(%d+),(.+)$")
        if h and cur.byname[n] then
          cur.byname[n].hits = tonumber(h)
        else
          local i, l, e = line:match("^FNL:(%d+),(%d+),?(%d*)$")
          if i then
            idx[i] = { line = tonumber(l), last = tonumber(e) }
          else
            local fi, fh, fname = line:match("^FNA:(%d+),(%d+),(.+)$")
            if fi and idx[fi] then
              local f = { name = fname, line = idx[fi].line, last = idx[fi].last, hits = tonumber(fh) }
              cur.fns[#cur.fns + 1] = f
              cur.byname[fname] = f
            else
              local dl, dh = line:match("^DA:(%d+),(%d+)")
              if dl then
                cur.da[tonumber(dl)] = tonumber(dh)
              end
            end
          end
        end
      end
    end
  end
  return files
end

---Gaps per file: uncalled functions, and never-run lines inside called functions
---@return table[] { path, name, line, kind = "uncalled"|"lines", lines = {..} }
function M.gaps(files)
  local out = {}
  for _, f in ipairs(files) do
    table.sort(f.fns, function(x, y)
      return x.line < y.line
    end)
    for i, fn in ipairs(f.fns) do
      if fn.hits == 0 then
        out[#out + 1] = { path = f.path, name = fn.name, line = fn.line, kind = "uncalled" }
      else
        local stop = fn.last or (f.fns[i + 1] and f.fns[i + 1].line - 1) or math.huge
        local missed = {}
        for l, h in pairs(f.da) do
          if h == 0 and l >= fn.line and l <= stop then
            missed[#missed + 1] = l
          end
        end
        table.sort(missed)
        if #missed > 0 then
          out[#out + 1] = { path = f.path, name = fn.name, line = missed[1], kind = "lines", lines = missed }
        end
      end
    end
  end
  return out
end

---"demo::Calculator::divide(long, long) const" -> { qual = "demo::Calculator", class =
---"Calculator", func = "divide" }; nil for things a test doesn't call directly
function M.split_name(name)
  -- lambdas, anonymous namespaces, compiler internals: not called by name from a test
  if name:find("{lambda", 1, true) or name:find("(anonymous", 1, true) or name:find("__", 1, true) then
    return nil
  end
  local base = name:gsub("%(.*$", "")
  local is_op = base:match("::operator[^:]*$") or base:match("^operator")
  if not is_op then
    repeat
      local before = base
      base = base:gsub("%b<>", "")
    until base == before
  end
  local parts = {}
  for p in (base .. "::"):gmatch("(.-)::") do
    parts[#parts + 1] = p
  end
  local func = parts[#parts]
  local owner = parts[#parts - 1]
  if not func or func == "" or (func == "main" and #parts == 1) then
    return nil
  end
  if owner and (func == owner or func == "~" .. owner) then
    return nil -- constructor / destructor: covered through the other tests
  end
  local is_class = owner ~= nil and owner:match("^%u") ~= nil
  return {
    qual = table.concat(parts, "::", 1, #parts - 1),
    class = is_class and owner or nil,
    func = func,
  }
end

---count_primes_sieve -> CountPrimesSieve, operator== -> OperatorEq
function M.camel(s)
  s = s:gsub("operator%s*==", "operatorEq"):gsub("operator%s*<<", "operatorShl"):gsub("operator%s*%(%)", "operatorCall")
  s = s:gsub("[^%w]+", "_")
  local out = s:gsub("_*(%w)(%w*)", function(a, b)
    return a:upper() .. b
  end)
  return out
end

---Names already used: "Suite.Test" -> true
function M.existing_tests(text)
  local names = {}
  for suite, test in text:gmatch("TEST[_%u]*%s*%(%s*([%w_]+)%s*,%s*([%w_]+)%s*%)") do
    names[suite .. "." .. test] = true
  end
  return names
end

---The TEST() stub for one uncalled function
---@param gap table from M.gaps
---@param used table names from M.existing_tests (updated)
---@param stem string file stem, for free functions ("math_utils" -> MathUtilsTest)
---@param ind string one indent level
function M.stub(gap, used, stem, ind)
  local n = M.split_name(gap.name)
  if not n then
    return nil
  end
  local suite = (n.class or M.camel(stem)) .. "Test"
  local test = M.camel(n.func)
  local name, k = test, 2
  while used[suite .. "." .. name] do
    name = test .. k
    k = k + 1
  end
  used[suite .. "." .. name] = true
  local call
  local lines = { ("// coverage: %s is never called by a test"):format(gap.name), ("TEST(%s, %s) {"):format(suite, name) }
  if n.class then
    lines[#lines + 1] = ind .. ("%s obj;"):format(n.qual)
    call = ("obj.%s(/* ... */)"):format(n.func)
  else
    call = ("%s(/* ... */)"):format(n.qual ~= "" and (n.qual .. "::" .. n.func) or n.func)
  end
  lines[#lines + 1] = ind .. ("// EXPECT_EQ(%s, /* expected */);"):format(call)
  lines[#lines + 1] = ind .. 'GTEST_SKIP() << "TODO: write this test (from coverage)";'
  lines[#lines + 1] = "}"
  return table.concat(lines, "\n")
end

-- ---------------------------------------------------------------- with Neovim
local function root()
  return require("util.gtest").root() or vim.uv.cwd()
end

---Load the report: gaps in the project's own sources (not tests/, build/, _deps)
function M.scan()
  local r = root()
  local lcov = require("util.coverage").lcov_file(r)
  if not vim.uv.fs_stat(lcov) then
    return nil, lcov
  end
  local files = M.parse_lcov(io.lines(lcov), function(sf)
    local p = vim.fs.normalize(sf:sub(1, 1) == "/" and sf or vim.fs.joinpath(r, sf))
    local rel = p:sub(#r + 2)
    if p:sub(1, #r + 1) ~= r .. "/" or rel:match("^tests?/") or rel:match("^build/") or rel:find("_deps/", 1, true) then
      return nil
    end
    return p
  end)
  local gaps = M.gaps(files)
  -- demangle what gcov left mangled (_Z...)
  local mangled = {}
  for _, g in ipairs(gaps) do
    if g.name:match("^_Z") then
      mangled[#mangled + 1] = g.name
    end
  end
  if #mangled > 0 and vim.fn.executable("c++filt") == 1 then
    local res = vim.system({ "c++filt" }, { stdin = table.concat(mangled, "\n") .. "\n", text = true }):wait()
    local plain = vim.split(res.stdout or "", "\n")
    local map = {}
    for i, m in ipairs(mangled) do
      map[m] = plain[i] ~= "" and plain[i] or m
    end
    for _, g in ipairs(gaps) do
      g.name = map[g.name] or g.name
    end
  end
  return gaps, lcov
end

function M.list(gaps)
  local items = {}
  for _, g in ipairs(gaps) do
    local text = g.kind == "uncalled" and ("never called: " .. g.name)
      or ("lines %s never run in %s"):format(table.concat(g.lines, ","), g.name)
    items[#items + 1] = { filename = g.path, lnum = g.line, text = text, type = g.kind == "uncalled" and "W" or "I" }
  end
  vim.fn.setqflist({}, " ", { title = "Missing tests (coverage)", items = items })
  vim.cmd("copen")
end

---The test file for a source: tests/<stem>_test.cpp, else a test file that includes
---its header, else a new tests/<stem>_test.cpp
local function test_file_for(r, src)
  local stem = vim.fn.fnamemodify(src, ":t:r")
  local direct = vim.fs.joinpath(r, "tests", stem .. "_test.cpp")
  if vim.uv.fs_stat(direct) then
    return direct, stem, false
  end
  for _, f in ipairs(vim.fn.glob(r .. "/tests/*.cpp", false, true)) do
    local text = table.concat(vim.fn.readfile(f), "\n")
    if text:find(stem .. "%.h") then
      return f, stem, false
    end
  end
  return direct, stem, true
end

local function header_for(r, stem)
  local h = vim.fn.glob(r .. "/include/**/" .. stem .. ".h*", false, true)[1]
    or vim.fn.glob(r .. "/src/**/" .. stem .. ".h*", false, true)[1]
  if not h then
    return nil
  end
  return (h:gsub("^" .. vim.pesc(r) .. "/include/", ""):gsub("^" .. vim.pesc(r) .. "/", ""))
end

function M.stubs(gaps)
  local r = root()
  local by_file, order = {}, {}
  for _, g in ipairs(gaps) do
    if g.kind == "uncalled" then
      local tf, stem, new = test_file_for(r, g.path)
      if not by_file[tf] then
        by_file[tf] = { stem = stem, new = new, gaps = {} }
        order[#order + 1] = tf
      end
      table.insert(by_file[tf].gaps, g)
    end
  end
  if #order == 0 then
    return vim.notify("every function is called by a test; the line gaps are in :GtestMissing list", vim.log.levels.INFO)
  end
  local added, first = 0, nil
  for _, tf in ipairs(order) do
    local e = by_file[tf]
    local text = vim.uv.fs_stat(tf) and table.concat(vim.fn.readfile(tf), "\n") or ""
    local used = M.existing_tests(text)
    local ind = text:match("\n(%s+)%S") or "    "
    local chunks = {}
    for _, g in ipairs(e.gaps) do
      local s = M.stub(g, used, e.stem, ind:gsub("\t", "    "))
      if s then
        chunks[#chunks + 1] = s
      end
    end
    if #chunks > 0 then
      local out = {}
      if text == "" then
        out[#out + 1] = "#include <gtest/gtest.h>"
        out[#out + 1] = ""
        local h = header_for(r, e.stem)
        if h then
          out[#out + 1] = ('#include "%s"'):format(h)
        end
      end
      local body = (text ~= "" and (text:gsub("%s+$", "") .. "\n\n") or (table.concat(out, "\n") .. "\n\n"))
        .. table.concat(chunks, "\n\n") .. "\n"
      vim.fn.mkdir(vim.fs.dirname(tf), "p")
      vim.fn.writefile(vim.split(body, "\n", { plain = true }), tf)
      added = added + #chunks
      first = first or tf
      if e.new then
        vim.notify("new test file " .. tf:sub(#r + 2) .. ": the template's CMakeLists builds tests/*_test.cpp", vim.log.levels.INFO)
      end
    end
  end
  if first then
    vim.cmd.edit(vim.fn.fnameescape(first))
    vim.fn.search("from coverage", "w")
    vim.notify(("%d test stub(s) added (skipped until written). <leader>tg builds + maps them"):format(added), vim.log.levels.INFO, { title = "Missing tests" })
  end
end

function M.ai(gaps)
  local r = root()
  local lines = {}
  for _, g in ipairs(gaps) do
    local rel = g.path:sub(#r + 2)
    if g.kind == "uncalled" then
      lines[#lines + 1] = ("- %s:%d %s is never called"):format(rel, g.line, g.name)
    else
      lines[#lines + 1] = ("- %s lines %s in %s never run"):format(rel, table.concat(g.lines, ","), g.name)
    end
  end
  local prompt = "Write GoogleTest tests (TEST / TEST_F, in the existing files under tests/, same style) "
    .. "that cover these gaps from the coverage report. Test behaviour and edge cases, not just calls; "
    .. "show each new test.\n" .. table.concat(lines, "\n") .. "\n@uncovered"
  local ok, oc = pcall(require, "opencode")
  if ok and oc.prompt then
    oc.prompt(prompt)
  else
    vim.fn.setreg("+", prompt)
    vim.notify("OpenCode is not available: the prompt is in the clipboard", vim.log.levels.WARN)
  end
end

---@param mode string? list | stubs | ai (nil: ask)
function M.run(mode)
  local gaps, lcov = M.scan()
  if not gaps then
    if vim.fn.confirm("No coverage report (" .. lcov .. "). Run tests with coverage now?", "&Yes\n&No", 1) == 1 then
      require("util.coverage").run(function()
        M.run(mode)
      end)
    end
    return
  end
  if #gaps == 0 then
    return vim.notify("No gaps: every function and line of src/ and include/ is run by the tests", vim.log.levels.INFO, { title = "Missing tests" })
  end
  local uncalled = 0
  for _, g in ipairs(gaps) do
    uncalled = uncalled + (g.kind == "uncalled" and 1 or 0)
  end
  local actions = {
    list = function() M.list(gaps) end,
    stubs = function() M.list(gaps) M.stubs(gaps) end,
    ai = function() M.list(gaps) M.ai(gaps) end,
  }
  if mode and actions[mode] then
    return actions[mode]()
  end
  local choices = {
    { "stubs", ("Add TEST() stubs for %d uncalled function(s)"):format(uncalled) },
    { "ai", "Ask the AI (OpenCode) to write the tests" },
    { "list", ("Only the list (%d gap(s), quickfix)"):format(#gaps) },
  }
  vim.ui.select(choices, {
    prompt = "Coverage gaps:",
    format_item = function(c) return c[2] end,
  }, function(c)
    if c then
      actions[c[1]]()
    end
  end)
end

return M
