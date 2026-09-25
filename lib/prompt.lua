-- lib/prompt.lua
-- Non-blocking prompt helper. Spawns the configured terminal as a full-width
-- bottom bar, or hands the prompt to a running Quickshell config over IPC, so the
-- compositor thread is never blocked waiting for user input. The result is written
-- to a state file, then read back inside a global callback dispatched by hyprctl.

local Config = require("hyprvim.config") ---@class HyprVimConfigModule
local Hypr = require("hyprvim.hypr") ---@class HyprVimHyprland
local Callback = require("hyprvim.lib.callback") ---@class Callback

--- @class Prompt
local Prompt = {}

local Utils = require("hyprvim.lib.utils") ---@class HyprVimUtils
local sq = Utils.sh_escape

--- @class PromptCompletion
--- @field name string
--- @field desc string?
--- @field takes_args boolean?
--- @field min_args integer?  Leading arguments it cannot run without; Enter waits for them
--- @field usage string?  Short signature, e.g. "<N>" or "[WINDOW]"
--- @field aliases string[]?  Alternate names; searchable in the menu but not listed as rows

--- One argument position of a command. `values` are fixed candidates, `source` is a
--- shell command printing "value<TAB>description" lines, `hint` describes a free-form value.
--- A source may add a third field, which is inserted instead of the displayed first field,
--- and sees the arguments typed before its position in $HV_ARGS.
--- @class PromptArgSpec
--- @field hint string?
--- @field values { [1]: string, [2]: string? }[]?
--- @field source string?
--- @field optional boolean?  The command runs without this position; only later ones may follow

local MENU_HEIGHT = 400
local HISTORY_SIZE = 200

local IPC_TARGET = "hyprvim_prompt"
local SPEC_VERSION = 1

local TITLES = { ["hyprvim-command"] = "Command", ["hyprvim-find"] = "Find", ["hyprvim-replace"] = "Replace" }

---@return "terminal"|"quickshell"
function Prompt.frontend()
  return (Config.prompt and Config.prompt.frontend) == "quickshell" and "quickshell" or "terminal"
end

---Shell test that succeeds only when a Quickshell instance took the spec at `path`.
---@param path string
---@return string
local function ipc_open(path)
  local ipc = (Config.which_key and Config.which_key.quickshell_ipc) or "qs ipc"
  return '[ "$(timeout 2 ' .. ipc .. " call " .. IPC_TARGET .. " open " .. sq(path) .. ' 2>/dev/null)" = ok ]'
end

---A background loop that fires `dispatch` itself if Quickshell dies before answering,
---so a crash mid-prompt cannot leave hyprvim suspended. The callback removes `spec_path`,
---which ends the loop; a second dispatch after that is a no-op.
---@param spec_path string
---@param dispatch string
---@return string
local function watchdog(spec_path, dispatch)
  return "while [ -e "
    .. sq(spec_path)
    .. " ]; do sleep 1; pgrep -x qs >/dev/null || "
    .. "{ hyprctl dispatch "
    .. sq(dispatch)
    .. "; break; }; done &"
end

local swept = false

---Remove prompt files a previous Lua state left behind: a reload drops their callbacks, so nothing else will.
local function sweep_stale()
  if swept then return end
  swept = true
  os.execute("rm -f " .. sq(Config.state_dir .. "/tmp") .. "/prompt-* 2>/dev/null")
end

---Write a frontend spec as JSON; the callback is dispatched with "quickshell" so it knows who answered.
---@param fields table
---@param callback_name string
---@return string|nil path
local function write_spec(fields, callback_name)
  fields.version = SPEC_VERSION
  fields.callback = callback_name .. '("quickshell")'
  local theme = {}
  for _, var in ipairs(require("hyprvim.whichkey.theme").read_vars()) do
    theme[var.name] = var.value
  end
  fields.theme = next(theme) and theme or nil
  local path = Utils.tmp_path("prompt-spec") .. ".json"
  local f = io.open(path, "w")
  if not f then return nil end
  f:write(Utils.json_encode(fields))
  f:close()
  return path
end

