#!/bin/bash
# hypr/.config/hypr/HyprVim/scripts/vim-find.sh
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

get_state() {
  local key="$1"
  local default="${2:-}"

  if [ -f "$STATE_FILE" ]; then
    jq -r ".$key // \"$default\"" "$STATE_FILE" 2>/dev/null || echo "$default"
  else
    echo "$default"
  fi
}

set_state() {
  local key="$1"
  local value="$2"

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
        -theme-str 'window { location: north; anchor: north; y-offset: 10%; x-offset: 0%; width: 600px; height: 40px; border: 0px; }' \
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

execute_find() {
  local search_term="$1"
  local direction="$2"
  local term_type="${3:-find_term}" # "char_term" or "find_term"

  # Check for wl-copy
  if ! command -v wl-copy &>/dev/null; then
    notify-send "HyprVim Find" "wl-clipboard not found. Install wl-clipboard for find functionality." 2>/dev/null || true
    hyprctl dispatch submap NORMAL
    exit 1
  fi

  # Store state
  set_state "direction" "$direction"
  set_state "$term_type" "$search_term"
  set_state "active" "true"

  # Copy search term to clipboard
  echo -n "$search_term" | wl-copy

  # Open find dialog
  hyprctl dispatch sendshortcut CTRL, F, activewindow
  sleep 0.15

  # Paste search term
  hyprctl dispatch sendshortcut CTRL, V, activewindow
  sleep 0.05

  # Dismiss autocomplete by adding then removing a space
  hyprctl dispatch sendshortcut , SPACE, activewindow
  sleep 0.05
  hyprctl dispatch sendshortcut , BACKSPACE, activewindow
  sleep 0.05

  # Execute search
  hyprctl dispatch sendshortcut , Return, activewindow
  sleep 0.05

  # Return to NORMAL mode
  hyprctl dispatch submap NORMAL
}

################################################################################
# Helper functions
################################################################################

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

  # Return to NORMAL mode
  hyprctl dispatch submap NORMAL

  # If empty or cancelled, abort
  if [ -z "$search_term" ]; then
    exit 0
  fi

  # Execute find
  execute_find "$search_term" "$direction" "$term_type"
}

repeat_find() {
  local term_type="$1"      # "char_term" or "find_term"
  local flip_direction="$2" # "true" or "false"

  local active direction search_term
  active=$(get_state "active" "false")
  direction=$(get_state "direction" "forward")

  logger -t hyprvim "repeat_find: term_type=$term_type, flip=$flip_direction, active=$active, direction=$direction"

  if [ "$active" = "true" ]; then
    # Search is active, just use F3
    logger -t hyprvim "repeat_find: search active, using F3"
    local use_shift="false"
    [ "$direction" = "forward" ] && use_shift="false" || use_shift="true"
    [ "$flip_direction" = "true" ] && { [ "$use_shift" = "true" ] && use_shift="false" || use_shift="true"; }

    if [ "$use_shift" = "true" ]; then
      hyprctl dispatch sendshortcut SHIFT, F3, activewindow
    else
      hyprctl dispatch sendshortcut , F3, activewindow
    fi
  else
    # Search is not active, re-execute with stored term
    search_term=$(get_state "$term_type" "")
    logger -t hyprvim "repeat_find: search inactive, stored term='$search_term'"

    if [ -z "$search_term" ]; then
      logger -t hyprvim "repeat_find: no stored term, aborting"
      hyprctl dispatch submap NORMAL
      exit 0
    fi

    # Flip direction if needed
    local new_direction="$direction"
    if [ "$flip_direction" = "true" ]; then
      [ "$direction" = "forward" ] && new_direction="backward" || new_direction="forward"
    fi

    logger -t hyprvim "repeat_find: calling execute_find with term='$search_term', direction='$new_direction'"
    execute_find "$search_term" "$new_direction" "$term_type"
  fi
}

################################################################################
# Main logic
################################################################################

ACTION="$1"
logger -t hyprvim "vim-find.sh called with ACTION='$ACTION'"

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
  # Check for wl-clipboard tools
  if ! command -v wl-paste &>/dev/null; then
    notify-send "HyprVim Find" "wl-clipboard not found. Install wl-clipboard for word search." 2>/dev/null || true
    hyprctl dispatch submap NORMAL
    exit 1
  fi

  # Clear clipboard to detect if copy actually works
  echo -n "" | wl-copy

  # Select word under cursor (inner word: CTRL+LEFT, then CTRL+SHIFT+RIGHT)
  hyprctl dispatch sendshortcut CTRL, LEFT, activewindow
  sleep 0.1
  hyprctl dispatch sendshortcut CTRL SHIFT, RIGHT, activewindow
  sleep 0.15

  # Copy selected word to clipboard
  hyprctl dispatch sendshortcut CTRL, C, activewindow
  sleep 0.2

  # Get the word from clipboard
  SEARCH_TERM=$(wl-paste 2>/dev/null | tr -d '\n')
  logger -t hyprvim "forward-word: clipboard contents='$SEARCH_TERM'"

  # If clipboard is empty, the selection/copy didn't work
  if [ -z "$SEARCH_TERM" ]; then
    logger -t hyprvim "forward-word: clipboard empty after copy - selection may have failed"
  fi

  # Deselect (press RIGHT to move cursor to end and deselect)
  hyprctl dispatch sendshortcut , RIGHT, activewindow

  # If empty, abort
  if [ -z "$SEARCH_TERM" ]; then
    logger -t hyprvim "forward-word: search term empty, aborting"
    hyprctl dispatch submap NORMAL
    exit 0
  fi

  # Determine direction (forward-word -> forward, backward-word -> backward)
  if [ "$ACTION" = "forward-word" ]; then
    DIRECTION="forward"
  else
    DIRECTION="backward"
  fi

  logger -t hyprvim "forward-word: executing find with term='$SEARCH_TERM' direction='$DIRECTION'"
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
  logger -t hyprvim "deactivate: starting"

  # Check if it was a till search and send LEFT if so
  till=$(get_state "till" "false")
  logger -t hyprvim "deactivate: till=$till"

  if [ "$till" = "true" ]; then
    logger -t hyprvim "deactivate: sending LEFT for till"
    hyprctl dispatch sendshortcut , LEFT, activewindow
    set_state "till" "false"
  fi

  # Mark search as inactive
  logger -t hyprvim "deactivate: setting active to false"
  set_state "active" "false"
  logger -t hyprvim "deactivate: state set, verifying..."
  verify_active=$(get_state "active" "")
  logger -t hyprvim "deactivate: verified active=$verify_active"

fi
