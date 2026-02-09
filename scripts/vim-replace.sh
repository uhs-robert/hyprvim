#!/bin/bash
# hypr/.config/hypr/HyprVim/scripts/vim-replace.sh
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

STATE_DIR="${XDG_RUNTIME_DIR:-/tmp}/hyprvim"
mkdir -p "$STATE_DIR"

MODE="${1:-char}"

################################################################################
# Detect and use appropriate input tool
################################################################################

get_input() {
  local prompt="$1"
  local tool=""

  # Prefer environment variable override
  if [ -n "${HYPRVIM_PROMPT:-}" ] && command -v "$HYPRVIM_PROMPT" &>/dev/null; then
    tool="$HYPRVIM_PROMPT"
  else
    # Fallback to auto-detect available tools
    for candidate in rofi wofi tofi fuzzel dmenu kdialog zenity; do
      if command -v "$candidate" &>/dev/null; then
        tool="$candidate"
        break
      fi
    done
  fi

  # Execute the selected tool
  local input=""
  case "$tool" in
  rofi)
    input=$(echo "" | rofi -dmenu -p "$prompt" -lines 0)
    ;;
  wofi)
    input=$(echo "" | wofi --dmenu --prompt "$prompt" --lines 1)
    ;;

  tofi)
    input=$(echo "" | tofi --prompt-text "$prompt")
    ;;
  fuzzel)
    input=$(echo "" | fuzzel --dmenu --prompt "$prompt")
    ;;
  dmenu)
    input=$(echo "" | dmenu -p "$prompt")
    ;;
  kdialog)
    input=$(kdialog --inputbox "$prompt" 2>/dev/null)
    ;;
  zenity)
    input=$(zenity --entry --title="Replace" --text="$prompt" 2>/dev/null)
    ;;
  *)
    notify-send "HyprVim Replace" "No input tool found. Install wofi, rofi, tofi, fuzzel, dmenu, zenity, or kdialog." 2>/dev/null || true
    return 1
    ;;
  esac

  echo "$input"
}

################################################################################
# Main logic
################################################################################

# Exit NORMAL mode so user can type in the input dialog
hyprctl dispatch submap reset

# Get replacement based on mode
if [ "$MODE" = "char" ]; then
  # r command: get single character, use count
  REPLACEMENT=$(get_input "Replace with: ")

  # Return to NORMAL mode
  hyprctl dispatch submap NORMAL

  # If empty or cancelled, abort
  if [ -z "$REPLACEMENT" ]; then
    exit 0
  fi

  # Only use first character
  REPLACE_CHAR="${REPLACEMENT:0:1}"

  # Get count from vim-count.sh (defaults to 1)
  COUNT_SCRIPT="${HOME}/.config/hypr/HyprVim/scripts/vim-count.sh"
  COUNT=$("$COUNT_SCRIPT" get)

  # Build replacement string (character repeated COUNT times)
  REPLACEMENT=""
  for ((i = 0; i < COUNT; i++)); do
    REPLACEMENT+="$REPLACE_CHAR"
  done

elif [ "$MODE" = "string" ]; then
  # R command: get string, use string length as count
  REPLACEMENT=$(get_input "REPLACE: ")

  # Return to NORMAL mode
  hyprctl dispatch submap NORMAL

  # If empty or cancelled, abort
  if [ -z "$REPLACEMENT" ]; then
    exit 0
  fi

  # Count is the length of the string
  COUNT=${#REPLACEMENT}
else
  echo "Unknown mode: $MODE" >&2
  exit 1
fi

# Check for wl-copy
if ! command -v wl-copy &>/dev/null; then
  notify-send "HyprVim Replace" "wl-clipboard not found. Install wl-clipboard for replace functionality." 2>/dev/null || true
  exit 1
fi

# Copy replacement to clipboard
echo -n "$REPLACEMENT" | wl-copy

# Select COUNT characters forward
if [ "$COUNT" -gt 1 ]; then
  for ((i = 0; i < COUNT; i++)); do
    hyprctl dispatch sendshortcut SHIFT, RIGHT, activewindow
    sleep 0.01
  done
else
  # Single character: just select it
  hyprctl dispatch sendshortcut SHIFT, RIGHT, activewindow
fi

sleep 0.05

# Paste replacement
hyprctl dispatch sendshortcut CTRL, V, activewindow
sleep 0.05

# Return to NORMAL mode (cursor will be at end of replacement)
hyprctl dispatch submap NORMAL
