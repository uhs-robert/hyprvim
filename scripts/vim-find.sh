#!/bin/bash
# hypr/.config/hypr/hyprvim/scripts/vim-find.sh
################################################################################
# vim-find.sh - Interactive find with configurable input methods
################################################################################
#
# Usage:
#   vim-find.sh char-forward   - f: prompt for char search (stores in char_term)
#   vim-find.sh char-backward  - F: prompt for char search (stores in char_term)
#   vim-find.sh char-till-forward - t: like f but moves cursor left after
#   vim-find.sh char-till-backward - T: like F but moves cursor left after
#   vim-find.sh search-forward - /: prompt for document search (stores in find_term)
#   vim-find.sh search-backward - ?: prompt for document search (stores in find_term)
#   vim-find.sh forward-word   - *: search forward for word under cursor (stores in find_term)
#   vim-find.sh backward-word  - #: search backward for word under cursor (stores in find_term)
#   vim-find.sh next-search           - n: F3 if active, else re-insert find_term
#   vim-find.sh prev-search           - N: Shift+F3 if active, else re-insert find_term
#   vim-find.sh next-char    - ;: F3 if active, else re-insert char_term
#   vim-find.sh prev-char - ,: Shift+F3 if active, else re-insert char_term
#   vim-find.sh deactivate     - Mark search as inactive (called on Escape)
#
# Configuration:
#   - Set HYPRVIM_PROMPT environment variable to override tool detection
#   - Auto-detects: wofi, rofi, tofi, fuzzel, dmenu, kdialog, zenity (in order)
#
################################################################################

set -euo pipefail

DEBUG="${HYPRVIM_DEBUG:-${HYPRVIM_FIND_DEBUG:-0}}"
STATE_DIR="${XDG_RUNTIME_DIR:-/tmp}/hyprvim"
STATE_FILE="$STATE_DIR/find-state.json"

mkdir -p "$STATE_DIR"

################################################################################
# State management helpers
################################################################################
# JSON structure:
# {
#   "active": true,
#   "direction": "forward",
#   "char_term": "a",
#   "find_term": "example",
#   "till": false
# }

# Log debug message if HYPRVIM_DEBUG=1
log_debug() {
  if [ "$DEBUG" = "1" ]; then
    logger -t hyprvim "$*"
  fi
}

# Check for required commands and exit with notification if missing
require_cmd() {
  local cmd
  for cmd in "$@"; do
    if ! command -v "$cmd" &>/dev/null; then
      notify-send "HyprVim Find" "Missing dependency: $cmd" 2>/dev/null || true
      hyprctl dispatch submap NORMAL
      exit 1
    fi
  done
}

# Remove newlines and trailing whitespace from search term
sanitize_term() {
  local term="$1"
  echo "$term" | tr -d '\n' | sed 's/[[:space:]]*$//'
}

# Extract the first word from a term (collapses whitespace/newlines)
first_word() {
  local term="$1"
  term=$(echo "$term" | tr '\n' ' ' | sed 's/[[:space:]]\+/ /g; s/^ //; s/ $//')
  echo "${term%% *}"
}

# Send keyboard shortcut to active window
send_shortcut() {
  hyprctl dispatch sendshortcut "$@" >/dev/null
}

# Send keyboard shortcut and sleep for specified duration
send_shortcut_sleep() {
  local sleep_time="$1"
  shift
  send_shortcut "$@"
  sleep "$sleep_time"
}

# Validate state key is allowed in JSON state
validate_state_key() {
  case "$1" in
  active | direction | char_term | find_term | till | post_move_left | post_move_left_len | last_action_direction | last_action_term_type)
    return 0
    ;;
  *)
    log_debug "state: invalid key '$1'"
    return 1
    ;;
  esac
}

# Get state value by key from JSON state file
get_state() {
  local key="$1"
  local default="${2:-}"

  if ! validate_state_key "$key"; then
    echo "$default"
    return 0
  fi

  if [ -f "$STATE_FILE" ]; then
    jq -r ".$key // \"$default\"" "$STATE_FILE" 2>/dev/null || echo "$default"
  else
    echo "$default"
  fi
}

