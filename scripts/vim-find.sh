#!/bin/bash
# hypr/.config/hypr/HyprVim/scripts/vim-find.sh
################################################################################
# vim-find.sh - Interactive find with configurable input methods
################################################################################
#
# Usage:
#   vim-find.sh forward        - f: prompt for search, open find, n=forward, N=backward
#   vim-find.sh backward       - F: prompt for search, open find, n=backward, N=forward
#   vim-find.sh forward-word   - *: search forward for word under cursor
#   vim-find.sh backward-word  - #: search backward for word under cursor
#   vim-find.sh next           - n: go in stored direction
#   vim-find.sh prev           - N: go opposite of stored direction
#
# Configuration:
#   - Set HYPRVIM_FINDER environment variable to override tool detection
#   - Auto-detects: wofi, rofi, tofi, fuzzel, dmenu, kdialog, zenity (in order)
#
################################################################################

set -euo pipefail

STATE_DIR="${XDG_RUNTIME_DIR:-/tmp}/hyprvim"
STATE_FILE="$STATE_DIR/find-direction"
SEARCH_FILE="$STATE_DIR/find-search-term"

mkdir -p "$STATE_DIR"

################################################################################
# Detect and use appropriate input tool
################################################################################

get_search_input() {
  local tool=""
  local prompt="Find: "

  # Prefer environment variable override
  if [ -n "${HYPRVIM_FINDER:-}" ] && command -v "$HYPRVIM_FINDER" &>/dev/null; then
    tool="$HYPRVIM_FINDER"
  else
    # Fallback to auto-detect available tools
    for candidate in wofi rofi tofi fuzzel dmenu kdialog zenity; do
      if command -v "$candidate" &>/dev/null; then
        tool="$candidate"
        break
      fi
    done
  fi

  # Execute the selected tool
  local input=""
  case "$tool" in
  wofi)
    input=$(echo "" | wofi --dmenu --prompt "$prompt" --lines 1)
    ;;
  rofi)
    input=$(echo "" | rofi -dmenu -p "$prompt" -lines 0)
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
    input=$(kdialog --inputbox "Search for:" 2>/dev/null)
    ;;
  zenity)
    input=$(zenity --entry --title="Find" --text="Search for:" 2>/dev/null)
    ;;
  *)
    # Fallback: notify user that no input tool is available
    notify-send "HyprVim Find" "No input tool found. Install wofi, rofi, tofi, fuzzel, dmenu, zenity, or kdialog." 2>/dev/null || true
    return 1
    ;;
  esac

  echo "$input"
}

################################################################################
# Execute find with the given search term and direction
################################################################################

execute_find() {
  local search_term="$1"
  local direction="$2"

  # Check for wl-copy
  if ! command -v wl-copy &>/dev/null; then
    notify-send "HyprVim Find" "wl-clipboard not found. Install wl-clipboard for find functionality." 2>/dev/null || true
    hyprctl dispatch submap NORMAL
    exit 1
  fi

  # Store direction and search term
  echo "$direction" >"$STATE_FILE"
  echo "$search_term" >"$SEARCH_FILE"

  # Copy search term to clipboard
  echo -n "$search_term" | wl-copy

  # Open find dialog
  hyprctl dispatch sendshortcut CTRL, F, activewindow
  sleep 0.15

  # Paste search term
  hyprctl dispatch sendshortcut CTRL, V, activewindow
  sleep 0.05

  # Execute search
  hyprctl dispatch sendshortcut , Return, activewindow
  sleep 0.05

  # Return to NORMAL mode
  hyprctl dispatch submap NORMAL
}

################################################################################
# Main logic
################################################################################

ACTION="$1"

if [ "$ACTION" = "forward" ] || [ "$ACTION" = "backward" ]; then
  # Exit NORMAL mode so user can type in the input dialog
  hyprctl dispatch submap reset

  # Get search term from user
  SEARCH_TERM=$(get_search_input)

  # Return to NORMAL mode
  hyprctl dispatch submap NORMAL

  # If empty or cancelled, abort
  if [ -z "$SEARCH_TERM" ]; then
    exit 0
  fi

  # Execute find with the search term and direction
  execute_find "$SEARCH_TERM" "$ACTION"

elif [ "$ACTION" = "forward-word" ] || [ "$ACTION" = "backward-word" ]; then
  # Check for wl-clipboard tools
  if ! command -v wl-paste &>/dev/null; then
    notify-send "HyprVim Find" "wl-clipboard not found. Install wl-clipboard for word search." 2>/dev/null || true
    hyprctl dispatch submap NORMAL
    exit 1
  fi

  # Select word under cursor (inner word: CTRL+LEFT, then CTRL+SHIFT+RIGHT)
  hyprctl dispatch sendshortcut CTRL, LEFT, activewindow
  sleep 0.05
  hyprctl dispatch sendshortcut CTRL SHIFT, RIGHT, activewindow
  sleep 0.05

  # Copy selected word to clipboard
  hyprctl dispatch sendshortcut CTRL, C, activewindow
  sleep 0.1

  # Get the word from clipboard
  SEARCH_TERM=$(wl-paste 2>/dev/null | tr -d '\n')

  # Deselect (press RIGHT to move cursor to end and deselect)
  hyprctl dispatch sendshortcut , RIGHT, activewindow

  # If empty, abort
  if [ -z "$SEARCH_TERM" ]; then
    hyprctl dispatch submap NORMAL
    exit 0
  fi

  # Determine direction (forward-word -> forward, backward-word -> backward)
  if [ "$ACTION" = "forward-word" ]; then
    DIRECTION="forward"
  else
    DIRECTION="backward"
  fi

  # Execute find with the search term and direction
  execute_find "$SEARCH_TERM" "$DIRECTION"

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
