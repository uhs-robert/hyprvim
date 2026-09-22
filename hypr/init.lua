local Submap = require("hyprvim.lib.submap") ---@class HyprVimSubmap
local sh_escape = require("hyprvim.lib.utils").sh_escape

local DEFAULT_DELAY_MS = 20

--- @class HyprVimHyprland
local Hyprland = {}

--- @param mods string modifier string ("CTRL", "CTRL SHIFT", "" for none)
--- @param key string key name ("RIGHT", "HOME", "c", etc.)
--- @param window? string target window (default: activewindow)
function Hyprland.send(mods, key, window)
  hl.dispatch(hl.dsp.send_shortcut({ mods = mods, key = key, window = window or "activewindow" }))
end

--- @param shortcuts {[1]: string, [2]: string, [3]?: string}[] entries as {mods, key[, window]}
function Hyprland.send_all(shortcuts)
  for _, s in ipairs(shortcuts) do
    Hyprland.send(s[1], s[2], s[3])
  end
end

--- Send shortcuts sequentially via chained hyprctl eval + sleep (avoids double-send from hl.timer).
--- @param shortcuts {[1]: string, [2]: string, [3]?: string}[]
--- @param delay_ms  integer|nil  ms between each key (default 20)
--- @param cb        fun()|nil    called ~delay_ms after last key fires
function Hyprland.send_batch(shortcuts, delay_ms, cb)
  local delay = (delay_ms or DEFAULT_DELAY_MS) / 1000
  local parts = {}
  for _, s in ipairs(shortcuts) do
    parts[#parts + 1] = string.format(
      "hyprctl dispatch 'hl.dsp.send_shortcut({mods=[[%s]],key=[[%s]],window=[[%s]]})'",
      s[1] or "",
      s[2],
      s[3] or "activewindow"
    )
  end
  local cmd = table.concat(parts, string.format(" && sleep %.3f && ", delay))
  hl.dispatch(hl.dsp.exec_cmd(cmd))
  if cb then hl.timer(cb, { timeout = (delay_ms or DEFAULT_DELAY_MS) * #shortcuts, type = "oneshot" }) end
end

--- Send shortcuts in one hyprctl --batch (single IPC round, no inter-key delay).
--- IPC dispatch escapes the bind handler's input-processing context, avoiding the
--- stuck-key race with the physical key release (LibreOffice autorepeat runaway).
--- @param shortcuts {[1]: string, [2]: string, [3]?: string}[] entries as {mods, key[, window]}
--- @param cb        fun()|nil called shortly after the batch fires
function Hyprland.send_burst(shortcuts, cb)
  local parts = {}
  for _, s in ipairs(shortcuts) do
    parts[#parts + 1] = string.format(
      "dispatch hl.dsp.send_shortcut({mods=[[%s]],key=[[%s]],window=[[%s]]})",
      s[1] or "",
      s[2],
      s[3] or "activewindow"
    )
  end
  hl.dispatch(hl.dsp.exec_cmd("hyprctl --batch " .. sh_escape(table.concat(parts, " ; "))))
  if cb then hl.timer(cb, { timeout = 50, type = "oneshot" }) end
end

--- @param name string submap name
function Hyprland.switch_mode(name) Submap.enter(name) end

--- Return to NORMAL mode.
function Hyprland.normal() Submap.enter("NORMAL") end

--- Temporarily suspend vim mode for a prompt; preserves submap state so it can be restored.
function Hyprland.suspend_vim() Submap.reset({ is_temporary = true }) end

--- Focus a specific window by its hex address.
---@param addr string  hex window address (e.g. "0x1234abcd")
function Hyprland.focus_window(addr) hl.dispatch(hl.dsp.focus({ window = "address:" .. addr })) end

--- Close the active window gracefully.
function Hyprland.close_window() hl.dispatch(hl.dsp.window.close()) end

--- Force-kill the active window.
function Hyprland.kill_window() hl.dispatch(hl.dsp.window.kill()) end

--- Close or kill the given windows, each targeted by address.
--- @param addresses string[]  window addresses (e.g. "0x1234abcd"); blanks are skipped
--- @param kill      boolean    true -> kill (SIGKILL), false -> graceful close
function Hyprland.close_windows(addresses, kill)
  local action = kill and hl.dsp.window.kill or hl.dsp.window.close
  for _, addr in ipairs(addresses) do
    if addr and addr ~= "" then hl.dispatch(action({ window = "address:" .. addr })) end
  end
end

--- Toggle floating on the active window.
function Hyprland.toggle_floating() hl.dispatch(hl.dsp.window.float()) end

--- Toggle fullscreen (mode 1 = maximize).
function Hyprland.toggle_fullscreen() hl.dispatch(hl.dsp.window.fullscreen(1)) end

--- Toggle pin (show on all workspaces).
function Hyprland.toggle_pin() hl.dispatch(hl.dsp.window.pin()) end

--- Toggle pseudo-tiling.
function Hyprland.toggle_pseudo() hl.dispatch(hl.dsp.window.pseudo()) end

--- Center the active floating window.
function Hyprland.center_window() hl.dispatch(hl.dsp.window.center()) end

---Set one window property, on `window` when given and the focused window otherwise.
---@param prop string
---@param value string|number
---@param window string|nil  window selector, e.g. "address:0x1234"
local function set_prop(prop, value, window)
  hl.dispatch(hl.dsp.window.set_prop({ prop = prop, value = tostring(value), window = window }))
end

--- @param active number active opacity 0.0–1.0
--- @param inactive number|nil inactive opacity; omit to leave unchanged
--- @param fullscreen number|nil fullscreen opacity; omit to leave unchanged
--- @param window string|nil window selector; omit for the focused window
function Hyprland.set_opacity(active, inactive, fullscreen, window)
  set_prop("opacity", active, window)
  set_prop("opacity_override", 1, window)
  if inactive then
    set_prop("opacity_inactive", inactive, window)
    set_prop("opacity_inactive_override", 1, window)
  end
  if fullscreen then
    set_prop("opacity_fullscreen", fullscreen, window)
    set_prop("opacity_fullscreen_override", 1, window)
  end
end

--- @param v number
--- @param window string|nil
function Hyprland.set_active_opacity(v, window)
  set_prop("opacity", v, window)
  set_prop("opacity_override", 1, window)
end

--- @param v number
--- @param window string|nil
function Hyprland.set_inactive_opacity(v, window)
  set_prop("opacity_inactive", v, window)
  set_prop("opacity_inactive_override", 1, window)
end

--- @param v number
--- @param window string|nil
function Hyprland.set_fullscreen_opacity(v, window)
  set_prop("opacity_fullscreen", v, window)
  set_prop("opacity_fullscreen_override", 1, window)
end

--- Reset opacity to window-rule defaults (removes any setprop override).
--- @param window string|nil
function Hyprland.reset_opacity(window)
  for _, prop in ipairs({ "opacity", "opacity_inactive", "opacity_fullscreen" }) do
    set_prop(prop, 1, window)
    set_prop(prop .. "_override", 0, window)
  end
end

local _nodim = {} -- address -> bool, tracks no_dim state per window

function Hyprland.toggle_dim()
  local win = hl.get_active_window()
  if not win then return end
  _nodim[win.address] = not _nodim[win.address]
  hl.dispatch(hl.dsp.window.set_prop({ prop = "no_dim", value = _nodim[win.address] and "1" or "0" }))
end

--- @param delta integer +1 or -1
function Hyprland.workspace_rel(delta)
  hl.dispatch(hl.dsp.focus({ workspace = "e" .. (delta >= 0 and "+" or "") .. tostring(delta) }))
end

--- @param n integer|string workspace number or selector (e.g. "name:Web", "empty", "e+1")
function Hyprland.focus_workspace(n) hl.dispatch(hl.dsp.focus({ workspace = n })) end

--- @param n integer|string workspace number or selector
function Hyprland.move_to_workspace(n) hl.dispatch(hl.dsp.window.move({ workspace = n })) end

---@type table<string, integer>
local NOTIFY_ICONS = {
  warning = 0,
  info = 1,
  hint = 2,
  error = 3,
  confused = 4,
  ok = 5,
}

---@param msg     string
---@param icon    string|nil   `"warning"`, `"info"`, `"hint"`, `"error"`, `"confused"`, `"ok"` (default `"info"`)
---@param time_ms integer|nil  display duration in ms (default 3000)
---@param color   string|nil   hex color e.g. `"rgb(ff0000)"` (default `"0"` = icon default)
function Hyprland.notify(msg, icon, time_ms, color)
  local icon_id = NOTIFY_ICONS[icon or "info"] or NOTIFY_ICONS.info
  time_ms = time_ms or 3000
  color = color or "0"
  hl.dispatch(
    hl.dsp.exec_cmd(string.format("hyprctl notify %d %d %s %s", icon_id, time_ms, color, sh_escape("HyprVim: " .. msg)))
  )
end

--- Reload Hyprland config.
function Hyprland.reload() hl.dispatch(hl.dsp.exec_cmd("hyprctl reload")) end

--- @param cmd string
function Hyprland.exec(cmd) hl.dispatch(hl.dsp.exec_cmd(cmd)) end

--- Run cmd, then dispatch a Lua expr via hyprctl once it exits.
--- Acts as shell --block: awaits the shell command before dispatching.
--- @param cmd string            Shell command to run
--- @param dispatch_expr string  hl.dsp.* Lua expression, e.g. 'hl.dsp.submap("Cursor")'
--- @return fun()
function Hyprland.cmd_then_dispatch(cmd, dispatch_expr)
  return function() hl.dispatch(hl.dsp.exec_cmd(cmd .. " ; hyprctl dispatch '" .. dispatch_expr .. "'")) end
end

return Hyprland
