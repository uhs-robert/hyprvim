-- keys/submaps/init.lua
-- Load all submap definitions (order matters: modes before operators before marks).

--- @class SubmapModule
--- @field setup fun()
local Submaps = {}

Submaps.setup = function()
  require("hyprvim.keys.submaps.modes")
  require("hyprvim.keys.submaps.vim-operators")
  require("hyprvim.keys.submaps.vim-marks")
  require("hyprvim.keys.submaps.vim-registers")
  require("hyprvim.keys.submaps.vim-replace-char")
end

return Submaps
