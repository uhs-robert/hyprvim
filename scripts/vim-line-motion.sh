#!/bin/bash
# scripts/vim-line-motion.sh
# hypr/.config/hypr/HyprVim/scripts/vim-line-motion.sh
################################################################################
# vim-line-motion.sh - Execute LINE mode motions with count support
################################################################################
#
# Usage:
#   vim-line-motion.sh down   - Move down from LINE mode (with count)
#   vim-line-motion.sh up     - Move up from LINE mode (with count)
#
# LINE mode has special first-motion behavior:
#   - First J: HOME + SHIFT+Down, then switch to V-LINE
#   - First K: END + SHIFT+Up, then switch to V-LINE
#   - Remaining motions use V-LINE behavior (SHIFT+Down/Up)
#
################################################################################

set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
COUNT_SCRIPT="$SCRIPT_DIR/vim-count.sh"

# Get count (and clear it)
COUNT=$("$COUNT_SCRIPT" get)

DIRECTION="$1"

if [ "$DIRECTION" = "down" ]; then
  # First motion: HOME + SHIFT+Down
  hyprctl --batch "dispatch sendshortcut , HOME, activewindow; dispatch sendshortcut SHIFT, Down, activewindow"

  # Switch to V-LINE
  hyprctl dispatch submap V-LINE

  # Remaining motions: just SHIFT+Down
  for ((i = 1; i < COUNT; i++)); do
    hyprctl dispatch sendshortcut SHIFT, Down, activewindow
  done
elif [ "$DIRECTION" = "up" ]; then
  # First motion: END + SHIFT+Up
  hyprctl --batch "dispatch sendshortcut , END, activewindow; dispatch sendshortcut SHIFT, Up, activewindow"

  # Switch to V-LINE
  hyprctl dispatch submap V-LINE

  # Remaining motions: just SHIFT+Up
  for ((i = 1; i < COUNT; i++)); do
    hyprctl dispatch sendshortcut SHIFT, Up, activewindow
  done
else
  echo "Invalid direction: $DIRECTION" >&2
  exit 1
fi
