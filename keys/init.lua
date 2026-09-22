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
  hl.bind("ESCAPE", function() wk.close() end, { non_consuming = true })
  hl.bind("BackSpace", function() wk.close() end, { non_consuming = true })
end

-- Load all submap definitions.
require("hyprvim.keys.submaps").setup()
