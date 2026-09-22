-- lib/clipboard.lua
-- Non-blocking clipboard I/O for Hyprland's synchronous Lua context.
-- io.popen("wl-paste"/"wl-copy") blocks the compositor thread; these helpers
-- offload both operations outside the Lua event loop via Hypr.exec.

local Hypr = require("hyprvim.hypr") ---@class HyprVimHyprland
local Utils = require("hyprvim.lib.utils") ---@class HyprVimUtils

local Clipboard = {} ---@class Clipboard

function Clipboard.pre_vim_path() return require("hyprvim.config").state_dir .. "/clipboard_pre_vim" end

-- Time for a spawned wl-paste to finish writing its tmpfile.
local SETTLE_MS = 50

---Read a selection after delay_ms (gives the app time to set it first).
---@param flag ""|"--primary "  wl-paste selection flag
---@param delay_ms integer
---@param cb fun(content: string)  receives selection text ("" if empty)
local function read_selection(flag, delay_ms, cb)
  local path = Utils.tmp_path("clip")
  hl.timer(function()
    Hypr.exec("wl-paste " .. flag .. "--no-newline 2>/dev/null >'" .. path .. "' || true")
    hl.timer(function()
      local f = io.open(path, "r")
      local content = f and (f:read("*a") or "") or ""
      if f then f:close() end
      os.remove(path)
      cb(content)
    end, { timeout = SETTLE_MS, type = "oneshot" })
  end, { timeout = delay_ms, type = "oneshot" })
end

---Write text to a selection. Writes to a tmpfile via io.open (no Wayland call), then
---dispatches wl-copy via Hypr.exec so the compositor thread is never blocked.
---@param flag string  wl-copy flags ("", "--primary " or "--type text/plain ")
---@param text string
local function write_selection(flag, text)
  local path = Utils.tmp_path("clip")
  local f = io.open(path, "w")
  if not f then return end
  f:write(text)
  f:close()
  Hypr.exec("wl-copy " .. flag .. "<'" .. path .. "'; rm -f '" .. path .. "'")
end

---Read the clipboard after delay_ms.
---@param delay_ms integer
---@param cb fun(content: string)
function Clipboard.read_async(delay_ms, cb) read_selection("", delay_ms, cb) end

---Read the primary selection after delay_ms.
---@param delay_ms integer
---@param cb fun(content: string)
function Clipboard.read_primary_async(delay_ms, cb) read_selection("--primary ", delay_ms, cb) end

---Write text to the clipboard.
---@param text string
function Clipboard.write(text) write_selection((#text == 1) and "--type text/plain " or "", text) end

---Write text to the Wayland primary selection.
---@param text string
function Clipboard.write_primary(text) write_selection("--primary ", text) end

---Save the current clipboard so it can be restored when vim mode exits.
---Called once when entering NORMAL from the reset (non-vim) state.
function Clipboard.save_pre_vim()
  read_selection("", 50, function(content)
    local out = io.open(Clipboard.pre_vim_path(), "w")
    if out then
      out:write(content)
      out:close()
    end
  end)
end

---Restore the clipboard saved by save_pre_vim(). Called on vim exit.
function Clipboard.restore_pre_vim()
  local f = io.open(Clipboard.pre_vim_path(), "r")
  if not f then return end
  local content = f:read("*a") or ""
  f:close()
  os.remove(Clipboard.pre_vim_path())
  if content ~= "" then Clipboard.write(content) end
end

return Clipboard
