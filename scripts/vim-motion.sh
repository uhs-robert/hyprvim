#!/bin/bash
# scripts/vim-motion.sh
# hypr/.config/hypr/hyprvim/scripts/vim-motion.sh
################################################################################
# vim-motion.sh - Execute motions with count support
################################################################################
#
# Usage:
#   vim-motion.sh <shortcut>              - Execute shortcut with count
#   vim-motion.sh --batch <commands>      - Execute batch commands with count
#   vim-motion.sh ... --after <commands>  - Run batch commands after each iteration
#
# Examples:
#   vim-motion.sh ", DOWN"                - Move down (with count)
#   vim-motion.sh "CTRL, RIGHT"           - Move word forward (with count)
#   vim-motion.sh --batch "dispatch sendshortcut , DOWN, activewindow"
#   vim-motion.sh --batch "dispatch sendshortcut CTRL, X, activewindow" --after "dispatch sendshortcut , DOWN, activewindow"
#
################################################################################

set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
COUNT_SCRIPT="$SCRIPT_DIR/vim-count.sh"

# Get count (and clear it)
COUNT=$("$COUNT_SCRIPT" get)

# Parse arguments
AFTER_CMD=""

if [ "$1" = "--batch" ]; then
  # Batch mode: execute hyprctl --batch commands
  shift

  BATCH_CMD=""
  while [ "$#" -gt 0 ]; do
    case "$1" in
    --after)
      shift
      AFTER_CMD="$1"
      shift || true
      ;;
    *)
      BATCH_CMD="$1"
      shift
      ;;
    esac
  done

  for ((i = 0; i < COUNT; i++)); do
    hyprctl --batch "$BATCH_CMD"
    if [ -n "$AFTER_CMD" ] && [ "$COUNT" -gt 1 ]; then
      hyprctl --batch "$AFTER_CMD"
    fi
  done
else
  # Simple shortcut mode
  SHORTCUT=""
  while [ "$#" -gt 0 ]; do
    case "$1" in
    --after)
      shift
      AFTER_CMD="$1"
      shift || true
      ;;
    *)
      if [ -z "$SHORTCUT" ]; then
        SHORTCUT="$1"
      else
        SHORTCUT="$SHORTCUT $1"
      fi
      shift
      ;;
    esac
  done

  IFS=' ' read -r -a shortcut_args <<<"$SHORTCUT"

  for ((i = 0; i < COUNT; i++)); do
    hyprctl dispatch sendshortcut "${shortcut_args[@]}" , activewindow
    if [ -n "$AFTER_CMD" ] && [ "$COUNT" -gt 1 ]; then
      hyprctl --batch "$AFTER_CMD"
    fi
  done
fi
