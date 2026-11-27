-- Build the coverage preset, run GoogleTest via ctest, produce lcov with gcovr,
-- then show it: signs in the gutter + the coverage summary (<leader>tC).
-- It uses its own build folder (build/coverage), so the normal build, clangd and the
-- test summary keep using build/debug. Gaps -> tests: <leader>tm (util/missing_tests).
local M = {}

local function root()
  local ok, g = pcall(require, "util.gtest")
  return (ok and g.root()) or vim.uv.cwd()
end

local function build_dir()
  return vim.g.cpp_coverage_build_dir or "build/coverage"
end

---@param r string? project root (default: the current project)
function M.lcov_file(r)
  return vim.fs.joinpath(r or root(), build_dir(), "coverage.info")
end

---Load the report and show it
---@param show_summary boolean? open the summary window too (default vim.g.coverage_summary ~= false)
function M.load(show_summary)
  local file = M.lcov_file()
  if not vim.uv.fs_stat(file) then
    vim.notify("No coverage file: " .. file .. "\nRun <leader>tC first.", vim.log.levels.WARN)
    return false
  end
  local cov = require("coverage")
  if cov.load_lcov then
    cov.load_lcov(file, true)
  else
    vim.cmd("CoverageLoadLcov " .. vim.fn.fnameescape(file))
    vim.cmd("CoverageShow")
  end
  if show_summary ~= false and vim.g.coverage_summary ~= false then
    -- the summary needs the report parsed: give nvim-coverage a moment
    vim.defer_fn(function()
      pcall(vim.cmd, "CoverageSummary")
    end, 300)
  end
  return true
end

---Tests with coverage, then show it
---@param on_done fun()? after a successful run (e.g. the missing-tests helper)
function M.run(on_done)
  local r = root()
  local cmd
  if vim.uv.fs_stat(r .. "/CMakePresets.json") then
    cmd = "cmake --preset coverage && cmake --build --preset coverage --target coverage"
  else
    local b = build_dir()
    cmd = ("cmake -S . -B %s -DCMAKE_BUILD_TYPE=Debug -DBUILD_TESTS=ON -DENABLE_COVERAGE=ON"
      .. " && cmake --build %s --target coverage"):format(b, b)
  end
  if r ~= vim.uv.cwd() then
    cmd = ("cd %s && %s"):format(vim.fn.shellescape(r), cmd)
  end
  require("util.run").shell(cmd, "Coverage", function()
    if M.load() and on_done then
      on_done()
    end
  end, function(out)
    -- only show gcovr's summary lines
    local lines = {}
    for line in out:gmatch("[^\n]+") do
      if line:match("^lines:") or line:match("^functions:") or line:match("^branches:") then
        table.insert(lines, line)
      end
    end
    return table.concat(lines, "\n") .. "\nMissing tests: <leader>tm"
  end)
end

return M
