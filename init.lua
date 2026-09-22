-- init.lua
--
--    ██╗  ██╗██╗   ██╗██████╗ ██████╗ ██╗   ██╗██╗███╗   ███╗
--    ██║  ██║╚██╗ ██╔╝██╔══██╗██╔══██╗██║   ██║██║████╗ ████║
--    ███████║ ╚████╔╝ ██████╔╝██████╔╝██║   ██║██║██╔████╔██║
--    ██╔══██║  ╚██╔╝  ██╔═══╝ ██╔══██╗╚██╗ ██╔╝██║██║╚██╔╝██║
--    ██║  ██║   ██║   ██║     ██║  ██║ ╚████╔╝ ██║██║ ╚═╝ ██║
--    ╚═╝  ╚═╝   ╚═╝   ╚═╝     ╚═╝  ╚═╝  ╚═══╝  ╚═╝╚═╝     ╚═╝
--

-- Resolve hyprvim.* modules from this checkout and drop stale ones for reload correctness
local here = debug.getinfo(1, "S").source:sub(2):match("(.*/)") or "./"
dofile(here .. "loader.lua")

for k in pairs(package.loaded) do
  if k:match("^hyprvim%.") and k ~= "hyprvim.loader" then package.loaded[k] = nil end
end

--- @class HyprVimAPI
--- @field setup     fun(overrides?: HyprVimConfig): HyprVimAPI
--- @field config    HyprVimInstance
--- @field whichkey  WhichKey
--- @field marks     any
--- @field registers any
--- @field command   any
--- @field editor    any
local API = {}

--- @param cfg HyprVimInstance
--- @param Vim Vim
--- @return HyprVimAPI
local function public_api(cfg, Vim)
  API.config = cfg
  API.whichkey = require("hyprvim.whichkey")
  API.marks = Vim.marks
  API.registers = Vim.registers
  API.command = Vim.command
  API.editor = Vim.editor

  return API
end

--- @param overrides HyprVimConfig?
--- @return HyprVimAPI
API.setup = function(overrides)
  local cfg = require("hyprvim.config").setup(overrides)
  require("hyprvim.lib.updater").check_async()

  local sh_escape = require("hyprvim.lib.utils").sh_escape
  os.execute("mkdir -p " .. sh_escape(cfg.state_dir .. "/registers"))
  os.execute("mkdir -p " .. sh_escape(cfg.state_dir .. "/marks"))

  require("hyprvim.hypr.rules").setup()
  local Vim = require("hyprvim.vim") ---@class Vim
  Vim.setup(cfg)

  if cfg.which_key and cfg.which_key.enabled then require("hyprvim.whichkey").start(cfg) end

  require("hyprvim.keys")

  -- Keep Submap.current/previous truthful for transitions dispatched outside Submap.enter
  -- (async editor/replace callbacks via hyprctl).
  hl.on("keybinds.submap", require("hyprvim.lib.submap").sync)

  return public_api(cfg, Vim)
end

return API
