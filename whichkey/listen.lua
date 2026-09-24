-- whichkey/listen.lua
-- Registers hl event handlers for the which-key HUD.

local dir = debug.getinfo(1, "S").source:sub(2):match("(.*/)") or "./"

local Render = require("hyprvim.whichkey.render") ---@class Render
local Utils = require("hyprvim.lib.utils") ---@class HyprVimUtils
local Theme = require("hyprvim.whichkey.theme")
local Submap = require("hyprvim.lib.submap") ---@class HyprVimSubmap
local sh_escape = Utils.sh_escape
local read_file = Utils.read_file
local file_exists = Utils.file_exists

--- @class Listen
local Listen = {}

--- Direct reference to the active pending HUD timer, set by make_submap_handler.
--- Allows Listen.cancel_pending() to kill it immediately without waiting for the callback.
local _pending_timer_ref = nil

--- Cancel the pending HUD timer immediately. Call from keybind actions that exit an
--- operator-pending submap so the HUD does not flash after the action completes.
function Listen.cancel_pending()
  if _pending_timer_ref then
    _pending_timer_ref:set_enabled(false)
    _pending_timer_ref = nil
  end
end

--- Returns true if sm is a persistent mode that should not auto-show the HUD.
--- @param sm string
--- @return boolean
local function is_sticky(sm)
  local spec = Submap.registry[sm]
  return spec ~= nil and spec.sticky == true
end

--- Returns true if sm is an operator-pending mode that needs a show delay.
--- @param sm string
--- @return boolean
local function requires_delay(sm)
  local spec = Submap.registry[sm]
  return spec ~= nil and spec.operator == true
end

--- Extracts and normalises which-key config from the top-level Config table.
--- @param Config table
--- @return { delay_ms: integer, vim_delay_ms: integer, position: string, deny_set: table, allow_set: table, has_allow: boolean }
local function parse_config(Config)
  local wk = Config.which_key or {}
  local auto = wk.auto_show or {}
  local deny_set = {}
  local allow_set = {}
  local has_allow = false
  if type(auto.disabled) == "table" then
    for _, v in ipairs(auto.disabled) do
      deny_set[v] = true
    end
  end
  if type(auto.enabled) == "table" then
    for _, v in ipairs(auto.enabled) do
      allow_set[v] = true
    end
    has_allow = true
  end
  return {
    delay_ms = wk.delay_ms or 0,
    vim_delay_ms = wk.vim_delay_ms or 300,
    position = wk.position or "bottom-right",
    deny_set = deny_set,
    allow_set = allow_set,
    has_allow = has_allow,
  }
end

--- Returns true if the HUD should be shown automatically for sm.
--- Respects the deny/allow lists from config; falls back to hiding only sticky modes.
--- @param sm string
--- @param config table
--- @return boolean
local function should_auto_show(sm, config)
  if config.deny_set[sm] then return false end
  if config.has_allow then return config.allow_set[sm] == true end
  return not is_sticky(sm)
end

--- @class DelayContext
--- @field sm string
--- @field prev_sm string
--- @field next_delay string   raw one-shot file contents, "" if absent
--- @field delay_ms integer
--- @field vim_delay_ms integer
--- @field submap_delay_ms integer|nil  per-submap override from SubmapSpec.delay_ms
--- @field hud_visible boolean

--- Returns the millisecond delay before showing the HUD.
--- next_delay overrides everything; submap_delay_ms beats vim_delay_ms/delay_ms;
--- HUD-visible chain collapses to 0 when both submaps are operator-pending.
--- @param ctx DelayContext
--- @return integer
local function compute_delay(ctx)
  if ctx.next_delay ~= "" then return tonumber(ctx.next_delay) or 0 end
  if requires_delay(ctx.sm) then
    if requires_delay(ctx.prev_sm) and ctx.hud_visible then return 0 end
    return ctx.submap_delay_ms or ctx.vim_delay_ms
  end
  return ctx.submap_delay_ms or ctx.delay_ms
