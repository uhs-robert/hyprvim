#!/bin/bash
# hypr/.config/hypr/hyprvim/scripts/vim-replace.sh
################################################################################
# vim-replace.sh - Replace characters (r) or forward by string (R)
################################################################################
#
# Usage:
#   vim-replace.sh char    - r: Replace [count] chars with single character
#   vim-replace.sh string  - R: Replace N chars with string (N = string length)
#
################################################################################

set -euo pipefail

# Source shared utilities
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
source "$SCRIPT_DIR/lib/core.sh"
source "$SCRIPT_DIR/lib/hypr.sh"
source "$SCRIPT_DIR/lib/ui.sh"
source "$SCRIPT_DIR/lib/clipboard.sh"

# Initialize script
init_script "replace"

MODE="${1:-char}"

################################################################################
# Main logic
################################################################################

# Exit NORMAL mode so user can type in the input dialog
exit_vim_mode

# Get replacement based on mode
if [ "$MODE" = "char" ]; then
  # r command: get single character, use count
  REPLACEMENT=$(get_user_input "Replace with: " "hyprvim-replace")

  # Return to NORMAL mode
  return_to_normal

  # If empty or cancelled, abort
  if [ -z "$REPLACEMENT" ]; then
    exit 0
  fi

  # Only use first character
  REPLACE_CHAR="${REPLACEMENT:0:1}"

  # Get count from vim-count.sh (defaults to 1)
  COUNT_SCRIPT="${HOME}/.config/hypr/hyprvim/scripts/vim-count.sh"
  COUNT=$("$COUNT_SCRIPT" get)

  # Build replacement string (character repeated COUNT times)
  REPLACEMENT=""
  for ((i = 0; i < COUNT; i++)); do
    REPLACEMENT+="$REPLACE_CHAR"
  done

elif [ "$MODE" = "string" ]; then
  # R command: get string, use string length as count
  REPLACEMENT=$(get_user_input "REPLACE: " "hyprvim-replace")

  # Return to NORMAL mode
  return_to_normal

  # If empty or cancelled, abort
  if [ -z "$REPLACEMENT" ]; then
    exit 0
  fi

  # Count is the length of the string
  COUNT=${#REPLACEMENT}
else
  log_error "Unknown mode: $MODE"
  exit 1
fi

# Check for wl-copy
require_cmd wl-copy

# Copy replacement to clipboard
clipboard_copy "$REPLACEMENT"

# Select COUNT characters forward
if [ "$COUNT" -gt 1 ]; then
  for ((i = 0; i < COUNT; i++)); do
    send_shortcut SHIFT, RIGHT
    sleep 0.01
  done
else
  # Single character: just select it
  send_shortcut SHIFT, RIGHT
fi

sleep 0.05

# Paste replacement
send_shortcut CTRL, V
sleep 0.05

# Return to NORMAL mode (cursor will be at end of replacement)
return_to_normal
