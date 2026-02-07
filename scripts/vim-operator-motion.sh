#!/bin/bash
# hypr/.config/hypr/HyprVim/scripts/vim-operator-motion.sh
################################################################################
# vim-operator-motion.sh - Execute operator motions with count-aware selection
################################################################################
#
# For operators with text objects (dw, cw, yw, dp, cp, yp, etc.):
# - With count > 1: repeat selection motion count times, then action once
# - With count = 1: execute normally (selection + action once)
#
# Usage:
#   vim-operator-motion.sh <selection-shortcut> <action-shortcut> [submap]
#
# Examples:
#   vim-operator-motion.sh "CTRL+SHIFT, RIGHT" "CTRL, X" "NORMAL"
#   vim-operator-motion.sh "CTRL+SHIFT, DOWN" "CTRL, C" "NORMAL"
#
################################################################################

set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
COUNT_SCRIPT="$SCRIPT_DIR/vim-count.sh"

# Get count and clear it
COUNT=$("$COUNT_SCRIPT" get)

SELECTION_SHORTCUT="$1"
ACTION_SHORTCUT="$2"
SUBMAP="${3:-NORMAL}"

# Parse shortcuts into arrays
IFS=' ' read -r -a selection_args <<<"$SELECTION_SHORTCUT"
IFS=' ' read -r -a action_args <<<"$ACTION_SHORTCUT"

if [ "$COUNT" -gt 1 ]; then
  # Repeat selection COUNT times
  for ((i = 0; i < COUNT; i++)); do
    hyprctl dispatch sendshortcut "${selection_args[@]}" , activewindow
  done

  # Then perform action once
  hyprctl dispatch sendshortcut "${action_args[@]}" , activewindow
else
  # Count = 1: select once, action once
  hyprctl dispatch sendshortcut "${selection_args[@]}" , activewindow
  hyprctl dispatch sendshortcut "${action_args[@]}" , activewindow
fi

# Return to specified submap
hyprctl dispatch submap "$SUBMAP"
