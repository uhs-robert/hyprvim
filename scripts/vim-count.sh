#!/bin/bash
# hypr/.config/hypr/hyprvim/scripts/vim-count.sh
################################################################################
# vim-count.sh - Count/repeat management for vim motions
################################################################################
#
# Usage:
#   vim-count.sh append <digit>     - Append digit to pending count
#   vim-count.sh get                - Get count and clear (returns 1 if empty)
#   vim-count.sh clear              - Clear pending count
#   vim-count.sh peek               - Get count without clearing
#   vim-count.sh handle_zero        - Special handling for '0' key in NORMAL mode
#   vim-count.sh handle_zero_visual - Special handling for '0' key in VISUAL mode
#
################################################################################

set -euo pipefail

COUNT_FILE="${XDG_RUNTIME_DIR:-/tmp}/hyprvim-count-$USER"
ACTION="${1:-}"
DIGIT="${2:-}"

################################################################################
# Actions
################################################################################

append_digit() {
  local digit="$1"

  # Validate digit
  if ! [[ "$digit" =~ ^[0-9]$ ]]; then
    echo "Invalid digit: $digit" >&2
    exit 1
  fi

  # Read current count
  local current=""
  if [ -f "$COUNT_FILE" ]; then
    current=$(cat "$COUNT_FILE")
  fi

  # Append new digit
  local new="${current}${digit}"

  # Cap at 3 digits (999 max)
  if [ ${#new} -le 3 ]; then
    echo "$new" >"$COUNT_FILE"
  fi
}

get_count() {
  local count="1"

  if [ -f "$COUNT_FILE" ]; then
    count=$(cat "$COUNT_FILE")
    rm -f "$COUNT_FILE"
  fi

  # Default to 1 if empty or invalid
  if [ -z "$count" ] || ! [[ "$count" =~ ^[0-9]+$ ]]; then
    count="1"
  fi

  echo "$count"
}

clear_count() {
  rm -f "$COUNT_FILE"
}

peek_count() {
  if [ -f "$COUNT_FILE" ]; then
    cat "$COUNT_FILE"
  else
    echo ""
  fi
}

handle_zero() {
  # In vim:
  # - '0' alone = go to start of line (motion)
  # - '10j' = 0 is part of count
  # So if count is empty, treat as motion. Otherwise append.

  local current=""
  if [ -f "$COUNT_FILE" ]; then
    current=$(cat "$COUNT_FILE")
  fi

  if [ -z "$current" ]; then
    # No pending count, treat as motion (HOME)
    hyprctl dispatch sendshortcut , HOME, activewindow
  else
    # Pending count exists, append 0
    append_digit "0"
  fi
}

handle_zero_visual() {
  # In visual mode:
  # - '0' alone = extend selection to start of line (SHIFT+HOME)
  # - '10j' = 0 is part of count
  # So if count is empty, treat as motion. Otherwise append.

  local current=""
  if [ -f "$COUNT_FILE" ]; then
    current=$(cat "$COUNT_FILE")
  fi

  if [ -z "$current" ]; then
    # No pending count, extend selection to line start (SHIFT+HOME)
    hyprctl dispatch sendshortcut SHIFT, HOME, activewindow
  else
    # Pending count exists, append 0
    append_digit "0"
  fi
}

################################################################################
# Main
################################################################################

case "$ACTION" in
append)
  append_digit "$DIGIT"
  ;;
get)
  get_count
  ;;
clear)
  clear_count
  ;;
peek)
  peek_count
  ;;
handle_zero)
  handle_zero
  ;;
handle_zero_visual)
  handle_zero_visual
  ;;
"")
  echo "Action required: append, get, clear, peek, handle_zero, handle_zero_visual" >&2
  exit 1
  ;;
*)
  echo "Unknown action: $ACTION" >&2
  exit 1
  ;;
esac
