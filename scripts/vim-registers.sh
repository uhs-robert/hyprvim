#!/bin/bash
# scripts/vim-registers.sh
# hypr/.config/hypr/HyprVim/scripts/vim-registers.sh
################################################################################
# vim-registers.sh - Register management for HyprVim
################################################################################
#
# Implements vim-like register system with special registers:
#   "  - Unnamed register (default, syncs with system clipboard)
#   0  - Yank register (last yank, preserved during deletes)
#   1-9 - Numbered registers (last 9 deletes, auto-cycling)
#   a-z - Named registers (manual storage)
#   _  - Black hole register (delete without affecting clipboard)
#   /  - Search register (last search term, read-only)
#
# Usage:
#   vim-registers.sh save <register>        - Save clipboard to register
#   vim-registers.sh load <register>        - Load register to clipboard
#   vim-registers.sh set-pending <register> - Set pending register
#   vim-registers.sh get-pending            - Get pending register
#   vim-registers.sh clear-pending          - Clear pending register
#   vim-registers.sh save-clipboard <mode>  - Save clipboard after yank
#   vim-registers.sh handle-yank <shortcut> <mode>   - Handle yank operation
#   vim-registers.sh handle-delete <shortcut> <mode> - Handle delete operation
#   vim-registers.sh handle-paste <shortcut> <mode>  - Handle paste operation
#   vim-registers.sh list                   - List all registers
#
################################################################################

set -euo pipefail
DEFAULT_REGISTER='"'
DEBUG=0
STATE_DIR="${XDG_RUNTIME_DIR:-/tmp}/hyprvim/registers"
mkdir -p "$STATE_DIR"

################################################################################
# HELPER FUNCTIONS
################################################################################

# Print debug message if DEBUG=1
log_debug() {
  if [[ "$DEBUG" -eq 1 ]]; then
    echo "[registers] $*" >&2
  fi
}

# Sleep with debug logging
sleep_with_debug() {
  local duration="$1"
  log_debug "sleep ${duration}s"
  sleep "$duration"
}

# Read current clipboard content
read_clipboard() {
  wl-paste 2>/dev/null || echo ""
}

# Write content to clipboard
write_clipboard() {
  local content="$1"
  copy_to_clipboard "$content"
}

