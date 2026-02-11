#!/bin/bash
# hypr/.config/hypr/hyprvim/scripts/lib/hypr.sh
################################################################################
# Hyprland integration functions for HyprVim scripts
################################################################################
#
# Provides: Keyboard shortcuts, mode switching, Hyprland dispatchers
#
################################################################################

set -euo pipefail

################################################################################
# Hyprland Integration
################################################################################

# Send keyboard shortcut to active window (or specified window)
# Usage: send_shortcut MODIFIER, KEY[, WINDOW]
send_shortcut() {
  # If only 2 args provided, default to activewindow
  if [ $# -eq 2 ]; then
    set -- "$1" "${2}," activewindow
  fi
  hyprctl dispatch sendshortcut "$@" >/dev/null 2>&1
}

# Send keyboard shortcut with sleep delay
# Usage: send_shortcut_sleep DURATION MODIFIER, KEY[, WINDOW]
send_shortcut_sleep() {
  local sleep_time="$1"
  shift
  send_shortcut "$@"
  sleep "$sleep_time"
}

# Send multiple shortcuts in a single batch command (fast, no delays)
# Usage: send_shortcuts ", HOME" "SHIFT, END" "CTRL, DOWN"
# All shortcuts sent in one batch command
send_shortcuts() {
  local batch=""
  for shortcut in "$@"; do
    batch+="dispatch sendshortcut $shortcut, activewindow; "
  done
  # Remove trailing semicolon and space
  batch="${batch%; }"
  hyprctl --batch "$batch" >/dev/null 2>&1
}

# Send multiple shortcuts with optional per-command sleep times
# Usage: send_shortcuts_sleep ", HOME:0.1" "SHIFT, END:0.2" "CTRL, DOWN"
# Each shortcut can have an optional :DURATION suffix for sleep after that command
send_shortcuts_sleep() {
  for arg in "$@"; do
    if [[ "$arg" =~ ^(.+):([0-9]+\.?[0-9]*)$ ]]; then
      # Shortcut with sleep time
      local shortcut="${BASH_REMATCH[1]}"
      local sleep_time="${BASH_REMATCH[2]}"
      hyprctl dispatch sendshortcut "$shortcut," activewindow >/dev/null 2>&1
      sleep "$sleep_time"
    else
      # Shortcut without sleep time
      hyprctl dispatch sendshortcut "$arg," activewindow >/dev/null 2>&1
    fi
  done
}

# Switch to a specific submap/mode
# Usage: switch_mode MODE_NAME
switch_mode() {
  local mode="$1"
  hyprctl dispatch submap "$mode" 2>/dev/null || true
}

# Return to NORMAL mode
return_to_normal() {
  hyprctl dispatch submap NORMAL 2>/dev/null || true
}

# Exit vim mode completely
exit_vim_mode() {
  hyprctl dispatch submap reset 2>/dev/null || true
}

################################################################################
# Export Functions
################################################################################

export -f send_shortcut
export -f send_shortcut_sleep
export -f send_shortcuts
export -f send_shortcuts_sleep
export -f switch_mode
export -f return_to_normal
export -f exit_vim_mode