end

--- Starts the eww daemon in the background (or pings it if already running),
--- then applies the current theme.
--- @param eww_dir string
local function init_eww(eww_dir)
  Theme.apply()
-- stylua: ignore
  os.execute(
    "("
      .. "eww -c "
      .. sh_escape(eww_dir)
      .. " ping >/dev/null 2>&1"
      .. " || eww -c "
      .. sh_escape(eww_dir)
      .. " daemon >/dev/null 2>&1"
      .. ") &"
  )
end

--- Reads one-shot skip/delay flags from state files, consuming them where appropriate.
--- Targetless skips and delay overrides are deleted on read; targeted skips stay until matched.
--- @param state_dir string
--- @return boolean skip_next
--- @return string skip_target
--- @return string next_delay
local function read_oneshot_flags(state_dir)
  local skip_path = state_dir .. "/whichkey-skip-next"
  local target_path = state_dir .. "/whichkey-skip-target"
  local delay_path = state_dir .. "/whichkey-next-delay"

  local skip_next = file_exists(skip_path)
  local skip_target = read_file(target_path)
  local next_delay = read_file(delay_path)

  -- Consume targetless skip and delay flags immediately; targeted skip stays until matched.
  if skip_next and skip_target == "" then os.remove(skip_path) end
  if next_delay ~= "" then os.remove(delay_path) end

  return skip_next, skip_target, next_delay
end

--- Removes the skip-next and skip-target flag files.
--- @param state_dir string
local function clear_skip_files(state_dir)
  os.remove(state_dir .. "/whichkey-skip-next")
  os.remove(state_dir .. "/whichkey-skip-target")
end

--- Returns true if the skip flag applies to sm and clears the flag files.
--- A targeted skip only matches when skip_target == sm; an untargeted skip matches any sm.
--- @param skip_next boolean
--- @param skip_target string
--- @param sm string
--- @param state_dir string
--- @return boolean
local function resolve_skip(skip_next, skip_target, sm, state_dir)
  if not skip_next then return false end
  if skip_target ~= "" and skip_target ~= sm then return false end
  clear_skip_files(state_dir)
  return true
end

--- Returns a function that spawns render.lua in the background for sm.
--- Guards against stale renders by checking the current-submap state file before rendering.
--- @param eww_dir string
--- @param state_dir string
--- @param render string  path to render.lua
--- @param position string
--- @return fun(sm: string)
local function make_spawner(eww_dir, state_dir, render, position)
  local script = dir .. "../scripts/whichkey-spawn"
  return function(sm)
    local mon = hl.get_active_monitor()
    local screen = (mon and mon.name) or ""
    local rotated = mon and ((mon.transform or 0) % 2 == 1)
    local geometry = mon
        and string.format(
          "%dx%dx%s",
          rotated and mon.height or mon.width,
          rotated and mon.width or mon.height,
          mon.scale
        )
      or ""
    local csm = state_dir .. "/current-submap"
    os.execute(
      Render.spawn_env()
        .. sh_escape(script)
        .. " "
        .. sh_escape(eww_dir)
        .. " "
        .. sh_escape(csm)
        .. " "
        .. sh_escape(sm)
        .. " "
        .. sh_escape(position)
        .. " "
        .. sh_escape(render)
        .. " "
        .. sh_escape(screen)
        .. " "
        .. sh_escape(geometry)
        .. " &"
    )
  end
end

--- Closes the HUD only if it is actually visible, avoiding a shell fork
--- and eww IPC round-trips on every submap change while hidden.
--- @param state_dir string
local function close_hud(state_dir)
  if file_exists(state_dir .. "/whichkey-visible") then Render.close() end
end

