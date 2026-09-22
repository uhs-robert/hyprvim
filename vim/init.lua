-- vim/init.lua
-- Public API for the vim engine. Submaps require("hyprvim.vim") to call into this.
--
-- Usage from a submap callback:
--   local vim = require("hyprvim.vim")
--   vim.motion.send("j")          -- move down
--   vim.count.append("3")         -- accumulate count
--   vim.marks.set("a")            -- set mark a
--   vim.registers.handle_yank("CTRL", "c", { collapse = true })

-- stylua: ignore
local lib      = require("hyprvim.vim.lib") ---@class VimLib
local exit = require("hyprvim.vim.exit")
local features = require("hyprvim.vim.features") ---@class VimFeatures
local commands = require("hyprvim.vim.commands") ---@class VimCommands
local Window = require("hyprvim.hypr.window") ---@class HyprVimWindow

local function setup(Config) Window.init(Config) end

-- stylua: ignore
--- @class Vim
local Vim = {
  setup       = setup,
  exit        = exit,
  -- lib
  count       = lib.count,
  motion      = lib.motion,
  line_motion = lib.line_motion,
  hypr        = lib.hypr,
  -- features
  marks       = features.marks,
  registers   = features.registers,
  find        = features.find,
  replace     = features.replace,
  -- commands
  command     = commands.command,
  editor      = commands.editor,
}

return Vim
