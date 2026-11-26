-- Resolve the executable to debug: CMake launch target first, otherwise ask.
local M = {}

function M.program_path()
  local ok, cmake = pcall(require, "cmake-tools")
  if ok and cmake.is_cmake_project and cmake.is_cmake_project() then
    local ok_path, path = pcall(cmake.get_launch_target_path)
    if ok_path and path and vim.fn.executable(path) == 1 then
      return path
    end
  end
  local p = vim.fn.input("Path to executable: ", vim.fn.getcwd() .. "/build/", "file")
  if p == nil or p == "" then
    return nil
  end
  return vim.fn.fnamemodify(p, ":p")
end

return M
