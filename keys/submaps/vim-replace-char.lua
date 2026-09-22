-- keys/submaps/vim-replace-char.lua
-- R-CHAR submap: overwrite [count] chars under the cursor with the pressed key (US layout).

local Submap = require("hyprvim.lib.submap") ---@class HyprVimSubmap
local vim = require("hyprvim.vim") ---@class Vim
local common = require("hyprvim.keys.submaps.common")

---@param char string  literal character the keycode produces
---@return fun()
local function rep(char)
  return function() vim.replace.character(char) end
end

local SHIFTED_DIGITS = { ")", "!", "@", "#", "$", "%", "^", "&", "*", "(" } -- index = digit + 1

-- keycode = { plain, shifted }
local PUNCT = {
  MINUS = { "-", "_" },
  EQUAL = { "=", "+" },
  BRACKETLEFT = { "[", "{" },
  BRACKETRIGHT = { "]", "}" },
  BACKSLASH = { "\\", "|" },
  SEMICOLON = { ";", ":" },
  APOSTROPHE = { "'", '"' },
  COMMA = { ",", "<" },
  PERIOD = { ".", ">" },
  SLASH = { "/", "?" },
  GRAVE = { "`", "~" },
}

Submap.define({
  name = "R-CHAR",
  operator = true,
  escape = function()
    vim.count.clear()
    Submap.enter("NORMAL")
  end,
  catchall = "stay",
  binds = function()
    local rows = common.exit_rows()
    table.insert(rows, { "SPACE", rep(" ") })
    table.insert(rows, { "TAB", rep("\t") })

    local letters = "abcdefghijklmnopqrstuvwxyz"
    for i = 1, #letters do
      local c = letters:sub(i, i)
      table.insert(rows, { c:upper(), rep(c) })
      table.insert(rows, { "SHIFT + " .. c:upper(), rep(c:upper()) })
    end

    for i = 0, 9 do
      local d = tostring(i)
      table.insert(rows, { d, rep(d) })
      table.insert(rows, { "SHIFT + " .. d, rep(SHIFTED_DIGITS[i + 1]) })
    end

    for key, chars in pairs(PUNCT) do
      table.insert(rows, { key, rep(chars[1]) })
      table.insert(rows, { "SHIFT + " .. key, rep(chars[2]) })
    end

    return rows
  end,
}).setup()
