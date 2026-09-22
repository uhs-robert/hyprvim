-- vim/lib/init.lua
-- Internal dispatch primitives. Required by vim/init.lua; not called directly from submaps.

--- @class VimLib
local VimLib = {}

VimLib.count = require("hyprvim.vim.lib.count")
VimLib.hypr = require("hyprvim.hypr")
VimLib.motion = require("hyprvim.vim.lib.motion")
VimLib.line_motion = require("hyprvim.vim.lib.line_motion")

return VimLib
