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
# Usage: send_shortcut "MODIFIER, KEY " [WINDOW]
send_shortcut() {
  local window="${2:-activewindow}"
  hyprctl --batch "dispatch sendshortcut $1, $window" >/dev/null 2>&1
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

# Close all other windows in workspace (keep current)
# Returns: Number of windows closed
close_other_windows() {
  local current_address
  current_address=$(hyprctl activewindow -j | jq -r '.address')
  local workspace_id
  workspace_id=$(hyprctl activeworkspace -j | jq -r '.id')
  local count=0

  while IFS= read -r address; do
    if [ "$address" != "$current_address" ] && [ -n "$address" ]; then
      hyprctl dispatch closewindow "address:$address"
      ((count++))
    fi
  done < <(hyprctl clients -j | jq -r ".[] | select(.workspace.id == $workspace_id) | .address")

  echo "$count"
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
# Window State Operations
################################################################################

# Toggle floating mode for active window
toggle_floating() {
  hyprctl dispatch togglefloating
}

# Toggle fullscreen for active window
toggle_fullscreen() {
  hyprctl dispatch fullscreen 1
}

# Toggle pin (show on all workspaces)
toggle_pin() {
  hyprctl dispatch pin
}

# Toggle pseudo-tiling mode
toggle_pseudo() {
  hyprctl dispatch pseudo
}

# Center active floating window
center_window() {
  hyprctl dispatch centerwindow
}

# Set window opacity (0.0-1.0)
# Usage: set_window_opacity 0.8
set_window_opacity() {
  local value="${1:-1.0}"
  hyprctl setprop active alpha "$value"
}

################################################################################
# Window Layout Operations
################################################################################

# Split window horizontally (preselect down)
split_window_horizontal() {
  hyprctl dispatch layoutmsg preselect d
}

# Split window vertically (preselect right)
split_window_vertical() {
  hyprctl dispatch layoutmsg preselect r
}

################################################################################
# Workspace Operations
################################################################################

# Switch to next workspace
next_workspace() {
  hyprctl dispatch workspace e+1
}

# Switch to previous workspace
prev_workspace() {
  hyprctl dispatch workspace e-1
}

# Switch to specific workspace number
# Usage: switch_to_workspace 3
switch_to_workspace() {
  local workspace="$1"
  hyprctl dispatch workspace "$workspace"
}

# Move active window to workspace
# Usage: move_window_to_workspace 5
move_window_to_workspace() {
  local workspace="$1"
  hyprctl dispatch movetoworkspace "$workspace"
}

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
# Application Launching
################################################################################

# Execute command via Hyprland
# Usage: exec_command "kitty"
exec_command() {
  local cmd="$1"
  hyprctl dispatch exec "$cmd"
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
export -f close_other_windows
export -f toggle_floating
export -f toggle_fullscreen
export -f toggle_pin
export -f toggle_pseudo
export -f center_window
export -f set_window_opacity
export -f split_window_horizontal
export -f split_window_vertical
export -f next_workspace
export -f prev_workspace
export -f switch_to_workspace
export -f move_window_to_workspace
export -f reload_hyprland_config
export -f lock_screen
export -f logout_hyprland
export -f exec_command