# Set state value by key in JSON state file
set_state() {
  local key="$1"
  local value="$2"

  validate_state_key "$key" || return 1

  # Initialize state file if it doesn't exist
  if [ ! -f "$STATE_FILE" ]; then
    echo '{}' >"$STATE_FILE"
  fi

  # Update the key
  jq --arg val "$value" ".$key = \$val" "$STATE_FILE" >"$STATE_FILE.tmp" && mv "$STATE_FILE.tmp" "$STATE_FILE"
}

################################################################################
# Detect and use appropriate input tool
################################################################################

# Prompt user for search input using available tool (rofi, wofi, etc)
get_search_input() {
  local prompt="${1:-Find: }"
  local tool=""

  # Prefer environment variable override
  if [ -n "${HYPRVIM_PROMPT:-}" ] && command -v "$HYPRVIM_PROMPT" &>/dev/null; then
    tool="$HYPRVIM_PROMPT"
  else
    # Fallback to auto-detect available tools
    for candidate in rofi wofi tofi fuzzel dmenu kdialog zenity; do
      if command -v "$candidate" &>/dev/null; then
        tool="$candidate"
        break
      fi
    done
  fi

  # Execute the selected tool
  local input=""
  case "$tool" in
  rofi)
    input=$(
      echo "" | rofi -dmenu -p "$prompt" -lines 0 \
        -theme-str 'window { location: north; anchor: north; y-offset: 10%; x-offset: 0%; width: 600px; height: 40px; border: 1px; }' \
        -theme-str 'mainbox { children: [inputbar]; padding: 0px; spacing: 0px; border: 0px; }' \
        -theme-str 'inputbar { padding: 8px 12px; children: [prompt,entry]; border: 0px; orientation: horizontal; }' \
        -theme-str 'prompt { padding: 0px 0px 0px 0px; vertical-align: 0.5; }' \
        -theme-str 'entry { vertical-align: 0.5; }'
    )
    ;;
  wofi)
    input=$(echo "" | wofi --dmenu --prompt "$prompt" --lines 0 --gtk-application-id hyprvim-find)
    ;;
  tofi)
    input=$(echo "" | tofi --prompt-text "$prompt")
    ;;
  fuzzel)
    input=$(echo "" | fuzzel --dmenu --prompt "$prompt" --app-id hyprvim-find)
    ;;
  dmenu)
    input=$(echo "" | dmenu -p "$prompt" -class hyprvim-find)
    ;;
  kdialog)
    input=$(kdialog --inputbox "Search for:" --class hyprvim-find 2>/dev/null)
    ;;
  zenity)
    input=$(zenity --entry --title="Find" --text="Search for:" --class=hyprvim-find 2>/dev/null)
    ;;
  *)
    notify-send "HyprVim Find" "No input tool found. Install wofi, rofi, tofi, fuzzel, dmenu, zenity, or kdialog." 2>/dev/null || true
    return 1
    ;;
  esac

  echo "$input"
}

################################################################################
# Execute find with the given search term and direction
################################################################################

# Execute find operation: store state, paste search term, and trigger find dialog
execute_find() {
  local search_term="$1"
  local direction="$2"
  local term_type="${3:-find_term}" # "char_term" or "find_term"

  require_cmd wl-copy

  # Store state
  set_state "direction" "$direction"
  set_state "$term_type" "$search_term"
  set_state "active" "true"
  set_state "post_move_left" "false"
  set_state "post_move_left_len" "0"
  set_state "last_action_direction" "$direction"
  set_state "last_action_term_type" "$term_type"

  # Copy search term to clipboard
  echo -n "$search_term" | wl-copy

  # Open find dialog
  send_shortcut_sleep 0.15 CTRL, F, activewindow

  # Paste search term
  send_shortcut_sleep 0.05 CTRL, V, activewindow

  # Dismiss autocomplete by adding then removing a space
  send_shortcut_sleep 0.05 , SPACE, activewindow
  send_shortcut_sleep 0.05 , BACKSPACE, activewindow

  # Execute search
  send_shortcut_sleep 0.05 , Return, activewindow

  # Return to NORMAL mode
  hyprctl dispatch submap NORMAL

  if [ "$direction" = "forward" ] && [ "$term_type" = "find_term" ] && [ "${#search_term}" -gt 1 ]; then
    set_state "post_move_left" "true"
    set_state "post_move_left_len" "${#search_term}"
  fi
}

