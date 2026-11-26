-- Build the coverage preset, run GoogleTest via ctest, produce lcov with gcovr,
-- then load it into nvim-coverage (signs in the gutter + :CoverageSummary).
local M = {}

local function build_dir()
  return vim.g.cpp_coverage_build_dir or "build/coverage"
end

function M.lcov_file()
  return vim.fs.joinpath(vim.uv.cwd(), build_dir(), "coverage.info")
end

function M.load()
  local file = M.lcov_file()
  if not vim.uv.fs_stat(file) then
    vim.notify("No coverage file: " .. file .. "\nRun <leader>tC first.", vim.log.levels.WARN)
    return
  end
  local cov = require("coverage")
  if cov.load_lcov then
    cov.load_lcov(file, true)
  else
    vim.cmd("CoverageLoadLcov " .. vim.fn.fnameescape(file))
  end
end

function M.run()
  local root = vim.uv.cwd()
  local cmd
  if vim.uv.fs_stat(root .. "/CMakePresets.json") then
    cmd = "cmake --preset coverage && cmake --build --preset coverage --target coverage"
  else
    local b = build_dir()
    cmd = ("cmake -S . -B %s -DCMAKE_BUILD_TYPE=Debug -DBUILD_TESTS=ON -DENABLE_COVERAGE=ON"
      .. " && cmake --build %s --target coverage"):format(b, b)
  end
  require("util.run").shell(cmd, "Coverage", function()
    M.load()
  end, function(out)
    -- only show gcovr's summary lines
    local lines = {}
    for line in out:gmatch("[^\n]+") do
      if line:match("^lines:") or line:match("^functions:") or line:match("^branches:") then
        table.insert(lines, line)
      end
    end
    return table.concat(lines, "\n")
  end)
end

return M
