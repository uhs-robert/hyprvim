--- Key binding helpers built on top of hl.bind.

local config = require("hyprvim.config")

--- @class HyprVimBindLib
local Bind = {
  leader = (config.keys or {}).leader or "SUPER",
}

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