--- Returns the keybinds.submap event handler.
--- Tracks previous submap for delay chaining, manages the pending timer,
--- and decides whether to show the HUD immediately, after a delay, or not at all.
--- @param config table  parsed config from parse_config()
--- @param state_dir string
--- @param spawn_render fun(sm: string)
--- @return fun(sm: string)
local function make_submap_handler(config, state_dir, spawn_render)
  state_dir = state_dir or ""
  local last_sm, prev_sm = "", ""
  local pending_timer, pending_target, stale_check_timer = nil, nil, nil

  local function write_current_submap(sm)
    if sm ~= "" then
      local f = io.open(state_dir .. "/current-submap", "w")
      if f then
        f:write(sm .. "\n")
        f:close()
      end
    else
      os.remove(state_dir .. "/current-submap")
    end
  end

  local function cancel_timer()
    if pending_timer then
      pending_timer:set_enabled(false)
      pending_timer = nil
      _pending_timer_ref = nil
    end
  end

  local function teardown(sm)
    cancel_timer()
    if stale_check_timer then
      stale_check_timer:set_enabled(false)
      stale_check_timer = nil
    end
    close_hud(state_dir)
    write_current_submap(sm)
  end

  local function schedule_hud(sm, dms)
    pending_target = sm
    pending_timer = hl.timer(function()
      pending_timer = nil
      _pending_timer_ref = nil
      local t = pending_target
      if last_sm ~= t then return end
      spawn_render(t)
      -- Stale-render guard: if the submap changed while the subprocess was rendering,
      -- the close() that fired during the handler ran before eww opened the window.
      -- Check after a render-completion window and close any now-orphaned HUD.
      local render_sm = t
      stale_check_timer = hl.timer(function()
        stale_check_timer = nil
        if last_sm ~= render_sm then close_hud(state_dir) end
      end, { timeout = 500, type = "oneshot" })
    end, { timeout = math.max(dms, 1), type = "oneshot" })
    _pending_timer_ref = pending_timer
  end

  return function(sm)
    sm = sm or ""
    if sm == last_sm then return end
    prev_sm = last_sm
    last_sm = sm

    -- Chaining between operator-pending submaps while the timer is still running:
    -- redirect the timer to the new submap so the clock continues from when the
    -- first operator key was pressed rather than restarting.
    if pending_timer and requires_delay(sm) and requires_delay(prev_sm) then
      pending_target = sm
      write_current_submap(sm)
      return
    end

    teardown(sm)

    local skip_next, skip_target, next_delay = read_oneshot_flags(state_dir)
    if sm == "" then
      clear_skip_files(state_dir)
      return
    end
    if sm == "NORMAL" then clear_skip_files(state_dir) end
    if resolve_skip(skip_next, skip_target, sm, state_dir) then return end
    if not should_auto_show(sm, config) then return end

    local spec = Submap.registry[sm]
    schedule_hud(
      sm,
      compute_delay({
        sm = sm,
        prev_sm = prev_sm,
        next_delay = next_delay,
        delay_ms = config.delay_ms,
        vim_delay_ms = config.vim_delay_ms,
        submap_delay_ms = spec and spec.delay_ms,
        hud_visible = file_exists(state_dir .. "/whichkey-visible"),
      })
    )
  end
end

--- Initialises the which-key HUD listener.
--- Starts the eww daemon (eww frontend only), then registers window.open and keybinds.submap handlers.
--- @param Config table  top-level HyprVim config table
function Listen.init(Config)
  local config = parse_config(Config)
  local eww_dir = Render.eww_dir
  local state_dir = Render.state_dir
  local render = dir .. "render.lua"

  if Render.frontend() == "eww" then
    init_eww(eww_dir)
  else
    Theme.apply()
  end

  local spawn_render = make_spawner(eww_dir, state_dir, render, config.position)

  hl.on("window.open", function() close_hud(state_dir) end)
  hl.on("keybinds.submap", make_submap_handler(config, state_dir, spawn_render))
end

return Listen