# Smart copy that uses --type text/plain for single characters
# This fixes wl-copy issues with single character content
copy_to_clipboard() {
  local content="$1"
  if [[ ${#content} -eq 1 ]]; then
    # Single character: use --type text/plain to fix wl-copy issue
    echo -n "$content" | wl-copy --type text/plain
  else
    echo -n "$content" | wl-copy
  fi
}

# Validate register name format
validate_register() {
  local register="$1"
  if ! [[ "$register" =~ ^[a-z0-9_\"/]$ ]]; then
    echo "Error: Invalid register name: $register" >&2
    return 1
  fi
  return 0
}

# Execute action with pending register, then clear and return to submap
with_pending_register() {
  local return_submap="$1"
  shift
  local action_fn="$1"
  shift

  local register
  register=$(get_pending)
  validate_register "$register" || return 1

  log_debug "action=$action_fn register=$register return=$return_submap"
  "$action_fn" "$register" "$return_submap" "$@"

  clear_pending
  hyprctl dispatch submap "$return_submap"
}

################################################################################
# CORE REGISTER OPERATIONS - Save and load register content
################################################################################

# Save current clipboard to a register
save_to_register() {
  local register="$1"

  validate_register "$register"

  # Read-only registers
  if [[ "$register" == "/" ]]; then
    echo "Error: Register / is read-only" >&2
    return 1
  fi

  # Get clipboard content
  local content
  content=$(read_clipboard)

  # Save to register file
  local register_file="$STATE_DIR/$register"
  echo -n "$content" >"$register_file"
}

# Load register content to clipboard
load_from_register() {
  local register="$1"

  validate_register "$register"

  # Handle special search register
  if [[ "$register" == "/" ]]; then
    local find_state="$STATE_DIR/../find-state.json"
    if [[ -f "$find_state" ]]; then
      local search_term
      search_term=$(jq -r '.find_term // ""' "$find_state" 2>/dev/null || echo "")
      write_clipboard "$search_term"
    else
      write_clipboard ""
    fi
    return 0
  fi

  # Load from register file
  local register_file="$STATE_DIR/$register"
  if [[ -f "$register_file" ]]; then
    local content
    content=$(<"$register_file")
    write_clipboard "$content"
  else
    # Empty register, copy empty string
    write_clipboard ""
  fi
}

################################################################################
# PENDING REGISTER MANAGEMENT - Track register for next operation
################################################################################

# Set pending register for next operation
set_pending() {
  local register="$1"
  echo -n "$register" >"$STATE_DIR/pending-register"
}

# Get pending register (or default to unnamed)
get_pending() {
  if [[ -f "$STATE_DIR/pending-register" ]]; then
    cat "$STATE_DIR/pending-register"
  else
    echo "$DEFAULT_REGISTER"
  fi
}

# Clear pending register
clear_pending() {
  rm -f "$STATE_DIR/pending-register"
}

################################################################################
# CLIPBOARD OPERATIONS - Backup, restore, and numbered register cycling
################################################################################

# Backup current clipboard
backup_clipboard() {
  read_clipboard >"$STATE_DIR/clipboard-backup"
}

# Restore clipboard from backup
restore_clipboard() {
  if [[ -f "$STATE_DIR/clipboard-backup" ]]; then
    local content
    content=$(<"$STATE_DIR/clipboard-backup")
    write_clipboard "$content"
    rm -f "$STATE_DIR/clipboard-backup"
  fi
}

# Cycle numbered registers for delete operations (vim-like behavior)
# Shifts registers 1-8 to 2-9, dropping register 9
cycle_numbered_registers() {
  for i in 8 7 6 5 4 3 2 1; do
    local src="$STATE_DIR/$i"
    local dst="$STATE_DIR/$((i + 1))"
    if [[ -f "$src" ]]; then
      mv "$src" "$dst"
    fi
  done
}

# Save deleted content to register and numbered registers
save_delete_content() {
  local register="$1"
  local content="$2"

  cycle_numbered_registers

  # Save to numbered register 1 (most recent delete)
  echo -n "$content" >"$STATE_DIR/1"

  # Save to the specified register (unnamed by default)
  echo -n "$content" >"$STATE_DIR/$register"
}

################################################################################
# OPERATION HANDLERS - Yank, delete, and paste operations
################################################################################

# Save clipboard to registers (called after yank operation)
save_clipboard() {
  local return_submap="$1" # e.g., "NORMAL"
  with_pending_register "$return_submap" _save_clipboard
}

# Internal: save clipboard to register and yank register
_save_clipboard() {
  local register="$1"
  local _return_submap="$2"

  sleep_with_debug 0.15

  # Get clipboard content
  local content
  content=$(read_clipboard)

  # Save to the specified register file directly
  local register_file="$STATE_DIR/$register"
  echo -n "$content" >"$register_file"

  # Also save to yank register (0) if not already
  if [[ "$register" != "0" ]]; then
    echo -n "$content" >"$STATE_DIR/0"
  fi

  # If we saved to a named register, restore unnamed to clipboard
  # so that regular 'p' still pastes from the unnamed register
  if [[ "$register" != "$DEFAULT_REGISTER" ]] && [[ -f "$STATE_DIR/$DEFAULT_REGISTER" ]]; then
    local unnamed_content
    unnamed_content=$(<"$STATE_DIR/$DEFAULT_REGISTER")
    write_clipboard "$unnamed_content"
  fi
}

# Handle yank operation - sends shortcut then saves
handle_yank() {
  local shortcut="$1"      # e.g., "CTRL, C"
  local return_submap="$2" # e.g., "NORMAL"

  with_pending_register "$return_submap" _handle_yank "$shortcut"
}

# Internal: execute yank shortcut and save to register
_handle_yank() {
  local register="$1"
  local return_submap="$2"
  local shortcut="$3"

  # Execute the yank shortcut (word splitting is intentional for hyprctl args)
  # shellcheck disable=SC2086
  hyprctl dispatch sendshortcut $shortcut, activewindow

  # Save from clipboard
  _save_clipboard "$register" "$return_submap"
}

# Handle delete operations to pending register or black hole
# Implements vim-like numbered register cycling (1-9)
handle_delete() {
  local shortcut="$1"      # e.g., "CTRL, X"
  local return_submap="$2" # e.g., "NORMAL"

  with_pending_register "$return_submap" _handle_delete "$shortcut"
}

# Internal: execute delete shortcut and save to register or black hole
_handle_delete() {
  local register="$1"
  local return_submap="$2"
  local shortcut="$3"

  # Handle black hole register specially
  if [[ "$register" == "_" ]]; then
    backup_clipboard

    # Execute delete shortcut (word splitting is intentional for hyprctl args)
    # shellcheck disable=SC2086
    hyprctl dispatch sendshortcut $shortcut, activewindow
    sleep_with_debug 0.05
    restore_clipboard
  else
    # Execute delete shortcut (word splitting is intentional for hyprctl args)
    # shellcheck disable=SC2086
    hyprctl dispatch sendshortcut $shortcut, activewindow

    # Wait for clipboard to be ready (increased for reliability)
    sleep_with_debug 0.2

    # Get deleted content
    local content
    content=$(read_clipboard)
    save_delete_content "$register" "$content"
  fi
}

# Handle paste operation - loads from pending register
handle_paste() {
  local shortcut="$1"      # e.g., "CTRL, V"
  local return_submap="$2" # e.g., "NORMAL"

  with_pending_register "$return_submap" _handle_paste "$shortcut"
}

# Internal: load register to clipboard and execute paste shortcut
_handle_paste() {
  local register="$1"
  local return_submap="$2"
  local shortcut="$3"

  # Load register to clipboard
  load_from_register "$register"

  # Wait for clipboard to be ready
  sleep_with_debug 0.15

  # Execute paste shortcut (word splitting is intentional for hyprctl args)
  # shellcheck disable=SC2086
  hyprctl dispatch sendshortcut $shortcut, activewindow

  # Wait to ensure paste completes before changing submaps
  sleep_with_debug 0.15
}

################################################################################
# UTILITY FUNCTIONS - Display and debug operations
################################################################################

# List all registers (debug/info)
list_registers() {
  echo "=== HyprVim Registers ==="
  echo

  # Show pending register
  if [[ -f "$STATE_DIR/pending-register" ]]; then
    echo "Pending: \"$(cat "$STATE_DIR/pending-register")\""
    echo
  fi

  # Show unnamed register
  if [[ -f "$STATE_DIR/$DEFAULT_REGISTER" ]]; then
    echo "\" (unnamed):"
    head -c 50 "$STATE_DIR/$DEFAULT_REGISTER" | tr '\n' ' '
    echo
    echo
  fi

  # Show yank register
  if [[ -f "$STATE_DIR/0" ]]; then
    echo "0 (yank):"
    head -c 50 "$STATE_DIR/0" | tr '\n' ' '
    echo
    echo
  fi

  # Show numbered registers (1-9, last deletes)
  for i in 1 2 3 4 5 6 7 8 9; do
    if [[ -f "$STATE_DIR/$i" ]]; then
      echo "$i (delete):"
      head -c 50 "$STATE_DIR/$i" | tr '\n' ' '
      echo
      echo
    fi
  done

  # Show named registers
  for reg_file in "$STATE_DIR"/*; do
    local reg_name
    reg_name=$(basename "$reg_file")
    if [[ "$reg_name" =~ ^[a-z]$ ]] && [[ -f "$reg_file" ]]; then
      echo "$reg_name:"
      head -c 50 "$reg_file" | tr '\n' ' '
      echo
      echo
    fi
  done

  # Show search register
  local find_state="$STATE_DIR/../find-state.json"
  if [[ -f "$find_state" ]]; then
    local search_term
    search_term=$(jq -r '.find_term // ""' "$find_state" 2>/dev/null || echo "")
    if [[ -n "$search_term" ]]; then
      echo "/ (search): $search_term"
      echo
    fi
  fi
}

################################################################################
# MAIN COMMAND DISPATCHER
################################################################################

if [[ "${1:-}" == "--debug" ]]; then
  DEBUG=1
  shift
fi

CMD="${1:-}"
shift || true

case "$CMD" in
save)
  save_to_register "$@"
  ;;
load)
  load_from_register "$@"
  ;;
set-pending)
  set_pending "$@"
  ;;
get-pending)
  get_pending
  ;;
clear-pending)
  clear_pending
  ;;
save-clipboard)
  save_clipboard "$@"
  ;;
handle-yank)
  handle_yank "$@"
  ;;
handle-delete)
  handle_delete "$@"
  ;;
handle-paste)
  handle_paste "$@"
  ;;
list)
  list_registers
  ;;
*)
  echo "Usage: $0 [--debug] {save|load|set-pending|get-pending|clear-pending|save-clipboard|handle-yank|handle-delete|handle-paste|list} [args...]"
  exit 1
  ;;
esac
