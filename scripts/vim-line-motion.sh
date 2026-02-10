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

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
COUNT_SCRIPT="$SCRIPT_DIR/vim-count.sh"

# Get count (and clear it)
COUNT=$("$COUNT_SCRIPT" get)

DIRECTION="$1"

if [ "$DIRECTION" = "down" ]; then
  # First motion
  hyprctl --batch "dispatch sendshortcut , HOME, activewindow; dispatch sendshortcut SHIFT, END, activewindow; dispatch sendshortcut SHIFT, Down, activewindow"
  hyprctl dispatch submap V-LINE

  # Remaining motions
  for ((i = 1; i < COUNT; i++)); do
    hyprctl --batch "dispatch sendshortcut SHIFT, Down, activewindow; dispatch sendshortcut SHIFT, END, activewindow"
  done
elif [ "$DIRECTION" = "up" ]; then
  # First motion
  hyprctl --batch "dispatch sendshortcut , END, activewindow; dispatch sendshortcut SHIFT, HOME, activewindow; dispatch sendshortcut SHIFT, Up, activewindow"
  hyprctl dispatch submap V-LINE

  # Remaining motions
  for ((i = 1; i < COUNT; i++)); do
    hyprctl --batch "dispatch sendshortcut SHIFT, Up, activewindow; dispatch sendshortcut SHIFT, HOME, activewindow"
  done
elif [ "$DIRECTION" = "paragraph-up" ]; then
  # First motion
  hyprctl --batch "dispatch sendshortcut , END, activewindow; dispatch sendshortcut CTRL SHIFT, Up, activewindow"
  hyprctl dispatch submap V-LINE

  # Remaining motions
  for ((i = 1; i < COUNT; i++)); do
    hyprctl dispatch sendshortcut CTRL SHIFT, Up, activewindow
  done
elif [ "$DIRECTION" = "paragraph-down" ]; then
  # First motion
  hyprctl --batch "dispatch sendshortcut , HOME, activewindow; dispatch sendshortcut CTRL SHIFT, Down, activewindow"
  hyprctl dispatch submap V-LINE

  # Remaining motions
  for ((i = 1; i < COUNT; i++)); do
    hyprctl dispatch sendshortcut CTRL SHIFT, Down, activewindow
  done
else
  echo "Invalid direction: $DIRECTION" >&2
  exit 1
fi
