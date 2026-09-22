-- vim/lib/count.lua
-- VimCount accumulator for vim motions (5j, 3dw, etc.)

local Config = require("hyprvim.config") ---@class HyprVimConfigModule
local Hypr = require("hyprvim.hypr") ---@class HyprVimHyprland

--- @class VimCount
local VimCount = {}

---@type integer  current accumulated running count value (0 = no count entered yet)
local RUNNING_COUNT = 0
local MAX_COUNT = Config.max_count or 1000

---Append a digit to the count accumulator. Capped at `config.max_count`; warns if clamped.
---@param digit integer|string
function VimCount.append(digit)
  local n = tonumber(digit)
  if not n or n < 0 or n > 9 then return end

  local cap = MAX_COUNT
  local next = RUNNING_COUNT * 10 + n
  if next > cap then
    RUNNING_COUNT = cap
    local notifications = Config.notifications or {}
    if notifications.all or notifications.warnings then
      Hypr.notify(string.format("VimCount clamped to %d", cap), "hint", 2000)
    end
  else
    RUNNING_COUNT = next
  end
end

---Return the current count (minimum 1) and reset the accumulator.
---@return integer
function VimCount.get()
  local n = RUNNING_COUNT > 0 and RUNNING_COUNT or 1
  RUNNING_COUNT = 0
  return n
end

---Return the accumulated count as a string without clearing it, or `""` if none.
---@return string
function VimCount.peek() return RUNNING_COUNT > 0 and tostring(RUNNING_COUNT) or "" end

---Reset the count accumulator without reading it.
function VimCount.clear() RUNNING_COUNT = 0 end

---Handle the `0` key: go to line start when no count is building, otherwise append 0.
function VimCount.handle_zero()
  if RUNNING_COUNT == 0 then
    hl.dispatch(hl.dsp.send_shortcut({ mods = "", key = "HOME", window = "activewindow" }))
  else
    VimCount.append(0)
  end
end

---Visual-mode variant of `handle_zero`: Shift+Home selects to line start instead.
function VimCount.handle_zero_visual()
  if RUNNING_COUNT == 0 then
    hl.dispatch(hl.dsp.send_shortcut({ mods = "SHIFT", key = "HOME", window = "activewindow" }))
  else
    VimCount.append(0)
  end
end

---Wrap `fn` to clear the count accumulator before calling it.
---@param fn fun()
---@return fun()
function VimCount.clear_then_fn(fn)
  return function()
    VimCount.clear()
    fn()
  end
end

return VimCount
