-- keys/submaps/vim-marks.lua
-- SET-MARK, MARKS (jump), DELETE-MARK

local Submap = require("hyprvim.lib.submap") ---@class HyprVimSubmap
local vim = require("hyprvim.vim") ---@class Vim
local marks = vim.marks
local common = require("hyprvim.keys.submaps.common")

local lowercase = "abcdefghijklmnopqrstuvwxyz"
local uppercase = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
local digits = "0123456789"

--- Build the rows that never change between refreshes.
local function static_rows(name)
  local rows = {}
  if name == "DELETE-MARK" then
    table.insert(rows, { "DELETE", function() marks.clear() end, "Clear all marks" })
    table.insert(rows, { "SHIFT + DELETE", function() marks.clear() end })
  else
    table.insert(rows, { "BackSpace", function() marks.dispatch_after() end })
  end
  for _, row in ipairs(common.footer()) do
    table.insert(rows, row)
  end
  return rows
end

--- Build dynamic letter/digit rows for all chars.
---
--- SET-MARK (only_existing=false): existing=nil, all chars bound with action, desc=plain char.
--- MARKS/DELETE-MARK (only_existing=true): all chars included; existing marks get action+desc,
--- non-existing get no-op+nil desc so hl.bind overwrites stale binds and whichkey hides them.
local function dynamic_rows(action, only_existing)
  local rows = {}
  local existing = only_existing and marks.all() or nil

  local function get_desc(c)
    if not existing then return c end
    local m = existing[c]
    if not m then return nil end
    local cls = (m.class ~= "" and m.class) or "?"
    return string.format("%s (ws:%d)", cls, m.workspace or 0)
  end

  local function get_action(c)
    if only_existing and existing and not existing[c] then
      return function() end
    end
    return function() action(c) end
  end

  for i = 1, #lowercase do
    local c = lowercase:sub(i, i)
    table.insert(rows, { c, get_action(c), get_desc(c) })
  end
  for i = 1, #uppercase do
    local c = uppercase:sub(i, i)
    table.insert(rows, { "SHIFT + " .. c:lower(), get_action(c), get_desc(c) })
  end
  for i = 1, #digits do
    local c = digits:sub(i, i)
    table.insert(rows, { c, get_action(c), get_desc(c) })
  end
  return rows
end

--- Register a mark submap.
--- For only_existing submaps: initial setup has static binds only; returns a refresh function
--- that registers a new hl.define_submap callback before each entry. Each refresh callback
--- re-binds ALL chars with current marks state (existing -> action+desc, missing -> no-op+nil),
--- so the latest callback overwrites stale binds from prior refreshes.
--- @param name          string
--- @param action        fun(c: string)
--- @param escape        "reset"|string|fun()
--- @param only_existing boolean
--- @return fun()|nil
local function mark_submap(name, action, escape, only_existing)
  Submap.define({
    name = name,
    escape = escape == "marks.exit" and function() marks.dispatch_after() end or escape,
    back = false,
    catchall = "stay",
    binds = function()
      local rows = static_rows(name)
      if not only_existing then
        for _, row in ipairs(dynamic_rows(action, false)) do
          table.insert(rows, row)
        end
      end
      return rows
    end,
  }).setup()

  if not only_existing then return end

  return function()
    hl.define_submap(name, function()
      for _, row in ipairs(dynamic_rows(action, true)) do
        hl.bind(row[1], row[2], { desc = row[3] })
      end
    end)
  end
end

mark_submap("SET-MARK", function(c) marks.set(c) end, "marks.exit", false)

local refresh_jump = mark_submap("MARKS", function(c) marks.jump(c) end, "marks.exit", true)
local refresh_delete = mark_submap("DELETE-MARK", function(c) marks.delete(c) end, "marks.exit", true)

marks.enter_set = function() Submap.enter("SET-MARK") end
marks.enter_jump = function()
  if refresh_jump then refresh_jump() end
  Submap.enter("MARKS")
end
marks.enter_delete = function()
  if refresh_delete then refresh_delete() end
  Submap.enter("DELETE-MARK")
end
