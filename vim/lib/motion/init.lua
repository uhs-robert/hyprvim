-- vim/lib/motion/init.lua
-- Execute vim motions with count support and terminal vs GUI routing.

local VimCount = require("hyprvim.vim.lib.count") ---@class VimCount
local Hypr = require("hyprvim.hypr") ---@class HyprVimHyprland
local Window = require("hyprvim.hypr.window") ---@class HyprVimWindow
local sc = require("hyprvim.vim.lib.motion.shortcuts")

--- @class VimMotion
local VimMotion = {}

--- Vim key -> shortcut tables (NORMAL/VISUAL/SELECT), for submaps that dispatch raw.
VimMotion.shortcuts = sc

---Split a key string into `{mods, key}` for terminal dispatch.
---TERM_KEYSYMS takes priority (e.g. `{` -> CTRL+UP).
---`"CTRL + r"` -> `"CTRL"`, `"r"`. `"u"` -> `""`, `"u"`.
---@param key string
---@return string mods
---@return string k
local function split_key(key)
  local ts = sc.TERM_KEYSYMS[key]
  if ts then return ts[1], ts[2] end
  local parts = {}
  for p in key:gmatch("[^+]+") do
    parts[#parts + 1] = p:match("^%s*(.-)%s*$")
  end
  if #parts >= 2 then
    local k = table.remove(parts)
    return table.concat(parts, " "), k
  end
  return "", key
end

---Send a raw `{mods, key}` shortcut `n` times.
---@param shortcut {[1]: string, [2]: string}
---@param n        integer|nil  defaults to 1; pass `count.get()` for count support
function VimMotion.send_raw(shortcut, n)
  n = n or 1
  for _ = 1, n do
    Hypr.send(shortcut[1], shortcut[2])
  end
end

---Execute a normal-mode vim motion with count support.
---Terminals receive the raw key so the inner editor handles it natively.
---GUI apps receive the mapped shortcut from NORMAL shortcuts.
---@param key  string  vim motion key, e.g. `"j"`, `"w"`, `"gg"`, `"{"`
---@param opts { count?: integer, force_gui?: boolean, shortcut?: {[1]:string,[2]:string} }|nil
function VimMotion.send(key, opts)
  opts = opts or {}
  local n = opts.count or VimCount.get()

  if Window.is_terminal() and not opts.force_gui then
    local tmods, tkey = split_key(key)
    for _ = 1, n do
      hl.dispatch(hl.dsp.send_shortcut({ mods = tmods, key = tkey }))
    end
    return
  end

  local shortcut = opts.shortcut or sc.NORMAL[key]
  if not shortcut then return end

  if type(shortcut[1]) == "table" then
    ---@cast shortcut {[1]:string,[2]:string}[]
    local seq = {}
    for _ = 1, n do
      for _, s in ipairs(shortcut) do seq[#seq + 1] = s end
    end
    Hypr.send_burst(seq)
  else
    ---@cast shortcut {[1]:string,[2]:string}
    if n == 1 then
      Hypr.send(shortcut[1], shortcut[2])
    else
      local seq = {}
      for _ = 1, n do seq[#seq + 1] = shortcut end
      Hypr.send_burst(seq)
    end
  end
end

---Execute a visual-mode vim motion, always GUI (selection shortcuts never go to terminal).
---@param key string  vim motion key, e.g. `"h"`, `"w"`, `"H"` (= Shift+h binding)
---@param n   integer|nil  defaults to current count
function VimMotion.send_visual(key, n)
  n = n or VimCount.get()
  local shortcut = sc.VISUAL[key]
  if not shortcut then return end
  if type(shortcut[1]) == "table" then
    ---@cast shortcut {[1]:string,[2]:string}[]
    local seq = {}
    for _ = 1, n do
      for _, s in ipairs(shortcut) do seq[#seq + 1] = s end
    end
    Hypr.send_burst(seq)
  else
    ---@cast shortcut {[1]:string,[2]:string}
    if n == 1 then
      Hypr.send(shortcut[1], shortcut[2])
    else
      local seq = {}
      for _ = 1, n do seq[#seq + 1] = shortcut end
      Hypr.send_burst(seq)
    end
  end
end

---Send a GUI shortcut `n` times, bypassing terminal routing.
---@param mods string
---@param key  string
---@param n    integer|nil
function VimMotion.send_gui(mods, key, n)
  n = n or VimCount.get()
  for _ = 1, n do
    Hypr.send(mods, key)
  end
end

---Send multiple `{mods, key}` pairs in order, each exactly once.
---@param shortcuts {[1]: string, [2]: string}[]
function VimMotion.send_sequence(shortcuts) Hypr.send_burst(shortcuts) end

---Return a bind action that sends a visual-mode motion key (always GUI, extends selection).
---@param key string
---@return fun()
function VimMotion.action_visual(key)
  return function() VimMotion.send_visual(key) end
end

---Return a bind action that sends a single vim motion key with count support.
---@param key  string
---@param opts { clear_count?: boolean }|nil
---@return fun()
function VimMotion.action(key, opts)
  return function()
    if opts and opts.clear_count then VimCount.clear() end
    VimMotion.send(key)
  end
end

---Return a bind action that sends a sequence of `{mods, key}` pairs.
---@param seq  {[1]: string, [2]: string}[]
---@param opts { clear_count?: boolean }|nil
---@return fun()
function VimMotion.action_seq(seq, opts)
  return function()
    if opts and opts.clear_count then VimCount.clear() end
    VimMotion.send_sequence(seq)
  end
end

return VimMotion
