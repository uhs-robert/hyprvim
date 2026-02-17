#!/bin/bash
# hypr/.config/hypr/hyprvim/scripts/vim-command.sh
################################################################################
# vim-command.sh - Command mode for HyprVim
################################################################################
#
# Usage:
#   vim-command.sh prompt         - Show command prompt and execute command
#   vim-command.sh after <name>   - Set submap to transition to after command
#   vim-command.sh exit           - Dispatch to saved submap state
#
# Supported Commands:
#
#   File Operations:
#     :w                     - Save file (Ctrl+S)
#     :wq                    - Save and quit
#     :q                     - Quit window
#     :q!                    - Force quit window (kill immediately)
#     :qa                    - Quit all windows in current workspace
#     :qa!                   - Force quit all windows in current workspace
#
#   Window Management:
#     :split, :sp            - Split window horizontally
#     :vsplit, :vsp, :vs     - Split window vertically
#     :only                  - Close all other windows (keep current)
#
#   Window States:
#     :float, :f             - Toggle floating mode
#     :fullscreen, :fs       - Toggle fullscreen
#     :pin                   - Pin window to all workspaces
#     :center, :c            - Center floating window
#     :pseudo                - Toggle pseudo-tiling
#
#   Workspace Navigation:
#     :tabn, :tn             - Next workspace
#     :tabp, :tp             - Previous workspace
#     :ws <num>              - Switch to workspace number
#     :move <num>            - Move window to workspace number
#
#   System Control:
#     :reload, :r            - Reload Hyprland config
#     :lock                  - Lock screen
#     :logout                - Exit Hyprland
#
#   Visual:
#     :opacity <0.0-1.0>     - Set window opacity
#
#   App Launching:
#     :e, :edit              - Open application launcher
#     :term, :t              - Open terminal
#
#   Utilities:
#     :help, :h              - Show keybindings help
#     :%s, :s                - Open native find/replace dialog (Ctrl+H)
#
################################################################################

set -euo pipefail

# Source shared utilities
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
source "$SCRIPT_DIR/lib/core.sh"
source "$SCRIPT_DIR/lib/hypr.sh"
source "$SCRIPT_DIR/lib/ui.sh"
source "$SCRIPT_DIR/lib/clipboard.sh"
source "$SCRIPT_DIR/lib/state.sh"

# Initialize script
init_script "command"

# Configuration
COMMAND_STATE_FILE="${XDG_RUNTIME_DIR:-/tmp}/hyprvim/command-state.json"

################################################################################
# Command Implementations
################################################################################

# :w - Save file
cmd_write() {
  send_shortcut "CTRL, S"
  notify_success "File saved" 0
  dispatch_to_after_submap "$COMMAND_STATE_FILE"
}

# :wq - Save and quit
cmd_write_quit() {
  send_shortcut "CTRL, S"
  sleep 0.1
  close_window
  notify_success "File saved and closing" 0
  dispatch_to_after_submap "$COMMAND_STATE_FILE"
}

# :q - Quit (close window)
cmd_quit() {
  close_window
  dispatch_to_after_submap "$COMMAND_STATE_FILE"
}

# :q! - Force quit (kill window immediately)
cmd_force_quit() {
  kill_window
  dispatch_to_after_submap "$COMMAND_STATE_FILE"
}

# :qa - Quit all (close all windows in current workspace)
cmd_quit_all() {
  local workspace_id
  workspace_id=$(hyprctl activeworkspace -j | jq -r '.id')

  local count
  count=$(close_workspace_windows)

  if [ "$count" -eq 0 ]; then
    notify_info "No windows to close" 1
  else
    notify_success "Closed $count window(s) in workspace $workspace_id" 1
  fi

  dispatch_to_after_submap "$COMMAND_STATE_FILE"
}

# :qa! - Force quit all (kill all windows in current workspace immediately)
cmd_force_quit_all() {
  local workspace_id
  workspace_id=$(hyprctl activeworkspace -j | jq -r '.id')

  local count
  count=$(kill_workspace_windows)

  if [ "$count" -eq 0 ]; then
    notify_info "No windows to close" 1
  else
    notify_success "Force closed $count window(s) in workspace $workspace_id" 1
  fi

  dispatch_to_after_submap "$COMMAND_STATE_FILE"
}

