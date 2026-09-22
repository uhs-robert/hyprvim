--- Submap lifecycle manager for HyprVim.
local Bind = require("hyprvim.lib.bind") ---@class HyprVimBindLib

--- @class HyprVimSubmap
local Submap = {
  --- @type table<string, SubmapSpec>
  registry = {},
  --- @type string
  current = "reset",
  --- @type string|nil
  previous = nil,
}

--- @class SubmapContext
--- @field current  string
--- @field previous string|nil
--- @field submaps  table
--- @field [string] any

--- @class SubmapSpec
--- @field name      string
--- @field desc?     string
--- @field enter?    string|string[]
--- @field escape?   "reset"|"previous"|string|false|fun(ctx: SubmapContext)  Exit on ESCAPE; defaults to "reset"
--- @field back?     "escape"|"previous"|string|false|fun(ctx: SubmapContext)  BackSpace target; default mirrors escape; "previous" = history via Submap.back(); false = no bind
--- @field catchall? "stay"|"reset"|false|fun(ctx: SubmapContext)   Unbound-key policy; defaults to false
--- @field on_enter? fun(ctx: SubmapContext)
--- @field on_exit?  fun(ctx: SubmapContext)
--- @field binds?    table[]|fun(): table[]
--- @field delay_ms? integer  Per-submap which-key HUD delay override; overrides global which_key.delay_ms
--- @field operator? boolean  Operator-pending mode; which-key HUD waits vim_delay_ms and chains delays
--- @field sticky?   boolean  Persistent mode; which-key HUD never auto-shows

--- @class SubmapHandle
--- @field enter fun()
--- @field back  fun()
--- @field setup fun()

--- Build a context table, optionally merged with extra fields.
--- @param extra table|nil
--- @return SubmapContext
local function context(extra)
  local ctx = { current = Submap.current, previous = Submap.previous, submaps = Submap }
  for k, v in pairs(extra or {}) do
    ctx[k] = v
  end
  return ctx
end

--- Fire the on_exit hook for a spec if present.
--- @param spec SubmapSpec|nil
--- @param from string
--- @param to   string
local function fire_exit(spec, from, to)
  if spec and spec.on_exit then spec.on_exit(context({ from = from, to = to })) end
end

--- Activate a named submap, firing exit/enter hooks.
--- Re-entering the current submap only re-dispatches (no hooks, no state change).
--- @param name string
function Submap.enter(name)
  if name == "reset" then return Submap.reset() end

  local next_spec = Submap.registry[name]
  if not next_spec then return end

  if name == Submap.current then
    hl.dispatch(hl.dsp.submap(name))
    return
  end

  local prev_name = Submap.current
  fire_exit(Submap.registry[prev_name], prev_name, name)

  Submap.previous = prev_name
  Submap.current = name

  hl.dispatch(hl.dsp.submap(name))

  if next_spec.on_enter then next_spec.on_enter(context({ from = prev_name, to = name, spec = next_spec })) end
end

--- Return to the global (reset) submap, firing the current submap's exit hook.
---@param opts? { is_temporary?: boolean }  if is_temporary, only dispatch to Hyprland without updating state
function Submap.reset(opts)
  if opts and opts.is_temporary then
    hl.dispatch(hl.dsp.submap("reset"))
    return
  end
  local prev_name = Submap.current
  fire_exit(Submap.registry[prev_name], prev_name, "reset")

  Submap.previous = prev_name
  Submap.current = "reset"

  hl.dispatch(hl.dsp.submap("reset"))
end

--- Exit the submap according to its spec.escape policy.
--- @param spec SubmapSpec
function Submap.exit(spec)
  local escape = spec.escape
  if escape == nil then escape = "reset" end

  if escape == false then return end
  if escape == "reset" then return Submap.reset() end
  if escape == "previous" then return Submap.back() end
  if type(escape) == "string" then return Submap.enter(escape) end
  if type(escape) == "function" then return escape(context({ spec = spec })) end
  return Submap.reset()
end

--- Return a function that switches to a named submap.
--- @param name string
--- @return fun()
function Submap.switch(name)
  return function() Submap.enter(name) end
end

--- Go back to the previous submap, or reset if there is none.
function Submap.back()
  local prev = Submap.previous
  if prev and prev ~= "reset" then
    Submap.enter(prev)
    Submap.previous = nil
    return
  end
  return Submap.reset()
end

--- Reconcile tracked state with a keybinds.submap event (covers raw/async dispatches).
--- State only, hooks never fire.
--- @param name string|nil  event payload ("" = reset)
function Submap.sync(name)
  if name == nil or name == "" or name == "reset" then return end
  if name == Submap.current then return end
  Submap.previous = Submap.current
  Submap.current = name
end

--- Resolve catchall policy, defaulting to false.
--- @param spec SubmapSpec
local function normalize_catchall(spec)
  if spec.catchall == nil then return false end
  return spec.catchall
end

--- Evaluate binds, calling the function if it is one.
--- @param binds table[]|fun(): table[]|nil
--- @return table[]|nil
local function resolve_binds(binds)
  if type(binds) == "function" then return binds() end
  return binds
end

