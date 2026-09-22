-- vim/features/find.lua
-- f/F/t/T character search and //?/*/#  document search.
-- Find operations require a prompt dialog and clipboard interaction, so they
-- exit vim mode for input, then re-enter once the search term is submitted.

local Hypr = require("hyprvim.hypr") ---@class HyprVimHyprland
local Config = require("hyprvim.config") ---@class HyprVimConfigModule
local Prompt = require("hyprvim.lib.prompt") ---@class Prompt
local Clipboard = require("hyprvim.lib.clipboard") ---@class Clipboard
local exit_vim = require("hyprvim.vim.exit")
local SEL = require("hyprvim.vim.lib.motion.shortcuts").SELECT

--- @class Find
local Find = {}

---@return string  absolute path to the find state file
local function state_path() return Config.state_dir .. "/find-state.json" end

---Read the flat-string/boolean JSON state file into a table.
---@return table<string, string>
local function state_read()
  local f = io.open(state_path(), "r")
  if not f then return {} end
  local t = {}
  for line in f:lines() do
    local k, raw = line:match('^%s*"([^"]+)"%s*:%s*"(.*)"')
    if k then
      t[k] = raw:gsub("\\(.)", function(c)
        if c == '"' then return '"' end
        if c == "\\" then return "\\" end
        if c == "n" then return "\n" end
        if c == "r" then return "\r" end
        return c
      end)
    else
      k = line:match('^%s*"([^"]+)"%s*:%s*true')
      if k then
        t[k] = "true"
      else
        k = line:match('^%s*"([^"]+)"%s*:%s*false')
        if k then t[k] = "false" end
      end
    end
  end
  f:close()
  return t
end