---Where recalled prompt history lives. State, not runtime state: it should survive a reboot,
---unlike everything else HyprVim keeps in `state_dir`.
---@return string
local function history_dir()
  local base = os.getenv("XDG_STATE_HOME")
  if not base or base == "" then base = (os.getenv("HOME") or ".") .. "/.local/state" end
  return base .. "/hyprvim/history"
end

local history_dir_ready = false

---@param wm_class string
---@return string|nil path  nil when history is off
local function history_path(wm_class)
  if (Config.prompt or {}).history == false then return nil end
  local dir = history_dir()
  if not history_dir_ready then
    os.execute("mkdir -p -m 700 " .. sq(dir))
    history_dir_ready = true
  end
  return dir .. "/" .. wm_class
end

---Entries oldest first, in the file format readline writes; its `#<epoch>` stamp lines are skipped.
---@param path string|nil
---@return string[]
local function read_history(path)
  local entries = {}
  local f = path and io.open(path, "r")
  if not f then return entries end
  for line in f:lines() do
    if line ~= "" and not line:match("^#%d+$") then entries[#entries + 1] = line end
  end
  f:close()
  return entries
end

---Mirrors `_hv_known_entry` below, so both frontends record the same lines.
---@param entry string
---@param completions (string|PromptCompletion)[]|nil
---@return boolean
local function is_known_entry(entry, completions)
  if not completions or #completions == 0 then return true end
  if entry:match("^!") or entry:match("^%%?s/") or entry:match("^silent !") then return true end
  local first = entry:match("^(%S*)")
  if first:match("^%d+$") then return true end
  for _, e in ipairs(completions) do
    if type(e) ~= "table" then
      if e == first then return true end
    else
      if e.name == first then return true end
      for _, alt in ipairs(e.aliases or {}) do
        if alt == first then return true end
      end
    end
  end
  return false
end

---Append the way the terminal frontend does: skip a repeat of the last entry, keep the newest `history_size`.
---@param path string|nil
---@param entry string
local function append_history(path, entry)
  if not path then return end
  local entries = read_history(path)
  if entries[#entries] == entry then return end
  entries[#entries + 1] = entry
  local size = (Config.prompt or {}).history_size or HISTORY_SIZE
  local first = math.max(1, #entries - size + 1)
  local tmp = path .. ".tmp"
  local f = io.open(tmp, "w")
  if not f then return end
  f:write(table.concat(entries, "\n", first) .. "\n")
  f:close()
  os.rename(tmp, path)
  os.execute("chmod 600 " .. sq(path))
end

---Readline keeps its own history list, so the file only has to be read in and written back.
---@param wm_class string
---@return string block, string? path
local function history_block(wm_class)
  local cfg = Config.prompt or {}
  local path = history_path(wm_class)
  if not path then return "" end
  local size = tostring(cfg.history_size or HISTORY_SIZE)
  local block = table.concat({
    "_hv_hist=" .. sq(path),
    "_hv_hist_size=" .. size,
    [[history -r "$_hv_hist" 2>/dev/null]],
    "",
  }, "\n")
  return block, path
end

---Appends the entered line, keeping the file to the configured size. A prompt with a
---completion list only records entries it recognises, so typos are not recalled.
local HISTORY_SAVE = [[
_hv_known_entry() {
    local first w
    [ -n "$_hv_words" ] || return 0
    case "$1" in !*|s/*|%s/*|"silent !"*) return 0;; esac
    first="${1%% *}"
    case "$first" in "" | *[!0-9]*) ;; *) return 0 ;; esac
    for w in $_hv_words; do [ "$w" = "$first" ] && return 0; done
    return 1
}
if [ -n "$_hv_hist" ] && [ -n "$__hv_in" ] && _hv_known_entry "$__hv_in"; then
    history -s "$__hv_in" 2>/dev/null
    history -w "$_hv_hist" 2>/dev/null
    tail -n "$_hv_hist_size" "$_hv_hist" > "$_hv_hist.tmp" 2>/dev/null && mv "$_hv_hist.tmp" "$_hv_hist"
    # the trim recreates the file, so the mode is set after it, not once at creation
    chmod 600 "$_hv_hist" 2>/dev/null
fi
]]

---@return boolean menu_enabled, integer height
local function menu_opts(opts)
  local cfg = Config.prompt or {}
  local enabled = cfg.completion_menu
  if enabled == nil then enabled = true end
  return enabled ~= false, opts.menu_height or cfg.completion_height or MENU_HEIGHT
end

-- Tab cycles through prefix matches. Used when fzf is not installed.
local CYCLE_BLOCK = [[
_hv_cycle_base=''
_hv_cycle_idx=-1
_hv_cycle() {
    local matches found m
    if [ -n "$_hv_cycle_base" ]; then
        mapfile -t matches < <(compgen -W "$_hv_words" -- "$_hv_cycle_base")
        found=0
        for m in "${matches[@]}"; do [ "$m" = "$READLINE_LINE" ] && { found=1; break; }; done
        [ $found -eq 0 ] && { _hv_cycle_base="$READLINE_LINE"; _hv_cycle_idx=-1; }
    else
        _hv_cycle_base="$READLINE_LINE"
    fi
    mapfile -t matches < <(compgen -W "$_hv_words" -- "$_hv_cycle_base")
    [ "${#matches[@]}" -eq 0 ] && return
    if [ "${#matches[@]}" -eq 1 ]; then
        _hv_insert "${matches[0]}"
        _hv_cycle_base=''
        _hv_cycle_idx=-1
    else
        _hv_cycle_idx=$(( (_hv_cycle_idx + 1) % ${#matches[@]} ))
        READLINE_LINE="${matches[$_hv_cycle_idx]}"
        READLINE_POINT="${#READLINE_LINE}"
    fi
}
]]

-- Tab opens an fzf menu over the completion list, fzf-tab style. The prompt bar
-- is one line tall, so it is grown around the menu and restored afterwards.
local FZF_BLOCK = [==[
_hv_insert() {
    local name="$1" flag
    # aliases are not rows of their own, so match the hidden alias column too
    flag=$(awk -F'\t' -v n="$name" '
        { sub(/ +$/, "", $1)
          if ($1 == n) { print $3; exit }
          split($4, alts, " ")
          for (i in alts) if (alts[i] == n) { print $3; exit } }' "$_hv_entries")
    [ "$flag" = "1" ] && name="$name "
    READLINE_LINE="$name"
    READLINE_POINT="${#READLINE_LINE}"
}
_hv_place() {
    local sel="class:^$_hv_class\$"
    hyprctl --batch "dispatch hl.dsp.window.resize({ x = $1, y = $2, window = '$sel' }) ; dispatch hl.dsp.window.move({ x = $3, y = $4, window = '$sel' })" >/dev/null 2>&1
}
_hv_tty_rows() {
    local size
    size=$(stty size </dev/tty 2>/dev/null | cut -d' ' -f1)
    printf '%s' "${size:-0}"
}
_hv_grow() {
    _hv_w=''; _hv_h=''
    # by class, not by focus: the bar can lose focus while the prompt is open
    eval "$(hyprctl clients | awk -F': ' -v cls="$_hv_class" '
        /^Window /              { x = ""; y = ""; w = ""; h = "" }
        /^[[:space:]]*at:/      { split($2, a, ","); x = a[1]; y = a[2] }
        /^[[:space:]]*size:/    { split($2, s, ","); w = s[1]; h = s[2] }
        /^[[:space:]]*class:/   { if ($2 == cls && w != "") { printf "_hv_x=%s;_hv_y=%s;_hv_w=%s;_hv_h=%s;", x, y, w, h; exit } }')"
    [ -n "$_hv_w" ] && [ -n "$_hv_h" ] || return 1
    local before rows tries=0
    before=$(_hv_tty_rows)
    _hv_place "$_hv_w" "$_hv_menu_h" "$_hv_x" "$((_hv_y + _hv_h - _hv_menu_h))"
    # the pty learns its new size from SIGWINCH, which lands after the dispatch returns
    while [ "$tries" -lt 30 ]; do
        rows=$(_hv_tty_rows)
        [ "$rows" -gt "$before" ] && break
        sleep 0.02
        tries=$((tries + 1))
    done
    _hv_rows=$((rows - 1))
    [ "$_hv_rows" -gt 1 ] || _hv_rows=10
}
_hv_shrink() {
    [ -n "$_hv_w" ] && [ -n "$_hv_h" ] || return 0
    _hv_place "$_hv_w" "$_hv_h" "$_hv_x" "$_hv_y"
}
_hv_pad() {
    awk -F'\t' '{ if (length($1) > w) w = length($1); a[NR] = $0 }
        END { for (i = 1; i <= NR; i++) { split(a[i], f, "\t"); printf "%-*s\t%s\t%s\n", w, f[1], f[2], f[3] } }'
}
_hv_pick() {
    local query="$1" prompt="$2" nth="${3:-1}"
    # inline height leaves the command line drawn above the list
    fzf --query "$query" --ansi --no-sort --info=inline --height="${_hv_rows:-10}" --layout=reverse --cycle \
        --bind=tab:down,btab:up,ctrl-n:down,ctrl-p:up \
        --delimiter=$'\t' --with-nth=1,2 --nth="$nth" --prompt="$prompt"
}
_hv_usage_cols() {
    local cols
    cols=$(stty size </dev/tty 2>/dev/null | cut -d' ' -f2)
    # the dimmed usage goes between name and description only when the menu has room for both
    awk -F'\t' -v cols="${cols:-0}" '
        { a[NR] = $0; if (length($1) > nw) nw = length($1); if (length($6) > uw) uw = length($6) }
        END { show = uw > 0 && cols >= nw + uw + 60
              for (i = 1; i <= NR; i++) {
                  n = split(a[i], f, "\t")
                  if (show) f[2] = sprintf("\033[2m%-*s\033[0m  %s", uw, f[6], f[2])
                  line = f[1]
                  for (j = 2; j <= n; j++) line = line "\t" f[j]
                  print line } }'
}
_hv_arg_candidates() {
    local cmd="$1" pos="$2" c p k payload desc
    [ -n "$_hv_args" ] && [ -r "$_hv_args" ] || return
    while IFS=$'\x1f' read -r c p k payload desc; do
        [ "$c" = "$cmd" ] && [ "$p" = "$pos" ] || continue
        case "$k" in
            v) printf '%s\t%s\n' "$payload" "$desc" ;;
            h) printf '\t%s\n' "$desc" ;;
            s) HV_ARGS="$_hv_prev_args" bash -c "$payload" 2>/dev/null ;;
        esac
    done < "$_hv_args"
}
_hv_arg_menu() {
    local cmd="$1" pos="$2" cur="$3" cands sel val
    cands=$(_hv_arg_candidates "$cmd" "$pos" | _hv_pad)
    [ -n "$cands" ] || return
    _hv_grow || return
    sel=$(printf '%s\n' "$cands" | _hv_rank "$cur" | _hv_pick "$cur" "$_hv_label$cmd " 1,2)
    _hv_shrink
    [ -n "$sel" ] || return
    val=$(printf '%s' "$sel" | cut -f3)
    [ -n "$val" ] || val=$(printf '%s' "$sel" | cut -f1 | sed 's/ *$//')
    [ -n "$val" ] || return
    if [ -n "$cur" ]; then
        READLINE_LINE="${READLINE_LINE% *} $val "
    else
        READLINE_LINE="$READLINE_LINE$val "
    fi
    READLINE_POINT="${#READLINE_LINE}"
}
_hv_shell_menu() {
    local pre="${READLINE_LINE%%!*}!" cur="${READLINE_LINE#*!}" cands sel
    case "$cur" in *" "*) return;; esac
    cands=$(compgen -c -- "$cur" | sort -u | sed 's/$/\t/')
    [ -n "$cands" ] || return
    _hv_grow || return
    sel=$(printf '%s\n' "$cands" | _hv_pick "$cur" "$_hv_label$pre")
    _hv_shrink
    [ -n "$sel" ] || return
    READLINE_LINE="$pre$(printf '%s' "$sel" | cut -f1) "
    READLINE_POINT="${#READLINE_LINE}"
}
_hv_rank() {
    # name matches outrank alias matches, which outrank description-only matches
    awk -F'\t' -v q="$1" '
        { name = $1; sub(/ +$/, "", name)
          lq = tolower(q); ln = tolower(name); la = tolower($4)
          if (lq == "") rank = 1
          else if (index(ln, lq) == 1) rank = 0
          else if (index(ln, lq) > 0) rank = 1
          else if (index(la, lq) > 0) rank = 2
          else rank = 3
          printf "%d\t%s\n", rank, $0 }' | sort -s -k1,1n | cut -f2-
}
_hv_menu() {
    # in a chain, complete only the command after the last |, then put the rest back
    local head=''
    case "$READLINE_LINE" in "!"* | "silent !"* | s/* | %s/*) ;; *"|"*)
        head="${READLINE_LINE%|*}|"
        READLINE_LINE="${READLINE_LINE##*|}"
        head="$head${READLINE_LINE%%[! ]*}"
        READLINE_LINE="${READLINE_LINE#"${READLINE_LINE%%[! ]*}"}"
        ;;
    esac
    _hv_menu_segment
    READLINE_LINE="$head$READLINE_LINE"
    READLINE_POINT="${#READLINE_LINE}"
}
_hv_menu_segment() {
    local line="$READLINE_LINE" cur sel matches cmd rest pos
    if [[ "$line" == "!"* || "$line" == "silent !"* ]]; then
        _hv_shell_menu
        return
    fi
    if [[ "$line" == *" "* ]]; then
        cmd="${line%% *}"
        rest="${line#* }"
        read -r -a matches <<< "$rest"
        if [[ "$line" == *" " ]]; then
            pos=$(( ${#matches[@]} + 1 ))
            cur=''
        else
            pos=${#matches[@]}
            cur="${matches[$((pos - 1))]}"
        fi
        # the arguments before this one, so a source can depend on them
        _hv_prev_args="${matches[*]:0:$((pos - 1))}"
        _hv_arg_menu "$cmd" "$pos" "$cur"
        return
    fi
    cur="$line"
    mapfile -t matches < <(compgen -W "$_hv_words" -- "$cur")
    if [ "${#matches[@]}" -eq 1 ]; then _hv_insert "${matches[0]}"; return; fi
    _hv_grow || { _hv_cycle; return; }
    sel=$(_hv_usage_cols < "$_hv_entries" | _hv_rank "$cur" | _hv_pick "$cur" "$_hv_label" 1,2,4)
    _hv_shrink
    [ -n "$sel" ] || return
    _hv_insert "$(printf '%s' "$sel" | cut -f1 | sed 's/ *$//')"
}
]==]

-- Enter runs _hv_enter first, which rebinds the key after it to accept the line or
-- hold it when the command still needs arguments. Column 5 of the entries is min_args.
local ENTER_BLOCK = [==[
_hv_enter() {
    local seg="$READLINE_LINE" words need usage key rest
    bind '"\C-x\C-w": accept-line'
    case "$seg" in "!"* | "silent !"* | s/* | %s/*) return 0 ;; esac
    read -r -a words <<< "${seg##*|}"
    [ "${#words[@]}" -gt 0 ] || return 0
    IFS=$'\t' read -r need usage < <(awk -F'\t' -v n="${words[0]}" '
        { name = $1; sub(/ +$/, "", name); hit = name == n
          split($4, alts, " "); for (i in alts) if (alts[i] == n) hit = 1
          if (hit) { print $5 "\t" $6; exit } }' "$_hv_entries")
    [ "${need:-0}" -gt $(( ${#words[@]} - 1 )) ] 2>/dev/null || return 0
    bind '"\C-x\C-w": redraw-current-line'
    [[ "$READLINE_LINE" == *" " ]] || READLINE_LINE="$READLINE_LINE "
    READLINE_POINT=${#READLINE_LINE}
    printf '\r\033[K\033[33m%s needs: %s\033[0m' "${words[0]}" "${usage:-an argument}" > /dev/tty
    # shown until a key or two seconds pass; a typed character carries on, a lone Escape cancels
    IFS= read -rsn1 -t 2 key < /dev/tty || return 0
    case "$key" in
        $'\e')
            IFS= read -rsn8 -t 0.05 rest < /dev/tty
            [ -n "$rest" ] || { READLINE_LINE=''; bind '"\C-x\C-w": accept-line'; }
            ;;
        [[:print:]])
            READLINE_LINE="$READLINE_LINE$key"
            READLINE_POINT=${#READLINE_LINE}
            ;;
    esac
    return 0
}
bind -x '"\C-x\C-v": _hv_enter'
bind '"\C-x\C-w": accept-line'
bind '"\C-m": "\C-x\C-v\C-x\C-w"'
]==]

-- Escape clears the line and accepts it; an empty result is already treated as a
-- cancel. The short keyseq-timeout keeps arrow keys and Alt bindings working.
local ESC_BLOCK = [[
bind 'set keyseq-timeout 50' 2>/dev/null
bind '"\e": "\C-a\C-k\C-m"' 2>/dev/null
]]

---Write per-argument candidates as "cmd/pos/kind/payload/desc" lines, separated by \x1f
---because bash collapses runs of tabs when splitting on them.
---Kinds: v = literal value, h = hint for a free-form value, s = shell command printing candidates.
---@param specs table<string, PromptArgSpec[]>
---@return string|nil path
local function write_arg_file(specs)
  if not specs or not next(specs) then return nil end
  local lines = {}
  for cmd, positions in pairs(specs) do
    for pos, spec in ipairs(positions) do
      if spec.hint then lines[#lines + 1] = table.concat({ cmd, pos, "h", "", spec.hint }, "\31") end
      for _, v in ipairs(spec.values or {}) do
        lines[#lines + 1] = table.concat({ cmd, pos, "v", v[1], v[2] or "" }, "\31")
      end
      -- the file is line based, so a source has to stay on one line
      if spec.source then
        lines[#lines + 1] = table.concat({ cmd, pos, "s", (spec.source:gsub("%s*\n%s*", " ")), "" }, "\31")
      end
    end
  end
  if #lines == 0 then return nil end
  table.sort(lines)
  local path = Utils.tmp_path("prompt-args")
  local f = io.open(path, "w")
  if not f then return nil end
  f:write(table.concat(lines, "\n") .. "\n")
  f:close()
  return path
end

---Write the completion list to a file and build the readline/fzf setup block.
---@param opts {wm_class?: string, completions?: (string|PromptCompletion)[], arg_completions?: table<string, PromptArgSpec[]>, menu_height?: integer}
---@param label string
---@param wm_class string
---@return string block, string? entries_file, string? args_file
local function completion_block(opts, label, wm_class)
  local entries = opts.completions
  if not entries or #entries == 0 then return "" end
  local menu_enabled, menu_height = menu_opts(opts)

  local width = 0
  for _, e in ipairs(entries) do
    local name = type(e) == "table" and e.name or e
    if #name > width then width = #name end
  end

  local names, lines = {}, {}
  for _, e in ipairs(entries) do
    local name = type(e) == "table" and e.name or e
    local desc = type(e) == "table" and (e.desc or "") or ""
    local flag = (type(e) == "table" and e.takes_args) and "1" or "0"
    local alts = type(e) == "table" and table.concat(e.aliases or {}, " ") or ""
    local min_args = type(e) == "table" and e.min_args or 0
    local usage = type(e) == "table" and e.usage or ""
    names[#names + 1] = name
    for _, alt in ipairs(type(e) == "table" and e.aliases or {}) do
      names[#names + 1] = alt
    end
    lines[#lines + 1] = string.format("%-" .. width .. "s\t%s\t%s\t%s\t%d\t%s", name, desc, flag, alts, min_args, usage)
  end

  local args_file = write_arg_file(opts.arg_completions)
  local entries_file = Utils.tmp_path("prompt-entries")
  local f = io.open(entries_file, "w")
  if not f then return "" end
  f:write(table.concat(lines, "\n") .. "\n")
  f:close()

  local header = table.concat({
    "_hv_words=" .. sq(table.concat(names, " ")),
    "_hv_entries=" .. sq(entries_file),
    "_hv_class=" .. sq(wm_class),
    "_hv_label=" .. sq(label),
    "_hv_menu_h=" .. tostring(menu_height),
    "_hv_args=" .. sq(args_file or ""),
  }, "\n")

  local bind = (menu_enabled and "if command -v fzf >/dev/null 2>&1; then\n" or "if false; then\n")
    .. "    bind -x '\"\\t\": _hv_menu'\n"
    .. "else\n"
    .. "    bind -x '\"\\t\": _hv_cycle'\n"
    .. "fi\n"

  return header .. "\n" .. FZF_BLOCK .. CYCLE_BLOCK .. bind .. ENTER_BLOCK, entries_file, args_file
end

---Build the terminal command that displays a prompt and writes input to state_file.
---Returns nil if the prompt script cannot be written.
---@param label      string    prompt label shown to the user
---@param opts       {wm_class?: string, completions?: (string|PromptCompletion)[], arg_completions?: table<string, PromptArgSpec[]>, menu_height?: integer, prelude?: string}
---@param state_file string    path where the result should land
---@return string|nil cmd, string? cleanup  the script's temp files, quoted for `rm -f`
local function build_cmd(label, opts, state_file)
  local wm_class = opts.wm_class or "hyprvim-prompt"
  local script = Utils.tmp_path("prompt-script")
  local f = io.open(script, "w")
  if not f then return nil end

  local comp_block, entries_file, args_file = completion_block(opts, label, wm_class)
  local hist_block = history_block(wm_class)
  local cleanup = sq(script)
    .. (entries_file and (" " .. sq(entries_file)) or "")
    .. (args_file and (" " .. sq(args_file)) or "")

  f:write(
    "trap 'rm -f "
      .. cleanup
      .. "' EXIT\n"
      .. (opts.prelude and ("( " .. opts.prelude .. " ) >/dev/null 2>&1 &\n") or "")
      .. comp_block
      .. ESC_BLOCK
      .. hist_block
      -- clear kernel-echoed typeahead so readline redraws it after the prompt
      .. "printf '\\033[2J\\033[H'\n"
      .. "read -e -r -p "
      .. sq(label)
      .. " __hv_in\n"
      .. HISTORY_SAVE
      .. "printf '%s' \"$__hv_in\" > "
      .. sq(state_file)
      .. "\n"
  )
  f:close()
  return Config.term_cmd(wm_class) .. " bash " .. sq(script), cleanup
end

---Completions, argument specs and history as the Quickshell spec carries them.
---@param label string
---@param opts table
---@param state_file string
---@param hist_path string|nil
---@return table
local function input_spec(label, opts, state_file, hist_path)
  local wm_class = opts.wm_class or "hyprvim-prompt"
  local completions = {}
  for _, e in ipairs(opts.completions or {}) do
    if type(e) == "table" then
      completions[#completions + 1] = {
        name = e.name,
        desc = e.desc or "",
        takes_args = e.takes_args == true,
        min_args = e.min_args or 0,
        usage = e.usage or "",
        aliases = e.aliases or {},
      }
    else
      completions[#completions + 1] =
        { name = e, desc = "", takes_args = false, min_args = 0, usage = "", aliases = {} }
    end
  end
  local args = {}
  for cmd, positions in pairs(opts.arg_completions or {}) do
    local list = {}
    for _, spec in ipairs(positions) do
      list[#list + 1] = {
        hint = spec.hint or "",
        optional = spec.optional == true,
        values = spec.values or {},
        source = spec.source and (spec.source:gsub("%s*\n%s*", " ")) or "",
      }
    end
    args[cmd] = list
  end
  return {
    kind = "input",
    title = opts.title or TITLES[wm_class] or "Prompt",
    label = label,
    text = opts.text or "",
    completions = completions,
    args = next(args) and args or nil,
    chain = #completions > 0,
    shell_source = opts.shell_source or "",
    history = read_history(hist_path),
    result_path = state_file,
  }
end

---Show a prompt without blocking the compositor.
---`callback` is called once with the entered string, or nil if cancelled or
---the prompt could not be created.
---@param label    string
---@param opts     {wm_class?: string, title?: string, completions?: (string|PromptCompletion)[], arg_completions?: table<string, PromptArgSpec[]>, menu_height?: integer, prelude?: string, shell_source?: string}  prelude runs in the background as the bar opens; shell_source lists commands for `!` completion in Quickshell
---@param callback fun(result: string|nil)
function Prompt.async(label, opts, callback)
  sweep_stale()
  local state_file = Utils.tmp_path("prompt-input")
  local quickshell = Prompt.frontend() == "quickshell"
  local wm_class = opts.wm_class or "hyprvim-prompt"
  -- in Quickshell mode the prelude runs once, outside the fallback script
  local term_opts = opts
  if quickshell then
    term_opts = {}
    for k, v in pairs(opts) do
      term_opts[k] = v
    end
    term_opts.prelude = nil
  end

  local cmd, cleanup = build_cmd(label, term_opts, state_file)
  if not cmd then
    Hypr.notify("prompt: failed to write prompt script", "error", 3000)
    callback(nil)
    return
  end

  local spec_path
  local dispatch, name = Callback.register(function(via)
    local f = io.open(state_file, "r")
    local result = f and f:read("*a"):gsub("%s+$", "") or ""
    if f then
      f:close()
      os.remove(state_file)
    end
    if spec_path then os.remove(spec_path) end
    -- the terminal saves its own history; Quickshell only hands back the line
    if via == "quickshell" and result ~= "" and is_known_entry(result, opts.completions) then
      append_history(history_path(wm_class), result)
    end
    callback(result ~= "" and result or nil)
  end)

  if quickshell then spec_path = write_spec(input_spec(label, opts, state_file, history_path(wm_class)), name) end
  if not spec_path then
    Hypr.cmd_then_dispatch(cmd, dispatch)()
    return
  end

  -- stylua: ignore
  Hypr.exec(
    (opts.prelude and ("( " .. opts.prelude .. " ) >/dev/null 2>&1 & ") or "")
      .. "if " .. ipc_open(spec_path) .. "; then rm -f " .. cleanup .. "; " .. watchdog(spec_path, dispatch)
      .. " else " .. cmd .. "; hyprctl dispatch '" .. dispatch .. "'; fi"
  )
end

---Run `command` and show what it printed: in a terminal, or in the Quickshell bar with the
---terminal as the fallback. `on_done` runs once the output is dismissed, or at once when there is none.
---@param command string
---@param on_done fun()
function Prompt.shell(command, on_done)
  sweep_stale()
  if Prompt.frontend() ~= "quickshell" then
    Hypr.cmd_then_dispatch(
      Config.term_cmd("hyprvim-shell")
        .. " bash -c "
        .. sq(
          "_hv_tmp=$(mktemp); "
            .. command
            .. ' 2>&1 | tee "$_hv_tmp";'
            .. " [ -s \"$_hv_tmp\" ] && { echo; read -rsn1 -p '[done] press any key...'; };"
            .. ' rm -f "$_hv_tmp"'
        ),
      Callback.register(on_done)
    )()
    return
  end

  local out = Utils.tmp_path("prompt-output")
  local spec_path
  local dispatch, name = Callback.register(function()
    os.remove(out)
    if spec_path then os.remove(spec_path) end
    on_done()
  end)
  spec_path = write_spec({ kind = "output", title = "Shell", label = "!", text = command, output_path = out }, name)
  local show = Config.term_cmd("hyprvim-shell")
    .. " bash -c "
    .. sq("cat " .. sq(out) .. "; echo; read -rsn1 -p '[done] press any key...'")
  -- stylua: ignore
  local script = "bash -c " .. sq(command) .. " > " .. sq(out) .. " 2>&1 < /dev/null; _hv_s=$?; "
    .. "[ $_hv_s -eq 0 ] || printf '\\n[exit %d]\\n' \"$_hv_s\" >> " .. sq(out) .. "; "
    .. (spec_path
      and ("[ -s " .. sq(out) .. " ] && " .. ipc_open(spec_path) .. " && { " .. watchdog(spec_path, dispatch) .. " exit 0; }; ")
      or "")
    .. "[ -s " .. sq(out) .. " ] && " .. show .. "; "
    .. "hyprctl dispatch '" .. dispatch .. "'"
  Hypr.exec("bash -c " .. sq(script))
end

return Prompt
