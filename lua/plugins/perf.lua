-- Profiling: perf record -> flamegraphs with filters, hotspot table, and
-- perfanno for heat-highlighted source lines.
return {
  {
    "t-troebst/perfanno.nvim",
    cmd = {
      "PerfLoadFlat", "PerfLoadCallGraph", "PerfLoadFlameGraph", "PerfPickEvent", "PerfCycleFormat",
      "PerfAnnotate", "PerfToggleAnnotations", "PerfAnnotateFunction", "PerfAnnotateSelection",
      "PerfHottestLines", "PerfHottestSymbols", "PerfHottestCallersFunction", "PerfHottestCallersSelection",
    },
    opts = function()
      local util = require("perfanno.util")
      local bg = vim.fn.synIDattr(vim.fn.hlID("Normal"), "bg", "gui")
      if bg == "" then
        bg = "#002b36" -- transparent theme: fall back to solarized base03
      end
      return {
        line_highlights = util.make_bg_highlights(bg, "#CC3300", 10), -- 10-step heat gradient
        vt_highlight = util.make_fg_highlight("#CC3300"),
        formats = {
          { percent = true, format = "%.2f%%", minimum = 0.5 },
          { percent = false, format = "%d", minimum = 1 },
        },
        annotate_after_load = true,
        annotate_on_open = true,
        thread_support = false,
      }
    end,
    init = function()
      local perf = function()
        return require("util.perf")
      end
      local cmd = vim.api.nvim_create_user_command

      cmd("PerfRecord", function(o) perf().record(o.args) end, { nargs = "*", desc = "perf record the launch target" })
      cmd("PerfAttach", function(o)
        if o.fargs[1] then
          perf().record(nil, { pid = tonumber(o.fargs[1]), seconds = tonumber(o.fargs[2]) or 10 })
        else
          perf().attach_prompt()
        end
      end, { nargs = "*", desc = "perf record -p PID [seconds]" })
      cmd("PerfFlame", function() perf().flamegraph() end, { desc = "Filtered flamegraph" })
      cmd("PerfFlameHot", function() perf().flamegraph({ hot_leaves = true }) end, { desc = "Hot-leaves icicle graph" })
      cmd("PerfDiff", function() perf().diff() end, { desc = "Differential flamegraph (old -> new)" })
      cmd("PerfHotspots", function() perf().hotspots() end, { desc = "Hotspot table" })
      cmd("PerfFilter", function(o)
        if #o.fargs == 0 then
          return perf().filter_menu()
        end
        local key = o.fargs[1]
        local value = vim.trim(o.args:sub(#key + 1))
        if perf().set_filter(key, value) then
          vim.notify(("perf filter %s = %s"):format(key, value), vim.log.levels.INFO, { title = "perf" })
        end
      end, {
        nargs = "*",
        desc = "perf filters: menu, or :PerfFilter <key> <value>",
        complete = function(arglead, line)
          if #vim.split(line, "%s+", { trimempty = true }) > (arglead == "" and 1 or 2) then
            return {}
          end
          return vim.tbl_filter(function(k)
            return k:find(arglead, 1, true) == 1
          end, perf().filter_keys())
        end,
      })
      cmd("PerfFilterReset", function()
        local p = perf()
        p.PRESETS[#p.PRESETS].apply(p.filters())
        p.set_filter("hide_kernel", true)
      end, { desc = "Reset perf filters" })
    end,
    keys = {
      -- recording / flamegraphs / filters (util.perf)
      { "<leader>pr", function() require("util.perf").record_prompt() end, desc = "perf record launch target" },
      { "<leader>pA", function() require("util.perf").attach_prompt() end, desc = "perf attach to PID" },
      { "<leader>ph", function() require("util.perf").hotspots() end, desc = "Hotspot table" },
      { "<leader>pf", function() require("util.perf").flamegraph() end, desc = "Flamegraph (filtered)" },
      { "<leader>pi", function() require("util.perf").flamegraph({ hot_leaves = true }) end, desc = "Hot leaves (icicle)" },
      { "<leader>pd", function() require("util.perf").diff() end, desc = "Diff flamegraph vs previous" },
      { "<leader>pF", function() require("util.perf").filter_menu() end, desc = "Filters…" },
      { "<leader>pX", "<cmd>PerfFilterReset<cr>", desc = "Reset filters" },
      -- source annotations (perfanno)
      { "<leader>pl", "<cmd>PerfLoadCallGraph<cr>", desc = "Annotate: load call graph" },
      { "<leader>pL", "<cmd>PerfLoadFlat<cr>", desc = "Annotate: load flat profile" },
      { "<leader>pt", "<cmd>PerfToggleAnnotations<cr>", desc = "Annotate: toggle" },
      { "<leader>pa", "<cmd>PerfAnnotateFunction<cr>", desc = "Annotate: current function" },
      { "<leader>pa", ":PerfAnnotateSelection<cr>", mode = "v", desc = "Annotate: selection" },
      { "<leader>pH", "<cmd>PerfHottestLines<cr>", desc = "Hottest source lines" },
      { "<leader>ps", "<cmd>PerfHottestSymbols<cr>", desc = "Hottest symbols" },
      { "<leader>pc", "<cmd>PerfHottestCallersFunction<cr>", desc = "Hottest callers of function" },
      { "<leader>pe", "<cmd>PerfPickEvent<cr>", desc = "Pick perf event" },
      { "<leader>pn", "<cmd>PerfCycleFormat<cr>", desc = "Cycle % / samples" },
    },
  },

  {
    "folke/which-key.nvim",
    opts = {
      spec = { { "<leader>p", group = "profile (perf)", icon = { icon = "󰈸 ", color = "red" } } },
    },
  },
}
