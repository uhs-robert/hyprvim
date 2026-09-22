-- keys/submaps/modes/v-line.lua
-- V-LINE, G-VLINE submaps

local Submap = require("hyprvim.lib.submap") ---@class HyprVimSubmap
local vim = require("hyprvim.vim") ---@class Vim
local motion = vim.motion
local count = vim.count
local lm = vim.line_motion
local reg = vim.registers
local wk = require("hyprvim.whichkey") ---@class WhichKey
local Hypr = require("hyprvim.hypr") ---@class HyprVimHyprland
local common = require("hyprvim.keys.submaps.common")

local LEADER = common.keys()

local send = Hypr.send
local VS = motion.shortcuts.VISUAL
local SEL = motion.shortcuts.SELECT
local function normal() Submap.enter("NORMAL") end
local function vline() Submap.enter("V-LINE") end
local function visual() Submap.enter("VISUAL") end

local footer = common.footer()

-- ---------------------------------------------------------------------------
-- V-LINE
-- ---------------------------------------------------------------------------

Submap.define({
  name = "V-LINE",
  sticky = true,
  on_enter = function(ctx)
    if ctx.from == "G-VLINE" then return end -- keep the line-selection anchor on return from G-VLINE
    count.clear()
    if ctx.from == "VISUAL" then
      lm.reset()
      return
    end
    lm.setup()
  end,
  escape = function()
    lm.reset()
    motion.send_sequence(SEL.deselect)
    normal()
  end,
  back = "escape",
  catchall = "stay",
  binds = function()
    local rows = {
      -- stylua: ignore start
      -- Editor
      { LEADER .. " + n", vim.editor.open_from_submap(),                  "Edit in Vim (Normal)" },
      { LEADER .. " + i", vim.editor.open_from_submap({ insert = true }), "Edit in Vim (Insert)" },
      -- Mode switches
      { "v", function() lm.reset() send("SHIFT", "HOME") visual() end, "Visual mode" },
      -- Motions
      { "j",                    function() lm.down(count.get()) end,           "Down",           { repeating = true } },
      { "k",                    function() lm.up(count.get()) end,             "Up",             { repeating = true } },
      { "SHIFT + BRACKETLEFT",  function() lm.paragraph_up(count.get()) end,   "Prev paragraph" },
      { "SHIFT + BRACKETRIGHT", function() lm.paragraph_down(count.get()) end, "Next paragraph" },
      { "CTRL + e",             function() motion.send_raw(VS["CTRL + e"]) end, "Page down", { repeating = true } },
      { "CTRL + y",             function() motion.send_raw(VS["CTRL + y"]) end, "Page up",   { repeating = true } },
      { "SHIFT + g",            function() lm.goto_end() vline() end, "Last line", { repeating = true } },
      -- Undo
      { "u",       function() motion.send("u") end,          "Undo", { repeating = true } },
      { "CTRL + r", function() motion.send("CTRL + r") end,  "Redo", { repeating = true } },
      -- Change / delete / yank / paste
      { "c",         function() lm.reset() reg.handle_delete("INSERT") end },
      { "SHIFT + x", function() wk.close() lm.reset() reg.handle_delete("NORMAL") end, "BackSpace", { repeating = true } },
      { "x",         function() lm.reset() reg.handle_delete("NORMAL") end, nil, { repeating = true } },
      { "d",         function() lm.reset() reg.handle_delete("NORMAL") end, "Delete", { repeating = true } },
      { "SHIFT + d", function() lm.reset() motion.send_raw(VS.H) send("", "Delete") normal() end, "Delete to line start" },
      { "y",         function() lm.reset() reg.handle_yank("CTRL", "c", { collapse = true }) end, "Yank", { repeating = true } },
      { "p",         function() reg.handle_paste("CTRL", "v", "NORMAL") end, "Paste", { repeating = true } },
      -- Normal shortcuts passthrough
      { "CTRL + x", function() send("CTRL", "x") normal() end, nil, { repeating = true } },
      { "CTRL + p", function() send("CTRL", "v") normal() end, nil, { repeating = true } },
      { "CTRL + v", function() send("CTRL", "v") normal() end, nil, { repeating = true } },
      { "CTRL + b", function() send("CTRL", "b") end, nil, { repeating = true } },
      { "CTRL + i", function() send("CTRL", "i") end, nil, { repeating = true } },
      { "CTRL + u", function() send("CTRL", "u") end, nil, { repeating = true } },
      { "CTRL + s", function() send("CTRL", "s") end, nil, { repeating = true } },
      -- G-VLINE
      { "g",         Submap.switch("G-VLINE"), "+Go Line" },
      -- stylua: ignore end
    }
    for i = 0, 9 do
      table.insert(rows, { tostring(i), function() count.append(tostring(i)) end })
    end
    for _, row in ipairs(footer) do
      table.insert(rows, row)
    end
    return rows
  end,
}).setup()

-- ---------------------------------------------------------------------------
-- G-VLINE
-- ---------------------------------------------------------------------------

Submap.define({
  name = "G-VLINE",
  escape = "NORMAL",
  back = "previous",
  catchall = "stay",
  binds = function()
    local rows = {
    -- stylua: ignore start
    { "g",         function() lm.goto_start() vline() end, "First line" },
    { "SHIFT + g", function() lm.goto_end()   vline() end, "Last line"  },
    { "n",         vim.editor.open_from_submap(),                  "Edit in Vim (Normal)" },
    { "i",         vim.editor.open_from_submap({ insert = true }), "Edit in Vim (Insert)" },
      -- stylua: ignore end
    }
    for _, row in ipairs(footer) do
      table.insert(rows, row)
    end
    return rows
  end,
}).setup()