# :help, :h - Show help viewer
cmd_help() {
  exit_vim_mode
  ${HYPRVIM_HELP_TERMINAL:-kitty --class floating-help -e} "$SCRIPT_DIR/vim-help.sh"
  dispatch_to_after_submap "$COMMAND_STATE_FILE"
}

# :%s, :s - Open native find/replace dialog
cmd_substitute() {
  send_shortcut "CTRL, H"
  switch_mode INSERT
}

################################################################################
# Window Management Commands
################################################################################

# :split, :sp - Split window horizontally
cmd_split() {
  split_window_horizontal
  notify_success "Window split" 0
  dispatch_to_after_submap "$COMMAND_STATE_FILE"
}

# :vsplit, :vsp - Split window vertically
cmd_vsplit() {
  split_window_vertical
  notify_success "Window split vertically" 0
  dispatch_to_after_submap "$COMMAND_STATE_FILE"
}

# :only - Close all other windows in workspace (keep current)
cmd_only() {
  local count
  count=$(close_other_windows)
  notify_success "Closed $count other window(s)" 1
  dispatch_to_after_submap "$COMMAND_STATE_FILE"
}

################################################################################
# Window State Commands
################################################################################

# :float, :f - Toggle floating mode
cmd_float() {
  toggle_floating
  notify_success "Toggled floating mode" 0
  dispatch_to_after_submap "$COMMAND_STATE_FILE"
}

# :fullscreen, :fs - Toggle fullscreen
cmd_fullscreen() {
  toggle_fullscreen
  notify_success "Toggled fullscreen" 0
  dispatch_to_after_submap "$COMMAND_STATE_FILE"
}

# :pin - Pin window to all workspaces
cmd_pin() {
  toggle_pin
  notify_success "Window pinned" 0
  dispatch_to_after_submap "$COMMAND_STATE_FILE"
}

# :center, :c - Center floating window
cmd_center() {
  center_window
  notify_success "Window centered" 0
  dispatch_to_after_submap "$COMMAND_STATE_FILE"
}

# :pseudo - Toggle pseudo-tiling
cmd_pseudo() {
  toggle_pseudo
  notify_success "Toggled pseudo-tiling" 0
  dispatch_to_after_submap "$COMMAND_STATE_FILE"
}

################################################################################
# Workspace Navigation Commands
################################################################################

# :tabn, :tn - Next workspace (like gt in vim)
cmd_workspace_next() {
  next_workspace
  dispatch_to_after_submap "$COMMAND_STATE_FILE"
}

# :tabp, :tp - Previous workspace (like gT in vim)
cmd_workspace_prev() {
  prev_workspace
  dispatch_to_after_submap "$COMMAND_STATE_FILE"
}

# :ws <num> - Switch to workspace number
cmd_workspace() {
  local ws_num="$1"
  if [[ "$ws_num" =~ ^[0-9]+$ ]]; then
    switch_to_workspace "$ws_num"
    notify_success "Switched to workspace $ws_num" 0
  else
    notify_info "Usage: :ws <number>" 1
  fi
  dispatch_to_after_submap "$COMMAND_STATE_FILE"
}

# :move <num> - Move window to workspace
cmd_move_workspace() {
  local ws_num="$1"
  if [[ "$ws_num" =~ ^[0-9]+$ ]]; then
    move_window_to_workspace "$ws_num"
    notify_success "Moved to workspace $ws_num" 1
  else
    notify_info "Usage: :move <number>" 1
  fi
  dispatch_to_after_submap "$COMMAND_STATE_FILE"
}

################################################################################
# System/Hyprland Control Commands
################################################################################

# :reload, :r - Reload Hyprland config
cmd_reload() {
  reload_hyprland_config
  notify_success "Hyprland config reloaded" 1
  dispatch_to_after_submap "$COMMAND_STATE_FILE"
}

# :lock - Lock screen
cmd_lock() {
  lock_screen
  dispatch_to_after_submap "$COMMAND_STATE_FILE"
}

# :logout - Logout/exit Hyprland
cmd_logout() {
  logout_hyprland
}

################################################################################
# Visual Commands
################################################################################