################################################################################
# Helper functions
################################################################################

# Prompt user for search term and execute find operation
prompt_and_execute() {
  local action_type="$1" # "char" or "find"
  local direction="$2"   # "forward" or "backward"

  # Exit NORMAL mode so user can type in the input dialog
  hyprctl dispatch submap reset

  # Set prompt text based on search type
  local prompt_text
  if [ "$action_type" = "char" ]; then
    prompt_text="Find: "
  else
    prompt_text="Search: "
  fi

  # Get search term from user
  local term_type="${action_type}_term"
  local search_term
  search_term=$(get_search_input "$prompt_text")
  search_term=$(sanitize_term "$search_term")

  # Return to NORMAL mode
  hyprctl dispatch submap NORMAL

  # If empty or cancelled, abort
  if [ -z "$search_term" ]; then
    exit 0
  fi

  # Execute find
  execute_find "$search_term" "$direction" "$term_type"
}

# Repeat previous find using F3 if active, or re-execute with stored term
repeat_find() {
  local term_type="$1"      # "char_term" or "find_term"
  local flip_direction="$2" # "true" or "false"

  local active direction search_term
  active=$(get_state "active" "false")
  direction=$(get_state "direction" "forward")

  log_debug "repeat_find: term_type=$term_type, flip=$flip_direction, active=$active, direction=$direction"

  if [ "$active" = "true" ]; then
    # Search is active, just use F3
    log_debug "repeat_find: search active, using F3"
    if [ "$term_type" = "find_term" ]; then
      local action_direction="$direction"
      if [ "$flip_direction" = "true" ]; then
        [ "$direction" = "forward" ] && action_direction="backward" || action_direction="forward"
      fi
      set_state "last_action_direction" "$action_direction"
      set_state "last_action_term_type" "$term_type"
      local find_term
      find_term=$(get_state "find_term" "")
      if [ "$action_direction" = "forward" ] && [ "${#find_term}" -gt 1 ]; then
        set_state "post_move_left" "true"
        set_state "post_move_left_len" "${#find_term}"
      else
        set_state "post_move_left" "false"
        set_state "post_move_left_len" "0"
      fi
    fi
    send_f3 "$direction" "$flip_direction"
  else
    # Search is not active, re-execute with stored term
    search_term=$(get_state "$term_type" "")
    log_debug "repeat_find: search inactive, stored term='$search_term'"

    if [ -z "$search_term" ]; then
      log_debug "repeat_find: no stored term, aborting"
      hyprctl dispatch submap NORMAL
      exit 0
    fi

    # Flip direction if needed
    local new_direction="$direction"
    if [ "$flip_direction" = "true" ]; then
      [ "$direction" = "forward" ] && new_direction="backward" || new_direction="forward"
    fi

    log_debug "repeat_find: calling execute_find with term='$search_term', direction='$new_direction'"
    execute_find "$search_term" "$new_direction" "$term_type"
  fi
}

# Send F3 or Shift+F3 based on direction and flip settings
send_f3() {
  local direction="$1"
  local flip_direction="$2"
  local use_shift="false"

  [ "$direction" = "forward" ] && use_shift="false" || use_shift="true"
  [ "$flip_direction" = "true" ] && { [ "$use_shift" = "true" ] && use_shift="false" || use_shift="true"; }

  if [ "$use_shift" = "true" ]; then
    send_shortcut SHIFT, F3, activewindow
  else
    send_shortcut , F3, activewindow
  fi
}

# Select and return word under cursor via clipboard
word_under_cursor() {
  require_cmd wl-copy wl-paste

  # Select word under cursor (inner word: CTRL+RIGHT, then CTRL+SHIFT+LEFT)
  send_shortcut_sleep 0.1 CTRL, RIGHT, activewindow
  send_shortcut_sleep 0.15 CTRL SHIFT, LEFT, activewindow

  # Copy selected word to clipboard
  send_shortcut_sleep 0.2 CTRL, C, activewindow

  # Read clipboard after copy
  local search_term
  search_term=$(wl-paste 2>/dev/null || echo "")
  search_term=$(sanitize_term "$search_term")
  search_term=$(first_word "$search_term")
  log_debug "word_under_cursor: clipboard contents='$search_term'"

  # Deselect (press RIGHT to move cursor to end and deselect)
  send_shortcut , RIGHT, activewindow

  echo "$search_term"
}

