-- keys/submaps/modes/normal.lua

local Submap = require("hyprvim.lib.submap") ---@class HyprVimSubmap
local Bind = require("hyprvim.lib.bind") ---@class HyprVimBindLib
local vim = require("hyprvim.vim") ---@class Vim
local wk = require("hyprvim.whichkey") ---@class WhichKey
local Hypr = require("hyprvim.hypr") ---@class HyprVimHyprland
local common = require("hyprvim.keys.submaps.common")

local LEADER, _, EXIT = common.keys()

local send = Hypr.send
local cc = vim.count.clear_then_fn
local vm = vim.motion.action
local vm_seq = vim.motion.action_seq
local SEL = vim.motion.shortcuts.SELECT

---Send a `{mods, key}` pair [count] times via send_batch (20ms spacing).
---@param pair {[1]: {[1]: string, [2]: string}, [2]: {[1]: string, [2]: string}}
local function send_all_n(pair)
  local cmds = {}
  for _ = 1, vim.count.get() do
    cmds[#cmds + 1] = pair[1]
    cmds[#cmds + 1] = pair[2]
  end
  Hypr.send_batch(cmds)
end

-- ── Marks ─────────────────────────────────────────────────────────────────────
-- stylua: ignore start
local function set_mark()  vim.marks.set_after("NORMAL") Submap.enter("SET-MARK") end
local function jump_mark() vim.marks.set_after("NORMAL") vim.marks.enter_jump() end
local function goto_mark() vim.marks.set_after("reset")  vim.marks.enter_jump() end

-- ── Insert mode ───────────────────────────────────────────────────────────────
local function insert_at_cursor() Submap.enter("INSERT") end
local function insert_after()     Submap.enter("INSERT") send("", "RIGHT") end
local function insert_eol()       Submap.enter("INSERT") send("", "END") end
local function insert_bol()       Submap.enter("INSERT") send("", "HOME") end
local function open_below()    Hypr.send_batch({ { "", "END" }, { "", "Return" } }, nil, function() Submap.enter("INSERT") end) end
local function open_above()    Hypr.send_batch({ { "", "HOME" }, { "", "Return" }, { "", "Up" } }, nil, function() Submap.enter("INSERT") end) end
local function open_below_se() Hypr.send_batch({ { "", "END" }, { "SHIFT", "Return" } }, nil, function() Submap.enter("INSERT") end) end
local function open_above_se() Hypr.send_batch({ { "", "HOME" }, { "SHIFT", "Return" }, { "", "Up" } }, nil, function() Submap.enter("INSERT") end) end

-- ── Change / delete / paste / indent ─────────────────────────────────────────
local function change_eol()
  vim.count.clear()
  Hypr.send_burst({ SEL.to_eol }, function() vim.registers.handle_delete("INSERT") end)
end
local function delete_eol()
  Hypr.send_burst({ SEL.to_eol }, function() vim.registers.handle_delete("NORMAL") end)
end
local function delete_before()
  local n = vim.count.get()
  local cmds = {}
  for _ = 1, n do cmds[#cmds + 1] = SEL.prev_char end
  Hypr.send_burst(cmds, function() vim.registers.handle_delete("NORMAL") end)
end
local function delete_under()
  local n = vim.count.get()
  local cmds = {}
  for _ = 1, n do cmds[#cmds + 1] = SEL.next_char end
  Hypr.send_burst(cmds, function() vim.registers.handle_delete("NORMAL") end)
end
local function paste()         vim.registers.handle_paste("CTRL", "v", "NORMAL", vim.count.get()) end
local function indent_line()   Hypr.send_batch({ { "", "HOME" }, { "", "TAB" } }) end
local function unindent_line() Hypr.send_batch({ { "", "HOME" }, { "SHIFT", "TAB" } }) end

-- ── Misc ──────────────────────────────────────────────────────────────────────
local function line_start()     vim.count.clear() send("", "HOME") end
local function line_end()       vim.count.clear() send("", "END") end
local function last_line()      vim.count.clear() send("CTRL", "END") end
local function backspace_move() wk.close() vim.motion.send("h") end
local function escape_gui()     vim.count.clear() send("", "ESCAPE") end
local function escape_normal()  vim.count.clear() wk.close() vim.find.deactivate() Hypr.send("", "Escape", "activewindow") end
local function alt_passthrough(key) return function() send("ALT", key) end end
-- stylua: ignore end

Submap.define({
  name = "NORMAL",
  sticky = true,
  escape = false,
  catchall = "stay",
  on_enter = function(ctx)
    if ctx.from == "reset" then require("hyprvim.lib.clipboard").save_pre_vim() end
  end,
  on_exit = function(ctx)
    local keep = { GOTO = true, CHANGE = true, YANK = true, DELETE = true, ["R-CHAR"] = true }
    if not keep[ctx.to] then vim.count.clear() end
  end,
  binds = function()
    -- stylua: ignore start
    Bind.key("h",          vm("h"),                          "Left")
    Bind.key("j",          vm("j"),                          "Down")
    Bind.key("k",          vm("k"),                          "Up")
    Bind.key("l",          vm("l"),                          "Right")
    Bind.key("SHIFT + h",  vm("0", { clear_count = true }),  "Start of line")
    Bind.key("SHIFT + j",  function() send_all_n({ { "", "HOME" }, { "", "DOWN" } }) end, "Down to next line start", { repeating = true })
    Bind.key("SHIFT + k",  function() send_all_n({ { "CTRL", "UP" },   { "", "HOME" } }) end, "Up to prev line start",   { repeating = true })
    Bind.key("SHIFT + l",  vm("$", { clear_count = true }),  "End of line")
    Bind.key("CTRL + h",   vm_seq({ { "CTRL", "LEFT" } }), "Ctrl left", { repeating = true })
    Bind.key("CTRL + j",   vm_seq({ { "CTRL", "DOWN" } }), "Ctrl down", { repeating = true })
    Bind.key("CTRL + k",   vm_seq({ { "CTRL", "UP" } }), "Ctrl up", { repeating = true })
    Bind.key("CTRL + l",   vm_seq({ { "CTRL", "RIGHT" } }), "Ctrl right", { repeating = true })
    Bind.key("b",          vm("b"),  "Prev word",        { repeating = true })
    Bind.key("e",          vm("e"),  "Next end of word", { repeating = true })
    Bind.key("w",          vm("w"),  "Next word",        { repeating = true })
    Bind.key("SHIFT + b",  vm("B"),  "Prev WORD",        { repeating = true })
    Bind.key("SHIFT + e",  vm("E"),  "Next end of WORD", { repeating = true })
    Bind.key("SHIFT + w",  vm("W"),  "Next WORD",        { repeating = true })
    Bind.key("CTRL + d",   vm("CTRL + d"), "Scroll down", { repeating = true })
    Bind.key("CTRL + f",   vm("CTRL + f"), "Scroll down", { repeating = true })
    Bind.key("CTRL + e",   vm("CTRL + e"), "Scroll down", { repeating = true })
    Bind.key("CTRL + u",   vm("CTRL + u"), "Scroll up",   { repeating = true })
    Bind.key("CTRL + b",   vm("CTRL + b"), "Scroll up",   { repeating = true })
    Bind.key("CTRL + y",   vm("CTRL + y"), "Scroll up",   { repeating = true })
    Bind.key("SHIFT + BRACKETLEFT",  vm("{"), "Paragraph start", { repeating = true })
    Bind.key("SHIFT + BRACKETRIGHT", vm("}"), "Paragraph end",   { repeating = true })
    Bind.key("u",          vm("u"),        "Undo", { repeating = true })
    Bind.key("CTRL + r",   vm("CTRL + r"), "Redo", { repeating = true })
    -- stylua: ignore end

    for i = 1, 9 do
      local s = tostring(i)
      Bind.key(s, function() vim.count.append(s) end)
    end

    -- stylua: ignore start
    return {
      { "SPACE", wk.toggle },

      -- Mode switches
      { "G",                  Submap.switch("GOTO"),      "+Goto"           },
      { "C",                  Submap.switch("CHANGE"),    "+Change"         },
      { "Y",                  Submap.switch("YANK"),      "+Yank"           },
      { "D",                  Submap.switch("DELETE"),    "+Delete"         },
      { "V",                  Submap.switch("VISUAL"),    "+Visual"         },
      { "SHIFT + V",          Submap.switch("V-LINE"),    "+V-Line"         },
      { "SHIFT + APOSTROPHE", function() vim.registers.enter_registers() end, "+Registers" },
      { "M",          set_mark,  "+Set-Mark"        },
      { "APOSTROPHE", jump_mark, "+Marks"           },
      { "GRAVE",      goto_mark, "+Marks then exit" },

      -- Find
      { "f",             cc(vim.find.char_forward),    "Find char forward"        },
      { "SHIFT + f",     cc(vim.find.char_backward),   "Find char backward"       },
      { "t",             cc(vim.find.char_till_forward),    "Find till forward"        },
      { "SHIFT + t",     cc(vim.find.char_till_backward),   "Find till backward"       },
      { "n",             cc(vim.find.next_search),     "Next match"               },
      { "SHIFT + n",     cc(vim.find.prev_search),     "Prev match"               },
      { "SLASH",         cc(vim.find.search_forward),  "Search forward"           },
      { "SHIFT + SLASH", cc(vim.find.search_backward), "Search backward"          },
      { "SHIFT + 8",     cc(vim.find.forward_word),    "Search word forward (*)"  },
      { "SHIFT + 3",     cc(vim.find.backward_word),   "Search word backward (#)" },
      { "SEMICOLON",     cc(vim.find.next_char),       "Repeat find (;)"          },
      { "COMMA",         cc(vim.find.prev_char),       "Reverse find (,)"         },

      -- Commands
      { "R",                 Submap.switch("R-CHAR"), "+Replace Char"   },
      { "SHIFT + R",         vim.replace.string,     "Replace Forward"  },
      { "SHIFT + SEMICOLON", cc(vim.command.prompt), "Command mode (:)" },

      -- Vim editor
      { LEADER .. " + N", vim.editor.open_from_submap(),                  "Edit in Vim (Normal)" },
      { LEADER .. " + I", vim.editor.open_from_submap({ insert = true }), "Edit in Vim (Insert)" },

      -- Count: 0 is special (start-of-line vs digit)
      { "0", vim.count.handle_zero, "Start of line" },

      -- Line
      { "SHIFT + MINUS", line_start, "Start of line" },
      { "SHIFT + 6",     line_start, "Start of line" },
      { "SHIFT + 4",     line_end,   "End of line"   },
      { "SHIFT + g",     last_line,  "Last line"     },
      { "SHIFT + GRAVE", last_line,  "Last line"     },

      -- BackSpace
      { "BackSpace", backspace_move, nil, { repeating = true } },

      -- Insert mode
      { "i",                insert_at_cursor, "Insert before cursor"            },
      { "a",                insert_after,     "Insert after cursor"             },
      { "SHIFT + a",        insert_eol,       "Insert at end of line"           },
      { "SHIFT + i",        insert_bol,       "Insert at start of line"         },
      { "o",                open_below,       "Insert line below"               },
      { "SHIFT + o",        open_above,       "Insert line above"               },
      { "CTRL + o",         open_below_se,    "Insert line below (Shift+Enter)" },
      { "CTRL + SHIFT + o", open_above_se,    "Insert line above (Shift+Enter)" },

      -- Change / delete
      { "SHIFT + c", change_eol,    "Change to end of line"                    },
      { "SHIFT + d", delete_eol,    "Delete to end of line"                    },
      { "SHIFT + x", delete_before, "Delete char before", { repeating = true } },
      { "x",         delete_under,  "Delete char under",  { repeating = true } },

      -- Paste
      { "p",         paste, "Paste after cursor"  },
      { "SHIFT + p", paste, "Paste before cursor" },

      -- Indent
      { "SHIFT + PERIOD", indent_line,   "Indent line",   { repeating = true } },
      { "SHIFT + COMMA",  unindent_line, "Unindent line", { repeating = true } },

      -- GUI passthrough / helpers
      { "tab",         Bind.pass()       },
      { "SHIFT + tab", Bind.pass()       },
      { "RETURN",      Bind.pass()       },
      { "q",           escape_gui },
      { "CTRL + q",    Submap.switch("NORMAL") },
      { "CTRL + c",    escape_gui },
      { "ALT + h",     alt_passthrough("left") },
      { "ALT + j",     alt_passthrough("down") },
      { "ALT + k",     alt_passthrough("up") },
      { "ALT + l",     alt_passthrough("right") },

      -- Escape (non-consuming: sends Escape to the active window)
      { "ESCAPE", escape_normal, "Escape", { non_consuming = true } },

      -- Global exit from vim mode
      { LEADER .. " + " .. EXIT, vim.exit, nil, { release = true } },
    }
    -- stylua: ignore end
  end,
}).setup()
