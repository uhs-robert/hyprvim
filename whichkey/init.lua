-- whichkey/init.lua
-- Public API for the WhichKey HUD system.

local dir = debug.getinfo(1, "S").source:sub(2):match("(.*/)") or "./"

local Render = require("hyprvim.whichkey.render") ---@class Render
local Utils = require("hyprvim.lib.utils") ---@class HyprVimUtils
local sh_escape = Utils.sh_escape

--- @class WhichKey
local WhichKey = {}

--- Show the HUD for a submap.
--- @type fun(submap: string, screen?: string)
WhichKey.show = Render.show

--- Hide the HUD (no-op when already hidden, to avoid a shell fork).
--- @type fun()
WhichKey.close = Render.close_if_visible

--- Write a one-shot skip flag consumed by the listener on the next submap entry.
--- @type fun(target?: string)
WhichKey.set_skip = Render.set_skip

--- Write a one-shot delay override consumed by the listener on the next submap entry.
--- @type fun(ms: number)
WhichKey.set_delay = Render.set_delay

--- Toggle the HUD for the current submap.
--- Spawns render.lua as a subprocess to avoid blocking Hyprland's Lua event loop.
function WhichKey.toggle()
  local cfg = require("hyprvim.config")
  local position = (cfg.which_key and cfg.which_key.position) or "bottom-right"

  os.execute(
    "("
      .. Render.spawn_env()
      .. "HYPRVIM_WHICH_KEY_POSITION="
      .. sh_escape(position)
      .. " lua "
      .. sh_escape(dir .. "render.lua")
      .. " info) &"
  )
end

--- Cancel any pending HUD timer. Call from keybind actions that immediately exit
--- an operator-pending submap so the HUD does not flash after the action completes.
function WhichKey.cancel_pending() require("hyprvim.whichkey.listen").cancel_pending() end

--- Register Hyprland event handlers for the which-key HUD.
--- Called by hyprvim's setup() when which_key.enabled is true.
--- @param Config table  merged hyprvim config from config.lua
function WhichKey.start(Config) require("hyprvim.whichkey.listen").init(Config) end

return WhichKey
