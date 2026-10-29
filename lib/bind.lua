--- Key binding helpers built on top of hl.bind.

local config = require("hyprvim.config")

--- @class HyprVimBindLib
local Bind = {
  leader = (config.keys or {}).leader or "SUPER",
}

--- Whether Hyprland is 0.57 or newer, whose rewritten keybind manager matches a key against the submap it was
--- pressed in, for the press and its key-up alike.
local KEYBINDS_V2 = (function()
  local version = type(hl.version) == "function" and hl.version() or nil
  if type(version) ~= "string" then return false end
  local major, minor = version:match("^(%d+)%.(%d+)")
  major, minor = tonumber(major), tonumber(minor)
  if not major then return false end
  return major > 0 or minor >= 57
end)()

--- Options for a bind that leaves its submap (exit vim, Back).
--- Before 0.57 it runs on key-up. On key-down the same press fires the bind it lands on (the global LEADER+V
--- re-enters vim), and the key-up reaches the next submap's release catchall. On 0.57 neither happens, while a
--- key-up bind lets its key-down reach the app and is shadowed once another key is let go first, so it never fires.
--- @return HL.BindOptions|nil
function Bind.leave_submap_opts()
  if KEYBINDS_V2 then return nil end
  return { release = true }
end

--- @param value string|string[]
--- @return string[]
local function as_list(value)
  if type(value) == "table" then return value end
  return { value }
end

--- @param prefix string
--- @param key    string
--- @return string
local function with_prefix(prefix, key)
  if not prefix or prefix == "" then return key end
  return prefix .. " + " .. key
end

--- @param keys   string|string[]
--- @param action HL.Dispatcher|function
--- @param desc   string|HL.BindOptions|nil
--- @param opts   HL.BindOptions|nil
function Bind.key(keys, action, desc, opts)
  if type(desc) == "table" and opts == nil then
    opts = desc
    desc = nil
  end

  opts = opts or {}

  if desc then
    opts.desc = desc --[[@as string]]
  end

  for _, key in ipairs(as_list(keys)) do
    hl.bind(key, action, opts)
  end
end

--- @param keys   string|string[]
--- @param action HL.Dispatcher|function
--- @param desc   string|HL.BindOptions|nil
--- @param opts   HL.BindOptions|nil
function Bind.leader_key(keys, action, desc, opts)
  local prefixed = {}
  for _, k in ipairs(as_list(keys)) do
    table.insert(prefixed, with_prefix(Bind.leader, k))
  end
  Bind.key(prefixed, action, desc, opts)
end

--- @param rows     { [1]: string|string[], [2]: any, [3]: string|HL.BindOptions|nil, [4]: HL.BindOptions|nil }[]
--- @param defaults HL.BindOptions|nil
function Bind.keys(rows, defaults)
  for _, row in ipairs(rows or {}) do
    local desc, row_opts = row[3], row[4]
    if type(desc) == "table" and row_opts == nil then
      row_opts = desc
      desc = nil
    end
    local opts = {}
    for k, v in pairs(defaults or {}) do
      opts[k] = v
    end
    for k, v in pairs(row_opts or {}) do
      opts[k] = v
    end
    Bind.key(row[1], row[2], desc, opts)
  end
end

---Pass the key through to the active window unchanged.
---@return fun()
function Bind.pass()
  return function() hl.dispatch(hl.dsp.pass({ window = "active" })) end
end

return Bind
