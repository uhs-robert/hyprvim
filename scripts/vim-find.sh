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

# Source shared utilities
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
source "$SCRIPT_DIR/lib/core.sh"
source "$SCRIPT_DIR/lib/hypr.sh"
source "$SCRIPT_DIR/lib/ui.sh"
source "$SCRIPT_DIR/lib/clipboard.sh"
source "$SCRIPT_DIR/lib/text.sh"
source "$SCRIPT_DIR/lib/state.sh"

# Initialize script
init_script "find"

# State file for find operations
STATE_FILE="$HYPRVIM_STATE_DIR/find-state.json"

################################################################################
# State management helpers
################################################################################
# JSON structure:
# {
#   "active": true,
#   "direction": "forward",
#   "char_term": "a",
#   "find_term": "example",
#   "till": false,
#   "last_action_direction": "forward",
#   "last_action_term_type": "find_term"
# }

# Validate state key is allowed in JSON state (find-specific keys)
validate_find_state_key() {
  case "$1" in
  active | direction | char_term | find_term | till | last_action_direction | last_action_term_type)
    return 0
    ;;
  *)
    log_debug "state: invalid key '$1'"
    return 1
    ;;
  esac
}

# Get find state value by key
get_find_state() {
  local key="$1"
  local default="${2:-}"

  if ! validate_find_state_key "$key"; then
    echo "$default"
    return 0
  fi

  get_state "$STATE_FILE" "$key" "$default"
}

# Set find state value by key
set_find_state() {
  local key="$1"
  local value="$2"

  validate_find_state_key "$key" || return 1
  set_state "$STATE_FILE" "$key" "$value"
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
  set_find_state "direction" "$direction"
  set_find_state "$term_type" "$search_term"
  set_find_state "active" "true"
  set_find_state "last_action_direction" "$direction"
  set_find_state "last_action_term_type" "$term_type"

  # Copy search term to clipboard (use --type text/plain for single chars)
  if [[ ${#search_term} -eq 1 ]]; then
    clipboard_copy_typed "$search_term" "text/plain"
  else
    clipboard_copy "$search_term"
  fi

  # Open find dialog
  send_shortcut_sleep 0.15 "CTRL, F"

  # Paste search term
  send_shortcut_sleep 0.05 "CTRL, V"

  # Dismiss autocomplete by adding then removing a space
  send_shortcut_sleep 0.05 ", SPACE"
  send_shortcut_sleep 0.05 ", BACKSPACE"

  # Execute search
  send_shortcut_sleep 0.05 ", Return"

  # Return to NORMAL mode
  return_to_normal
}

################################################################################
# Helper functions
################################################################################

# Prompt user for search term and execute find operation
prompt_and_execute() {
  local action_type="$1" # "char" or "find"
  local direction="$2"   # "forward" or "backward"

  # Exit NORMAL mode so user can type in the input dialog
  exit_vim_mode

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
  search_term=$(get_user_input "$prompt_text" "hyprvim-find")
  search_term=$(sanitize_text "$search_term")

  # Return to NORMAL mode
  return_to_normal

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
  active=$(get_find_state "active" "false")
  direction=$(get_find_state "direction" "forward")

  log_debug "repeat_find: term_type=$term_type, flip=$flip_direction, active=$active, direction=$direction"

  if [ "$active" = "true" ]; then
    # Search is active, just use F3
    log_debug "repeat_find: search active, using F3"
    if [ "$term_type" = "find_term" ]; then
      local action_direction="$direction"
      if [ "$flip_direction" = "true" ]; then
        [ "$direction" = "forward" ] && action_direction="backward" || action_direction="forward"
      fi
      set_find_state "last_action_direction" "$action_direction"
      set_find_state "last_action_term_type" "$term_type"
    fi
    send_f3 "$direction" "$flip_direction"
  else
    # Search is not active, re-execute with stored term
    search_term=$(get_find_state "$term_type" "")
    log_debug "repeat_find: search inactive, stored term='$search_term'"

    if [ -z "$search_term" ]; then
      log_debug "repeat_find: no stored term, aborting"
      return_to_normal
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
    send_shortcut "SHIFT, F3"
  else
    send_shortcut ", F3"
  fi
}

# Select and return word under cursor via clipboard
word_under_cursor() {
  require_cmd wl-copy wl-paste

  # Select word under cursor (inner word: CTRL+RIGHT, then CTRL+SHIFT+LEFT)
  send_shortcut_sleep 0.1 "CTRL, RIGHT"
  send_shortcut_sleep 0.15 "CTRL SHIFT, LEFT"

  # Copy selected word to clipboard
  send_shortcut_sleep 0.2 "CTRL, C"

  # Read clipboard after copy
  local search_term
  search_term=$(clipboard_paste)
  search_term=$(sanitize_text "$search_term")
  search_term=$(first_word "$search_term")
  log_debug "word_under_cursor: clipboard contents='$search_term'"

  # Deselect (press RIGHT to move cursor to end and deselect)
  send_shortcut ", RIGHT"

  echo "$search_term"
}

# Deactivate search, handle till cursor adjustment, and mark inactive
deactivate_search() {
  log_debug "deactivate: starting"

  # Only send ESC if search is active
  local active
  active=$(get_find_state "active" "false")
  log_debug "deactivate: active=$active"

  if [ "$active" = "true" ]; then
    send_shortcut ", ESCAPE"
  fi

  # Check if it was a till search and send LEFT if so
  local till
  till=$(get_find_state "till" "false")
  log_debug "deactivate: till=$till"

  if [ "$till" = "true" ]; then
    log_debug "deactivate: sending LEFT for till"
    send_shortcut ", LEFT"
    set_find_state "till" "false"
  fi

  # Mark search as inactive
  log_debug "deactivate: setting active to false"
  set_find_state "active" "false"
  log_debug "deactivate: state set, verifying..."
  local verify_active
  verify_active=$(get_find_state "active" "")
  log_debug "deactivate: verified active=$verify_active"
}

################################################################################
# Main logic
################################################################################

ACTION="$1"
log_debug "vim-find.sh called with ACTION='$ACTION'"

if [ "$ACTION" = "char-forward" ]; then
  set_find_state "till" "false"
  prompt_and_execute "char" "forward"

elif [ "$ACTION" = "char-backward" ]; then
  set_find_state "till" "false"
  prompt_and_execute "char" "backward"

elif [ "$ACTION" = "char-till-forward" ]; then
  set_find_state "till" "true"
  prompt_and_execute "char" "forward"

elif [ "$ACTION" = "char-till-backward" ]; then
  set_find_state "till" "true"
  prompt_and_execute "char" "backward"

elif [ "$ACTION" = "search-forward" ]; then
  set_find_state "till" "false"
  prompt_and_execute "find" "forward"

elif [ "$ACTION" = "search-backward" ]; then
  set_find_state "till" "false"
  prompt_and_execute "find" "backward"

elif [ "$ACTION" = "forward-word" ] || [ "$ACTION" = "backward-word" ]; then
  set_find_state "till" "false"
  SEARCH_TERM=$(word_under_cursor)
  SEARCH_TERM=$(first_word "$SEARCH_TERM")

  # If clipboard is empty, the selection/copy didn't work
  if [ -z "$SEARCH_TERM" ]; then
    log_debug "forward-word: clipboard empty after copy - selection may have failed"
  fi

  # If empty, abort
  if [ -z "$SEARCH_TERM" ]; then
    log_debug "forward-word: search term empty, aborting"
    return_to_normal
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
