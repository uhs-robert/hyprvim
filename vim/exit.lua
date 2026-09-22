-- vim/exit.lua
-- Composes the full vim-mode teardown

local Submap = require("hyprvim.lib.submap") ---@class HyprVimSubmap
local Clipboard = require("hyprvim.lib.clipboard") ---@class Clipboard

---Exit vim mode entirely
return function()
  Clipboard.restore_pre_vim()
  Submap.reset()
  Submap.previous = nil
end
