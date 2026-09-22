-- keys/submaps/common.lua
-- Shared LEADER/ACT/EXIT keys and footer rows for submap specs

local wk = require("hyprvim.whichkey") ---@class WhichKey
local vim = require("hyprvim.vim") ---@class Vim
local config = require("hyprvim.config") ---@class HyprVimConfigModule

local Common = {}

--- @return string leader, string activate, string exit
function Common.keys() return config.keys.leader or "SUPER", config.keys.activate or "V", config.keys.exit or "ESCAPE" end

--- LEADER+ACT / LEADER+EXIT exit-vim rows.
--- @return table[]
function Common.exit_rows()
  local LEADER, ACT, EXIT = Common.keys()
  return {
    { LEADER .. " + " .. ACT, vim.exit, { release = true } },
    { LEADER .. " + " .. EXIT, vim.exit, { release = true } },
  }
end

--- Whichkey toggle + exit-vim footer rows.
--- @return table[]
function Common.footer()
  local rows = Common.exit_rows()
  table.insert(rows, 1, { "SPACE", wk.toggle })
  return rows
end

return Common
