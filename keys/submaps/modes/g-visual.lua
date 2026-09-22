-- keys/submaps/modes/g-visual.lua

local Submap = require("hyprvim.lib.submap") ---@class HyprVimSubmap
local vim = require("hyprvim.vim") ---@class Vim
local common = require("hyprvim.keys.submaps.common")

local VS = vim.motion.shortcuts.VISUAL
local function visual() Submap.enter("VISUAL") end

Submap.define({
  name = "G-VISUAL",
  operator = true,
  escape = "VISUAL",
  back = "previous",
  catchall = "stay",
  binds = {
    -- stylua: ignore start
    { "e",         function() vim.motion.send_sequence(VS.ge) visual() end, "Prev end of word" },
    { "g",         function() vim.motion.send_raw(VS.gg) visual() end, "First line" },
    { "SHIFT + g", function() vim.motion.send_raw(VS.G)  visual() end, "Last line"  },
    { "n",         vim.editor.open_from_submap(),                  "Edit in Vim (Normal)" },
    { "i",         vim.editor.open_from_submap({ insert = true }), "Edit in Vim (Insert)" },
    table.unpack(common.footer()),
    -- stylua: ignore end
  },
}).setup()
