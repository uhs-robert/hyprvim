-- vim/commands/command.lua
-- Vim-style command mode (:w, :q, :split, :ws N, etc.)

local Hypr = require("hyprvim.hypr") ---@class HyprVimHyprland
local Config = require("hyprvim.config") ---@class HyprVimConfigModule
local Updater = require("hyprvim.lib.updater") ---@class Updater
local Prompt = require("hyprvim.lib.prompt") ---@class Prompt
local Callback = require("hyprvim.lib.callback") ---@class Callback

local Command = {} --- @class Command

local sq = require("hyprvim.lib.utils").sh_escape

---Close or kill every window in the active workspace.
---@param kill boolean  true -> kill (SIGKILL), false -> graceful close
local function close_workspace_windows(kill)
  local ws = hl.get_active_workspace()
  if not ws then return end
  local addresses = {}
  for _, w in ipairs(hl.get_workspace_windows(ws) or {}) do
    addresses[#addresses + 1] = w.address
  end
  Hypr.close_windows(addresses, kill)
end

---Show a formatted command reference in a floating terminal.
---@param restore fun()  re-enters the originating submap when the terminal closes
---@return true
local function show_help(restore, name)
  local help_file = require("hyprvim.lib.utils").tmp_path("command-help") .. ".md"
  local f = io.open(help_file, "w")
  if not f then return end
  f:write(Command.render_help())
  f:close()
  local search = name and (" '+/^| `:" .. name:gsub("[%W]", ".") .. "`'") or ""
  Hypr.cmd_then_dispatch(
    Config.term_cmd("hyprvim-help")
      .. " bash -c "
      .. sq(Config.applications.editor .. " -RM" .. search .. " " .. help_file .. "; rm -f " .. help_file),
    Callback.register(restore)
  )()
  return true
end

---The bang forms skip the confirmation, so only the bare name is offered.
local no_confirm = { ["logout!"] = true, ["shutdown!"] = true, ["reboot!"] = true }

---Ask in the prompt bar before doing something that ends the session. Anything but
---y or yes cancels, so Escape and an empty line both mean no.
---@param question string
---@param restore fun()|nil  re-enters the originating submap once the answer is in
---@param action fun()
---@return true
local function confirm(question, restore, action)
  Prompt.async(question .. " [y/N] ", { wm_class = "hyprvim-command" }, function(answer)
    if answer and answer:lower():match("^y") then action() end
    if restore then restore() end
  end)
  return true
end

local function do_logout()
  Hypr.exec("command -v hyprshutdown >/dev/null 2>&1 && hyprshutdown || hyprctl dispatch 'hl.dsp.exit()'")
end
local function do_shutdown() hl.dispatch(hl.dsp.exec_cmd("systemctl poweroff")) end
local function do_reboot() hl.dispatch(hl.dsp.exec_cmd("systemctl reboot")) end

---Focus the next or previous window; monocle only answers its own layout command.
---@param forward boolean
local function cycle(forward)
  local ok, layout = pcall(hl.get_config, "general:layout")
  if ok and layout == "monocle" then
    hl.dispatch(hl.dsp.layout(forward and "cyclenext" or "cycleprev"))
  else
    hl.dispatch(hl.dsp.window.cycle_next({ next = forward }))
  end
end

---HyprVim submaps a person can sensibly enter; the rest are mid-keystroke states.
local ENTERABLE_MODES = { NORMAL = true, INSERT = true, VISUAL = true, ["V-LINE"] = true }

---Every submap Hyprland has binds for, written by the prompt shell as the bar opens.
---Lua cannot ask hyprctl itself: it runs on the compositor thread and would deadlock.
local SUBMAP_CACHE = Config.state_dir .. "/submaps"

---@return table<string, true>
local function known_submaps()
  local names = {}
  local f = io.open(SUBMAP_CACHE, "r")
  if not f then return names end
  for line in f:lines() do
    if line ~= "" then names[line] = true end
  end
  f:close()
  return names
end

---Exact-match dispatch table: command string -> handler(restore).
---@type table<string, fun(restore: fun()): true?>
-- stylua: ignore start
local commands = {
  w      = function() Hypr.send("CTRL", "S") end,
  wq     = function()
    Hypr.send("CTRL", "S")
    hl.timer(function() Hypr.close_window() end, { timeout = 100, type = "oneshot" })
  end,
  q      = function() Hypr.close_window() end,
  ["q!"] = function() Hypr.kill_window() end,
  qa     = function() close_workspace_windows(false) end,
  ["qa!"]= function() close_workspace_windows(true) end,
  only   = function()
    local win = hl.get_active_window()
    local ws = hl.get_active_workspace()
    if not (win and ws) then return end
    local addresses = {}
    for _, w in ipairs(hl.get_workspace_windows(ws) or {}) do
      if w.address ~= win.address then addresses[#addresses + 1] = w.address end
    end
    Hypr.close_windows(addresses, false)
  end,
  split      = function() hl.dispatch(hl.dsp.layout("preselect d")) end,
  vsplit     = function() hl.dispatch(hl.dsp.layout("preselect r")) end,
  float      = function() Hypr.toggle_floating() end,
  fullscreen = function() Hypr.toggle_fullscreen() end,
  pin        = function() Hypr.toggle_pin() end,
  center     = function() Hypr.center_window() end,
  pseudo     = function() Hypr.toggle_pseudo() end,
  dim        = function() Hypr.toggle_dim() end,
  workspace_next = function() Hypr.workspace_rel(1) end,
  workspace_prev = function() Hypr.workspace_rel(-1) end,
  reload     = function() Hypr.reload() end,
  update     = function() Updater.update() end,
  lock       = function() Hypr.exec(Config.applications.lock) end,
  logout     = function(restore) return confirm("Log out?", restore, do_logout) end,
  ["logout!"] = function() do_logout() end,
  shutdown   = function(restore) return confirm("Power off?", restore, do_shutdown) end,
  ["shutdown!"] = function() do_shutdown() end,
  reboot     = function(restore) return confirm("Restart?", restore, do_reboot) end,
  ["reboot!"] = function() do_reboot() end,
  group      = function() hl.dispatch(hl.dsp.group.toggle()) end,
  group_next = function() hl.dispatch(hl.dsp.group.next()) end,
  group_prev = function() hl.dispatch(hl.dsp.group.prev()) end,
  group_lock = function() hl.dispatch(hl.dsp.group.lock({ action = "toggle" })) end,
  marks      = function() require("hyprvim.vim.features.marks").list() end,
  next       = function() cycle(true) end,
  prev       = function() cycle(false) end,
  untag      = function() hl.dispatch(hl.dsp.window.clear_tags()) end,
  swallow    = function() hl.dispatch(hl.dsp.window.toggle_swallow()) end,
  renderer_reload = function() hl.dispatch(hl.dsp.force_renderer_reload()) end,
  picker     = function() hl.dispatch(hl.dsp.exec_cmd("pidof hyprpicker || (hyprpicker | wl-copy)")) end,
  edit       = function() Hypr.exec(Config.applications.terminal .. " " .. Config.applications.editor) end,
  terminal   = function() Hypr.exec(Config.applications.terminal) end,
  help       = show_help,
}
-- Aliases
local aliases = {
  sp = "split", vsp = "vsplit", vs = "vsplit",
  f  = "float", fs = "fullscreen", c = "center",
  tabn = "workspace_next", tn = "workspace_next",
  tabp = "workspace_prev", tp = "workspace_prev",
  r  = "reload", e = "edit", t = "terminal",
  poweroff = "shutdown", pick = "picker", hyprpicker = "picker",
  restart = "reboot",
  ["poweroff!"] = "shutdown!", ["restart!"] = "reboot!",
  h = "help", close = "q", kill = "q!",
  write = "w", save = "w",
  write_quit = "wq", save_quit = "wq",
  quit = "q",
  close_workspace = "qa", kill_workspace = "qa!",
}
for alias, canonical in pairs(aliases) do commands[alias] = commands[canonical] end

---Set by any rejection so a chain can stop at the first command that failed.
local chain_failed = false

---Report a rejected argument and return nil so the caller stops.
---@param cmd string
---@param expected string
local function reject(cmd, expected)
  chain_failed = true
  Hypr.notify(":" .. cmd .. " expects " .. expected, "error", 3000)
end

---@return number|nil  the value if it parses as a number within 0-1
local function unit(a)
  local v = tonumber(a)
  if v and v >= 0 and v <= 1 then return v end
end

---@return integer|nil  the value if it parses as a whole number
local function int(a)
  local v = tonumber(a)
  if v and v % 1 == 0 then return v end
end

---@param allowed string[]
---@return string|nil  the value if it is one of `allowed`
local function one_of(a, allowed)
  for _, v in ipairs(allowed) do
    if a == v then return a end
  end
end

---A leading + or - makes a value relative to the current one.
---@return number|nil value, boolean relative
local function number_or_delta(a)
  local v = tonumber(a)
  if not v then return nil, false end
  return v, a:match("^[+-]") ~= nil
end

---Selector prefixes Hyprland accepts, so a trailing word can be told apart from a value.
local SELECTOR_KEYS =
  { address = true, class = true, title = true, initialclass = true, initialtitle = true, pid = true, tag = true }

---Split a trailing window selector off an argument string: "0.8 address:0x1" -> "0.8", "address:0x1".
---@return string args, string|nil window
local function take_window(a)
  local head, last = a:match("^(.-)%s*(%S+)$")
  local key = last and last:match("^(%a+):")
  if key and SELECTOR_KEYS[key] then return head, last end
  return a, nil
end

---Opacity HyprVim last set per window; Hyprland does not expose a window's current opacity.
---@type table<string, table<string, number>>
local opacity_set = {}
local OPACITY_OPTION = {
  active = "decoration:active_opacity",
  inactive = "decoration:inactive_opacity",
  fullscreen = "decoration:fullscreen_opacity",
}

---@param window string|nil
---@return string|nil
local function window_key(window)
  if window then return (window:gsub("^address:", "")) end
  local active = hl.get_active_window()
  return active and active.address
end

---Resolve an opacity word: absolute values must be 0-1, relative ones are clamped into it.
---@param word string
---@param kind "active"|"inactive"|"fullscreen"
---@param key string|nil
---@return number|nil
local function resolve_opacity(word, kind, key)
  local v, relative = number_or_delta(word)
  if not v then return nil end
  if not relative then return unit(word) end
  local current = key and opacity_set[key] and opacity_set[key][kind]
  if not current then
    local ok, default = pcall(hl.get_config, OPACITY_OPTION[kind])
    current = (ok and type(default) == "number") and default or 1
  end
  return math.floor(math.max(0, math.min(1, current + v)) * 100 + 0.5) / 100
end

---@param kind string
---@param key string|nil
---@param v number
local function remember_opacity(kind, key, v)
  if not key then return end
  opacity_set[key] = opacity_set[key] or {}
  opacity_set[key][kind] = v
end

---Handler for one opacity kind, taking a value or delta and an optional window.
---@param name string
---@param kind "active"|"inactive"|"fullscreen"
---@param setter fun(v: number, window: string|nil)
---@return fun(a: string)
local function single_opacity(name, kind, setter)
  return function(a)
    local args, window = take_window(a)
    local key = window_key(window)
    local v = resolve_opacity(args, kind, key)
    if not v then return reject(name, "a value between 0 and 1, or +/- to adjust") end
    setter(v, window)
    remember_opacity(kind, key, v)
  end
end

---Shift a gap option by `delta`, whether it is one number or a per-side table.
---@return integer|table|nil
local function shift_gap(option, delta)
  local ok, current = pcall(hl.get_config, option)
  if not ok then return nil end
  if type(current) == "number" then return math.max(0, current + delta) end
  if type(current) ~= "table" then return nil end
  local out = {}
  for _, side in ipairs({ "top", "right", "bottom", "left" }) do
    out[side] = math.max(0, (current[side] or 0) + delta)
  end
  return out
end

---Argument-taking commands: name -> handler(args_string).
---Arguments are validated here; a rejected value notifies instead of silently doing nothing.
---@type table<string, fun(args: string)>
local arg_commands = {
  workspace      = function(a) Hypr.focus_workspace(tonumber(a) or a) end,
  move           = function(a)
    local x, y = a:match("^([+-]?%d+)%s+([+-]?%d+)$")
    if not x then return reject("move", "an X and Y offset in pixels, e.g. 100 -50") end
    hl.dispatch(hl.dsp.window.move({ x = tonumber(x), y = tonumber(y) }))
  end,
  move_workspace = function(a) Hypr.move_to_workspace(tonumber(a) or a) end,
  ["move_workspace!"] = function(a) hl.dispatch(hl.dsp.window.move({ workspace = (tonumber(a) or a), follow = false })) end,
  resize_width   = function(a)
    local n = int(a)
    if not n then return reject("resize_width", "a whole number of pixels") end
    hl.dispatch(hl.dsp.window.resize({ x = -n, y = 0, relative = true }))
  end,
  resize_height  = function(a)
    local n = int(a)
    if not n then return reject("resize_height", "a whole number of pixels") end
    hl.dispatch(hl.dsp.window.resize({ x = 0, y = -n, relative = true }))
  end,
  size           = function(a)
    local w, h = a:match("^(%d+)%s+(%d+)$")
    if not w then return reject("size", "a width and height in pixels, e.g. 800 600") end
    hl.dispatch(hl.dsp.window.resize({ x = tonumber(w), y = tonumber(h) }))
  end,
  opacity        = function(a)
    local args, window = take_window(a)
    local key = window_key(window)
    if args == "reset" then
      if key then opacity_set[key] = nil end
      return Hypr.reset_opacity(window)
    end
    local kinds, values = { "active", "inactive", "fullscreen" }, {}
    local expected = "up to three values between 0 and 1, +/- to adjust, or reset"
    for word in args:gmatch("%S+") do
      local kind = kinds[#values + 1]
      local v = kind and resolve_opacity(word, kind, key)
      if not v then return reject("opacity", expected) end
      values[#values + 1] = v
    end
    if #values == 0 then return reject("opacity", expected) end
    Hypr.set_opacity(values[1], values[2], values[3], window)
    for i, v in ipairs(values) do
      remember_opacity(kinds[i], key, v)
    end
  end,
  dim                = function(a)
    local args, window = take_window(a)
    if not one_of(args, { "on", "off" }) then return reject("dim", "on or off") end
    hl.dispatch(hl.dsp.window.set_prop({ prop = "no_dim", value = args == "on" and "0" or "1", window = window }))
  end,
  opacity_active     = single_opacity("opacity_active", "active", Hypr.set_active_opacity),
  opacity_inactive   = single_opacity("opacity_inactive", "inactive", Hypr.set_inactive_opacity),
  opacity_fullscreen = single_opacity("opacity_fullscreen", "fullscreen", Hypr.set_fullscreen_opacity),
  gaps           = function(a)
    local v, relative = number_or_delta(a)
    if not v or v % 1 ~= 0 then return reject("gaps", "a whole number of pixels, or +/- to adjust") end
    if not relative then
      if v < 0 then return reject("gaps", "a whole number of pixels, or +/- to adjust") end
      return hl.config({ general = { gaps_in = v, gaps_out = v } })
    end
    local gaps_in, gaps_out = shift_gap("general:gaps_in", v), shift_gap("general:gaps_out", v)
    if gaps_in == nil or gaps_out == nil then return reject("gaps", "an absolute value; current gaps are unreadable") end
    hl.config({ general = { gaps_in = gaps_in, gaps_out = gaps_out } })
  end,
  float          = function(a)
    if not one_of(a, { "on", "off", "toggle" }) then return reject("float", "on, off or toggle") end
    hl.dispatch(hl.dsp.window.float({ action = a }))
  end,
  fullscreen     = function(a)
    if not one_of(a, { "fullscreen", "maximized" }) then return reject("fullscreen", "fullscreen or maximized") end
    hl.dispatch(hl.dsp.window.fullscreen({ mode = a }))
  end,
  monitor        = function(a) hl.dispatch(hl.dsp.focus({ monitor = a })) end,
  move_monitor   = function(a) hl.dispatch(hl.dsp.window.move({ monitor = a })) end,
  swap           = function(a)
    if not one_of(a, { "l", "r", "u", "d" }) then return reject("swap", "a direction: l, r, u or d") end
    hl.dispatch(hl.dsp.window.swap({ direction = a }))
  end,
  special        = function(a) hl.dispatch(hl.dsp.workspace.toggle_special(a)) end,
  move_special   = function(a) hl.dispatch(hl.dsp.window.move({ workspace = "special:" .. a })) end,
  rename         = function(a) hl.dispatch(hl.dsp.workspace.rename({ name = a })) end,
  prop           = function(a)
    local args, window = take_window(a)
    local prop, val = args:match("^(%S+)%s+(.+)$")
    if not prop then return reject("prop", "a property name and a value, e.g. no_dim 1") end
    hl.dispatch(hl.dsp.window.set_prop({ prop = prop, value = val, window = window }))
  end,
  window         = function(a) hl.dispatch(hl.dsp.focus({ window = a })) end,
  set            = function(a)
    local option, value = a:match("^(%S+)%s+(.+)$")
    if not option then return reject("set", "an option name and a value, e.g. general:gaps_in 5") end
    local target, path = {}, {}
    for part in option:gmatch("[^:]+") do
      path[#path + 1] = part
    end
    local leaf = table.remove(path)
    local node = target
    for _, part in ipairs(path) do
      node[part] = {}
      node = node[part]
    end
    node[leaf] = tonumber(value) or (value == "true" and true) or (value == "false" and false) or value
    hl.config(target)
  end,
  layout         = function(a)
    -- plugins and hl.layout.register add layouts, so any name may be valid
    if not a:match("^%S+$") then return reject("layout", "a layout name, e.g. dwindle") end
    hl.config({ general = { layout = a } })
  end,
  group_move     = function(a)
    if not one_of(a, { "l", "r", "u", "d" }) then return reject("group_move", "a direction: l, r, u or d") end
    hl.dispatch(hl.dsp.group.move_window({ direction = a }))
  end,
  group_window   = function(a)
    local index = tonumber(a)
    if not index or index < 1 then return reject("group_window", "a window number, counting from 1") end
    hl.dispatch(hl.dsp.group.active({ index = index }))
  end,
  workspace_monitor = function(a)
    if a == "" then return reject("workspace_monitor", "a monitor name") end
    local ws = hl.get_active_workspace()
    if not ws then return end
    hl.dispatch(hl.dsp.workspace.move({ workspace = tostring(ws.id), monitor = a }))
  end,
  workspace_swap = function(a)
    local one, two = a:match("^(%S+)%s+(%S+)$")
    if not one then return reject("workspace_swap", "two monitor names, e.g. eDP-1 DP-7") end
    hl.dispatch(hl.dsp.workspace.swap_monitors({ monitor1 = one, monitor2 = two }))
  end,
  help           = function(a, restore) return show_help(restore, a) end,
  tag            = function(a)
    local args, window = take_window(a)
    if not args:match("^%S+$") then return reject("tag", "a tag name, e.g. +work or -work") end
    hl.dispatch(hl.dsp.window.tag({ tag = args, window = window }))
  end,
  untag          = function(a)
    local args, window = take_window(a)
    if args ~= "" or not window then return reject("untag", "a window, e.g. address:0x1234") end
    hl.dispatch(hl.dsp.window.clear_tags({ window = window }))
  end,
  -- returns true so the prompt does not restore the mode it was opened from
  submap         = function(a)
    if ENTERABLE_MODES[a] then
      Hypr.switch_mode(a)
      return true
    end
    if require("hyprvim.lib.submap").registry[a] then
      return reject("submap", "a mode you can enter; " .. a .. " only makes sense mid-keystroke")
    end
    -- an unknown submap has no binds, which would leave the keyboard stranded
    if not known_submaps()[a] then return reject("submap", "a submap that exists, e.g. NORMAL") end
    hl.dispatch(hl.dsp.submap(a))
    return true
  end,
  layoutcmd      = function(a)
    if a == "" then return reject("layoutcmd", "a layout command, e.g. togglesplit") end
    hl.dispatch(hl.dsp.layout(a))
  end,
  zorder         = function(a)
    if not one_of(a, { "top", "bottom" }) then return reject("zorder", "top or bottom") end
    hl.dispatch(hl.dsp.window.alter_zorder({ mode = a }))
  end,
}

-- Aliases for argument-taking commands
local arg_aliases = {
  ws = "workspace",
  focus = "window",
  move_to_workspace = "move_workspace",
  ["move!"] = "move_workspace!",
  send_monitor = "move_monitor",
  send_special = "move_special",
  resize = "resize_width",
  vresize = "resize_height",
  resize_exact = "size",
  mon = "monitor",
  layoutmsg = "layoutcmd",
  active_opacity = "opacity_active",
  inactive_opacity = "opacity_inactive",
  fullscreen_opacity = "opacity_fullscreen",
}
for alias, canonical in pairs(arg_aliases) do arg_commands[alias] = arg_commands[canonical] end

---Descriptions and argument specs contributed by `Config.commands`.
local user_descriptions, user_arg_specs, user_names = {}, {}, {}

---User commands are either a bare function or `{ fn, desc = ..., args = { ... } }`.
if Config.commands then
  for name, spec in pairs(Config.commands) do
    local fn = type(spec) == "function" and spec or (spec[1] or spec.fn)
    if fn then
      user_names[name] = true
      if type(spec) == "table" then
        user_descriptions[name] = spec.desc
        user_arg_specs[name] = spec.args
      end
      if user_arg_specs[name] then
        arg_commands[name] = fn
      else
        commands[name] = fn
      end
    end
  end
end
-- stylua: ignore end

---Completion descriptions; arg-taking entries carry their argument hint.
-- stylua: ignore start
local descriptions = {
  w = "save window (Ctrl+S)",
  wq = "save, then close window",
  q = "close window",
  ["q!"] = "kill window",
  qa = "close every window in workspace",
  ["qa!"] = "kill every window in workspace",
  only = "close every other window in workspace",
  split = "preselect next window below",
  vsplit = "preselect next window right",
  float = "toggle floating",
  fullscreen = "toggle fullscreen",
  pin = "toggle pin above workspaces",
  center = "center window",
  pseudo = "toggle pseudotiling",
  dim = "toggle window dimming",
  workspace_next = "focus the next workspace",
  workspace_prev = "focus the previous workspace",
  reload = "reload hyprland config",
  update = "update hyprvim",
  lock = "lock the session",
  logout = "log out of the session, after confirming",
  shutdown = "power off, after confirming",
  reboot = "restart the machine, after confirming",
  picker = "pick a color to the clipboard",
  group = "toggle the window into a group",
  group_next = "focus the next window in the group",
  group_prev = "focus the previous window in the group",
  group_lock = "lock or unlock the group",
  marks = "list the marks that are set",
  next = "focus the next window",
  prev = "focus the previous window",
  untag = "clear every tag from the window",
  swallow = "toggle swallowed windows visible",
  renderer_reload = "reload the renderer, e.g. after a monitor change",
  edit = "open the editor in a terminal",
  terminal = "open a terminal",
  help = "show the command reference",
}

local arg_descriptions = {
  workspace = "focus a workspace <N>",
  move = "move window by pixels <X Y>",
  move_workspace = "move window to a workspace <N>",
  ["move_workspace!"] = "move window to a workspace, keep focus here <N>",
  resize_width = "shrink the width <N>",
  resize_height = "shrink the height <N>",
  size = "set the window size <W H>",
  opacity = "set window opacity; +/- adjusts <A [I] [F] | reset [WINDOW]>",
  opacity_active = "set active opacity; +/- adjusts <V [WINDOW]>",
  opacity_inactive = "set inactive opacity; +/- adjusts <V [WINDOW]>",
  opacity_fullscreen = "set fullscreen opacity; +/- adjusts <V [WINDOW]>",
  dim = "set window dimming <on|off [WINDOW]>",
  gaps = "set gaps in and out; +/- adjusts <N>",
  float = "set the floating state <on|off|toggle>",
  fullscreen = "set the fullscreen mode <fullscreen|maximized>",
  monitor = "focus a monitor <NAME>",
  move_monitor = "move window to a monitor <NAME>",
  swap = "swap window in a direction <DIR>",
  special = "toggle a special workspace <NAME>",
  move_special = "move window to a special workspace <NAME>",
  rename = "rename the current workspace <NAME>",
  prop = "set a window property <PROP VALUE [WINDOW]>",
  window = "focus a window by selector <SELECTOR>",
  zorder = "alter the window z-order <top|bottom>",
  help = "show the command reference at one entry <COMMAND>",
  set = "set any Hyprland option <OPTION VALUE>",
  layout = "set the tiling layout <NAME>",
  layoutcmd = "run a command the active layout provides <CMD [ARGS]>",
  tag = "tag the window; +name adds, -name removes <NAME [WINDOW]>",
  untag = "clear every tag from another window <WINDOW>",
  submap = "switch to a HyprVim mode or one of your submaps <NAME>",
  group_move = "move the window into a group in a direction <DIR>",
  group_window = "focus a window in the group by number <N>",
  workspace_monitor = "move this workspace to a monitor <NAME>",
  workspace_swap = "swap the workspaces of two monitors <NAME NAME>",
}
-- stylua: ignore end

---Aliases are folded into the canonical entry instead of listed on their own.
---@type table<string, string[]>
local alias_names = {}
for _, table_ in ipairs({ aliases, arg_aliases }) do
  for alias, canonical in pairs(table_) do
    alias_names[canonical] = alias_names[canonical] or {}
    local list = alias_names[canonical]
    list[#list + 1] = alias
  end
end
for _, list in pairs(alias_names) do
  table.sort(list)
end

---Split "description <ARGS>" into its two parts.
---@return string desc, string args
local function split_args(desc)
  local text, args = desc:match("^(.-) <(.+)>$")
  if text then return text, args end
  return desc, ""
end

---@type PromptCompletion[]
local COMPLETIONS = {}
local seen = {}
local function add(name, desc, takes_args)
  local entry = seen[name]
  if entry then
    -- dim/float/fullscreen work with and without an argument; keep the plain description
    if takes_args then entry.takes_args = true end
    return
  end
  -- the usage is carried apart, so the menu can show it in its own column
  entry = {
    name = name,
    desc = split_args(desc or ""),
    takes_args = takes_args or false,
    aliases = alias_names[name],
  }
  entry.base_desc = entry.desc
  if entry.aliases then entry.desc = entry.desc .. " (" .. table.concat(entry.aliases, ", ") .. ")" end
  seen[name] = entry
  COMPLETIONS[#COMPLETIONS + 1] = entry
end

for name in pairs(commands) do
  if not aliases[name] and not no_confirm[name] then
    add(name, descriptions[name] or user_descriptions[name] or "user command")
  end
end
for name in pairs(arg_commands) do
  if not arg_aliases[name] then add(name, arg_descriptions[name] or user_descriptions[name] or "user command", true) end
end
table.sort(COMPLETIONS, function(a, b) return a.name < b.name end)

---Every name that resolves, aliases included, for the unknown-command suggestion.
local KNOWN_NAMES = {}
for _, source in ipairs({ commands, arg_commands }) do
  for name in pairs(source) do
    KNOWN_NAMES[#KNOWN_NAMES + 1] = name
  end
end
table.sort(KNOWN_NAMES)

---Shell one-liners that list live Hyprland objects as "value<TAB>description" pairs.
local sources = {
  workspaces = [==[hyprctl workspaces | awk '/^workspace ID/ { id=$3; name=$4; gsub(/[()]/,"",name); mon=$7; sub(/:$/,"",mon); printf "%s\t%s on %s\n", id, name, mon }' | sort -n]==],
  specials = [==[hyprctl workspaces | awk '/^workspace ID/ { name=$4; gsub(/[()]/,"",name); if (name ~ /^special:/) { sub(/^special:/,"",name); printf "%s\topen special workspace\n", name } }' | sort -u]==],
  monitors = [==[hyprctl monitors | awk '/^Monitor /{ id=$4; gsub(/[():]/,"",id); printf "%s\tmonitor ID %s\n", $2, id }']==],
  windows = Config.install_dir .. "/scripts/hyprvim-window-list",
  options = [==[hyprctl descriptions | awk -F'"' '/"name":/ { n = $4 } /"description":/ { printf "%s\t%s\n", n, $4 }']==],
}

---Opacity steps offered for any 0-1 value.
---@param label string
---@return { [1]: string, [2]: string }[]
local function opacity_values(label)
  local values = { { "+0.1", "raise " .. label }, { "-0.1", "lower " .. label } }
  for i = 10, 4, -1 do
    local v = string.format("%.1f", i / 10)
    values[#values + 1] = { v, label }
  end
  return values
end

---Selectors Hyprland accepts anywhere a workspace is expected.
local workspace_selectors = {
  { "empty", "first empty workspace" },
  { "e+1", "next open workspace" },
  { "e-1", "previous open workspace" },
  { "previous", "last focused workspace" },
  { "name:", "workspace by name, e.g. name:Web" },
}

local workspace_arg = { hint = "workspace number or name", values = workspace_selectors, source = sources.workspaces }
local monitor_arg = { hint = "monitor name or direction", source = sources.monitors }

---Per-argument candidates, indexed by command name then argument position.
---@type table<string, PromptArgSpec[]>
-- stylua: ignore start
local arg_specs = {
  workspace = { workspace_arg },
  move      = { { hint = "horizontal offset in pixels" }, { hint = "vertical offset in pixels" } },
  move_workspace = { workspace_arg },
  ["move_workspace!"] = { workspace_arg },
  monitor      = { monitor_arg },
  move_monitor = { monitor_arg },
  special      = { { hint = "special workspace name", source = sources.specials } },
  move_special = { { hint = "special workspace name", source = sources.specials } },
  window       = { { hint = "window selector, or pick a window below", source = sources.windows } },
  rename       = { { hint = "new name for the current workspace" } },
  opacity = {
    { hint = "0-1, or reset", values = (function()
        local v = { { "reset", "restore configured opacity" } }
        for _, entry in ipairs(opacity_values("active opacity")) do v[#v + 1] = entry end
        return v
      end)() },
    { hint = "0-1, optional", optional = true, values = opacity_values("inactive opacity") },
    { hint = "0-1, optional", optional = true, values = opacity_values("fullscreen opacity") },
  },
  opacity_active     = { { hint = "0-1", values = opacity_values("active opacity") } },
  opacity_inactive   = { { hint = "0-1", values = opacity_values("inactive opacity") } },
  opacity_fullscreen = { { hint = "0-1", values = opacity_values("fullscreen opacity") } },
  dim  = { { values = { { "on", "dim when inactive" }, { "off", "never dim" } } }, { hint = "window, optional", optional = true, source = sources.windows } },
  gaps = { { hint = "pixels, applied to gaps_in and gaps_out", values = { { "+2", "widen" }, { "-2", "narrow" }, { "0", "" }, { "5", "" }, { "10", "" }, { "20", "" } } } },
  float = { { values = { { "toggle", "toggle floating" }, { "on", "force floating" }, { "off", "force tiled" } } } },
  fullscreen = { { values = { { "fullscreen", "true fullscreen" }, { "maximized", "maximize within gaps" } } } },
  swap   = { { values = { { "l", "left" }, { "r", "right" }, { "u", "up" }, { "d", "down" } } } },
  zorder = { { values = { { "top", "raise above other windows" }, { "bottom", "send behind other windows" } } } },
  set = {
    { hint = "option name, e.g. general:gaps_in", source = sources.options },
    { hint = "value", source = 'set -- $HV_ARGS; ' .. sq(Config.install_dir .. "/scripts/hyprvim-option-values") .. ' "$1"' },
  },
  layout = { {
    hint = "layout name; plugins add their own",
    values = {
      { "dwindle", "spiral tiling" },
      { "master", "master and stack" },
      { "scrolling", "windows on an infinite tape" },
      { "monocle", "one window fills the workspace" },
    },
    source = [==[{ hyprctl layouts 2>/dev/null | grep -v 'unknown request'; hyprctl getoption general:layout | awk '/^str:/ { print $2 }'; } | awk 'NF && !seen[$1]++ && $1 !~ /^(dwindle|master|scrolling|monocle)$/ { printf "%s\tregistered layout\n", $1 }']==],
  } },
  group_move = { { values = { { "l", "left" }, { "r", "right" }, { "u", "up" }, { "d", "down" } } } },
  group_window = { { hint = "window number in the group, counting from 1" } },
  workspace_monitor = { monitor_arg },
  workspace_swap = { monitor_arg, monitor_arg },
  help = { { hint = "command to jump to", values = (function()
    local names = {}
    for _, entry in ipairs(COMPLETIONS) do
      names[#names + 1] = { entry.name, entry.base_desc }
    end
    return names
  end)() } },
  prop = {
    { hint = "window property", values = {
      { "opaque", "disable transparency" },
      { "no_dim", "disable dimming" },
      { "no_blur", "disable blur" },
      { "no_border", "hide the border" },
      { "no_shadow", "hide the shadow" },
      { "no_rounding", "square corners" },
      { "no_anim", "disable animations" },
      { "keep_aspect_ratio", "lock the aspect ratio" },
      { "immediate", "allow tearing" },
      { "alpha", "opacity, 0-1" },
      { "alpha_inactive", "inactive opacity, 0-1" },
      { "alpha_fullscreen", "fullscreen opacity, 0-1" },
    } },
    { hint = "value: 1 or 0 for toggles, 0-1 for alpha", values = { { "1", "on" }, { "0", "off" } } },
    { hint = "window, optional", optional = true, source = sources.windows },
  },
  resize_width  = { { hint = "pixels to shrink the width by" } },
  resize_height = { { hint = "pixels to shrink the height by" } },
  size          = { { hint = "width in pixels" }, { hint = "height in pixels" } },
}
-- stylua: ignore end

for name, spec in pairs(user_arg_specs) do
  arg_specs[name] = spec
end

-- aliases complete their arguments the same way the canonical name does
for alias, canonical in pairs(arg_aliases) do
  if arg_specs[canonical] then arg_specs[alias] = arg_specs[canonical] end
end

---Commands `hl.dsp.layout()` takes, tagged with the layouts that provide them.
-- stylua: ignore start
local layout_commands = {
  { "preselect",       "override the next split direction",            { "dwindle" } },
  { "togglesplit",     "toggle the split direction",                   { "dwindle" } },
  { "swapsplit",       "swap the two halves of the split",             { "dwindle" } },
  { "rotatesplit",     "rotate the split",                             { "dwindle" } },
  { "splitratio",      "change the split ratio",                       { "dwindle" } },
  { "movetoroot",      "move to the root of the workspace tree",       { "dwindle" } },
  { "swapwithmaster",  "swap the window with the master",              { "master" } },
  { "focusmaster",     "focus the master window",                      { "master" } },
  { "addmaster",       "add a master",                                 { "master" } },
  { "removemaster",    "remove a master",                              { "master" } },
  { "mfact",           "change the master split ratio",                { "master" } },
  { "orientationnext", "cycle the orientation",                        { "master" } },
  { "orientationcenter", "put the master in the centre",               { "master" } },
  { "rollnext",        "roll the next window into master",             { "master" } },
  { "rollprev",        "roll the previous window into master",         { "master" } },
  { "swapnext",        "swap with the next window",                    { "master" } },
  { "swapprev",        "swap with the previous window",                { "master" } },
  { "cyclenext",       "focus the next window",                        { "master", "monocle" } },
  { "cycleprev",       "focus the previous window",                    { "master", "monocle" } },
  { "center",          "centre the focused column",                    { "scrolling" } },
  { "colresize",       "resize the column, e.g. +0.2 or +conf",        { "scrolling" } },
  { "consume",         "take the window into the previous column",     { "scrolling" } },
  { "consume_or_expel","consume when alone, expel otherwise",          { "scrolling" } },
  { "expel",           "move the window to its own column",            { "scrolling" } },
  { "promote",         "move the window to a new column ahead",        { "scrolling" } },
  { "fit",             "fit active, visible, all, toend, tobeg, expand", { "scrolling" } },
  { "fit_into_view",   "fit the active column into view",              { "scrolling" } },
  { "focus",           "move focus and centre, wrapping at the ends",  { "scrolling" } },
  { "move",            "scroll by pixels (+200) or columns (+col)",    { "scrolling" } },
  { "swapcol",         "swap the column with l or r",                  { "scrolling" } },
  { "inhibit_scroll",  "freeze the view for this workspace",           { "scrolling" } },
}
-- stylua: ignore end

---Candidates for `:layoutcmd`, narrowed to the layout in use.
---@param active string|nil
---@return { [1]: string, [2]: string }[]
local function layout_command_values(active)
  local values = {}
  for _, cmd in ipairs(layout_commands) do
    for _, layout in ipairs(cmd[3]) do
      if layout == active then values[#values + 1] = { cmd[1], cmd[2] } end
    end
  end
  if #values > 0 then return values end
  for _, cmd in ipairs(layout_commands) do
    values[#values + 1] = { cmd[1], cmd[2] .. " (" .. table.concat(cmd[3], ", ") .. ")" }
  end
  return values
end

arg_specs.tag = {
  { hint = "tag name; +name adds, -name removes, a bare name toggles" },
  { hint = "window, optional", optional = true, source = sources.windows },
}
arg_specs.untag = { { hint = "window to clear", source = sources.windows } }

---Candidates for `:submap`: HyprVim's enterable modes, then every submap that is not
---HyprVim's, read from the cache so internal operator states stay hidden.
---@return PromptArgSpec[]
local function submap_spec()
  local values, internal = {}, {}
  for name in pairs(ENTERABLE_MODES) do
    values[#values + 1] = { name, "HyprVim mode" }
  end
  table.sort(values, function(a, b) return a[1] < b[1] end)
  for name in pairs(require("hyprvim.lib.submap").registry or {}) do
    internal[#internal + 1] = name
  end
  local skip = sq(table.concat(internal, "|"))
  return {
    {
      hint = "mode or submap name",
      values = values,
      source = "cat "
        .. sq(SUBMAP_CACHE)
        .. " 2>/dev/null | awk -v skip="
        .. skip
        .. ' \'BEGIN { n = split(skip, a, "|"); for (i = 1; i <= n; i++) s[a[i]] = 1 } NF && !($0 in s) { printf "%s\\tsubmap\\n", $0 }\'',
    },
  }
end
arg_specs.submap = submap_spec()

-- seeded unfiltered; `Command.prompt` narrows it to the layout in use
arg_specs.layoutcmd = { { hint = "layout command", values = layout_command_values(nil) } }

---Leading argument positions a command cannot run without; 0 when it also runs bare.
---@param name string
---@return integer
local function min_args_of(name)
  if commands[name] or not arg_commands[name] then return 0 end
  local n = 0
  for _, spec in ipairs(arg_specs[name] or { {} }) do
    if spec.optional then break end
    n = n + 1
  end
  return n
end

---Usage word for one argument position, from its fixed values or its hint.
---@param spec PromptArgSpec
---@return string
local function usage_word(spec)
  local values = spec.values or {}
  if not spec.hint and not spec.source and #values > 0 and #values <= 4 then
    local words = {}
    for i, v in ipairs(values) do
      words[i] = v[1]
    end
    return table.concat(words, "|")
  end
  local word = (spec.hint or ""):match("^[^,;]*"):gsub("^%s+", ""):gsub("%s+$", ""):gsub("%s+", "_"):upper()
  return word ~= "" and word or "ARG"
end

---Short signature such as `<A [I] [F] | reset [WINDOW]>`: <> is required, [] optional.
---@param name string
---@param min_args integer
---@return string
local function usage_of(name, min_args)
  local _, usage = split_args(arg_descriptions[name] or user_descriptions[name] or "")
  if usage ~= "" and min_args > 0 then return "<" .. usage .. ">" end
  if usage ~= "" then return usage:match("^%[.*%]$") and usage or ("[" .. usage .. "]") end
  local words = {}
  for i, spec in ipairs(arg_specs[name] or {}) do
    local word = usage_word(spec)
    words[i] = i <= min_args and word or ("[" .. word .. "]")
  end
  usage = table.concat(words, " ")
  return min_args > 0 and ("<" .. usage .. ">") or usage
end

for _, entry in ipairs(COMPLETIONS) do
  entry.min_args = min_args_of(entry.name)
  entry.usage = arg_commands[entry.name] and usage_of(entry.name, entry.min_args) or ""
end

-- stylua: ignore start
local HELP_INTRO = table.concat({
  "Press `:` in NORMAL mode, type a command and press Enter. `Escape` dismisses the bar and `Up` recalls earlier commands.",
  "",
  "- **Tab completes.** With [fzf](https://github.com/junegunn/fzf) installed it opens a searchable menu of commands and what they do; search matches descriptions too, so `close` finds `:q` and `:only`. Without fzf, Tab cycles matches.",
  "- **Arguments complete too.** Tab after a command offers its values: open windows and workspaces, monitors, layouts, the current value and range of any `:set` option.",
  "- **Chain commands** with `|`: `:float on | center | opacity 0.9` runs all three and stops at the first that fails.",
  "- **Adjust instead of set.** A leading `+` or `-` changes a value relatively: `:opacity -0.1`, `:gaps +2`.",
  "- **Target any window.** A trailing selector acts on another window without focusing it: `:opacity 0.8 address:0x1234`.",
  "- **Reach anything else** with `:set OPTION VALUE` for any Hyprland option and `:layoutcmd` for commands your layout provides.",
}, "\n")
-- stylua: ignore end

---Section order for the generated reference; names not listed fall into "Other".
-- stylua: ignore start
local help_groups = {
  { "File / Window",     { "w", "wq", "q", "q!", "qa", "qa!", "only" } },
  { "Layout",            { "split", "vsplit", "float", "fullscreen", "pin", "center", "pseudo", "zorder", "swap" } },
  { "Navigation",        { "window", "next", "prev", "workspace", "workspace_next", "workspace_prev", "monitor", "special" } },
  { "Groups",            { "group", "group_next", "group_prev", "group_window", "group_move", "group_lock" } },
  { "Window Move",       { "move", "move_workspace", "move_workspace!", "move_monitor", "move_special" } },
  { "Window Resize",     { "resize_width", "resize_height", "size" } },
  { "Window Properties", { "opacity", "opacity_active", "opacity_inactive", "opacity_fullscreen", "dim", "prop", "tag", "untag", "swallow" } },
  { "Workspace",         { "rename", "gaps", "workspace_monitor", "workspace_swap" } },
  { "Configuration",     { "set", "layout", "layoutcmd" } },
  { "System",            { "reload", "renderer_reload", "submap", "lock", "update", "logout", "reboot", "shutdown", "picker" } },
  { "Apps",              { "edit", "terminal", "help", "marks" } },
}

---Rows that have no entry in the dispatch tables.
local help_extras = {
  { "Shell", {
    { ":!cmd", "Run a shell command and show its output, e.g. `:!ls`" },
    { ":silent !cmd", "Launch a shell command detached, without showing output, e.g. `:silent !firefox`" },
  } },
  { "Search / Replace", { { ":%s/", "Trigger the editor find and replace (Ctrl+H)" } } },
  { "Prompt", {
    { "Tab", "Complete; with fzf installed this opens a searchable menu, and a second Tab completes arguments" },
    { "Escape", "Dismiss the command bar without running anything" },
    { "a | b", "Run commands in order, stopping at the first that fails; a backslash before the pipe makes it literal" },
    { "N", "Focus workspace N, e.g. :3" },
  } },
}
-- stylua: ignore end

---@param rows { [1]: string, [2]: string }[]
---@return string
local function render_table(rows)
  local w1, w2 = #"Command", #"Description"
  for _, row in ipairs(rows) do
    w1 = math.max(w1, #row[1])
    w2 = math.max(w2, #row[2])
  end
  -- padded by hand: string.format caps field widths at 99
  local function line(a, b)
    return "| " .. a .. string.rep(" ", w1 - #a) .. " | " .. b .. string.rep(" ", w2 - #b) .. " |"
  end
  local out = { line("Command", "Description"), "| " .. string.rep("-", w1) .. " | " .. string.rep("-", w2) .. " |" }
  for _, row in ipairs(rows) do
    out[#out + 1] = line(row[1], row[2])
  end
  return table.concat(out, "\n")
end

---Check the command tables against each other; used by `scripts/check-commands`.
---@return string[] problems  empty when the tables agree
function Command.lint()
  local problems = {}
  local function report(text) problems[#problems + 1] = text end

  for name in pairs(commands) do
    if arg_commands[name] and not (descriptions[name] and arg_descriptions[name]) then
      report(name .. ": takes both forms but is missing one of the two descriptions")
    end
  end
  for name in pairs(commands) do
    if not aliases[name] and not no_confirm[name] and not descriptions[name] and not user_names[name] then
      report(name .. ": no description")
    end
  end
  for name in pairs(no_confirm) do
    if not commands[(name:gsub("!$", ""))] then report(name .. ": skips a confirmation that does not exist") end
  end
  for name in pairs(arg_commands) do
    if not arg_aliases[name] and not arg_descriptions[name] and not user_names[name] then
      report(name .. ": no description")
    end
  end
  for _, pair in ipairs({ { aliases, commands }, { arg_aliases, arg_commands } }) do
    for alias, canonical in pairs(pair[1]) do
      if not pair[2][canonical] then report(alias .. ": alias of unknown command " .. canonical) end
    end
  end
  for name in pairs(descriptions) do
    if not commands[name] then report(name .. ": described but not dispatched") end
  end
  for name in pairs(arg_descriptions) do
    if not arg_commands[name] then report(name .. ": described but not dispatched") end
  end
  for name in pairs(arg_specs) do
    if not arg_commands[name] then report(name .. ": has argument candidates but takes no arguments") end
  end
  for name in pairs(arg_commands) do
    if not arg_aliases[name] and not arg_specs[name] and not user_names[name] then
      report(name .. ": takes arguments with no candidates or hint")
    end
  end
  for name, positions in pairs(arg_specs) do
    for i = 2, #positions do
      if positions[i - 1].optional and not positions[i].optional then
        report(name .. ": argument " .. i .. " is required after an optional one")
      end
    end
  end
  table.sort(problems)
  return problems
end

---Render the command reference from the dispatch tables, so it cannot drift from them.
---@return string markdown
function Command.render_help()
  local grouped = {}
  for _, group in ipairs(help_groups) do
    for _, name in ipairs(group[2]) do
      grouped[name] = true
    end
  end

  local others = {}
  for _, entry in ipairs(COMPLETIONS) do
    if not grouped[entry.name] then others[#others + 1] = entry.name end
  end
  local sections = {}
  for _, group in ipairs(help_groups) do
    sections[#sections + 1] = group
  end
  if #others > 0 then sections[#sections + 1] = { "Other", others } end

  ---@param name string
  ---@param args string
  ---@param desc string
  ---@param aliases string[]|nil
  ---@return { [1]: string, [2]: string }
  local function row(name, args, desc, aliases)
    local command = ":" .. name .. (args ~= "" and (" " .. args) or "")
    local text = desc:gsub("^%l", string.upper)
    if aliases then text = text .. " _(alias: `" .. table.concat(aliases, "`, `") .. "`)_" end
    return { "`" .. command:gsub("|", "\\|") .. "`", text }
  end

  local out = { "# HyprVim Command Reference (`:`)", "", HELP_INTRO, "" }
  for _, group in ipairs(sections) do
    local rows = {}
    for _, name in ipairs(group[2]) do
      local entry = seen[name]
      local plain, with_args = descriptions[name], arg_descriptions[name]
      if plain then rows[#rows + 1] = row(name, "", plain, entry and entry.aliases) end
      if with_args then
        local desc, args = split_args(with_args)
        rows[#rows + 1] = row(name, args, desc, (not plain) and entry and entry.aliases or nil)
      end
      if not plain and not with_args and entry then rows[#rows + 1] = row(name, "", entry.base_desc, entry.aliases) end
    end
    if #rows > 0 then
      out[#out + 1] = "## " .. group[1]
      out[#out + 1] = ""
      out[#out + 1] = render_table(rows)
      out[#out + 1] = ""
    end
  end
  for _, group in ipairs(help_extras) do
    local rows = {}
    for _, item in ipairs(group[2]) do
      rows[#rows + 1] = { "`" .. item[1]:gsub("|", "\\|") .. "`", item[2] }
    end
    out[#out + 1] = "## " .. group[1]
    out[#out + 1] = ""
    out[#out + 1] = render_table(rows)
    out[#out + 1] = ""
  end
  return table.concat(out, "\n")
end

---Levenshtein distance, capped: anything past `limit` is not a useful suggestion.
---@return integer
local function distance(a, b, limit)
  if math.abs(#a - #b) > limit then return limit + 1 end
  local prev = {}
  for j = 0, #b do
    prev[j] = j
  end
  for i = 1, #a do
    local current = { [0] = i }
    local best = current[0]
    for j = 1, #b do
      local cost = a:sub(i, i) == b:sub(j, j) and 0 or 1
      current[j] = math.min(prev[j] + 1, current[j - 1] + 1, prev[j - 1] + cost)
      best = math.min(best, current[j])
    end
    if best > limit then return limit + 1 end
    prev = current
  end
  return prev[#b]
end

---Closest known command name to `name`, by prefix first and edit distance second.
---@param name string
---@return string|nil
local function nearest(name)
  local best, best_distance = nil, 3
  for _, known in ipairs(KNOWN_NAMES) do
    if #name > 1 and known:sub(1, #name) == name then return known end
    local d = distance(name, known, best_distance - 1)
    if d < best_distance then
      best, best_distance = known, d
    end
  end
  return best
end

---Report what an argument-taking command was given without an argument.
---@param cmd string
local function missing_args(cmd)
  local canonical = arg_aliases[cmd] or cmd
  local text, args = (arg_descriptions[canonical] or ""):match("^(.-) <(.+)>$")
  local usage = seen[canonical] and seen[canonical].usage
  reject(cmd, args and (args .. ", to " .. text) or (usage ~= "" and usage) or "an argument")
end

---Look up and run a command string against the dispatch tables and special prefixes.
---@param cmd string  raw input from the prompt (may have leading/trailing whitespace)
---@param restore fun()  re-enters the originating submap (passed to async commands)
---@return true|nil  true if the command dispatched an async operation
local function execute(cmd, restore)
  cmd = cmd:gsub("^%s+", ""):gsub("%s+$", "")

  local fn = commands[cmd]
  if fn then return fn(restore) end

  if arg_commands[cmd] then
    local entry = seen[arg_aliases[cmd] or cmd]
    if entry and entry.min_args == 0 then return arg_commands[cmd]("", restore) end
    return missing_args(cmd)
  end

  -- a bare number focuses that workspace, the way :42 jumps to a line in vim
  if cmd:match("^%d+$") then return Hypr.focus_workspace(tonumber(cmd)) end

  local name, args = cmd:match("^(%S+)%s+(.*)")
  if name then
    local afn = arg_commands[name]
    if afn then return afn(args, restore) end
  end

  if cmd:match("^%%?s/") then
    Hypr.send("CTRL", "h")
    return
  end

  local detached = cmd:match("^silent%s+!(.+)$")
  if detached then return Hypr.exec(detached) end

  local shell_cmd = cmd:match("^!(.+)$")
  if shell_cmd then
    Prompt.shell(shell_cmd, restore)
    return true
  end

  chain_failed = true
  local name = cmd:match("^%S+") or cmd
  local suggestion = nearest(name)
  if suggestion == name then suggestion = nil end
  Hypr.notify(
    "unknown command: " .. name .. (suggestion and (", did you mean :" .. suggestion .. "?") or ""),
    "error",
    3000
  )
end

---Split a line on unescaped |, the way vim separates commands; \| is a literal pipe.
---Shell and substitute lines are never split, since the pipe belongs to them.
---@param line string
---@return string[]
local function split_chain(line)
  if line:match("^%s*!") or line:match("^%s*silent%s+!") or line:match("^%s*%%?s/") then return { line } end
  local parts, buf, i = {}, {}, 1
  while i <= #line do
    local c = line:sub(i, i)
    if c == "\\" and line:sub(i + 1, i + 1) == "|" then
      buf[#buf + 1] = "|"
      i = i + 2
    elseif c == "|" then
      parts[#parts + 1] = table.concat(buf)
      buf = {}
      i = i + 1
    else
      buf[#buf + 1] = c
      i = i + 1
    end
  end
  parts[#parts + 1] = table.concat(buf)
  return parts
end

---Run each command of a chain in order, stopping at the first that fails.
---@param line string
---@param restore fun()
---@return true|nil  true once a command has taken over restoring the submap
local function run_chain(line, restore)
  local segments = {}
  for _, segment in ipairs(split_chain(line)) do
    segments[#segments + 1] = segment:gsub("^%s+", ""):gsub("%s+$", "")
  end
  -- checked up front so a malformed chain runs nothing rather than half of itself
  for _, segment in ipairs(segments) do
    if segment == "" then return reject("|", "a command on each side") end
  end
  for i, segment in ipairs(segments) do
    chain_failed = false
    -- an async command restores the submap itself, so nothing may run after it
    if execute(segment, restore) then
      if i < #segments then
        Hypr.notify(":" .. segment:match("^%S+") .. " waits for input, so it has to come last", "warning", 3000)
      end
      return true
    end
    if chain_failed then return end
  end
end

---Show the `:` command prompt, execute the entered command, then restore the current submap.
function Command.prompt()
  local origin = require("hyprvim.lib.submap").current
  Hypr.suspend_vim()
  hl.timer(function()
    -- the layout can change between prompts, so its messages are collected here
    local ok, active = pcall(hl.get_config, "general:layout")
    arg_specs.submap = submap_spec()
    local spec = { { hint = "layout command", values = layout_command_values(ok and active or nil) } }
    arg_specs.layoutcmd = spec
    for alias, canonical in pairs(arg_aliases) do
      if canonical == "layoutcmd" then arg_specs[alias] = spec end
    end
    local opts = {
      wm_class = "hyprvim-command",
      completions = COMPLETIONS,
      arg_completions = arg_specs,
      shell_source = "compgen -c | sort -u",
      prelude = "hyprctl binds | awk -F': ' '/^[[:space:]]*submap:/ && $2 != \"\" { print $2 }' | sort -u > " .. sq(
        SUBMAP_CACHE .. ".tmp"
      ) .. " && mv " .. sq(SUBMAP_CACHE .. ".tmp") .. " " .. sq(SUBMAP_CACHE),
    }
    Prompt.async(":", opts, function(cmd)
      local function restore()
        if origin and origin ~= "reset" then Hypr.switch_mode(origin) end
      end
      if not cmd then
        restore()
        return
      end
      hl.timer(function()
        if not run_chain(cmd, restore) then restore() end
      end, { timeout = 50, type = "oneshot" })
    end)
    -- stopgap: shrinks (does not close) the unguarded reset→terminal-focus leak window
  end, { timeout = 20, type = "oneshot" })
end

return Command