--- Merge user keymap overrides for a named submap on top of built-in binds.
--- User entries with a matching key replace the built-in entry; new keys are appended.
--- @param name         string
--- @param builtin      table[]|nil
--- @return table[]
local function merge_user_keymaps(name, builtin)
  local cfg = require("hyprvim.config") --[[@as HyprVimConfig]]
  local user = cfg.keymaps and cfg.keymaps[name]
  if not user or #user == 0 then return builtin or {} end

  local overridden = {}
  for _, row in ipairs(user) do
    local keys = type(row[1]) == "table" and row[1] or { row[1] }
    for _, k in ipairs(keys) do
      overridden[k] = true
    end
  end

  local result = {}
  for _, row in ipairs(builtin or {}) do
    local keys = type(row[1]) == "table" and row[1] or { row[1] }
    local skip = false
    for _, k in ipairs(keys) do
      if overridden[k] then
        skip = true
        break
      end
    end
    if not skip then result[#result + 1] = row end
  end

  for _, row in ipairs(user) do
    -- shift opts from [3] to [4] so Bind.keys treats it correctly
    result[#result + 1] = type(row[3]) == "table" and { row[1], row[2], nil, row[3] } or row
  end
  return result
end

--- Invoke an action: calls if function, dispatches if HL dispatcher.
--- @param action HL.Dispatcher|function
local function run(action)
  if type(action) == "function" then return action() end
  return hl.dispatch(action)
end

--- Wrap rows with opts.oneshot = true so their action calls exit_fn after firing.
--- Marks wrapped rows opts.keep = true to prevent double-wrap.
--- @param rows    table[]
--- @param exit_fn fun()
--- @return table[]
local function apply_individual_oneshots(rows, exit_fn)
  local result = {}
  for _, row in ipairs(rows) do
    local opts = row[4]
    if type(opts) == "table" and opts.oneshot then
      local kept = { keep = true }
      for k, v in pairs(opts) do
        if k ~= "oneshot" then kept[k] = v end
      end
      result[#result + 1] = {
        row[1],
        function()
          run(row[2])
          exit_fn()
        end,
        row[3],
        kept,
      }
    else
      result[#result + 1] = row
    end
  end
  return result
end

--- Wrap all rows so every action calls exit_fn after firing (oneshot mode).
--- Skips rows already marked opts.keep = true.
--- @param rows    table[]
--- @param exit_fn fun()
--- @return table[]
local function wrap_oneshot(rows, exit_fn)
  local wrapped = {}
  for _, row in ipairs(rows) do
    local opts = row[4]
    if type(opts) == "table" and opts.keep then
      wrapped[#wrapped + 1] = row
    else
      wrapped[#wrapped + 1] = {
        row[1],
        function()
          run(row[2])
          exit_fn()
        end,
        row[3],
        opts,
      }
    end
  end
  return wrapped
end

--- Register the catchall bind for a submap.
--- @param catchall "stay"|"reset"|false|fun(ctx: SubmapContext)
--- @param exit_fn  fun()
--- @param spec     SubmapSpec
local function bind_catchall(catchall, exit_fn, spec)
  local opts = { release = true, ignore_mods = true }
  if catchall == "stay" then
    hl.bind("catchall", hl.dsp.no_op(), opts)
  elseif catchall == "reset" then
    hl.bind("catchall", exit_fn, opts)
  elseif type(catchall) == "function" then
    hl.bind("catchall", function() catchall(context({ spec = spec })) end, opts)
  end
end

--- Declare a submap and return a handle with enter/exit/back/setup methods.
--- Call handle.setup() once during startup to register all binds.
--- @param spec SubmapSpec
--- @return SubmapHandle
function Submap.define(spec)
  Submap.registry[spec.name] = spec

  local M = {}

  function M.enter() Submap.enter(spec.name) end

  function M.exit() Submap.exit(spec) end

  function M.back()
    local back = spec.back
    if back == nil then return M.exit() end
    if back == false then return end
    if back == "escape" then return M.exit() end
    if back == "previous" then return Submap.back() end
    if type(back) == "string" then return Submap.enter(back) end
    if type(back) == "function" then return back(context({ spec = spec })) end
    M.exit()
  end

  function M.setup()
    if spec.enter then Bind.key(spec.enter, M.enter, spec.desc or ("+" .. spec.name)) end

    hl.define_submap(spec.name, function()
      local catchall = normalize_catchall(spec)
      local raw_binds =
        apply_individual_oneshots(merge_user_keymaps(spec.name, resolve_binds(spec.binds)) or {}, M.exit)
      local binds = catchall == "reset" and wrap_oneshot(raw_binds, M.exit) or raw_binds

      Bind.keys(binds)

      if spec.escape ~= false then
        Bind.key("ESCAPE", M.exit, "Exit " .. spec.name)
        if spec.back ~= false then
          local back_opts = catchall == "reset" and { release = true } or nil
          local back_label = type(spec.back) == "string" and ("Back to " .. spec.back) or ("Exit " .. spec.name)
          Bind.key("BackSpace", M.back, back_label, back_opts)
        end
      end

      bind_catchall(catchall, M.exit, spec)
    end)
  end

  return M
end

return Submap
