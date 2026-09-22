-- whichkey/lib/eww.lua
-- Thin wrappers around the eww IPC command for the WhichKey HUD.

local dir = debug.getinfo(1, "S").source:sub(2):match("(.*/)") or "./"
local root = dir .. "../../"

local Utils = require("hyprvim.lib.utils") ---@class HyprVimUtils
local sh_escape = Utils.sh_escape

--- @class Eww
local Eww = {}

Eww.dir = os.getenv("EWW_DIR") or (root .. "eww/whichkey")

Eww.POSITIONS = { "bottom-right", "bottom-center", "top-center", "bottom-left", "top-right", "top-left", "center" }

--- Run an eww subcommand against the whichkey config dir.
--- @param args string
function Eww.run(args) os.execute("eww -c " .. sh_escape(Eww.dir) .. " " .. args .. " >/dev/null 2>&1 || true") end

--- Open a whichkey eww window, preferring a specific screen.
--- @param window string
--- @param screen string
--- @return boolean
function Eww.open_window(window, screen)
  if screen and screen ~= "" then
    -- stylua: ignore
    local ok = os.execute(
      "eww -c " .. sh_escape(Eww.dir)
        .. " open --screen " .. sh_escape(screen)
        .. " " .. sh_escape(window)
        .. " >/dev/null 2>&1"
    )
    if ok then return true end
  end
  return os.execute("eww -c " .. sh_escape(Eww.dir) .. " open " .. sh_escape(window) .. " >/dev/null 2>&1") ~= nil
end

--- Push item data into eww variables for the appropriate layout (center vs sidebar).
--- @param pos string  position key, e.g. "bottom-right" or "center"
--- @param title string
--- @param items string  JSON array
--- @param jq_items fun(expr: string): string
--- @param ncols integer|nil  columns to split across in center layouts, 1-4 (default 4)
function Eww.update_layout(pos, title, items, jq_items, ncols)
  if pos:find("center") then
    ncols = math.min(4, math.max(1, ncols or 4))
    local cols = {}
    for i = 1, 4 do
      cols[i] = i <= ncols
          and jq_items(string.format("[to_entries | .[] | select(.key %% %d == %d) | .value]", ncols, i - 1))
        or "[]"
    end
    Eww.run(
      string.format(
        "update title=%s col1=%s col2=%s col3=%s col4=%s",
        sh_escape(title),
        sh_escape(cols[1]),
        sh_escape(cols[2]),
        sh_escape(cols[3]),
        sh_escape(cols[4])
      )
    )
  else
    Eww.run("update title=" .. sh_escape(title) .. " items=" .. sh_escape(items))
  end
end

return Eww
