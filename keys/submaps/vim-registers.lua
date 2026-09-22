-- keys/submaps/vim-registers.lua
-- REGISTERS submap activated by " in NORMAL mode

local Submap = require("hyprvim.lib.submap") ---@class HyprVimSubmap
local vim = require("hyprvim.vim") ---@class Vim
local reg = vim.registers
local wk = require("hyprvim.whichkey") ---@class WhichKey
local common = require("hyprvim.keys.submaps.common")

-- Return to origin: NORMAL in the vim flow, reset when entered from a global bind.
local function set(name)
  reg.set_pending(name)
  Submap.back()
end

Submap.define({
  name = "REGISTERS",
  on_enter = function() vim.count.clear() end,
  escape = "previous",
  catchall = "stay",
  binds = function()
    local result = {}

    local letters = "abcdefghijklmnopqrstuvwxyz"
    for i = 1, #letters do
      local c = letters:sub(i, i)
      result[#result + 1] = { c:upper(), function() set(c) end }
    end

    for i = 1, 9 do
      local s = tostring(i)
      result[#result + 1] = { s, function() set(s) end }
    end

    -- Content previews come live from whichkey (Items.build_register_items), not these descs.
    -- stylua: ignore start
    result[#result + 1] = { "SHIFT + APOSTROPHE", function() set('"') end, "Unnamed register (default)" }
    result[#result + 1] = { "0",                  function() set("0") end, "Yank register (last yank)"  }
    result[#result + 1] = { "SHIFT + MINUS",      function() set("_") end, "Black hole register"        }
    result[#result + 1] = { "SHIFT + EQUAL",      function() set("+") end, "System clipboard"           }
    result[#result + 1] = { "SHIFT + 8",          function() set("*") end, "Primary selection"          }
    result[#result + 1] = { "SLASH",              function() set("/") end, "Search register"            }
    result[#result + 1] = { "SHIFT + SLASH",      wk.toggle                                             }
    for _, row in ipairs(common.exit_rows()) do
      result[#result + 1] = row
    end
    -- stylua: ignore end

    return result
  end,
}).setup()

reg.enter_registers = function() Submap.enter("REGISTERS") end
