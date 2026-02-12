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
# Submap State Management
################################################################################

# Helper function to dispatch to submap after command
dispatch_submap() {
  local after_submap="NORMAL"

  # Read from command-state.json
  if [ -f "$COMMAND_STATE_FILE" ]; then
    after_submap=$(jq -r '.after // "NORMAL"' "$COMMAND_STATE_FILE" 2>/dev/null || echo "NORMAL")
    # Clear the after property
    local temp_file="${COMMAND_STATE_FILE}.tmp"
    jq 'del(.after)' "$COMMAND_STATE_FILE" >"$temp_file" 2>/dev/null && mv "$temp_file" "$COMMAND_STATE_FILE"
  fi

  hyprctl dispatch submap "$after_submap" 2>/dev/null || true
}

# Set the after-submap property
set_after_submap() {
  local submap="${1:-NORMAL}"
  ensure_json_file "$COMMAND_STATE_FILE"
  local temp_file="${COMMAND_STATE_FILE}.tmp"
  jq --arg after "$submap" '.after = $after' "$COMMAND_STATE_FILE" >"$temp_file" && mv "$temp_file" "$COMMAND_STATE_FILE"
}

################################################################################
# Command Implementations
################################################################################

# :w - Save file
cmd_write() {
  send_shortcut CTRL, S
  notify_success "File saved" 0
  dispatch_submap
}

# :wq - Save and quit
cmd_write_quit() {
  send_shortcut CTRL, S
  sleep 0.1
  close_window
  notify_success "File saved and closing" 0
  dispatch_submap
}

# :q - Quit (close window)
cmd_quit() {
  close_window
  dispatch_submap
}

# :q! - Force quit (kill window immediately)
cmd_force_quit() {
  kill_window
  dispatch_submap
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

  dispatch_submap
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

  dispatch_submap
}

# :help, :h - Show help viewer
cmd_help() {
  exit_vim_mode
  ${HYPRVIM_HELP_TERMINAL:-kitty --class floating-help -e} "$SCRIPT_DIR/vim-help.sh"
  # dispatch_submap
}

# :%s, :s - Open native find/replace dialog
cmd_substitute() {
  send_shortcut CTRL, H
  switch_mode INSERT
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

  help | h)
    cmd_help
    ;;

  %s | s)
    cmd_substitute
    ;;

  *)
    notify_info "Unknown command: $cmd. See ':help' for available commands." 1
    dispatch_submap
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
    dispatch_submap
    exit 0
  fi

  log_debug "main: received command='$cmd'"

  execute_command "$cmd"
  ;;

after)
  set_after_submap "$ARG"
  ;;

exit)
  dispatch_submap
  ;;

*)
  log_error "Unknown action: $ACTION. Use: prompt, after, exit"
  exit 1
  ;;
esac
