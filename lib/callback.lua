-- lib/callback.lua
-- One-shot global callbacks for hyprctl dispatch round-trips.

--- @class Callback
local Callback = {}

local _cb_id = 0

---Register `fn` as a one-shot global callback; arguments in the dispatched call reach `fn`.
---@param fn fun(...)
---@return string dispatch  dispatchable call string, e.g. "_hv_cb_3()"
---@return string name  the global's name, for a caller that dispatches it with arguments
function Callback.register(fn)
  _cb_id = _cb_id + 1
  local name = "_hv_cb_" .. _cb_id
  _G[name] = function(...)
    _G[name] = nil
    fn(...)
  end
  return name .. "()", name
end

return Callback
