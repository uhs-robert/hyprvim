#!/bin/bash
# scripts/vim-line-motion.sh
# hypr/.config/hypr/hyprvim/scripts/vim-line-motion.sh
################################################################################
# vim-line-motion.sh - Execute LINE mode motions with count support
################################################################################
#
# Usage:
#   vim-line-motion.sh down         - Move down from LINE mode (with count)
#   vim-line-motion.sh up           - Move up from LINE mode (with count)
#   vim-line-motion.sh paragraph-up - Move to previous paragraph (with count)
#   vim-line-motion.sh paragraph-down - Move to next paragraph (with count)
#
# LINE mode has special first-motion behavior:
#   - First J: HOME + SHIFT+Down, then switch to V-LINE
#   - First K: END + SHIFT+Up, then switch to V-LINE
#   - First {: END + CTRL SHIFT+Up, then switch to V-LINE
#   - First }: HOME + CTRL SHIFT+Down, then switch to V-LINE
#   - Remaining motions use V-LINE behavior (SHIFT+arrow or CTRL SHIFT+arrow)
#
################################################################################

set -euo pipefail

# Source shared utilities
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
source "$SCRIPT_DIR/lib/hypr.sh"

COUNT_SCRIPT="$SCRIPT_DIR/vim-count.sh"

################################################################################
# Helper Functions
################################################################################

# Move down from LINE mode
motion_down() {
  local count="$1"

  # First motion: establish line selection and switch to V-LINE
  send_shortcuts ", HOME" "SHIFT, END" "SHIFT, Down" "SHIFT, END"
  switch_mode V-LINE

  # Remaining motions
  for ((i = 1; i < count; i++)); do
    send_shortcuts "SHIFT, Down" "SHIFT, END"
  done
}

# Move up from LINE mode
motion_up() {
  local count="$1"

  # First motion: establish line selection and switch to V-LINE
  send_shortcuts ", END" "SHIFT, HOME" "SHIFT, Up" "SHIFT, HOME"
  switch_mode V-LINE

  # Remaining motions
  for ((i = 1; i < count; i++)); do
    send_shortcuts "SHIFT, Up" "SHIFT, HOME"
  done
}

# Move to previous paragraph
motion_paragraph_up() {
  local count="$1"

  # First motion: establish paragraph selection and switch to V-LINE
  send_shortcuts ", END" "CTRL SHIFT, Up"
  switch_mode V-LINE

  # Remaining motions
  for ((i = 1; i < count; i++)); do
    send_shortcuts "CTRL SHIFT, Up"
  done
}

# Move to next paragraph
motion_paragraph_down() {
  local count="$1"

  # First motion: establish paragraph selection and switch to V-LINE
  send_shortcuts ", HOME" "CTRL SHIFT, Down"
  switch_mode V-LINE

  # Remaining motions
  for ((i = 1; i < count; i++)); do
    send_shortcuts "CTRL SHIFT, Down"
  done
}

################################################################################
# Main Logic
################################################################################

# Get count (and clear it)
COUNT=$("$COUNT_SCRIPT" get)

DIRECTION="$1"

case "$DIRECTION" in
down)
  motion_down "$COUNT"
  ;;
up)
  motion_up "$COUNT"
  ;;
paragraph-up)
  motion_paragraph_up "$COUNT"
  ;;
paragraph-down)
  motion_paragraph_down "$COUNT"
  ;;
*)
  echo "Invalid direction: $DIRECTION" >&2
  exit 1
  ;;
esac
