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

# Send multiple shortcuts with sleep delay between each
# Usage: send_shortcuts_sleep 0.1 ", HOME" "SHIFT, END" "CTRL, DOWN"
# First argument is the sleep duration, followed by shortcuts to execute
send_shortcuts_sleep() {
  local sleep_time="$1"
  shift
  for shortcut in "$@"; do
    hyprctl dispatch sendshortcut "$shortcut," activewindow >/dev/null 2>&1
    sleep "$sleep_time"
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
# Window Management
################################################################################

# Close current window gracefully (allows app to prompt for save)
close_window() {
  hyprctl dispatch closewindow activewindow
}

# Force kill current window immediately
kill_window() {
  hyprctl dispatch killactive
}

# Close all windows in current workspace
# Returns: Number of windows closed
close_workspace_windows() {
  local workspace_id
  workspace_id=$(hyprctl activeworkspace -j | jq -r '.id')

  # Get all window addresses in current workspace
  local windows
  windows=$(hyprctl clients -j | jq -r ".[] | select(.workspace.id == $workspace_id) | .address")

  if [ -z "$windows" ]; then
    echo "0"
    return 0
  fi

  local count=0
  # Close each window (gives apps chance to save)
  while IFS= read -r addr; do
    hyprctl dispatch closewindow "address:$addr"
    count=$((count + 1))
  done <<<"$windows"

  echo "$count"
}

# Force close all windows in current workspace
# Usage: kill_workspace_windows
# Returns: Number of windows killed
kill_workspace_windows() {
  local workspace_id
  workspace_id=$(hyprctl activeworkspace -j | jq -r '.id')

  # Get all window addresses in current workspace
  local windows
  windows=$(hyprctl clients -j | jq -r ".[] | select(.workspace.id == $workspace_id) | .address")

  if [ -z "$windows" ]; then
    echo "0"
    return 0
  fi

  local count=0
  # Force close each window immediately
  while IFS= read -r addr; do
    hyprctl dispatch closewindow "address:$addr"
    count=$((count + 1))
  done <<<"$windows"

  echo "$count"
}

################################################################################
################################################################################
# System Control
################################################################################

# Reload Hyprland configuration
reload_hyprland_config() {
  hyprctl reload
}

# Lock screen
lock_screen() {
  hyprctl dispatch exec "${HYPRVIM_LOCK:-hyprlock}"
}

# Exit/logout from Hyprland
logout_hyprland() {
  hyprctl dispatch exit
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
export -f close_window
export -f kill_window
export -f close_workspace_windows
export -f kill_workspace_windows
