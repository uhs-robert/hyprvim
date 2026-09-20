-- vim/commands/command.lua
-- Vim-style command mode (:w, :q, :split, :ws N, etc.)

local Hypr = require("hypr") ---@class HyprVimHyprland
local Config = require("config") ---@class HyprVimConfigModule
local Updater = require("lib.updater") ---@class Updater
local Prompt = require("lib.prompt") ---@class Prompt
local Callback = require("lib.callback") ---@class Callback

local Command = {} --- @class Command

local sq = require("lib.utils").sh_escape

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
local function show_help(restore)
  local help_file = require("lib.utils").tmp_path("command-help") .. ".md"
  local f = io.open(help_file, "w")
  if not f then return end
  f:write(Command.render_help())
  f:close()
  Hypr.cmd_then_dispatch(
    Config.term_cmd("hyprvim-help")
      .. " bash -c "
      .. sq(Config.applications.editor .. " -RM " .. help_file .. "; rm -f " .. help_file),
    Callback.register(restore)
  )()
  return true
end

---Commands that end the session ask for the bang, the way `:q!` does, because the
---completion menu puts them one keystroke apart.
---@param name string
---@param what string
local function needs_bang(name, what)
  Hypr.notify("run :" .. name .. "! to " .. what, "warning", 4000)
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
  reload     = function() os.execute("hyprctl reload &") end,
  update     = function() Updater.update() end,
  lock       = function() Hypr.exec(Config.applications.lock) end,
  logout     = function() needs_bang("logout", "end the session") end,
  ["logout!"] = function()
    if os.execute("command -v hyprshutdown >/dev/null 2>&1") then
      os.execute("hyprshutdown &")
    else
      hl.dispatch(hl.dsp.exit())
    end
  end,
  shutdown   = function() needs_bang("shutdown", "power off") end,
  ["shutdown!"] = function() hl.dispatch(hl.dsp.exec_cmd("systemctl poweroff")) end,
  reboot     = function() needs_bang("reboot", "restart the machine") end,
  ["reboot!"] = function() hl.dispatch(hl.dsp.exec_cmd("systemctl reboot")) end,
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


