-- keys/submaps/modes/visual.lua
-- VISUAL, V-I, V-A submaps

local Submap = require("hyprvim.lib.submap") ---@class HyprVimSubmap
local vim = require("hyprvim.vim") ---@class Vim
local motion = vim.motion
local count = vim.count
local reg = vim.registers
local wk = require("hyprvim.whichkey") ---@class WhichKey
local Hypr = require("hyprvim.hypr") ---@class HyprVimHyprland
local common = require("hyprvim.keys.submaps.common")
local LEADER = common.keys()

local send = Hypr.send

local normal = Submap.switch("NORMAL")
local va = motion.action_visual
local vm = motion.action
local va_seq = motion.action_seq
local VS = motion.shortcuts.VISUAL
local SEL = motion.shortcuts.SELECT

-- ── Visual actions ────────────────────────────────────────────────────────────
-- stylua: ignore start
local function change_sel()    reg.handle_delete("INSERT") end
local function delete_sel()    reg.handle_delete("NORMAL") end
local function backspace_sel() wk.close() reg.handle_delete("NORMAL") end
local function delete_bol()    motion.send_raw(VS.H) send("", "Delete") normal() end
local function yank_sel()      reg.handle_yank("CTRL", "c", { collapse = true }) end
local function yank_bol()      motion.send_sequence(SEL.line_from_end) reg.handle_yank("CTRL", "c", { collapse = true }) end
local function paste_sel()     reg.handle_paste("CTRL", "v", "NORMAL") end
local function sel_bol()       motion.send_raw(VS.H) end
local function sel_eol()       motion.send_raw(VS.L) end
local function sel_page_down() motion.send_raw(VS["CTRL + e"]) end
local function sel_page_up()   motion.send_raw(VS["CTRL + y"]) end
local function sel_last_line() motion.send_raw(VS.G) end

---Return an action that passes a CTRL+key shortcut through without leaving visual mode.
---@param key string
---@return fun()
local function fmt(key) return function() send("CTRL", key) end end

---Return an action that passes a CTRL+key shortcut and returns to normal mode.
---@param key string
---@return fun()
local function passthrough(key) return function() send("CTRL", key) normal() end end
-- stylua: ignore end

local footer = common.footer()

-- ---------------------------------------------------------------------------
-- VISUAL
-- ---------------------------------------------------------------------------

