-- vim/lib/line_motion.lua
-- V-LINE mode motions with first-motion anchoring behavior.

local VimCount = require("hyprvim.vim.lib.count") ---@class VimCount
local Hypr = require("hyprvim.hypr") ---@class HyprVimHyprland

--- @class VLineMotion
local VLineMotion = {}

---@return string
local function state_dir() return require("hyprvim.config").state_dir end

---@return string  path to the first-motion sentinel file
local function flag_path() return state_dir() .. "/vline-first-motion" end

---Return true if this is the first motion since V-LINE was entered.
---The first motion anchors the opposite end of the selection before extending.
---@return boolean
local function first_motion()
  local f = io.open(flag_path(), "r")
  if not f then return false end
  f:close()
  return true
end

local function clear_first_motion() os.remove(flag_path()) end

---Select the current line (End -> Shift+Home) and enter V-LINE mode.
---Sets the first-motion flag so the next `j`/`k` anchors correctly.
function VLineMotion.setup()
  local f = io.open(flag_path(), "w")
  if f then f:close() end
  Hypr.send_batch({ { "", "End" }, { "SHIFT", "Home" } })
end

---Clear the first-motion flag. Called on V-LINE exit to avoid stale state.
function VLineMotion.reset() clear_first_motion() end

---Extend the V-LINE selection downward by `n` lines.
---On first motion, anchors the top of the selection at the start of the current line.
---@param n integer|nil  defaults to current count
function VLineMotion.down(n)
  n = n or VimCount.get()
  local cmds = {}
  if first_motion() then
    cmds[#cmds + 1] = { "", "HOME" }
    cmds[#cmds + 1] = { "SHIFT", "END" }
    clear_first_motion()
  end
  for _ = 1, n do
    cmds[#cmds + 1] = { "SHIFT", "DOWN" }
  end
  cmds[#cmds + 1] = { "SHIFT", "END" }
  Hypr.send_all(cmds)
end

---Extend the V-LINE selection upward by `n` lines.
---On first motion, anchors the bottom of the selection at the end of the current line.
---@param n integer|nil
function VLineMotion.up(n)
  n = n or VimCount.get()
  local cmds = {}
  if first_motion() then
    cmds[#cmds + 1] = { "", "END" }
    cmds[#cmds + 1] = { "SHIFT", "HOME" }
    clear_first_motion()
  end
  for _ = 1, n do
    cmds[#cmds + 1] = { "SHIFT", "UP" }
  end
  cmds[#cmds + 1] = { "SHIFT", "HOME" }
  Hypr.send_all(cmds)
end

---Extend the V-LINE selection up by `n` paragraphs (`{`).
---@param n integer|nil
function VLineMotion.paragraph_up(n)
  n = n or VimCount.get()
  if first_motion() then
    Hypr.send("SHIFT", "HOME")
    clear_first_motion()
  end
  for _ = 1, n do
    Hypr.send("CTRL SHIFT", "UP")
  end
end

---Extend the V-LINE selection down by `n` paragraphs (`}`).
---@param n integer|nil
function VLineMotion.paragraph_down(n)
  n = n or VimCount.get()
  if first_motion() then
    Hypr.send("SHIFT", "END")
    clear_first_motion()
  end
  for _ = 1, n do
    Hypr.send("CTRL SHIFT", "DOWN")
  end
end

---Extend the V-LINE selection to the document start (`gg`).
function VLineMotion.goto_start()
  if first_motion() then
    Hypr.send("", "END")
    clear_first_motion()
  end
  Hypr.send("CTRL SHIFT", "HOME")
end

---Extend the V-LINE selection to the document end (`G`).
function VLineMotion.goto_end()
  if first_motion() then
    Hypr.send("", "HOME")
    clear_first_motion()
  end
  Hypr.send("CTRL SHIFT", "END")
end

return VLineMotion
