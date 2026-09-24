-- config.lua

local Utils = require("hyprvim.lib.utils") ---@class HyprVimUtils

-- stylua: ignore
local TERM_FLAGS = {
  kitty      = { class = "--class",   exec = "-e" },
  ghostty    = { class = "--class",   exec = "-e" },
  alacritty  = { class = "--class",   exec = "-e" },
  wezterm    = { class = "--class",   exec = "--",  pre = "start" },
  foot       = { class = "--app-id",  exec = "-e" },
  footclient = { class = "--app-id",  exec = "-e" },
  xterm      = { class = "-class",    exec = "-e" },
}

local XDG = os.getenv("XDG_RUNTIME_DIR") or "/tmp"
local XCC = os.getenv("XDG_CONFIG_HOME") or ((os.getenv("HOME") or "") .. "/.config")

--- @class HyprVimKeys
--- @field leader?   "SUPER"|"ALT"|"CTRL"|"SHIFT"|"META"|"HYPER"  Hyprland modifier key used as the vim leader
--- @field activate? string  Key name pressed together with leader to enter NORMAL mode (e.g. "V")
--- @field exit?     string  Key name pressed together with leader to exit ANY mode (e.g. "ESCAPE")

--- @class HyprVimTermFlags
--- @field class string  Flag used to set the window class (e.g. "--class" or "--app-id")
--- @field exec  string  Flag used to run a command (e.g. "-e" or "--")
--- @field pre?  string  Extra word inserted before class flag (e.g. "start" for wezterm)

--- @class HyprVimApplications
--- @field terminal?     "kitty"|"ghostty"|"alacritty"|"wezterm"|"foot"|"footclient"|"xterm"|string  Terminal used for prompts, the help viewer, and open-editor feature; built-in flag mappings exist for the listed values, add an entry to `term_flags` for others
--- @field term_flags?   table<string,HyprVimTermFlags>  Per-terminal flag overrides; e.g. `{ wezterm = { class = "--class", exec = "--", pre = "start" } }`. nil tries to autoresolve flags from the built-in terminal list.
--- @field lock?         string  Screen lock command executed by `:lock` and the L key in NORMAL mode (e.g. "hyprlock")
--- @field editor?       "vim"|"nvim"  Editor launched by the open-editor feature, `:edit` and the `:help` viewer; the help viewer relies on its `-RM` and `+/pattern` flags

--- @class HyprVimNotifications
--- @field all?      boolean  true: enable all notifications, overriding the individual flags below
--- @field marks?    boolean  true: show a desktop notification when a mark is set or jumped to
--- @field warnings? boolean  true: show a notification for recoverable issues (e.g. count clamped)
--- @field errors?   boolean  true: show a notification for hard failures (e.g. mark not set)

--- @class HyprVimAutoShow
--- @field disabled string[]|nil  Submaps that never auto-show the HUD; nil means nothing is suppressed
--- @field enabled  string[]|nil  Only show HUD for these submaps; nil (default) means all except `disabled`

--- @class HyprVimWhichKey
--- @field enabled?      boolean  true: show the which-key HUD on submap entry (requires eww or Quickshell, see `frontend`)
--- @field frontend?     "eww"|"quickshell"  Renderer for the HUD; "quickshell" sends it to a running Quickshell config over IPC (default "eww")
--- @field quickshell_ipc? string  Shell command prefix for Quickshell IPC, run unquoted through sh (default "qs ipc"); e.g. "qs -c myshell ipc"; also used by `prompt.frontend = "quickshell"`
--- @field delay_ms?     integer  Milliseconds to wait before showing the panel (0 = instant)
--- @field vim_delay_ms? integer  Delay for vim operator-pending submaps (DELETE/CHANGE/YANK and their sub-modes); overrides delay_ms for those submaps (default 300)
--- @field position? "bottom-right"|"bottom-left"|"bottom-center"|"top-right"|"top-left"|"top-center"  Panel anchor position
--- @field auto_show? HyprVimAutoShow

--- @class HyprVimPrompt
--- @field frontend?          "terminal"|"quickshell"  Who draws the prompt bar; "quickshell" hands it to a running Quickshell config over IPC (`which_key.quickshell_ipc`) and falls back to the terminal when none answers (default "terminal")
--- @field completion_menu?   boolean  true: Tab opens an fzf menu over the completions (requires fzf); false: Tab cycles matches (default true); terminal frontend only
--- @field completion_height? integer  Height in pixels the prompt bar grows to while the menu is open (default 400); terminal frontend only
--- @field history?          boolean  true: recall earlier entries with the arrow keys, kept per prompt under `$XDG_STATE_HOME/hyprvim/history` (default true)
--- @field history_size?     integer  Entries kept per prompt (default 200)

--- @class HyprVimUpdates
--- @field channel? "stable"|"nightly"|"off"|string  "stable" = latest GitHub release (default), "nightly" = git HEAD, "off" = disabled, any other string = pinned release tag or commit SHA