---Report a rejected argument and return nil so the caller stops.
---@param cmd string
---@param expected string
local function reject(cmd, expected)
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
    if a == "reset" then return Hypr.reset_opacity() end
    local values = {}
    for word in a:gmatch("%S+") do
      local v = unit(word)
      if not v then return reject("opacity", "up to three values between 0 and 1, or reset") end
      values[#values + 1] = v
    end
    if #values == 0 or #values > 3 then return reject("opacity", "up to three values between 0 and 1, or reset") end
    Hypr.set_opacity(values[1], values[2], values[3])
  end,
  dim                = function(a)
    if not one_of(a, { "on", "off" }) then return reject("dim", "on or off") end
    hl.dispatch(hl.dsp.window.set_prop({ prop = "no_dim", value = a == "on" and "0" or "1" }))
  end,
  opacity_active     = function(a)
    local v = unit(a)
    if not v then return reject("opacity_active", "a value between 0 and 1") end
    Hypr.set_active_opacity(v)
  end,
  opacity_inactive   = function(a)
    local v = unit(a)
    if not v then return reject("opacity_inactive", "a value between 0 and 1") end
    Hypr.set_inactive_opacity(v)
  end,
  opacity_fullscreen = function(a)
    local v = unit(a)
    if not v then return reject("opacity_fullscreen", "a value between 0 and 1") end
    Hypr.set_fullscreen_opacity(v)
  end,
  gaps           = function(a)
    local n = int(a)
    if not n or n < 0 then return reject("gaps", "a whole number of pixels") end
    hl.config({ general = { gaps_in = n, gaps_out = n } })
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
    local prop, val = a:match("^(%S+)%s+(.+)$")
    if not prop then return reject("prop", "a property name and a value, e.g. no_dim 1") end
    hl.dispatch(hl.dsp.window.set_prop({ prop = prop, value = val }))
  end,
  window         = function(a) hl.dispatch(hl.dsp.focus({ window = a })) end,
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
  logout = "log out of the session (asks for the bang)",
  ["logout!"] = "log out of the session",
  shutdown = "power off (asks for the bang)",
  ["shutdown!"] = "power off",
  reboot = "restart the machine (asks for the bang)",
  ["reboot!"] = "restart the machine",
  picker = "pick a color to the clipboard",
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
  opacity = "set window opacity <A [I] [F] | reset>",
  opacity_active = "set active opacity <V>",
  opacity_inactive = "set inactive opacity <V>",
  opacity_fullscreen = "set fullscreen opacity <V>",
  dim = "set window dimming <on|off>",
  gaps = "set gaps in and out <N>",
  float = "set the floating state <on|off|toggle>",
  fullscreen = "set the fullscreen mode <fullscreen|maximized>",
  monitor = "focus a monitor <NAME>",
  move_monitor = "move window to a monitor <NAME>",
  swap = "swap window in a direction <DIR>",
  special = "toggle a special workspace <NAME>",
  move_special = "move window to a special workspace <NAME>",
  rename = "rename the current workspace <NAME>",
  prop = "set a window property <PROP VALUE>",
  window = "focus a window by selector <SELECTOR>",
  zorder = "alter the window z-order <top|bottom>",
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
  entry = {
    name = name,
    desc = desc or "",
    takes_args = takes_args or false,
    aliases = alias_names[name],
  }
  entry.base_desc = entry.desc
  if entry.aliases then entry.desc = entry.desc .. " (" .. table.concat(entry.aliases, ", ") .. ")" end
  seen[name] = entry
  COMPLETIONS[#COMPLETIONS + 1] = entry
end

for name in pairs(commands) do
  if not aliases[name] then add(name, descriptions[name] or user_descriptions[name] or "user command") end
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
}

---Opacity steps offered for any 0-1 value.
---@param label string
---@return { [1]: string, [2]: string }[]
local function opacity_values(label)
  local values = {}
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
    { hint = "0-1, optional", values = opacity_values("inactive opacity") },
    { hint = "0-1, optional", values = opacity_values("fullscreen opacity") },
  },
  opacity_active     = { { hint = "0-1", values = opacity_values("active opacity") } },
  opacity_inactive   = { { hint = "0-1", values = opacity_values("inactive opacity") } },
  opacity_fullscreen = { { hint = "0-1", values = opacity_values("fullscreen opacity") } },
  dim  = { { values = { { "on", "dim when inactive" }, { "off", "never dim" } } } },
  gaps = { { hint = "pixels, applied to gaps_in and gaps_out", values = { { "0", "" }, { "2", "" }, { "5", "" }, { "10", "" }, { "20", "" } } } },
  float = { { values = { { "toggle", "toggle floating" }, { "on", "force floating" }, { "off", "force tiled" } } } },
  fullscreen = { { values = { { "fullscreen", "true fullscreen" }, { "maximized", "maximize within gaps" } } } },
  swap   = { { values = { { "l", "left" }, { "r", "right" }, { "u", "up" }, { "d", "down" } } } },
  zorder = { { values = { { "top", "raise above other windows" }, { "bottom", "send behind other windows" } } } },
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


---Section order for the generated reference; names not listed fall into "Other".
-- stylua: ignore start
local help_groups = {
  { "File / Window",     { "w", "wq", "q", "q!", "qa", "qa!", "only" } },
  { "Layout",            { "split", "vsplit", "float", "fullscreen", "pin", "center", "pseudo", "zorder", "swap" } },
  { "Navigation",        { "window", "workspace", "workspace_next", "workspace_prev", "monitor", "special" } },
  { "Window Move",       { "move", "move_workspace", "move_workspace!", "move_monitor", "move_special" } },
  { "Window Resize",     { "resize_width", "resize_height", "size" } },
  { "Window Properties", { "opacity", "opacity_active", "opacity_inactive", "opacity_fullscreen", "dim", "prop" } },
  { "Workspace",         { "rename", "gaps" } },
  { "System",            { "reload", "lock", "update", "logout", "logout!", "reboot", "reboot!", "shutdown", "shutdown!", "picker" } },
  { "Apps",              { "edit", "terminal", "help" } },
}