Submap.define({
  name = "VISUAL",
  sticky = true,
  on_enter = function() count.clear() end,
  escape = function()
    motion.send_sequence(SEL.deselect)
    normal()
  end,
  back = function()
    wk.close()
    normal()
  end,
  catchall = "stay",
  binds = function()
    local rows = {
      -- stylua: ignore start
      -- Count
      { "0", count.handle_zero_visual },
      -- Mode switches
      { "g", Submap.switch("G-VISUAL"), "+Goto" },
      { "SHIFT + v", function() Hypr.send_burst({ { "SHIFT", "HOME" }, { "SHIFT", "END" } }, Submap.switch("V-LINE")) end, "V-Line mode" },
      -- Editor
      { LEADER .. " + n", vim.editor.open_from_submap(),                  "Edit in Vim (Normal)" },
      { LEADER .. " + i", vim.editor.open_from_submap({ insert = true }), "Edit in Vim (Insert)" },
      -- Char motions
      { "h",         va("h"), "Left",          { repeating = true } },
      { "j",         va("j"), "Down",          { repeating = true } },
      { "k",         va("k"), "Up",            { repeating = true } },
      { "l",         va("l"), "Right",         { repeating = true } },
      { "SHIFT + h", va("H"), "Start of line", { repeating = true } },
      { "SHIFT + j", va("J"), "J",             { repeating = true } },
      { "SHIFT + k", va("K"), "K",             { repeating = true } },
      { "SHIFT + l", va("L"), "End of line",   { repeating = true } },
      -- Word
      { "b",         va("b"), "Prev word",     { repeating = true } },
      { "e",         va("e"), "Next end word", { repeating = true } },
      { "w",         va("w"), "Next word",     { repeating = true } },
      { "SHIFT + b", va("B"), nil,             { repeating = true } },
      { "SHIFT + e", va("E"), nil,             { repeating = true } },
      { "SHIFT + w", va("W"), nil,             { repeating = true } },
      -- Paragraph
      { "SHIFT + BRACKETLEFT",  va_seq({ { "SHIFT", "HOME" }, { "CTRL SHIFT", "UP" } }),   "Paragraph start", { repeating = true } },
      { "SHIFT + BRACKETRIGHT", va_seq({ { "SHIFT", "END" },  { "CTRL SHIFT", "DOWN" } }), "Paragraph end",   { repeating = true } },
      -- Line / page
      { "SHIFT + MINUS", sel_bol,       "Start of line", { repeating = true } },
      { "SHIFT + 4",     sel_eol,       "End of line",   { repeating = true } },
      { "CTRL + e",      sel_page_down, "Page down",     { repeating = true } },
      { "CTRL + y",      sel_page_up,   "Page up",       { repeating = true } },
      { "SHIFT + g",     sel_last_line, "Last line",     { repeating = true } },
      -- Undo
      { "u",        vm("u"),        "Undo", { repeating = true } },
      { "SHIFT + u", vm("u"),       nil,    { repeating = true } },
      { "CTRL + r",  vm("CTRL + r"), "Redo", { repeating = true } },
      -- Change / delete / yank / paste
      { "c",         change_sel,    "Change"                                  },
      { "SHIFT + x", backspace_sel, "BackSpace",  { repeating = true }        },
      { "x",         delete_sel,    nil,          { repeating = true }        },
      { "d",         delete_sel,    "Delete",     { repeating = true }        },
      { "SHIFT + d", delete_bol,    "Delete to line start"                    },
      { "y",         yank_sel,      "Yank"                                    },
      { "SHIFT + y", yank_bol,      "Yank to line start"                      },
      { "p",         paste_sel,     "Paste",      { repeating = true }        },
      { "SHIFT + p", paste_sel,     nil,          { repeating = true }        },
      -- Normal shortcuts passthrough
      { "CTRL + x", passthrough("x"), nil, { repeating = true } },
      { "CTRL + p", passthrough("v"), nil, { repeating = true } },
      { "CTRL + v", passthrough("v"), nil, { repeating = true } },
      { "CTRL + b", fmt("b"),         nil, { repeating = true } },
      { "CTRL + i", fmt("i"),         nil, { repeating = true } },
      { "CTRL + u", fmt("u"),         nil, { repeating = true } },
      { "CTRL + s", fmt("s"),         nil, { repeating = true } },
      -- Sub-submaps
      { "i",         Submap.switch("V-INSIDE"), "+Inner"  },
      { "SHIFT + i", Submap.switch("V-INSIDE")            },
      { "a",         Submap.switch("V-AROUND"), "+Around" },
      { "SHIFT + a", Submap.switch("V-AROUND")            },
      -- stylua: ignore end
    }
    for i = 1, 9 do
      table.insert(rows, { tostring(i), function() count.append(tostring(i)) end })
    end
    for _, row in ipairs(footer) do
      table.insert(rows, row)
    end
    return rows
  end,
}).setup()

-- ---------------------------------------------------------------------------
-- V-INSIDE / V-AROUND (text objects in visual mode)
-- ---------------------------------------------------------------------------

---@param name        string   submap name
---@param parent_name string   submap to return to after selection
---@param objects     { [1]: string, [2]: Shortcut[], [3]?: string, [4]?: Shortcut }[]  { key, seq, label?, ext? }
local function visual_text_object(name, parent_name, objects)
  local parent = Submap.switch(parent_name)
  local binds = { table.unpack(footer) }
  for _, obj in ipairs(objects) do
    local key, seq, label, ext = obj[1], obj[2], obj[3], obj[4]
    local act = function()
      local n = count.get()
      motion.send_sequence(seq)
      if ext and n > 1 then motion.send_raw(ext, n - 1) end
      parent()
    end
    table.insert(binds, { key, act, label })
    table.insert(binds, { "SHIFT + " .. key, act })
  end
  Submap.define({
    name = name,
    escape = "NORMAL",
    back = "previous",
    catchall = "stay",
    binds = binds,
  }).setup()
end

-- Around objects reuse the inner recipes, matching the operator submaps.
visual_text_object("V-INSIDE", "VISUAL", {
  { "w", SEL.inner_word, "Word", SEL.next_word },
  { "p", SEL.inner_para, "Paragraph", SEL.next_para },
})

visual_text_object("V-AROUND", "VISUAL", {
  { "w", SEL.inner_word, "Word", SEL.next_word },
  { "p", SEL.inner_para, "Paragraph", SEL.next_para },
})
