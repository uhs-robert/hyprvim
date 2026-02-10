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
STATE_DIR="${XDG_RUNTIME_DIR:-/tmp}/hyprvim/registers"
mkdir -p "$STATE_DIR"

################################################################################
# HELPER FUNCTIONS
################################################################################

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

################################################################################
# CORE REGISTER OPERATIONS - Save and load register content
################################################################################

# Save current clipboard to a register
save_to_register() {
  local register="$1"

  # Validate register name
  if ! [[ "$register" =~ ^[a-z0-9_\"/]$ ]]; then
    echo "Error: Invalid register name: $register" >&2
    return 1
  fi

  # Read-only registers
  if [[ "$register" == "/" ]]; then
    echo "Error: Register / is read-only" >&2
    return 1
  fi

  # Get clipboard content
  local content
  content=$(wl-paste 2>/dev/null || echo "")

  # Save to register file
  local register_file="$STATE_DIR/$register"
  echo -n "$content" >"$register_file"
}

# Load register content to clipboard
load_from_register() {
  local register="$1"

  # Validate register name
  if ! [[ "$register" =~ ^[a-z0-9_\"/]$ ]]; then
    echo "Error: Invalid register name: $register" >&2
    return 1
  fi

  # Handle special search register
  if [[ "$register" == "/" ]]; then
    local find_state="$STATE_DIR/../find-state.json"
    if [[ -f "$find_state" ]]; then
      local search_term
      search_term=$(jq -r '.find_term // ""' "$find_state" 2>/dev/null || echo "")
      copy_to_clipboard "$search_term"
    else
      copy_to_clipboard ""
    fi
    return 0
  fi

  # Load from register file
  local register_file="$STATE_DIR/$register"
  if [[ -f "$register_file" ]]; then
    local content
    content=$(<"$register_file")
    copy_to_clipboard "$content"
  else
    # Empty register, copy empty string
    copy_to_clipboard ""
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
    echo '"'
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
  wl-paste 2>/dev/null >"$STATE_DIR/clipboard-backup" || echo "" >"$STATE_DIR/clipboard-backup"
}

# Restore clipboard from backup
restore_clipboard() {
  if [[ -f "$STATE_DIR/clipboard-backup" ]]; then
    local content
    content=$(<"$STATE_DIR/clipboard-backup")
    copy_to_clipboard "$content"
    rm -f "$STATE_DIR/clipboard-backup"
  fi
}

# Cycle numbered registers for delete operations (vim-like behavior)
# Shifts registers 1-8 to 2-9, dropping register 9
cycle_numbered_registers() {
  # Shift registers 8→9, 7→8, ... 1→2
  for i in 8 7 6 5 4 3 2 1; do
    local src="$STATE_DIR/$i"
    local dst="$STATE_DIR/$((i + 1))"
    if [[ -f "$src" ]]; then
      mv "$src" "$dst"
    fi
  done
}

################################################################################
# OPERATION HANDLERS - Yank, delete, and paste operations
################################################################################

# Save clipboard to registers (called after yank operation)
save_clipboard() {
  local return_submap="$1" # e.g., "NORMAL"
  sleep 0.15

  # Get pending register (default to unnamed)
  local register
  register=$(get_pending)

  # Get clipboard content
  local content
  content=$(wl-paste 2>/dev/null || echo "")

  # Save to the specified register file directly
  local register_file="$STATE_DIR/$register"
  echo -n "$content" >"$register_file"

  # Also save to yank register (0) if not already
  if [[ "$register" != "0" ]]; then
    echo -n "$content" >"$STATE_DIR/0"
  fi

  # If we saved to a named register, restore unnamed to clipboard
  # so that regular 'p' still pastes from the unnamed register
  if [[ "$register" != '"' ]] && [[ -f "$STATE_DIR/\"" ]]; then
    local unnamed_content
    unnamed_content=$(<"$STATE_DIR/\"")
    copy_to_clipboard "$unnamed_content"
  fi

  # Clear pending register
  clear_pending

  # Return to specified submap
  hyprctl dispatch submap "$return_submap"
}

# Handle yank operation - sends shortcut then saves
handle_yank() {
  local shortcut="$1"      # e.g., "CTRL, C"
  local return_submap="$2" # e.g., "NORMAL"

  # Execute the yank shortcut (word splitting is intentional for hyprctl args)
  # shellcheck disable=SC2086
  hyprctl dispatch sendshortcut $shortcut, activewindow

  # Save from clipboard
  save_clipboard "$return_submap"
}

# Handle delete operations to pending register or black hole
# Implements vim-like numbered register cycling (1-9)
handle_delete() {
  local shortcut="$1"      # e.g., "CTRL, X"
  local return_submap="$2" # e.g., "NORMAL"

  # Get pending register
  local register
  register=$(get_pending)

  # Handle black hole register specially
  if [[ "$register" == "_" ]]; then
    backup_clipboard

    # Execute delete shortcut (word splitting is intentional for hyprctl args)
    # shellcheck disable=SC2086
    hyprctl dispatch sendshortcut $shortcut, activewindow
    sleep 0.05
    restore_clipboard
  else
    # Execute delete shortcut (word splitting is intentional for hyprctl args)
    # shellcheck disable=SC2086
    hyprctl dispatch sendshortcut $shortcut, activewindow

    # Wait for clipboard to be ready (increased for reliability)
    sleep 0.2

    # Get deleted content
    local content
    content=$(wl-paste 2>/dev/null || echo "")

    # Cycle numbered registers (1-8 → 2-9)
    cycle_numbered_registers

    # Save to numbered register 1 (most recent delete)
    echo -n "$content" >"$STATE_DIR/1"

    # Save to the specified register (unnamed by default)
    echo -n "$content" >"$STATE_DIR/$register"
  fi

  # Clear pending register
  clear_pending

  # Return to specified submap
  hyprctl dispatch submap "$return_submap"
}

# Handle paste operation - loads from pending register
handle_paste() {
  local shortcut="$1"      # e.g., "CTRL, V"
  local return_submap="$2" # e.g., "NORMAL"

  # Get pending register (default to unnamed)
  local register
  register=$(get_pending)

  # Load register to clipboard
  local register_file="$STATE_DIR/$register"
  if [[ -f "$register_file" ]]; then
    local content
    content=$(<"$register_file")
    copy_to_clipboard "$content"
  else
    copy_to_clipboard ""
  fi

  # Wait for clipboard to be ready
  sleep 0.15

  # Execute paste shortcut (word splitting is intentional for hyprctl args)
  # shellcheck disable=SC2086
  hyprctl dispatch sendshortcut $shortcut, activewindow

  # Wait to ensure paste completes before changing submaps
  sleep 0.15

  # Clear pending register
  clear_pending

  # Return to specified submap
  hyprctl dispatch submap "$return_submap"
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
  if [[ -f "$STATE_DIR/\"" ]]; then
    echo "\" (unnamed):"
    head -c 50 "$STATE_DIR/\"" | tr '\n' ' '
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

case "$1" in
save)
  save_to_register "$2"
  ;;
load)
  load_from_register "$2"
  ;;
set-pending)
  set_pending "$2"
  ;;
get-pending)
  get_pending
  ;;
clear-pending)
  clear_pending
  ;;
save-clipboard)
  save_clipboard "$2"
  ;;
handle-yank)
  handle_yank "$2" "$3"
  ;;
handle-delete)
  handle_delete "$2" "$3"
  ;;
handle-paste)
  handle_paste "$2" "$3"
  ;;
list)
  list_registers
  ;;
*)
  echo "Usage: $0 {save|load|set-pending|get-pending|clear-pending|save-clipboard|handle-yank|handle-delete|handle-paste|list} [args...]"
  exit 1
  ;;
esac
