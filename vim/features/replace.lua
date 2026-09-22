-- vim/features/replace.lua
-- r (replace count chars, via R-CHAR submap) and R (replace with string) commands.

local VimCount = require("hyprvim.vim.lib.count") ---@class VimCount
local Hypr = require("hyprvim.hypr") ---@class HyprVimHyprland
local Clipboard = require("hyprvim.lib.clipboard") ---@class Clipboard
local Prompt = require("hyprvim.lib.prompt") ---@class Prompt
local exit_vim = require("hyprvim.vim.exit")

--- @class ReplaceModule
local Replace = {}

-- wl-copy needs a moment to start serving the new clipboard before we paste.
local CLIP_SETTLE_MS = 60
local RESTORE_BASE_MS = 200 -- fixed clipboard read window + margin
local RESTORE_PER_KEY_MS = 3.0 -- per-char selection processing; > 2.29 measured slope
local function restore_delay(n) return math.ceil(RESTORE_BASE_MS + n * RESTORE_PER_KEY_MS) end

---Select `n` chars right, replace `text` via clipboard paste, then return to NORMAL.
---@param text string  replacement text
---@param n    integer number of chars to overwrite
local function run_replace(text, n)
  Clipboard.read_async(1, function(backup)
    Clipboard.write(text)
    local sel = {}
    for _ = 1, n do
      sel[#sel + 1] = { "SHIFT", "RIGHT" }
    end
    hl.timer(function()
      Hypr.send_burst(sel, function()
        Hypr.send("CTRL", "V")
        hl.timer(function()
          Clipboard.write(backup)
          Hypr.normal()
        end, { timeout = restore_delay(n), type = "oneshot" })
      end)
    end, { timeout = CLIP_SETTLE_MS, type = "oneshot" })
  end)
end

---`r` (called from the R-CHAR submap): overwrite the next [count] characters with `char`.
---Suspends vim binds so the injected keys are not intercepted, then returns to NORMAL.
---@param char string  literal replacement character
function Replace.character(char)
  local n = VimCount.get()
  Hypr.suspend_vim()
  run_replace(string.rep(char, n), n)
end

---`R`: prompt for a replacement string and overwrite the next `#string` characters with it.
function Replace.string()
  VimCount.get() -- clear
  exit_vim()
  hl.timer(function()
    Prompt.async("Replace with: ", { wm_class = "hyprvim-replace" }, function(str)
      if not str then
        Hypr.normal()
        return
      end
      run_replace(str, #str)
    end)
    -- TODO: stopgap: shrinks (does not close) the unguarded reset terminal-focus leak window
  end, { timeout = 20, type = "oneshot" })
end

return Replace
