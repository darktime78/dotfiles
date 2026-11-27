-- CMake project setup for clangd and GoogleTest (neotest-gtest), without manual steps:
--   * first C/C++ file of an unconfigured CMake project -> `cmake --preset debug` once in
--     the background, then clangd restarts (correct C++20 flags and include paths)
--   * opening a test file of a built project -> its tests are mapped to the test
--     executable (neotest-gtest :ConfigureGtestAll, via ctest)
--   * <leader>tg -> configure + build + map in one go (run it after adding test files)
-- Off: vim.g.cmake_auto_configure = false (options.lua).
local M = {}

local done = {} -- per root: auto-configure / auto-map already tried this session

-- directories that never hold the project's own tests: build trees (GoogleTest's sources
-- and its 2500 self-tests sit in build/*/_deps), vendored code, tool caches
local skip_dirs = {
  build = true, out = true, _deps = true,
  third_party = true, ["3rdparty"] = true, thirdparty = true, external = true, extern = true,
  vendor = true, deps = true, subprojects = true, node_modules = true, venv = true,
}

---neotest discovery filter (neotest-gtest filter_dir): false = don't search this directory
---@param name string
---@param rel_path string relative to root
---@param root string
function M.filter_dir(name, rel_path, root)
  if skip_dirs[name] or name:match("^build[-_.]") or name:match("^cmake%-build") then
    return false
  end
  -- a build directory with any other name
  return vim.uv.fs_stat(root .. "/" .. rel_path .. "/CMakeCache.txt") == nil
end

local test_ext = { cpp = true, cppm = true, cc = true, cxx = true, ["c++"] = true } -- as neotest-gtest

---The project's GoogleTest files (test_*.cpp / *_test.cpp outside build and vendor dirs)
---@param root string
---@return string[]
function M.test_files(root)
  local files = {}
  for name, kind in vim.fs.dir(root, {
    depth = 8,
    skip = function(rel)
      return not rel:match("^%.") and M.filter_dir(vim.fs.basename(rel), rel, root)
    end,
  }) do
    local base = vim.fs.basename(name)
    local stem, ext = base:match("^(.*)%.([^.]+)$")
    if kind == "file" and test_ext[ext] and (base:match("^test_") or stem:match("_test$")) then
      files[#files + 1] = root .. "/" .. name
    end
  end
  return files
end

---Project root: the nearest directory with CMakeLists.txt that is not inside another one
---@param path string?
---@return string?
function M.root(path)
  path = path or vim.api.nvim_buf_get_name(0)
  if path == "" then
    path = vim.uv.cwd()
  end
  local found = vim.fs.find("CMakeLists.txt", { upward = true, path = vim.fs.dirname(path) })[1]
  if not found then
    return nil
  end
  local root = vim.fs.dirname(found)
  -- subdirectories have their own CMakeLists.txt: go up to the top-level project
  while true do
    local parent = vim.fs.find("CMakeLists.txt", { upward = true, path = vim.fs.dirname(root) })[1]
    if not parent then
      break
    end
    root = vim.fs.dirname(parent)
  end
  return root
end

---The configure preset to use: "debug" if CMakePresets.json has it, else nil (plain cmake)
function M.preset(root)
  local f = io.open(root .. "/CMakePresets.json")
  if not f then
    return nil
  end
  local ok, json = pcall(vim.json.decode, f:read("*a"))
  f:close()
  if not ok then
    return nil
  end
  for _, p in ipairs(json.configurePresets or {}) do
    if p.name == "debug" then
      return "debug"
    end
  end
  return nil
end

local preset = M.preset

---The build folder: cmake-tools' current one (its preset / build type) when it manages
---this project, else build/<preset> (build/debug)
function M.build_dir(root)
  local cmake = package.loaded["cmake-tools"] -- only if it is in use (don't load it here)
  if type(cmake) == "table" and cmake.get_build_directory then
    local cfg = cmake.get_config and cmake.get_config()
    local dir = tostring(cmake.get_build_directory() or "")
    if cfg and tostring(cfg.cwd) == root and dir ~= "" and dir ~= "nil" then
      return dir
    end
  end
  return root .. "/build/" .. (preset(root) or "debug")
end
local build_dir = M.build_dir

function M.configured(root)
  return vim.uv.fs_stat(build_dir(root) .. "/CMakeCache.txt") ~= nil
end

local configured = M.configured
local function restart_clangd()
  M.restart_clangd()
end

---Run commands one after another in root; on_done(ok)
local function chain(root, steps, on_done)
  local function step(i)
    if i > #steps then
      return on_done(true)
    end
    local s = steps[i]
    vim.notify(s.title .. " …", vim.log.levels.INFO, { title = "CMake" })
    vim.system(s.cmd, { cwd = root, text = true }, function(res)
      vim.schedule(function()
        if res.code ~= 0 then
          local out = ((res.stdout or "") .. (res.stderr or "")):gsub("%s+$", "")
          local tail = table.concat(vim.list_slice(vim.split(out, "\n"), math.max(1, #vim.split(out, "\n") - 15)), "\n")
          vim.notify(s.title .. " failed:\n" .. tail, vim.log.levels.ERROR, { title = "CMake" })
          return on_done(false)
        end
        step(i + 1)
      end)
    end)
  end
  step(1)
end

local function configure_cmd(root)
  local p = preset(root)
  if p then
    return { "cmake", "--preset", p }
  end
  return { "cmake", "-S", ".", "-B", build_dir(root), "-G", "Ninja", "-DCMAKE_BUILD_TYPE=Debug", "-DCMAKE_EXPORT_COMPILE_COMMANDS=ON" }
end

local function build_cmd(root)
  local p = preset(root)
  if p then
    return { "cmake", "--build", "--preset", p }
  end
  return { "cmake", "--build", build_dir(root) }
end

---clangd reads compile_commands.json from the project root (CMakeLists.txt links it there
---in the template; for other projects we link it here)
---@param force boolean? also re-point an existing link (another build folder now)
function M.link_compile_db(root, force)
  local db = build_dir(root) .. "/compile_commands.json"
  local link = root .. "/compile_commands.json"
  if not vim.uv.fs_stat(db) then
    return false
  end
  local st = vim.uv.fs_lstat(link)
  if st and force and st.type == "link" and vim.uv.fs_readlink(link) ~= db then
    vim.uv.fs_unlink(link)
    st = nil
  end
  if not st then
    vim.uv.fs_symlink(db, link)
    return true
  end
  return false
end
local link_compile_db = M.link_compile_db

function M.restart_clangd()
  if #vim.lsp.get_clients({ name = "clangd" }) == 0 then
    return -- not running yet: it starts with the right flags anyway
  end
  if vim.fn.exists(":LspRestart") == 2 then
    vim.cmd("LspRestart clangd")
  elseif vim.fn.exists(":lsp") == 2 then
    vim.cmd("lsp restart clangd") -- Neovim 0.12
  else
    for _, c in ipairs(vim.lsp.get_clients({ name = "clangd" })) do
      c:stop()
    end
    vim.defer_fn(function()
      vim.cmd("silent! doautocmd FileType")
    end, 500)
  end
end

---Map test files to executables (needs a built project: ctest knows the tests then)
---@param tries integer? retries left while neotest is still discovering the test files
function M.map_tests(tries)
  tries = tries or 20
  local ok, ctest = pcall(require, "neotest-gtest.executables.ctest")
  if not ok then
    return
  end
  -- neotest must have discovered the test files first: mapping only covers files that are
  -- in its positions tree, so wait until every test file of the project is there
  local nok, neotest = pcall(require, "neotest")
  if nok and neotest.state and not M.discovered(neotest) then
    if tries > 0 then
      vim.defer_fn(function()
        M.map_tests(tries - 1)
      end, 1000)
    end
    if tries > 1 then
      return
    end -- last try: map whatever is there
  end
  ctest.configure_all()
end

---Are all test files of the current project in neotest-gtest's positions tree?
function M.discovered(neotest)
  local root = M.root()
  local ids = vim.tbl_filter(function(id)
    return vim.startswith(id, "neotest-gtest:")
  end, neotest.state.adapter_ids())
  if #ids == 0 then
    return false
  end
  if not root then
    return true
  end
  for _, file in ipairs(M.test_files(root)) do
    local real, found = vim.uv.fs_realpath(file) or file, false
    for _, id in ipairs(ids) do
      local tree = neotest.state.positions(id)
      if tree and (tree:get_key(file) or tree:get_key(real)) then
        found = true
        break
      end
    end
    if not found then
      return false
    end
  end
  return true
end

---<leader>tg: configure (if needed) + build + map tests
function M.setup_project()
  local root = M.root()
  if not root then
    return vim.notify("not in a CMake project", vim.log.levels.WARN, { title = "CMake" })
  end
  local steps = {}
  if not configured(root) then
    steps[#steps + 1] = { title = "Configure (" .. table.concat(configure_cmd(root), " ") .. ")", cmd = configure_cmd(root) }
  end
  steps[#steps + 1] = { title = "Build", cmd = build_cmd(root) }
  local had_db = vim.uv.fs_stat(root .. "/compile_commands.json") ~= nil
  chain(root, steps, function(ok)
    if not ok then
      return
    end
    link_compile_db(root)
    if not had_db then
      restart_clangd()
    end
    M.map_tests()
  end)
end

---Autocommands: configure once on the first C/C++ file, map tests on test files
function M.setup()
  vim.api.nvim_create_autocmd("BufReadPost", {
    group = vim.api.nvim_create_augroup("cmake_auto", { clear = true }),
    pattern = { "*.cpp", "*.cc", "*.cxx", "*.hpp", "*.h", "*.hh" },
    callback = function(ev)
      if vim.g.cmake_auto_configure == false or vim.fn.executable("cmake") == 0 then
        return
      end
      local root = M.root(ev.file)
      if not root or done[root] then
        return
      end
      done[root] = true
      if not configured(root) then
        chain(root, { { title = "First configure of " .. vim.fs.basename(root), cmd = configure_cmd(root) } }, function(ok)
          if ok then
            link_compile_db(root)
            restart_clangd()
            vim.notify("clangd uses the build flags now. Tests: <leader>tg builds and maps them", vim.log.levels.INFO, { title = "CMake" })
          end
        end)
      else
        link_compile_db(root)
        -- a built project: map its test files (quiet if nothing is built yet)
        if vim.fn.executable("ctest") == 1 and vim.fn.glob(build_dir(root) .. "/**/CTestTestfile.cmake") ~= "" then
          vim.defer_fn(function()
            M.map_tests()
          end, 2000)
        end
      end
    end,
  })
end

return M