# Deactivate search, handle till cursor adjustment, and mark inactive
deactivate_search() {
  log_debug "deactivate: starting"

  # Only send ESC if search is active
  local active
  active=$(get_state "active" "false")
  log_debug "deactivate: active=$active"

  if [ "$active" = "true" ]; then
    send_shortcut , ESCAPE, activewindow
  fi

  # Check if it was a till search and send LEFT if so
  local till
  till=$(get_state "till" "false")
  log_debug "deactivate: till=$till"

  if [ "$till" = "true" ]; then
    log_debug "deactivate: sending LEFT for till"
    send_shortcut , LEFT, activewindow
    set_state "till" "false"
  fi

  # If configured, move cursor left by term length
  local post_move_left move_left_count last_action_direction last_action_term_type
  post_move_left=$(get_state "post_move_left" "false")
  move_left_count=$(get_state "post_move_left_len" "0")
  last_action_direction=$(get_state "last_action_direction" "forward")
  last_action_term_type=$(get_state "last_action_term_type" "find_term")
  if [ "$post_move_left" = "true" ] && [ "$move_left_count" -gt 0 ] && [ "$last_action_direction" = "forward" ] && [ "$last_action_term_type" = "find_term" ]; then
    for ((i = 0; i < move_left_count; i++)); do
      send_shortcut , LEFT, activewindow
    done
  fi

  # Mark search as inactive
  log_debug "deactivate: setting active to false"
  set_state "active" "false"
  log_debug "deactivate: state set, verifying..."
  local verify_active
  verify_active=$(get_state "active" "")
  log_debug "deactivate: verified active=$verify_active"
}

################################################################################
# Main logic
################################################################################

ACTION="$1"
log_debug "vim-find.sh called with ACTION='$ACTION'"

if [ "$ACTION" = "char-forward" ]; then
  set_state "till" "false"
  prompt_and_execute "char" "forward"

elif [ "$ACTION" = "char-backward" ]; then
  set_state "till" "false"
  prompt_and_execute "char" "backward"

elif [ "$ACTION" = "char-till-forward" ]; then
  set_state "till" "true"
  prompt_and_execute "char" "forward"

elif [ "$ACTION" = "char-till-backward" ]; then
  set_state "till" "true"
  prompt_and_execute "char" "backward"

elif [ "$ACTION" = "search-forward" ]; then
  set_state "till" "false"
  prompt_and_execute "find" "forward"

elif [ "$ACTION" = "search-backward" ]; then
  set_state "till" "false"
  prompt_and_execute "find" "backward"

elif [ "$ACTION" = "forward-word" ] || [ "$ACTION" = "backward-word" ]; then
  set_state "till" "false"
  SEARCH_TERM=$(word_under_cursor)
  SEARCH_TERM=$(first_word "$SEARCH_TERM")

  # If clipboard is empty, the selection/copy didn't work
  if [ -z "$SEARCH_TERM" ]; then
    log_debug "forward-word: clipboard empty after copy - selection may have failed"
  fi

  # If empty, abort
  if [ -z "$SEARCH_TERM" ]; then
    log_debug "forward-word: search term empty, aborting"
    hyprctl dispatch submap NORMAL
    exit 0
  fi

  # Determine direction (forward-word -> forward, backward-word -> backward)
  if [ "$ACTION" = "forward-word" ]; then
    DIRECTION="forward"
  else
    DIRECTION="backward"
  fi

  log_debug "forward-word: executing find with term='$SEARCH_TERM' direction='$DIRECTION'"
  # Execute find with the search term and direction (find_term for / ? * #)
  execute_find "$SEARCH_TERM" "$DIRECTION" "find_term"

elif [ "$ACTION" = "next-search" ]; then
  repeat_find "find_term" "false"

elif [ "$ACTION" = "prev-search" ]; then
  repeat_find "find_term" "true"

elif [ "$ACTION" = "next-char" ]; then
  repeat_find "char_term" "false"

elif [ "$ACTION" = "prev-char" ]; then
  repeat_find "char_term" "true"

elif [ "$ACTION" = "deactivate" ]; then
  deactivate_search
fi
