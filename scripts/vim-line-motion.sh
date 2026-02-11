#!/bin/bash
# hypr/.config/hypr/hyprvim/scripts/vim-line-motion.sh
################################################################################
# vim-line-motion.sh - Execute V-LINE mode motions with count support
################################################################################
#
# Usage:
#   vim-line-motion.sh enter-vline     - Enter V-LINE mode (sets first-motion flag)
#   vim-line-motion.sh reset           - Clear first-motion flag
#   vim-line-motion.sh down            - Move down in V-LINE mode (with count)
#   vim-line-motion.sh up              - Move up in V-LINE mode (with count)
#   vim-line-motion.sh paragraph-up    - Move to previous paragraph (with count)
#   vim-line-motion.sh paragraph-down  - Move to next paragraph (with count)
#   vim-line-motion.sh goto-start      - Go to document start (gg)
#   vim-line-motion.sh goto-end        - Go to document end (G)
#
# First-motion behavior:
#   When entering V-LINE from NORMAL (SHIFT+V), a first-motion flag is set.
#   The first motion establishes line selection with proper anchoring:
#   - First J: HOME + SHIFT+END + SHIFT+Down + SHIFT+END
#   - First K: END + SHIFT+HOME + SHIFT+Up + SHIFT+HOME
#   - First {: END + CTRL SHIFT+Up
#   - First }: HOME + CTRL SHIFT+Down
#
#   Subsequent motions use standard V-LINE behavior:
#   - J: SHIFT+Down + SHIFT+END
#   - K: SHIFT+Up + SHIFT+HOME
#   - {: END + CTRL SHIFT+Up
#   - }: HOME + CTRL SHIFT+Down
#
################################################################################

set -euo pipefail

# Source shared utilities
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
source "$SCRIPT_DIR/lib/hypr.sh"

COUNT_SCRIPT="$SCRIPT_DIR/vim-count.sh"
STATE_DIR="${XDG_RUNTIME_DIR:-/tmp}/hyprvim"
FIRST_MOTION_FLAG="$STATE_DIR/vline-first-motion"

################################################################################
# Helper Functions
################################################################################

# Reset V-LINE first-motion state flag
reset_state() {
  [[ -f "$FIRST_MOTION_FLAG" ]] && rm -f "$FIRST_MOTION_FLAG"
}

# Move down in V-LINE mode
motion_down() {
  local count="$1"

  if [[ -f "$FIRST_MOTION_FLAG" ]]; then
    # First motion: establish line selection
    send_shortcuts ", HOME" "SHIFT, END" "SHIFT, Down" "SHIFT, END"
    reset_state

    # Remaining motions
    for ((i = 1; i < count; i++)); do
      send_shortcuts "SHIFT, Down" "SHIFT, END"
    done
  else
    # Subsequent motions in V-LINE: standard behavior
    for ((i = 0; i < count; i++)); do
      send_shortcuts "SHIFT, Down" "SHIFT, END"
    done
  fi
}

# Move up in V-LINE mode
motion_up() {
  local count="$1"

  if [[ -f "$FIRST_MOTION_FLAG" ]]; then
    # First motion: establish line selection
    send_shortcuts ", END" "SHIFT, HOME" "SHIFT, Up" "SHIFT, HOME"
    reset_state

    # Remaining motions
    for ((i = 1; i < count; i++)); do
      send_shortcuts "SHIFT, Up" "SHIFT, HOME"
    done
  else
    # Subsequent motions in V-LINE: standard behavior
    for ((i = 0; i < count; i++)); do
      send_shortcuts "SHIFT, Up" "SHIFT, HOME"
    done
  fi
}

# Move to previous paragraph in V-LINE mode
motion_paragraph_up() {
  local count="$1"

  if [[ -f "$FIRST_MOTION_FLAG" ]]; then
    # First motion: establish paragraph selection
    send_shortcuts ", END" "CTRL SHIFT, Up"
    reset_state

    # Remaining motions
    for ((i = 1; i < count; i++)); do
      send_shortcut "CTRL SHIFT," UP
    done
  else
    # Subsequent motions in V-LINE: standard behavior
    for ((i = 0; i < count; i++)); do
      send_shortcuts ", END" "CTRL SHIFT, Up"
    done
  fi
}

# Move to next paragraph in V-LINE mode
motion_paragraph_down() {
  local count="$1"

  if [[ -f "$FIRST_MOTION_FLAG" ]]; then
    # First motion: establish paragraph selection
    send_shortcuts ", HOME" "CTRL SHIFT, Down"
    reset_state

    # Remaining motions
    for ((i = 1; i < count; i++)); do
      send_shortcut "CTRL SHIFT," DOWN
    done
  else
    # Subsequent motions in V-LINE: standard behavior
    for ((i = 0; i < count; i++)); do
      send_shortcuts ", HOME" "CTRL SHIFT, Down"
    done
  fi
}

# Go to document start (gg)
motion_goto_start() {
  if [[ -f "$FIRST_MOTION_FLAG" ]]; then
    send_shortcuts , END
    reset_state
  fi
  send_shortcut "CTRL SHIFT," HOME
}

# Go to document end (G)
motion_goto_end() {
  if [[ -f "$FIRST_MOTION_FLAG" ]]; then
    send_shortcut , HOME
    reset_state
  fi
  send_shortcut "CTRL SHIFT," END
}

################################################################################
# Main Logic
################################################################################

COMMAND="$1"

case "$COMMAND" in
enter-vline)
  # Enter V-LINE mode with first-motion flag set
  mkdir -p "$STATE_DIR"
  touch "$FIRST_MOTION_FLAG"
  send_shortcuts ", End" "SHIFT, Home"
  switch_mode V-LINE
  ;;
reset)
  # Clear first-motion flag (used when exiting V-LINE)
  reset_state
  ;;
goto-start)
  motion_goto_start
  ;;
goto-end)
  motion_goto_end
  ;;
down | up | paragraph-up | paragraph-down)
  # Get count (and clear it)
  COUNT=$("$COUNT_SCRIPT" get)

  case "$COMMAND" in
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
  esac
  ;;
*)
  echo "Invalid command: $COMMAND" >&2
  exit 1
  ;;
esac
