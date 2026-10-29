-- keys/init.lua
-- Global activation bind and all submap definitions.
-- Called from hyprvim/init.lua after vim.setup() and whichkey.start().

local Config = require("hyprvim.config") ---@class HyprVimConfigModule
local leader = (Config.keys or {}).leader or "SUPER"
local act = (Config.keys or {}).activate or "V"

-- Global Activation: Enters NORMAL mode.
hl.bind(leader .. " + " .. act, function()
  require("hyprvim.vim").count.clear()
  require("hyprvim.lib.submap").enter("NORMAL")
end)

-- Global WhichKey Toggles
if Config.which_key and Config.which_key.enabled then
  local wk = require("hyprvim.whichkey") ---@class WhichKey
  hl.bind(leader .. " + SHIFT + SLASH", function() wk.toggle() end)
  -- Escape and BackSpace close an open HUD and stop there; with the HUD hidden they reach the focused app as usual.
  local function close_or_pass()
    if not wk.is_visible() then return { pass_event = true } end
    wk.close()
  end
  hl.bind("ESCAPE", close_or_pass)
  hl.bind("BackSpace", close_or_pass)
end

-- Load all submap definitions.
require("hyprvim.keys.submaps").setup()
