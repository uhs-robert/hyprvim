-- whichkey/theme.lua
-- Reads theme.conf variables and converts them into eww/whichkey/_vars.scss.

local dir = debug.getinfo(1, "S").source:sub(2):match("(.*/)") or "./"
local root = dir .. "../"

local Utils = require("hyprvim.lib.utils")
local Config = require("hyprvim.config")

local Theme = {}

local DEFAULT_THEME = [[
# ~/.config/hyprvim/theme.conf
#
# Controls the colors and font size of the which-key HUD (the eww widget, or the
# `theme` field sent to a Quickshell frontend).
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

--- Reads the `$name` variables from theme.conf in file order; missing file yields none.
--- @return { name: string, value: string }[]
function Theme.read_vars()
  local vars = {}
  local f = io.open(Config.config_dir .. "/theme.conf", "r")
  if not f then return vars end
  for line in f:lines() do
    if not line:match("^%s*#") and line:match("%S") then
      -- `$name: value;` for colors, `$name = value` for sizes
      local name, value = line:match("^%$([%a_][%w_]*)%s*:%s*([^;]*)")
      if not name then
        name, value = line:match("^%$([%a_][%w_]*)%s*=%s*(.*)")
      end
      if name then vars[#vars + 1] = { name = name, value = (value:gsub("%s+$", "")) } end
    end
  end
  f:close()
  return vars
end

--- Reads theme.conf and writes _vars.scss.
function Theme.apply()
  local cfg_dir = Config.config_dir
  os.execute("mkdir -p " .. Utils.sh_escape(cfg_dir))
  local vars_file = root .. "eww/whichkey/_vars.scss"
  local user_scss = cfg_dir .. "/whichkey.scss"

  create_if_missing(user_scss, DEFAULT_USER_SCSS)
  create_if_missing(cfg_dir .. "/theme.conf", DEFAULT_THEME)

  local lines = {}
  table.insert(lines, "// Auto-generated from theme.conf, do not edit directly")
  table.insert(lines, "// To customize, edit theme.conf and run: hyprctl reload")
  table.insert(lines, "")
  for _, var in ipairs(Theme.read_vars()) do
    table.insert(lines, "$" .. var.name .. ": " .. var.value .. ";")
  end

  Utils.write_file(vars_file, table.concat(lines, "\n") .. "\n")
end

return Theme
