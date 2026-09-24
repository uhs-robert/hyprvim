#!/usr/bin/env lua
-- whichkey/render.lua

local script_path = debug.getinfo(1, "S").source:sub(2)
local dir = script_path:match("(.*/)") or "./"
dofile(dir .. "../loader.lua")

local Utils = require("hyprvim.lib.utils") ---@class HyprVimUtils
local read_file = Utils.read_file
local write_file = Utils.write_file
local file_exists = Utils.file_exists
local pread = Utils.pread
local sh_escape = Utils.sh_escape

local Eww = require("hyprvim.whichkey.lib.eww") ---@class Eww
local Quickshell = require("hyprvim.whichkey.lib.quickshell") ---@class Quickshell
local Items = require("hyprvim.whichkey.lib.items") ---@class Items
local Config = require("hyprvim.config") ---@class HyprVimConfigModule

--- @class Render
local Render = {}

Render.state_dir = Config.state_dir
Render.eww_dir = Eww.dir
Render.position = os.getenv("HYPRVIM_WHICH_KEY_POSITION")
  or (Config.which_key and Config.which_key.position)
  or "bottom-right"

os.execute("mkdir -p " .. sh_escape(Render.state_dir))

--- Returns true if submap is still the active one (or is GLOBAL).
--- Reads current-submap state file; used to abort stale HUD renders.
--- @param submap string
--- @return boolean
local function is_submap_active(submap)
  if submap == "GLOBAL" then return true end
  return read_file(Render.state_dir .. "/current-submap") == submap
end

local POSITIONS = Eww.POSITIONS

--- Active HUD frontend; the env var carries the configured value into render subprocesses.
--- @return "eww"|"quickshell"
function Render.frontend()
  local env = os.getenv("HYPRVIM_WHICH_KEY_FRONTEND")
  if env and env ~= "" then return env == "quickshell" and "quickshell" or "eww" end
  return (Config.which_key and Config.which_key.frontend) == "quickshell" and "quickshell" or "eww"
end

--- Env assignments that carry the frontend settings into a render subprocess.
--- @return string  shell prefix ending in a space
function Render.spawn_env()
  return "HYPRVIM_WHICH_KEY_FRONTEND="
    .. sh_escape(Render.frontend())
    .. " HYPRVIM_WHICH_KEY_QS_IPC="
    .. sh_escape(Quickshell.ipc_prefix())
    .. " "
end

--- Mark the HUD visible for the listener and toggle.
local function mark_visible()
  local vf = io.open(Render.state_dir .. "/whichkey-visible", "w")
  if vf then vf:close() end
end

--- Close HUD and return true (for use as `if close_if(cond) then return end`).
--- @param cond boolean
--- @return boolean
local function close_if(cond)
  if cond then Render.close() end
  return cond
end

--------------------------------------------------------------------------------
-- Public API
--------------------------------------------------------------------------------

