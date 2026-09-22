-- vim/features/init.lua
-- Stateful vim features. Required by vim/init.lua.

--- @class VimFeatures
local VimFeatures = {}

VimFeatures.marks = require("hyprvim.vim.features.marks")
VimFeatures.registers = require("hyprvim.vim.features.registers")
VimFeatures.find = require("hyprvim.vim.features.find")
VimFeatures.replace = require("hyprvim.vim.features.replace")

return VimFeatures
