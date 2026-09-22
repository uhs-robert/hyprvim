-- keys/submaps/modes/insert.lua

local Submap = require("hyprvim.lib.submap") ---@class HyprVimSubmap
local common = require("hyprvim.keys.submaps.common")

Submap.define({
  name = "INSERT",
  escape = "NORMAL",
  back = false,
  binds = common.exit_rows(),
}).setup()
