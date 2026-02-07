#!/bin/bash
# scripts/vim-find.sh
# hypr/.config/hypr/HyprVim/scripts/vim-find.sh
################################################################################
# vim-find.sh - Set find direction and navigate search results
################################################################################
#
# Usage:
#   vim-find.sh forward   - f: open find, n=forward, N=backward
#   vim-find.sh backward  - F: open find, n=backward, N=forward
#   vim-find.sh next      - n: go in stored direction
#   vim-find.sh prev      - N: go opposite of stored direction
#
################################################################################

set -euo pipefail

STATE_DIR="${XDG_RUNTIME_DIR:-/tmp}/hyprvim"
STATE_FILE="$STATE_DIR/find-direction"

mkdir -p "$STATE_DIR"

ACTION="$1"

if [ "$ACTION" = "forward" ] || [ "$ACTION" = "backward" ]; then
  # Store direction
  echo "$ACTION" > "$STATE_FILE"

  # Open find dialog and exit to reset submap so user can type
  hyprctl dispatch submap reset
  hyprctl dispatch sendshortcut CTRL, F, activewindow
  return

elif [ "$ACTION" = "next" ]; then
  # Read stored direction (default to forward)
  DIRECTION=$(cat "$STATE_FILE" 2>/dev/null || echo "forward")

  if [ "$DIRECTION" = "forward" ]; then
    hyprctl dispatch sendshortcut , F3, activewindow
  else
    hyprctl dispatch sendshortcut SHIFT, F3, activewindow
  fi

elif [ "$ACTION" = "prev" ]; then
  # Read stored direction (default to forward)
  DIRECTION=$(cat "$STATE_FILE" 2>/dev/null || echo "forward")

  if [ "$DIRECTION" = "forward" ]; then
    hyprctl dispatch sendshortcut SHIFT, F3, activewindow
  else
    hyprctl dispatch sendshortcut , F3, activewindow
  fi
fi

# Return to NORMAL mode
hyprctl dispatch submap NORMAL