---Serialise `t` and write it to the find state file.
---@param t table<string, string>
local function state_write(t)
  local parts = {}
  for k, v in pairs(t) do
    if v == "true" or v == "false" then
      parts[#parts + 1] = string.format('  "%s": %s', k, v)
    else
      parts[#parts + 1] = string.format('  "%s": %q', k, tostring(v))
    end
  end
  table.sort(parts)
  local json = "{\n" .. table.concat(parts, ",\n") .. "\n}\n"
  local f = io.open(state_path(), "w")
  if f then
    f:write(json)
    f:close()
  end
end

---Open the app's find bar (Ctrl+F), paste `term`, and commit the search.
---Persists all state so `n`/`N`/`;`/`,` can repeat or reverse later.
---@param term      string   search string
---@param direction string   `"forward"` or `"backward"`
---@param term_type string   state key: `"char_term"` or `"find_term"`
---@param is_till   boolean  true when called from `t`/`T` (cursor stops before match)
local function do_find(term, direction, term_type, is_till)
  local t = state_read()
  t.active = "true"
  t.direction = direction
  t[term_type] = term
  t.last_action_direction = direction
  t.last_action_term_type = term_type
  t.till = is_till and "true" or "false"
  state_write(t)

  Clipboard.write(term)
  hl.timer(function()
    Hypr.send("CTRL", "f")
    hl.timer(function()
      Hypr.send("CTRL", "v")
      hl.timer(function()
        Hypr.send("", "Return")
        Hypr.normal()
      end, { timeout = 100, type = "oneshot" })
    end, { timeout = 150, type = "oneshot" })
  end, { timeout = 50, type = "oneshot" })
end

---Exit vim mode, show the search prompt, then call `do_find` with the entered term.
---@param term_type string   `"char_term"` or `"find_term"`
---@param direction string   `"forward"` or `"backward"`
---@param is_till   boolean
local function prompt_and_find(term_type, direction, is_till)
  local label = (term_type == "char_term") and "Find: " or "Search: "
  exit_vim()
  hl.timer(function()
    Prompt.async(label, { wm_class = "hyprvim-find" }, function(term)
      if not term then
        Hypr.normal()
        return
      end
      term = term:gsub("[\r\n]", ""):gsub("%s+$", "")
      if term == "" then
        Hypr.normal()
        return
      end
      hl.timer(function() do_find(term, direction, term_type, is_till) end, { timeout = 50, type = "oneshot" })
    end)
    -- TODO: stopgap: shrinks (does not close) the unguarded reset terminal-focus leak window
  end, { timeout = 20, type = "oneshot" })
end

---Repeat the last find: F3/Shift+F3 while the find bar is open, else re-run `do_find`.
---@param term_type string   `"char_term"` or `"find_term"`
---@param flip      boolean  true to reverse direction (i.e. `N` vs `n`)
local function repeat_find(term_type, flip)
  local t = state_read()
  local active = t.active or "false"
  local direction = t.direction or "forward"
  local term = t[term_type] or ""

  if active == "true" then
    local use_shift = (direction == "backward")
    if flip then use_shift = not use_shift end
    hl.timer(function()
      Hypr.send(use_shift and "SHIFT" or "", "F3")
      Hypr.normal()
    end, { timeout = 20, type = "oneshot" })
  else
    if term == "" then
      Hypr.normal()
      return
    end
    local new_dir = direction
    if flip then new_dir = (direction == "forward") and "backward" or "forward" end
    hl.timer(function() do_find(term, new_dir, term_type, false) end, { timeout = 20, type = "oneshot" })
  end
end

---Select the word under the cursor via keyboard shortcuts, copy it, and search for it.
---Implements `*` (forward) and `#` (backward).
---@param direction string  `"forward"` or `"backward"`
local function word_under_cursor(direction)
  hl.timer(function()
    Hypr.send_all(SEL.inner_word)
    hl.timer(function()
      Clipboard.read_primary_async(150, function(s)
        Hypr.send("", "RIGHT") -- deselect
        hl.dispatch(hl.dsp.exec_cmd("wl-copy --primary < /dev/null"))
        local term = s:gsub("[\r\n]", ""):gsub("%s+$", ""):match("^%S+") or ""
        if term == "" then
          Hypr.normal()
          return
        end
        do_find(term, direction, "find_term", false)
      end)
    end, { timeout = 50, type = "oneshot" })
  end, { timeout = 20, type = "oneshot" })
end

-- Public API all map directly to vim motions:
--   f/F  char forward/backward       t/T  till forward/backward
--   /    search forward              ?    search backward
--   */#  word under cursor           n/N  repeat/reverse search
--   ;/,  repeat/reverse char find

function Find.char_forward() prompt_and_find("char_term", "forward", false) end
function Find.char_backward() prompt_and_find("char_term", "backward", false) end
function Find.char_till_forward() prompt_and_find("char_term", "forward", true) end
function Find.char_till_backward() prompt_and_find("char_term", "backward", true) end
function Find.search_forward() prompt_and_find("find_term", "forward", false) end
function Find.search_backward() prompt_and_find("find_term", "backward", false) end
function Find.forward_word() word_under_cursor("forward") end
function Find.backward_word() word_under_cursor("backward") end
function Find.next_search() repeat_find("find_term", false) end
function Find.prev_search() repeat_find("find_term", true) end
function Find.next_char() repeat_find("char_term", false) end
function Find.prev_char() repeat_find("char_term", true) end

---Return the last document search term, or `""` if none.
---@return string
function Find.get_term() return state_read().find_term or "" end

---Dismiss the active find bar and clean up till/active state.
---Called when leaving NORMAL mode so the app's find UI is not left open.
function Find.deactivate()
  local t = state_read()
  local active = t["active"] or "false"
  local till = t["till"] or "false"
  if active ~= "true" and till ~= "true" then return end
  if active == "true" then Hypr.send("", "Escape") end
  if till == "true" then
    Hypr.send("", "LEFT")
    t["till"] = "false"
  end
  t["active"] = "false"
  state_write(t)
end

return Find
