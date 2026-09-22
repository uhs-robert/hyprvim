-- whichkey/theme.lua
-- Converts theme.conf variables into eww/whichkey/_vars.scss.

local dir = debug.getinfo(1, "S").source:sub(2):match("(.*/)") or "./"
local root = dir .. "../"

local Utils = require("hyprvim.lib.utils")
local Config = require("hyprvim.config")

local Theme = {}

local DEFAULT_THEME = [[
# ~/.config/hyprvim/theme.conf
#
# Controls the colors and font size of the which-key HUD (eww widget).
# Changes are applied automatically on the next `hyprctl reload`.
#
# Any $variable defined here is automatically passed through to the eww SCSS.

# Theme Colors
$bg_core: #070C13;
$bg_border: #5D8BBB;
$fg: #F7EDE1;
$primary: #7FA3C9;
$secondary: #D6CE7C;
$accent: #FFA0A0;
$info: #B0C8DE;

# Base font size (all other sizes scale from this)
$base_font_size = 12px

# Vertical padding per key row (lower = more compact list)
$row_padding_y = 2px
]]

local DEFAULT_USER_SCSS = [[
// whichkey.scss
//
// User style overrides for the which-key HUD.
// Edit this file to customize layout, spacing, and borders.
// All variables from theme.conf and eww.scss are available here.
//
// Examples:

// Rounder corners
// .wk { border-radius: 16px; }

// Tighter padding
// .wk { padding: 6px 10px; }

// Tighter rows (or set $row_padding_y in theme.conf)
// .wk-row { padding: 0 5px; }

// Larger font
// * { font-size: 14px; }

// Custom key label color
// .wk-key { color: $accent; }

// Hide the footer
// .wk-footer { display: none; }
]]

--- @param path string
--- @return boolean
local function file_exists(path)
  local f = io.open(path, "r")
  if f then
    f:close()
    return true
  end
  return false
end

--- @param path string
--- @param content string
local function create_if_missing(path, content)
  if not file_exists(path) then
    local f = io.open(path, "w")
    if f then
      f:write(content)
      f:close()
    end
  end
end

--- Reads theme.conf and writes _vars.scss.
function Theme.apply()
  local cfg_dir = Config.config_dir
  os.execute("mkdir -p " .. Utils.sh_escape(cfg_dir))
  local theme_file = cfg_dir .. "/theme.conf"
  local vars_file = root .. "eww/whichkey/_vars.scss"
  local user_scss = cfg_dir .. "/whichkey.scss"

  create_if_missing(user_scss, DEFAULT_USER_SCSS)
  create_if_missing(theme_file, DEFAULT_THEME)

  local lines = {}
  table.insert(lines, "// Auto-generated from theme.conf, do not edit directly")
  table.insert(lines, "// To customize, edit theme.conf and run: hyprctl reload")
  table.insert(lines, "")

  local f = io.open(theme_file, "r")
  if f then
    for line in f:lines() do
      -- skip comments and blank lines
      if not line:match("^%s*#") and line:match("%S") then
        -- $name: value;  (colon-style, e.g. color vars)
        local name, value = line:match("^%$([%a_][%w_]*)%s*:%s*([^;]*)")
        if name then
          table.insert(lines, "$" .. name .. ": " .. value:gsub("%s+$", "") .. ";")
        else
          -- $name = value  (equals-style, e.g. font-size)
          name, value = line:match("^%$([%a_][%w_]*)%s*=%s*(.*)")
          if name then table.insert(lines, "$" .. name .. ": " .. value:gsub("%s+$", "") .. ";") end
        end
      end
    end
    f:close()
  end

  Utils.write_file(vars_file, table.concat(lines, "\n") .. "\n")
end

return Theme
