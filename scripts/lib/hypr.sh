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
export -f switch_mode
export -f return_to_normal
export -f exit_vim_mode
