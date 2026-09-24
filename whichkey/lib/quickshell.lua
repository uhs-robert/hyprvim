-- whichkey/lib/quickshell.lua
-- Quickshell frontend for the WhichKey HUD: writes a JSON payload and drives the `hyprvim_whichkey` IPC target.

local Utils = require("hyprvim.lib.utils") ---@class HyprVimUtils
local sh_escape = Utils.sh_escape
local json_escape = Utils.json_escape

local Config = require("hyprvim.config") ---@class HyprVimConfigModule
local Theme = require("hyprvim.whichkey.theme")

--- @class Quickshell
local Quickshell = {}

Quickshell.TARGET = "hyprvim_whichkey"
Quickshell.PAYLOAD_VERSION = 1

--- @class QuickshellPayloadFields
--- @field submap string
--- @field title string
--- @field position string
--- @field screen string
--- @field columns integer

local PAYLOAD_JQ = "{version: $version, submap: $submap, title: $title, position: $position, screen: $screen,"
  .. ' columns: $columns, items: ($items[0] | map({key, desc, group: (.class == "is-submap")})),'
  .. ' footer: [{key: "ESC", desc: "close"}, {key: "BS", desc: "back"}], theme: $theme}'

--- IPC command prefix; the env var carries the configured value into render subprocesses.
--- @return string
function Quickshell.ipc_prefix()
  local env = os.getenv("HYPRVIM_WHICH_KEY_QS_IPC")
  if env and env ~= "" then return env end
  return (Config.which_key and Config.which_key.quickshell_ipc) or "qs ipc"
end

--- Path of the payload file handed to `show`.
--- @return string
function Quickshell.payload_path() return Config.state_dir .. "/whichkey.json" end

--- theme.conf variables as a flat JSON object of strings.
--- @return string
local function theme_json()
  local parts = {}
  for _, var in ipairs(Theme.read_vars()) do
    parts[#parts + 1] = '"' .. json_escape(var.name) .. '":"' .. json_escape(var.value) .. '"'
  end
  return "{" .. table.concat(parts, ",") .. "}"
end

--- Write the payload atomically so the frontend never reads a partial file.
--- @param fields QuickshellPayloadFields
--- @param items_tmp string  path to the resolved items JSON array
--- @return string|nil  payload path, or nil when writing failed
function Quickshell.write_payload(fields, items_tmp)
  local path = Quickshell.payload_path()
  local tmp = path .. ".tmp"
  -- stylua: ignore
  local ok = os.execute(
    "jq -c -n"
      .. " --slurpfile items " .. sh_escape(items_tmp)
      .. " --argjson version " .. Quickshell.PAYLOAD_VERSION
      .. " --arg submap " .. sh_escape(fields.submap)
      .. " --arg title " .. sh_escape(fields.title)
      .. " --arg position " .. sh_escape(fields.position)
      .. " --arg screen " .. sh_escape(fields.screen)
      .. " --argjson columns " .. math.floor(fields.columns)
      .. " --argjson theme " .. sh_escape(theme_json())
      .. " " .. sh_escape(PAYLOAD_JQ)
      .. " > " .. sh_escape(tmp) .. " 2>/dev/null"
      .. " && mv -f " .. sh_escape(tmp) .. " " .. sh_escape(path)
  )
  if not ok then
    os.remove(tmp)
    return nil
  end
  return path
end

--- Ask the frontend to show the payload at path; blocks until the IPC call returns.
--- @param path string
--- @return boolean  false when no Quickshell instance answered
function Quickshell.show(path)
  local cmd = Quickshell.ipc_prefix() .. " call " .. Quickshell.TARGET .. " show " .. sh_escape(path)
  return os.execute(cmd .. " >/dev/null 2>&1") == true
end

--- Shell command that hides the HUD, for callers that batch it into a background job.
--- @return string
function Quickshell.hide_cmd()
  return Quickshell.ipc_prefix() .. " call " .. Quickshell.TARGET .. " hide >/dev/null 2>&1"
end

return Quickshell
