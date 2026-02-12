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
#   :w                       - Save file (Ctrl+S)
#   :wq                      - Save and quit (Ctrl+S then Alt+F4)
#   :q                       - Quit window (Alt+F4, allows app to prompt for save)
#   :q!                      - Force quit window (kill immediately)
#   :qa                      - Quit all windows in current workspace
#   :qa!                     - Force quit all windows in current workspace
#   :help, :h                - Show keybindings help
#   :%s, :s                  - Open native find/replace dialog (Ctrl+H)
#   System Control:
#     :reload, :r            - Reload Hyprland config
#     :lock                  - Lock screen
#     :logout                - Exit Hyprland
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
  send_shortcut CTRL, S
  notify_success "File saved" 0
  dispatch_to_after_submap "$COMMAND_STATE_FILE"
}

# :wq - Save and quit
cmd_write_quit() {
  send_shortcut CTRL, S
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
  send_shortcut CTRL, H
  switch_mode INSERT
}

################################################################################
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
# Command Parser and Dispatcher
################################################################################

# Parse and execute command
execute_command() {
  local cmd="$1"

  log_debug "execute_command: cmd='$cmd'"

  # Remove leading/trailing whitespace
  cmd=$(echo "$cmd" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')

  case "$cmd" in
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
  cmd=$(get_user_input ":" "hyprvim-command" "w, wq, q, qa, %s, h|help")


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
