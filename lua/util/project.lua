-- C++ / CMake project: one command to make every plugin work, and keep them working.
--
--   :CppInit [preset]   (<leader>mi)  run it in the project (cwd, or a file of it):
--     no CMakeLists.txt here -> offers to create a project from ~/.config/nvim/project-template
--     cd to the project root, cmake-tools: this root + the preset (debug), configure, build,
--     compile_commands.json in the root, clangd restarted, GoogleTest files mapped.
--   After that, the cmake-tools commands keep it right: every configure (also preset /
--   build type switches) re-links compile_commands.json and restarts clangd; every build
--   re-maps the tests, so the test summary follows rebuilds and preset changes.
local M = {}

local g = require("util.gtest")

local function notify(msg, level)
  vim.notify(msg, level or vim.log.levels.INFO, { title = "C++ project" })
end

-- cmake-tools' generate calls itself for presets: run the refresh once per burst
local pending = {}
local function once(key, fn)
  if pending[key] then
    return
  end
  pending[key] = true
  vim.defer_fn(function()
    pending[key] = nil
    fn()
  end, 400)
end

-- compile database clangd was last (re)started with. CMake's own CREATE_LINK may have
-- re-pointed the root link already, so compare targets instead of trusting link_compile_db
local clangd_db

---Link the root compile_commands.json to the current build; restart clangd if it changed
---@param root string
function M.refresh_clangd(root)
  g.link_compile_db(root, true)
  local db = vim.uv.fs_realpath(root .. "/compile_commands.json")
  if db and db ~= clangd_db then
    clangd_db = db
    g.restart_clangd()
  end
end

function M.after_configure()
  once("configure", function()
    local root = g.root()
    if root then
      M.refresh_clangd(root)
    end
  end)
end

function M.after_build()
  once("build", function()
    g.map_tests()
  end)
end

local function ok_result(r)
  return r == nil or (type(r) == "table" and r.code == 0)
end

---Wrap cmake-tools' generate / build so every configure and build refreshes clangd and
---the test mapping. Its :CMakeGenerate / :CMakeBuild commands hold the original
---functions, so they are registered again (same options).
function M.hook_cmake_tools()
  local ok, cmake = pcall(require, "cmake-tools")
  if not ok or cmake._cpp_project_hooked then
    return
  end
  cmake._cpp_project_hooked = true
  local generate, build = cmake.generate, cmake.build
  cmake.generate = function(opt, cb)
    return generate(opt, function(r)
      if cb then
        cb(r)
      end
      if ok_result(r) then
        vim.schedule(M.after_configure)
      end
    end)
  end
  cmake.build = function(opt, cb)
    return build(opt, function(r)
      if cb then
        cb(r)
      end
      if ok_result(r) then
        vim.schedule(M.after_build)
      end
    end)
  end
  -- preset / build type pickers call cmake.generate through the module: already covered
  vim.api.nvim_create_user_command("CMakeGenerate", function(o)
    cmake.generate(o)
  end, { nargs = "*", bang = true, desc = "CMake configure" })
  vim.api.nvim_create_user_command("CMakeBuild", function(o)
    cmake.build(o)
  end, { nargs = "*", bang = true, desc = "CMake build" })
end

local function template_dir()
  return vim.fn.stdpath("config") .. "/project-template"
end

---Copy the template into dest (files that exist already are left alone)
local function copy_template(dest)
  local src = template_dir()
  if not vim.uv.fs_stat(src) then
    return false
  end
  for name, kind in vim.fs.dir(src, { depth = 20 }) do
    local from, to = src .. "/" .. name, dest .. "/" .. name
    if kind == "directory" then
      vim.fn.mkdir(to, "p")
    elseif not vim.uv.fs_stat(to) then
      vim.fn.mkdir(vim.fs.dirname(to), "p")
      vim.uv.fs_copyfile(from, to)
    end
  end
  return true
end

local function has_preset(root, name)
  local f = io.open(root .. "/CMakePresets.json")
  if not f then
    return false, false
  end
  local okj, json = pcall(vim.json.decode, f:read("*a"))
  f:close()
  if not okj then
    return false, false
  end
  local conf, buildp = false, false
  for _, p in ipairs(json.configurePresets or {}) do
    conf = conf or p.name == name
  end
  for _, p in ipairs(json.buildPresets or {}) do
    buildp = buildp or p.name == name
  end
  return conf, buildp
end

---@param preset string? configure preset (default "debug")
function M.init(preset)
  preset = (preset and preset ~= "") and preset or "debug"
  local cwd = vim.uv.cwd()
  local root = vim.uv.fs_stat(cwd .. "/CMakeLists.txt") and g.root(cwd .. "/CMakeLists.txt") or g.root()
  if not root then
    local empty = #vim.fn.readdir(cwd) == 0
    local q = ("No CMakeLists.txt in %s.%s Create a project from the template here?"):format(
      cwd, empty and "" or " (existing files stay)")
    if vim.fn.confirm(q, "&Yes\n&No", empty and 1 or 2) ~= 1 then
      return
    end
    if not copy_template(cwd) then
      return notify("no template at " .. template_dir(), vim.log.levels.ERROR)
    end
    notify("project created from the template")
    root = cwd
  end
  if root ~= cwd then
    vim.cmd.cd(vim.fn.fnameescape(root))
    notify("cd " .. root)
  end

  local okc, cmake = pcall(require, "cmake-tools")
  if not okc then
    return g.setup_project() -- no cmake-tools: plain cmake
  end
  M.hook_cmake_tools()
  local cfg = cmake.get_config()
  if tostring(cfg.cwd) ~= root then
    cfg.cwd = root
    pcall(cmake.register_autocmd)
    pcall(cmake.register_autocmd_provided_by_users)
  end
  local conf, buildp = has_preset(root, preset)
  if conf then
    cfg.configure_preset = preset
    if buildp then
      cfg.build_preset = preset
    end
  elseif vim.uv.fs_stat(root .. "/CMakePresets.json") then
    notify("no configure preset '" .. preset .. "': pick one", vim.log.levels.WARN)
  end

  notify("configure (" .. (conf and preset or "cmake-tools") .. ") …")
  cmake.generate({ bang = false, fargs = {} }, function(r)
    if not ok_result(r) then
      return vim.schedule(function()
        notify("configure failed: " .. tostring(r and r.message or "") .. " (<leader>mo shows the output)", vim.log.levels.ERROR)
      end)
    end
    vim.schedule(function()
      notify("build …")
      cmake.build({ fargs = {} }, function(b)
        vim.schedule(function()
          if not ok_result(b) then
            return notify("build failed (<leader>mo shows the output)", vim.log.levels.ERROR)
          end
          M.refresh_clangd(root)
          g.map_tests()
          notify(table.concat({
            "ready: clangd, CMake, tests",
            "<leader>tt / <leader>tr run tests, <leader>ts summary",
            "<leader>tC coverage, <leader>tm missing tests",
          }, "\n"))
        end)
      end)
    end)
  end)
end

return M
