-- whichkey/lib/items.lua
-- Builds HUD item JSON arrays for marks, registers, and generic submaps.

local Utils = require("hyprvim.lib.utils") ---@class HyprVimUtils
local file_exists = Utils.file_exists
local write_file = Utils.write_file
local pread = Utils.pread
local sh_escape = Utils.sh_escape
local json_escape = Utils.json_escape

local Config = require("hyprvim.config") ---@class HyprVimConfigModule
local Clipboard = require("hyprvim.lib.clipboard") ---@class Clipboard
local Hyprctl = require("hyprvim.whichkey.lib.hyprctl") ---@class HyprCtl
local Find = require("hyprvim.vim.features.find") ---@class Find

--- @class Items
local Items = {}

--- Strips a trailing incomplete UTF-8 sequence left by byte-level truncation.
--- @param s string
--- @return string
local function trim_partial_utf8(s)
  local i = #s
  while i > 0 and s:byte(i) >= 0x80 and s:byte(i) < 0xC0 do
    i = i - 1
  end
  if i > 0 then
    local b = s:byte(i)
    local need = (b >= 0xF0 and 4) or (b >= 0xE0 and 3) or (b >= 0xC0 and 2) or 1
    if b >= 0xC0 and #s - i + 1 < need then return s:sub(1, i - 1) end
  end
  return s
end

-- TODO: build_mark_items exists because hl.bind descriptions cannot be updated or removed
-- per-submap once registered; only hl.unbind exists and it is global. So whichkey reads
-- marks.json directly instead of relying on hyprctl bind descriptions.
-- If Hyprland gains per-submap unbind:
--   - Remove build_mark_items entirely; MARKS/SET-MARK/DELETE-MARK fall through to
--     Hyprctl.build_items like every other submap.
--   - In vim-marks.lua refresh callback, replace the no-op overwrite pattern with
--     hl.unbind calls for deleted mark keys so binds are cleanly removed.
-- Track: https://github.com/hyprwm/Hyprland/discussions/15040
--- @param sm string
--- @return string|nil
function Items.build_mark_items(sm)
  local marks_file = Config.state_dir .. "/marks.json"
  if sm ~= "MARKS" and sm ~= "SET-MARK" and sm ~= "DELETE-MARK" then return nil end

  local marks_jq = 'to_entries | map(select(.value | type == "object")) | map({'
    .. 'key:.key, desc:((.value.class // "?") + '
    .. '(if ((.value.title // "") | length) > 0 then " \\u00b7 " + (.value.title | .[0:20]) else "" end) + '
    .. '" [ws:" + (.value.workspace | tostring) + "]"), class:""}) | '
    .. 'sort_by(if (.key | test("^[a-z]$")) then [0,.key] elif (.key | test("^[A-Z]$")) then [1,.key] else [2,.key] end)'

  -- SET-MARK: show occupied slots; fall through to hyprctl when none so all slots appear.
  if sm == "SET-MARK" then
    if not file_exists(marks_file) then return nil end
    local result = pread("jq -c '" .. marks_jq .. "' " .. sh_escape(marks_file) .. " 2>/dev/null")
    if result == "" or result == "[]" or result == "null" then return nil end
    return result
  end

  -- MARKS / DELETE-MARK: always return a result (never fall through to hyprctl so stale
  -- hl.bind descriptions never leak into the HUD as ghost entries).
  -- Exit keys live in the HUD footer; the placeholder keeps the HUD open when no marks exist
  local empty_items = '[{"key":"-","desc":"No marks set","class":""}]'
  local tail_items = sm == "DELETE-MARK" and '[{"key":"DELETE","desc":"Clear all marks","class":""}]' or "[]"

  if not file_exists(marks_file) then return empty_items end

  local expr = "((" .. marks_jq .. ") + " .. tail_items .. ") | if length > 0 then . else " .. empty_items .. " end"
  local result = pread("jq -c " .. sh_escape(expr) .. " " .. sh_escape(marks_file) .. " 2>/dev/null")
  if result == "" or result == "null" then return empty_items end
  return result
end

--- @param sm string
--- @return string|nil
function Items.build_register_items(sm)
  if sm ~= "REGISTERS" then return nil end
  local reg_dir = Config.state_dir .. "/registers"
  if not file_exists(reg_dir) then return nil end

  local function make_item(key, prefix, content, fallback)
    local desc
    if content ~= "" then
      desc = prefix ~= "" and ("[" .. prefix .. "] " .. content) or content
      if #desc > 45 then
        desc = trim_partial_utf8(desc:sub(1, 42)) .. "..."
      else
        desc = trim_partial_utf8(desc)
      end
    elseif fallback then
      desc = fallback
    else
      return nil
    end
    return '{"key":"' .. json_escape(key) .. '","desc":"' .. json_escape(desc) .. '","class":""}'
  end

  local items = {}
  local function add(k, p, path, fallback)
    local item = make_item(k, p, Utils.read_head(path, 50), fallback)
    if item then items[#items + 1] = item end
  end

  local pre_vim = Utils.read_head(Clipboard.pre_vim_path(), 50)
  items[#items + 1] = make_item("PLUS", "system", pre_vim, "System clipboard")

  local primary = pread("wl-paste --primary --no-newline 2>/dev/null"):gsub("%s+", " "):gsub("^ ", "")
  items[#items + 1] = make_item("ASTERISK", "primary", primary, "Primary selection")

  add('"', "default", reg_dir .. '/"', "Unnamed register (default)")
  add("0", "yank", reg_dir .. "/0", "Yank register (last yank)")
  items[#items + 1] = make_item("_", "", "", "Black hole register")
  for _, n in ipairs({ "1", "2", "3", "4", "5", "6", "7", "8", "9" }) do
    add(n, "delete", reg_dir .. "/" .. n)
  end
  for c in ("abcdefghijklmnopqrstuvwxyz"):gmatch(".") do
    add(c, "", reg_dir .. "/" .. c)
  end

  items[#items + 1] = make_item("/", "search", Find.get_term(), "Search register")

  return "[" .. table.concat(items, ",") .. "]"
end

--- Fetches HUD items for submap, writes them to a temp file, and retries once on empty.
--- Returns items JSON, temp file path, and item count. Count 0 means nothing to show.
--- @param submap string
--- @return string items_json, string items_tmp, integer count
function Items.resolve(submap)
  local function fetch()
    return Items.build_mark_items(submap) or Items.build_register_items(submap) or Hyprctl.build_items(submap) or "[]"
  end
  local tmp = Utils.tmp_path("whichkey-items")
  local items = fetch()
  write_file(tmp, items)
  local count = tonumber(pread("jq -c 'length' " .. sh_escape(tmp) .. " 2>/dev/null")) or 0
  if count == 0 then
    -- Retry once hyprctl binds may lag submap transitions
    os.execute("sleep 0.02")
    items = fetch()
    write_file(tmp, items)
    count = tonumber(pread("jq -c 'length' " .. sh_escape(tmp) .. " 2>/dev/null")) or 0
  end
  if count == 0 then os.remove(tmp) end
  return items, tmp, count
end

return Items