---Rows that have no entry in the dispatch tables.
local help_extras = {
  { "Shell", { { ":!cmd", "Run a shell command and show its output, e.g. `:!ls`" } } },
  { "Search / Replace", { { ":%s/", "Trigger the editor find and replace (Ctrl+H)" } } },
  { "Prompt", {
    { "Tab", "Complete; with fzf installed this opens a searchable menu, and a second Tab completes arguments" },
    { "Escape", "Dismiss the command bar without running anything" },
  } },
}
-- stylua: ignore end

---Split "description <ARGS>" into its two parts.
---@return string desc, string args
local function split_args(desc)
  local text, args = desc:match("^(.-) <(.+)>$")
  if text then return text, args end
  return desc, ""
end

---@param rows { [1]: string, [2]: string }[]
---@return string
local function render_table(rows)
  local function width(text) return #text end
  local w1, w2 = #"Command", #"Description"
  for _, row in ipairs(rows) do
    w1 = math.max(w1, width(row[1]))
    w2 = math.max(w2, width(row[2]))
  end
  local out = {
    string.format("| %-" .. w1 .. "s | %-" .. w2 .. "s |", "Command", "Description"),
    string.format("| %s | %s |", string.rep("-", w1), string.rep("-", w2)),
  }
  for _, row in ipairs(rows) do
    local pad1 = string.rep(" ", w1 - width(row[1]))
    local pad2 = string.rep(" ", w2 - width(row[2]))
    out[#out + 1] = string.format("| %s%s | %s%s |", row[1], pad1, row[2], pad2)
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
    if not aliases[name] and not descriptions[name] and not user_names[name] then report(name .. ": no description") end
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

  local out = { "# HyprVim Command Reference (`:`)", "" }
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
  reject(cmd, args and (args .. ", to " .. text) or "an argument")
end

---Look up and run a command string against the dispatch tables and special prefixes.
---@param cmd string  raw input from the prompt (may have leading/trailing whitespace)
---@param restore fun()  re-enters the originating submap (passed to async commands)
---@return true|nil  true if the command dispatched an async operation
local function execute(cmd, restore)
  cmd = cmd:gsub("^%s+", ""):gsub("%s+$", "")

  local fn = commands[cmd]
  if fn then return fn(restore) end

  if arg_commands[cmd] then return missing_args(cmd) end

  local name, args = cmd:match("^(%S+)%s+(.*)")
  if name then
    local afn = arg_commands[name]
    if afn then return afn(args) end
  end

  if cmd:match("^%%?s/") then
    Hypr.send("CTRL", "h")
    return
  end

  local shell_cmd = cmd:match("^!(.+)$")
  if shell_cmd then
    Hypr.cmd_then_dispatch(
      Config.term_cmd("hyprvim-shell")
        .. " bash -c "
        .. sq(
          "_hv_tmp=$(mktemp); "
            .. shell_cmd
            .. ' 2>&1 | tee "$_hv_tmp";'
            .. " [ -s \"$_hv_tmp\" ] && { echo; read -rsn1 -p '[done] press any key...'; };"
            .. ' rm -f "$_hv_tmp"'
        ),
      Callback.register(restore)
    )()
    return true
  end

  local name = cmd:match("^%S+") or cmd
  local suggestion = nearest(name)
  if suggestion == name then suggestion = nil end
  Hypr.notify(
    "unknown command: " .. name .. (suggestion and (", did you mean :" .. suggestion .. "?") or ""),
    "error",
    3000
  )
end

---Show the `:` command prompt, execute the entered command, then restore the current submap.
function Command.prompt()
  local origin = require("lib.submap").current
  Hypr.suspend_vim()
  hl.timer(function()
    local opts = { wm_class = "hyprvim-command", completions = COMPLETIONS, arg_completions = arg_specs }
    Prompt.async(":", opts, function(cmd)
      local function restore()
        if origin and origin ~= "reset" then Hypr.switch_mode(origin) end
      end
      if not cmd then
        restore()
        return
      end
      hl.timer(function()
        if not execute(cmd, restore) then restore() end
      end, { timeout = 50, type = "oneshot" })
    end)
    -- stopgap: shrinks (does not close) the unguarded reset→terminal-focus leak window
  end, { timeout = 20, type = "oneshot" })
end

return Command