--- Hide the HUD and clear the visible state file.
function Render.close()
  local visible_file = sh_escape(Render.state_dir .. "/whichkey-visible")
  if Render.frontend() == "quickshell" then
    os.execute("(" .. Quickshell.hide_cmd() .. "; rm -f " .. visible_file .. ") &")
    return
  end
  local ec = "eww -c " .. sh_escape(Eww.dir)
  local parts = { ec .. " update visible=false >/dev/null 2>&1" }
  for _, pos in ipairs(POSITIONS) do
    parts[#parts + 1] = ec .. " close whichkey-" .. pos .. " >/dev/null 2>&1"
  end
  parts[#parts + 1] = "rm -f " .. visible_file
  os.execute("(" .. table.concat(parts, "; ") .. ") &")
end

--- Close the HUD only when it is visible, avoiding a shell fork when hidden.
function Render.close_if_visible()
  if file_exists(Render.state_dir .. "/whichkey-visible") then Render.close() end
end

--- Toggle the HUD: close if visible, otherwise show the current submap (or GLOBAL).
function Render.toggle()
  if file_exists(Render.state_dir .. "/whichkey-visible") then
    Render.close()
    return
  end
  local current = read_file(Render.state_dir .. "/current-submap")
  local target = (current ~= "" and current ~= "reset") and current or "GLOBAL"
  local screen = pread("hyprctl -j monitors 2>/dev/null | jq -r '.[] | select(.focused) | .name' 2>/dev/null")
  Render.show(target, screen)
end

--- Write one-shot skip flag for the listener.
--- @param target string|nil  submap name to target, or nil for next submap
function Render.set_skip(target)
  local f = io.open(Render.state_dir .. "/whichkey-skip-next", "w")
  if f then f:close() end
  if target and target ~= "" then write_file(Render.state_dir .. "/whichkey-skip-target", target) end
end

--- Write one-shot delay override for the listener.
--- @param ms number  delay in milliseconds
function Render.set_delay(ms) write_file(Render.state_dir .. "/whichkey-next-delay", tostring(ms)) end

--- Render the HUD for the given submap.
--- @param submap string
--- @param screen string|nil  monitor name; queries focused monitor if omitted
--- @param geometry string|nil  "WxHxS" monitor geometry; queries hyprctl if omitted
function Render.show(submap, screen, geometry)
  submap = submap or ""
  screen = screen or ""
  geometry = geometry or ""

  if submap == "reset" or submap == "hide" then submap = "" end

  if submap ~= "" and submap ~= "GLOBAL" then
    if close_if(not is_submap_active(submap)) then return end
    write_file(Render.state_dir .. "/current-submap", submap)
  elseif submap == "" then
    os.execute("rm -f " .. sh_escape(Render.state_dir .. "/current-submap"))
  end

  if close_if(submap == "") then return end

  if screen == "" then
    screen = pread("hyprctl -j monitors 2>/dev/null | jq -r '.[] | select(.focused) | .name' 2>/dev/null")
  end

  local items, items_tmp, num_items = Items.resolve(submap)
  if close_if(num_items == 0) then return end

  local function jq_items(expr)
    return pread("jq -c " .. sh_escape(expr) .. " " .. sh_escape(items_tmp) .. " 2>/dev/null")
  end

  -- Monitor geometry: passed in by the listener; hyprctl query is the fallback
  local info = geometry
  if info == "" then
    info = pread(
      "hyprctl -j monitors 2>/dev/null | jq -r --arg n "
        .. sh_escape(screen)
        .. " '.[] | select(.name == $n) | (.transform % 2 == 1) as $rot"
        .. ' | "\\(if $rot then .height else .width end)x\\(if $rot then .width else .height end)x\\(.scale)"\' 2>/dev/null'
    )
  end
  if info == "" then info = "1920x1080x1.0" end
  local _, ph, ps = info:match("^(%d+)x(%d+)x([%d%.]+)")
  local lh = math.floor((tonumber(ph) or 1080) / (tonumber(ps) or 1))

  -- Panel chrome plus per-row height, measured from the rendered widget at the default theme
  local pos = Render.position
  if not pos:find("center") and (102 + num_items * 24) > lh * 0.9 then
    pos = pos:find("^top") and "top-center" or "bottom-center"
  end

  local window = "whichkey-" .. pos
  local title = submap == "GLOBAL" and "Global Bindings" or submap

  local rows_fit = math.max(1, math.floor((lh * 0.9 - 102) / 24))
  local ncols = math.min(4, math.ceil(num_items / rows_fit))

  if Render.frontend() == "quickshell" then
    local path = Quickshell.write_payload({
      submap = submap,
      title = title,
      position = pos,
      screen = screen,
      columns = pos:find("center") and ncols or 1,
    }, items_tmp)
    os.remove(items_tmp)
    if not path or not is_submap_active(submap) then return end
    if not Quickshell.show(path) then return end
    if not is_submap_active(submap) then
      Render.close()
      return
    end
    mark_visible()
    return
  end

  Eww.run("update visible=false")
  Eww.update_layout(pos, title, items, jq_items, ncols)
  os.remove(items_tmp)

  if not is_submap_active(submap) then return end

  for _, p in ipairs(POSITIONS) do
    if "whichkey-" .. p ~= window then Eww.run("close whichkey-" .. p) end
  end

  if not Eww.open_window(window, screen) then return end

  -- Final stale check: the submap may have changed while eww was opening the window.
  if not is_submap_active(submap) then
    Render.close()
    return
  end

  write_file(Render.state_dir .. "/whichkey-current-window", window)
  mark_visible()
  Eww.run("update visible=true")
end

--------------------------------------------------------------------------------
-- Script entry point (called as subprocess by whichkey-listen.lua)
--------------------------------------------------------------------------------

if arg and arg[0] and arg[0]:match("render%.lua$") then
  local argv = arg
  local cmd = argv[1] or ""

  if cmd:sub(1, 1) == "-" then
    local i = 1
    while i <= #argv do
      local a = argv[i]
      if a == "-s" or a == "--skip" then
        local target = (argv[i + 1] and argv[i + 1]:sub(1, 1) ~= "-") and argv[i + 1] or nil
        Render.set_skip(target)
        i = i + (target and 2 or 1)
      elseif a:sub(1, 7) == "--skip=" then
        Render.set_skip(a:sub(8))
        i = i + 1
      elseif a == "-d" or a == "--delay" then
        Render.set_delay(tonumber(argv[i + 1]) or 0)
        i = i + 2
      elseif a:sub(1, 8) == "--delay=" then
        Render.set_delay(tonumber(a:sub(9)) or 0)
        i = i + 1
      elseif a == "-c" or a == "--close" then
        Render.close()
        os.exit(0)
      else
        i = i + 1
      end
    end
  elseif cmd == "info" or cmd == "--info" then
    Render.toggle()
  else
    Render.show(cmd, argv[2], argv[3])
  end
end

return Render