# :opacity <value> - Set window opacity (0.0-1.0)
cmd_opacity() {
  local value="${1:-1.0}"
  if [[ "$value" =~ ^[0-9]*\.?[0-9]+$ ]]; then
    set_window_opacity "$value"
    notify_success "Opacity set to $value" 0
  else
    notify_info "Usage: :opacity <0.0-1.0>" 1
  fi
  dispatch_to_after_submap "$COMMAND_STATE_FILE"
}

################################################################################
# App Launching Commands
################################################################################

# :e, :edit - Open launcher
cmd_edit() {
  exit_vim_mode

  local launcher
  launcher=$(get_launcher_command)

  if [ -z "$launcher" ]; then
    notify_info "No launcher found (rofi, wofi, tofi, fuzzel)" 1
    dispatch_to_after_submap "$COMMAND_STATE_FILE"
    return
  fi

  exec_command "$launcher"
  dispatch_to_after_submap "$COMMAND_STATE_FILE"
}

# :term, :t - Open terminal
cmd_terminal() {
  exec_command "${TERMINAL:-kitty}"
  notify_success "Terminal launched" 0
  dispatch_to_after_submap "$COMMAND_STATE_FILE"
}

################################################################################
# Command Parser and Dispatcher
################################################################################

# Parse and execute command
execute_command() {
  local cmd="$1"

  log_debug "execute_command: cmd='$cmd'"

  # Remove leading/trailing whitespace
  cmd=$(echo "$cmd" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')

  case "$cmd" in
  # File operations
  w)
    cmd_write
    ;;

  wq)
    cmd_write_quit
    ;;

  q)
    cmd_quit
    ;;

  q!)
    cmd_force_quit
    ;;

  qa)
    cmd_quit_all
    ;;

  qa!)
    cmd_force_quit_all
    ;;

  # Window management
  split | sp)
    cmd_split
    ;;

  vsplit | vsp | vs)
    cmd_vsplit
    ;;

  only)
    cmd_only
    ;;

  # Window states
  float | f)
    cmd_float
    ;;

  fullscreen | fs)
    cmd_fullscreen
    ;;

  pin)
    cmd_pin
    ;;

  center | c)
    cmd_center
    ;;

  pseudo)
    cmd_pseudo
    ;;

  # Workspace navigation
  tabn | tn)
    cmd_workspace_next
    ;;

  tabp | tp)
    cmd_workspace_prev
    ;;

  ws*)
    # Extract workspace number: ":ws5" or ":ws 5"
    local num="${cmd#ws}"
    num="${num#[[:space:]]}"
    cmd_workspace "$num"
    ;;

  move*)
    # Extract workspace number: ":move5" or ":move 5"
    local num="${cmd#move}"
    num="${num#[[:space:]]}"
    cmd_move_workspace "$num"
    ;;

  # System control
  reload | r)
    cmd_reload
    ;;

  lock)
    cmd_lock
    ;;

  logout)
    cmd_logout
    ;;

  # Visual
  opacity*)
    # Extract opacity value: ":opacity0.5" or ":opacity 0.5"
    local val="${cmd#opacity}"
    val="${val#[[:space:]]}"
    cmd_opacity "$val"
    ;;

  # App launching
  e | edit)
    cmd_edit
    ;;

  term | t)
    cmd_terminal
    ;;

  # Utilities
  help | h)
    cmd_help
    ;;

  %s | s)
    cmd_substitute
    ;;

  *)
    notify_info "Unknown command: $cmd. See ':help' for available commands." 1
    dispatch_to_after_submap "$COMMAND_STATE_FILE"
    ;;
  esac
}

################################################################################
# Main Logic
################################################################################

ACTION="${1:-prompt}"
ARG="${2:-}"

case "$ACTION" in
prompt)
  exit_vim_mode

  # Get command from user
  cmd=$(get_user_input ":" "hyprvim-command" "w, wq, q, float, fullscreen, ws, move, reload, help")

  # If empty or cancelled, abort
  if [ -z "$cmd" ]; then
    dispatch_to_after_submap "$COMMAND_STATE_FILE"
    exit 0
  fi

  log_debug "main: received command='$cmd'"

  execute_command "$cmd"
  ;;

after)
  set_after_submap "$COMMAND_STATE_FILE" "$ARG"
  ;;

exit)
  dispatch_to_after_submap "$COMMAND_STATE_FILE"
  ;;

*)
  log_error "Unknown action: $ACTION. Use: prompt, after, exit"
  exit 1
  ;;
esac
