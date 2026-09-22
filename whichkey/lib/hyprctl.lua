-- whichkey/lib/hyprctl.lua
-- Fetches whichkey HUD items from `hyprctl binds` via a jq filter.

local dir = debug.getinfo(1, "S").source:sub(2):match("(.*/)") or "./"

local Utils = require("hyprvim.lib.utils") ---@class HyprVimUtils
local pread = Utils.pread
local sh_escape = Utils.sh_escape

--- @class HyprCtl
local HyprCtl = {}

local JQ_FILE = dir .. "binds.jq"

--- Build HUD items from `hyprctl binds` for any submap.
--- @param sm string
--- @return string|nil  JSON array string, or nil on error
function HyprCtl.build_items(sm)
  local result = pread(
    "hyprctl binds -j 2>/dev/null | jq -c --arg sm " .. sh_escape(sm) .. " -f " .. sh_escape(JQ_FILE) .. " 2>/dev/null"
  )
  if result == "" or result == "null" then return nil end
  return result
end

return HyprCtl