--- @class HyprVimUserCommandArg
--- @field hint?   string    Shown in the completion menu when the value is free-form
--- @field values? { [1]: string, [2]: string? }[]  Fixed candidates as { value, description } pairs
--- @field source? string    Shell command printing "value<TAB>description" lines, run when the menu opens

--- @class HyprVimUserCommand
--- @field [1]    fun(args?: string)  Handler; receives the argument string when `args` is set
--- @field desc?  string              Description shown in the completion menu and `:help`
--- @field args?  HyprVimUserCommandArg[]  One entry per argument position

--- @class HyprVimConfig
--- @field keys? HyprVimKeys
--- @field applications? HyprVimApplications
--- @field notifications? HyprVimNotifications
--- @field updates? HyprVimUpdates
--- @field enable_debug? boolean  true: write verbose diagnostic logs to the systemd journal (`journalctl -t hyprvim`)
--- @field max_count? integer     Maximum count digit accumulator; counts above this are silently clamped (default 1000)
--- @field which_key? HyprVimWhichKey
--- @field prompt? HyprVimPrompt
--- @field keymaps? table<string, { [1]: string|string[], [2]: any, [3]: HL.BindOptions|nil }[]>  Per-submap bind overrides; entries with a matching key replace the built-in bind, new keys are appended. Submap names: "NORMAL", "VISUAL", "V-LINE", "INSERT", etc.
--- @field commands? table<string, fun()|HyprVimUserCommand>  User-defined commands merged into the built-in command table; new names are added, existing names are overridden
--- @field defaults? HyprVimConfig  Internal: holds the default values before user overrides are merged

--- @class HyprVimInstance : HyprVimConfig
--- @field xdg string          Resolved `$XDG_RUNTIME_DIR`
--- @field state_dir string    Resolved runtime state directory (`$XDG_RUNTIME_DIR/hyprvim`)
--- @field config_dir string   Resolved user config directory (`$XDG_CONFIG_HOME/hyprvim`)
--- @field install_dir string  Resolved HyprVim installation directory (repo root)
--- @field which_key HyprVimWhichKey
--- @field prompt HyprVimPrompt
--- @field setup fun(overrides?: HyprVimConfig|table): HyprVimInstance
--- @field term_cmd fun(class: string): string  Returns the full terminal launch prefix for the given window class

--- @class HyprVimConfigModule : HyprVimConfig
--- @field defaults HyprVimConfig
--- @field setup fun(overrides?: HyprVimConfig|table): HyprVimInstance
--- @field term_cmd fun(class: string): string
local Config = {}

Config.xdg = XDG
Config.state_dir = XDG .. "/hyprvim"
Config.config_dir = XCC .. "/hyprvim"
Config.install_dir = (debug.getinfo(1, "S").source:match("^@(.+)/config%.lua$") or ".")

-- stylua: ignore
Config.defaults = {
  keys = {
    leader   = "SUPER",
    activate = "V",
    exit     = "ESCAPE",
  },
  applications = {
    terminal     = "kitty",
    term_flags   = nil,
    lock         = "hyprlock",
    editor       = "nvim",
  },
  notifications = {
    all      = false,
    marks    = false,
    warnings = true,
    errors   = true,
  },
  which_key = {
    enabled        = true,
    frontend       = "eww",
    quickshell_ipc = "qs ipc",
    delay_ms       = 0,
    vim_delay_ms   = 300,
    position       = "bottom-right",
    auto_show = {
      disabled = { "NORMAL", "VISUAL", "V-LINE", "INSERT" },
      enabled  = nil,
    },
  },
  prompt = {
    frontend          = "terminal",
    completion_menu   = true,
    completion_height = 400,
    history           = true,
    history_size      = 200,
  },
  updates = {
    channel = "stable",
  },
  enable_debug = false,
  max_count    = 1000,
}

--- Merges user overrides into defaults and writes the result onto this module table.
--- After calling setup(), any module that does require("hyprvim.config") gets the configured values.
--- @param overrides HyprVimConfig|table|nil
Config.setup = function(overrides)
  local merged = Utils.deep_extend({}, Config.defaults)
  if overrides then Utils.deep_extend(merged, overrides) end
  for k, v in pairs(merged) do
    Config[k] = v
  end
  return Config --[[@as HyprVimInstance]]
end

---Return the full terminal launch prefix for `class` (e.g. "kitty --class hyprvim-open-vim -e").
---Looks up the configured terminal in the built-in flag table, then merges any user overrides
---from `applications.term_flags`.  Unknown terminals fall back to `--class … -e`.
---@param class string  Wayland app-id / window class to assign
---@return string
function Config.term_cmd(class)
  local term = Config.applications.terminal
  local user = (Config.applications.term_flags or {})[term]
  local flags = Utils.deep_extend({}, TERM_FLAGS[term] or { class = "--class", exec = "-e" }, user or {})
  local parts = { term }
  if flags.pre then parts[#parts + 1] = flags.pre end
  parts[#parts + 1] = flags.class .. " " .. class
  parts[#parts + 1] = flags.exec
  return table.concat(parts, " ")
end

return Config
