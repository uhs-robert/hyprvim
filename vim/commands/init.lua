-- vim/commands/init.lua

--- @class VimCommands
local VimCommands = {}

VimCommands.command = require("hyprvim.vim.commands.command")
VimCommands.editor = require("hyprvim.vim.commands.editor")

return VimCommands
