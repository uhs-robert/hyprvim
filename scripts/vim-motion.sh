#!/bin/bash
# hypr/.config/hypr/HyprVim/scripts/vim-motion.sh
################################################################################
# vim-motion.sh - Execute motions with count support
################################################################################
#
# Usage:
#   vim-motion.sh <shortcut>              - Execute shortcut with count
#   vim-motion.sh --batch <commands>      - Execute batch commands with count
#
# Examples:
#   vim-motion.sh ", DOWN"                - Move down (with count)
#   vim-motion.sh "CTRL, RIGHT"           - Move word forward (with count)
#   vim-motion.sh --batch "dispatch sendshortcut , DOWN, activewindow"
#
################################################################################

set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
COUNT_SCRIPT="$SCRIPT_DIR/vim-count.sh"

# Get count (and clear it)
COUNT=$("$COUNT_SCRIPT" get)

# Parse arguments
if [ "$1" = "--batch" ]; then
  # Batch mode: execute hyprctl --batch commands
  shift
  BATCH_CMD="$*"

  for ((i = 0; i < COUNT; i++)); do
    hyprctl --batch "$BATCH_CMD"
  done
else
  # Simple shortcut mode
  SHORTCUT="$*"
  IFS=' ' read -r -a shortcut_args <<<"$SHORTCUT"

  for ((i = 0; i < COUNT; i++)); do
    hyprctl dispatch sendshortcut "${shortcut_args[@]}" , activewindow
  done
fi
