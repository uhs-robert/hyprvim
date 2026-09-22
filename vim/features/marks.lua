-- vim/features/marks.lua
-- Window/workspace bookmark system.
-- Marks store: workspace id, window address, monitor name, class, title.
-- State: $XDG_RUNTIME_DIR/hyprvim/marks.json

local Hypr = require("hyprvim.hypr") ---@class HyprVimHyprland
local Config = require("hyprvim.config") ---@class HyprVimConfigModule
local Utils = require("hyprvim.lib.utils") ---@class HyprVimUtils

--- @class Marks
--- @field enter_set    fun()  enter the SET-MARK submap
--- @field enter_jump   fun()  refresh MARKS submap binds then enter it
--- @field enter_delete fun()  refresh DELETE-MARK submap binds then enter it
local Marks = {}

---@return string  absolute path to the marks state file
local function marks_path() return Config.state_dir .. "/marks.json" end

---@class Mark
---@field workspace integer
---@field window    string   hex window address
---@field monitor   string   monitor name
---@field class     string   window class
---@field title     string   window title

---Read all marks from the JSON state file.
---@return table<string, Mark>
local function json_read()
  local f = io.open(marks_path(), "r")
  if not f then return {} end
  local s = f:read("*a")
  f:close()
  local t = {}
  -- json_write escapes quotes/braces inside strings, so these patterns cannot misfire.
  local function field(body, name)
    local v = body:match('"' .. name .. '"%s*:%s*"([^"]*)"')
    return v and Utils.json_unescape(v)
  end
  -- Each mark: "X": { "workspace": N, "window": "0x...", "monitor": "...", ... }
  for key, body in s:gmatch('"([^"]*)"%s*:%s*(%b{})') do
    local m = {}
    m.workspace = tonumber(body:match('"workspace"%s*:%s*(%d+)'))
    m.window = field(body, "window")
    m.monitor = field(body, "monitor")
    m.class = field(body, "class")
    m.title = field(body, "title")
    t[Utils.json_unescape(key)] = m
  end
  return t
end

---Serialise `t` and write it to the marks state file.
---@param t table<string, Mark>
local function json_write(t)
  local esc = Utils.json_escape
  local parts = {}
  for k, m in pairs(t) do
    parts[#parts + 1] = string.format(
      '  "%s": {"workspace":%d,"window":"%s","monitor":"%s","class":"%s","title":"%s"}',
      esc(k),
      m.workspace or 0,
      esc(m.window or ""),
      esc(m.monitor or ""),
      esc(m.class or ""),
      esc(m.title or "")
    )
  end
  table.sort(parts)
  local f = io.open(marks_path(), "w")
  if f then
    f:write("{\n" .. table.concat(parts, ",\n") .. "\n}\n")
    f:close()
  end
end

---@return string  absolute path to the after-submap state file
local function after_path() return Config.state_dir .. "/marks-after" end

---Store which submap to return to after a mark operation completes.
---@param submap string|nil  submap name; defaults to `"NORMAL"`
function Marks.set_after(submap)
  local f = io.open(after_path(), "w")
  if f then
    f:write(submap or "NORMAL")
    f:close()
  end
end

---Read the stored after-submap, remove the state file, and switch to that mode.
---A `"reset"` target means a full vim exit (clipboard restore + submap reset).
---Missing file defaults to `"reset"`: the in-vim entry points always call set_after
---first, so an absent file means the submap was entered outside a vim session (external
---script or global bind), which should exit to global rather than drop into vim.
function Marks.dispatch_after()
  local f = io.open(after_path(), "r")
  local target = "reset"
  if f then
    target = f:read("*a"):gsub("%s+$", "")
    f:close()
    os.remove(after_path())
  end
  if target == "reset" then return require("hyprvim.vim.exit")() end
  Hypr.switch_mode(target ~= "" and target or "NORMAL")
end

---Send a notification via Hyprland if marks notifications are enabled in config.
---@param msg     string
---@param urgency string|nil  `"low"` (hint), `"normal"` (default/info), or `"critical"` (error)
local function notify(msg, urgency)
  local notifications = Config.notifications or {}
  if not (notifications.all or notifications.marks) then return end
  local icon = ({ low = "hint", normal = "info", critical = "error" })[urgency or "normal"] or "info"
  Hypr.notify(msg, icon, 3000)
end

---Save the active window and workspace as mark `char`.
---@param char string  single character mark name
function Marks.set(char)
  if not char or char == "" then return end

  local win = hl.get_active_window()
  local mon = hl.get_active_monitor()
  if not win then
    notify("No active window", "critical")
    Marks.dispatch_after()
    return
  end

  local ws = win.workspace and win.workspace.id or 0
  local addr = win.address or ""
  local cls = win.class or ""
  local ttl = win.title or ""
  local mname = mon and mon.name or ""

  local marks = json_read()
  marks[char] = { workspace = ws, window = addr, monitor = mname, class = cls, title = ttl }
  json_write(marks)

  notify(string.format("Mark '%s' -> %s (ws:%d)", char, cls, ws))
  Marks.dispatch_after()
end

---Focus the window stored in mark `char`. Removes the mark if the window no longer exists.
---`focuswindow address:X` switches workspace automatically.
---@param char string
function Marks.jump(char)
  if not char or char == "" then return end

  local marks = json_read()
  local m = marks[char]
  if not m then
    notify("Mark '" .. char .. "' not set", "critical")
    Marks.dispatch_after()
    return
  end

  local windows = hl.get_windows()
  for _, w in ipairs(windows or {}) do
    if w.address == m.window then
      Hypr.focus_window(m.window)
      notify(string.format("Jumped to '%s' -> %s", char, m.class or ""))
      Marks.dispatch_after()
      return
    end
  end

  -- Stale mark: remove it.
  marks[char] = nil
  json_write(marks)
  notify(string.format("Mark '%s' deleted (window closed)", char), "low")
  Marks.dispatch_after()
end

---Remove mark `char` from the state file.
---@param char string
function Marks.delete(char)
  if not char or char == "" then return end
  local marks = json_read()
  if not marks[char] then
    notify("Mark '" .. char .. "' not set", "critical")
    Marks.dispatch_after()
    return
  end
  marks[char] = nil
  json_write(marks)
  notify("Deleted mark '" .. char .. "'")
  Marks.dispatch_after()
end

---Delete every mark and notify with the count cleared.
function Marks.clear()
  local marks = json_read()
  local n = 0
  for _ in pairs(marks) do
    n = n + 1
  end
  if n == 0 then
    notify("No marks to clear", "low")
    Marks.dispatch_after()
    return
  end
  json_write({})
  notify(string.format("Cleared %d marks", n))
  Marks.dispatch_after()
end

---Return the raw marks table (char -> Mark).
---@return table<string, Mark>
function Marks.all() return json_read() end

---Return all marks as a formatted multiline string and post a desktop notification.
---@return string
function Marks.list()
  local marks = json_read()
  local lines = {}
  local keys = {}
  for k in pairs(marks) do
    keys[#keys + 1] = k
  end
  table.sort(keys)
  for _, k in ipairs(keys) do
    local m = marks[k]
    local ttl = (m.title or ""):sub(1, 30)
    lines[#lines + 1] = string.format("%s: %s (ws:%d)", k, ttl, m.workspace or 0)
  end
  local result = (#lines > 0) and table.concat(lines, "\n") or "No marks set"
  -- Explicit list request: always notify, unlike the gated set/jump toasts.
  Hypr.notify(string.format("Marks (%d)\n%s", #lines, result), "info", 5000)
  return result
end

return Marks
