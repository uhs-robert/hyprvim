-- keys/submaps/modes/g-motion.lua

local Submap = require("hyprvim.lib.submap") ---@class HyprVimSubmap
local vim = require("hyprvim.vim") ---@class Vim
local Hypr = require("hyprvim.hypr") ---@class HyprVimHyprland
local common = require("hyprvim.keys.submaps.common")

local send = Hypr.send
local NM = vim.motion.shortcuts.NORMAL
local function normal() Submap.enter("NORMAL") end

Submap.define({
  name = "GOTO",
  operator = true,
  escape = "NORMAL",
  back = "previous",
  catchall = "stay",
  binds = {
    -- stylua: ignore start
    { "e",          function() vim.motion.send_sequence(NM.ge) normal() end, "Prev end of word" },
    { "SHIFT + t",  function() send("CTRL", "PAGE_UP")   normal() end, "Prev tab"   },
    { "t",          function() send("CTRL", "PAGE_DOWN") normal() end, "Next tab"   },
    { "g",          function() vim.motion.send_raw(NM.gg) normal() end, "Doc start"  },
    { "SHIFT + g",  function() vim.motion.send_raw(NM.G)  normal() end, "Last line"  },
    { "m",          function() vim.count.clear() vim.marks.list() normal() end, "Marks list" },
    table.unpack(common.footer()),
    -- stylua: ignore end
  },
}).setup()
