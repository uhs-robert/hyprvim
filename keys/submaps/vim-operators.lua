-- keys/submaps/vim-operators.lua
-- DELETE, CHANGE, YANK operators with nested I/A/G sub-submaps

local Submap = require("hyprvim.lib.submap") ---@class HyprVimSubmap
local vim = require("hyprvim.vim") ---@class Vim
local motion = vim.motion
local count = vim.count
local reg = vim.registers
local Hypr = require("hyprvim.hypr") ---@class HyprVimHyprland
local common = require("hyprvim.keys.submaps.common")

local send = Hypr.send

local footer = common.footer()

-- Selection recipes live in vim/lib/motion/shortcuts.lua (SELECT table).
-- The AROUND submaps reuse the inner objects, so aw/ap currently behave like
-- iw/ip; true around-objects would need trailing-whitespace handling.
local SEL = motion.shortcuts.SELECT

-- Select [count]× sel via send_burst, then run the operator action.
local function sel_then(sel, action)
  return function()
    local keys = {}
    for _ = 1, count.get() do
      keys[#keys + 1] = sel
    end
    Hypr.send_burst(keys, action)
  end
end

-- Count-insensitive: clear count, select once, then act.
local function sel1_then(sel, action)
  return function()
    count.clear()
    Hypr.send_burst({ sel }, action)
  end
end

-- Send a fixed selection sequence, then act.
local function seq_then(seq, action)
  return function() Hypr.send_burst(seq, action) end
end

-- Select to the count-th word end: n-1 next_word extensions, then the one-shot
-- word_end recipe (VISUAL.e can't serve here: its repeat-friendly alias of w
-- would eat the trailing space).
local function word_end_then(action)
  return function()
    local keys = {}
    for _ = 2, count.get() do
      keys[#keys + 1] = SEL.next_word
    end
    for _, s in ipairs(SEL.word_end) do
      keys[#keys + 1] = s
    end
    Hypr.send_burst(keys, action)
  end
end

--- Build and register the I/A/G sub-submaps for one operator.
--- @param op_name  string  parent submap name (e.g. "DELETE")
--- @param on_word  fun()   action for word text objects
--- @param on_para  fun()   action for paragraph text objects
--- @param on_first fun()   action for first-line goto
--- @param on_last  fun()   action for last-line goto
local function make_sub_submaps(op_name, on_word, on_para, on_first, on_last)
  local text_obj_rows = function()
    -- A count extends the object forward: 3iw ~ word + next 2 words.
    local function obj(seq, ext, action)
      return function()
        local n = count.get()
        local keys = {}
        for _, s in ipairs(seq) do
          keys[#keys + 1] = s
        end
        for _ = 2, n do
          keys[#keys + 1] = ext
        end
        Hypr.send_burst(keys, action)
      end
    end
    local word = obj(SEL.inner_word, SEL.next_word, on_word)
    local para = obj(SEL.inner_para, SEL.next_para, on_para)
    -- stylua: ignore start
    local rows = {
      { "w",         word, "Word" },
      { "SHIFT + w", word },
      { "p",         para, "Paragraph" },
      { "SHIFT + p", para },
    }
    -- stylua: ignore end
    for _, row in ipairs(footer) do
      table.insert(rows, row)
    end
    return rows
  end

  Submap.define({
    name = op_name .. "-INSIDE",
    operator = true,
    escape = "NORMAL",
    back = op_name,
    catchall = "stay",
    binds = text_obj_rows(),
  }).setup()

  Submap.define({
    name = op_name .. "-AROUND",
    operator = true,
    escape = "NORMAL",
    back = op_name,
    catchall = "stay",
    binds = text_obj_rows(),
  }).setup()

  Submap.define({
    name = op_name .. "-GOTO",
    operator = true,
    escape = "NORMAL",
    back = op_name,
    catchall = "stay",
    binds = function()
      local rows = {
        -- stylua: ignore start
        { "g",         seq_then({ SEL.first_line }, on_first), "First line" },
        { "SHIFT + g", seq_then({ SEL.last_line }, on_last),  "Last line"  },
        -- stylua: ignore end
      }
      for _, row in ipairs(footer) do
        table.insert(rows, row)
      end
      return rows
    end,
  }).setup()
end

-- ---------------------------------------------------------------------------
-- DELETE
-- ---------------------------------------------------------------------------

local function del(after)
  return function() reg.handle_delete(after) end
end

Submap.define({
  name = "DELETE",
  operator = true,
  escape = "NORMAL",
  back = "previous",
  catchall = "stay",
  binds = function()
    local rows = {
      -- stylua: ignore start
      { "w",         sel_then(SEL.next_word, del("NORMAL")), "Next word" },
      { "SHIFT + w", sel_then(SEL.next_word, del("NORMAL")) },
      { "e",         word_end_then(del("NORMAL")), "Next end of word" },
      { "SHIFT + e", word_end_then(del("NORMAL")) },
      { "b",         sel_then(SEL.prev_word, del("NORMAL")), "Prev word" },
      { "SHIFT + b", sel_then(SEL.prev_word, del("NORMAL")) },
      { "d",         seq_then(SEL.line, function() del("NORMAL")() send("", "BackSpace") send("", "DOWN") end), "Delete line" },
      { "SHIFT + 4", sel1_then(SEL.to_eol, del("NORMAL")), "End of line"   },
      { "SHIFT + 6", sel1_then(SEL.to_bol, del("NORMAL")), "Start of line" },
      { "0",         sel1_then(SEL.to_bol, del("NORMAL")), "Start of line" },
      { "SHIFT + g", sel1_then(SEL.last_line, del("NORMAL")), "Last line" },
      { "m",         function() count.clear() vim.marks.set_after("NORMAL") vim.marks.enter_delete() end, "+Delete Mark" },
      { "i",         function() Submap.enter("DELETE-INSIDE") end, "+Inner" },
      { "SHIFT + i", function() Submap.enter("DELETE-INSIDE") end },
      { "a",         function() Submap.enter("DELETE-AROUND") end, "+Around" },
      { "SHIFT + a", function() Submap.enter("DELETE-AROUND") end },
      { "g",         function() count.clear() Submap.enter("DELETE-GOTO") end, "+Go" },
      -- stylua: ignore end
    }
    for _, row in ipairs(footer) do
      table.insert(rows, row)
    end
    return rows
  end,
}).setup()

make_sub_submaps("DELETE", del("NORMAL"), del("NORMAL"), del("NORMAL"), del("NORMAL"))

-- ---------------------------------------------------------------------------
-- CHANGE
-- ---------------------------------------------------------------------------

Submap.define({
  name = "CHANGE",
  operator = true,
  escape = "NORMAL",
  back = "previous",
  catchall = "stay",
  binds = function()
    local rows = {
      -- stylua: ignore start
      { "w",         sel_then(SEL.next_word, del("INSERT")), "Next word" },
      { "SHIFT + w", word_end_then(del("INSERT")) },
      { "e",         word_end_then(del("INSERT")), "End of next word" },
      { "b",         sel_then(SEL.prev_word, del("INSERT")), "Prev word" },
      { "SHIFT + b", sel_then(SEL.prev_word, del("INSERT")) },
      { "c",         seq_then(SEL.line, del("INSERT")), "Change line" },
      { "SHIFT + 4", sel1_then(SEL.to_eol, del("INSERT")), "End of line"   },
      { "SHIFT + 6", sel1_then(SEL.to_bol, del("INSERT")), "Start of line" },
      { "0",         sel1_then(SEL.to_bol, del("INSERT")), "Start of line" },
      { "SHIFT + g", sel1_then(SEL.last_line, del("INSERT")), "Last line" },
      { "i",         function() Submap.enter("CHANGE-INSIDE") end, "+Inner" },
      { "SHIFT + i", function() Submap.enter("CHANGE-INSIDE") end },
      { "a",         function() Submap.enter("CHANGE-AROUND") end, "+Around" },
      { "SHIFT + a", function() Submap.enter("CHANGE-AROUND") end },
      { "g",         function() count.clear() Submap.enter("CHANGE-GOTO") end, "+Go" },
      -- stylua: ignore end
    }
    for _, row in ipairs(footer) do
      table.insert(rows, row)
    end
    return rows
  end,
}).setup()

make_sub_submaps("CHANGE", del("INSERT"), del("INSERT"), del("INSERT"), del("INSERT"))

-- ---------------------------------------------------------------------------
-- YANK
-- ---------------------------------------------------------------------------

-- collapse=false only for linewise yank, which positions the cursor itself.
local function yank(after, collapse)
  if collapse == nil then collapse = true end
  return function() reg.handle_yank("CTRL", "c", { return_mode = after, collapse = collapse }) end
end

Submap.define({
  name = "YANK",
  operator = true,
  escape = "NORMAL",
  back = "previous",
  catchall = "stay",
  binds = function()
    -- stylua: ignore start
    local rows = {
      { "w",         sel_then(SEL.next_word, yank("NORMAL")), "Next word" },
      { "e",         word_end_then(yank("NORMAL")), "Next end of word" },
      { "b",         sel_then(SEL.prev_word, yank("NORMAL")), "Prev word" },
      { "SHIFT + w", sel_then(SEL.next_word, yank("NORMAL")) },
      { "SHIFT + e", word_end_then(yank("NORMAL")) },
      { "SHIFT + b", sel_then(SEL.prev_word, yank("NORMAL")) },
      { "y",         seq_then(SEL.line, function() yank("NORMAL", false)() send("", "DOWN") end), "Yank line" },
      { "SHIFT + 4", sel1_then(SEL.to_eol, yank("NORMAL")), "End of line"   },
      { "0",         sel1_then(SEL.to_bol, yank("NORMAL")), "Start of line" },
      { "SHIFT + 6", sel1_then(SEL.to_bol, yank("NORMAL")), "Start of line" },
      { "SHIFT + g", sel1_then(SEL.last_line, yank("NORMAL")), "Last line" },
      { "i",         function() Submap.enter("YANK-INSIDE") end, "+Inner" },
      { "SHIFT + i", function() Submap.enter("YANK-INSIDE") end },
      { "a",         function() Submap.enter("YANK-AROUND") end, "+Around" },
      { "SHIFT + a", function() Submap.enter("YANK-AROUND") end },
      { "g",         function() count.clear() Submap.enter("YANK-GOTO") end, "+Go" },
      -- stylua: ignore end
    }
    for _, row in ipairs(footer) do
      table.insert(rows, row)
    end
    return rows
  end,
}).setup()

make_sub_submaps("YANK", yank("NORMAL"), yank("NORMAL"), yank("NORMAL"), yank("NORMAL"))
