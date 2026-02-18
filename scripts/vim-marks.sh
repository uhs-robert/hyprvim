#!/bin/bash
# scripts/vim-marks.sh
# hypr/.config/hypr/hyprvim/scripts/vim-marks.sh
################################################################################
# vim-marks.sh - Window/Workspace mark and teleportation system for Hyprland
################################################################################
#
# Usage:
#   vim-marks.sh set <char>    - Save current window/workspace as mark
#   vim-marks.sh jump <char>   - Jump to saved mark
#   vim-marks.sh list          - List all marks
#   vim-marks.sh delete <char> - Delete specific mark
#   vim-marks.sh clear         - Clear all marks
#   vim-marks.sh after <name>  - Set submap to transition to after next operation
#   vim-marks.sh exit          - Dispatch to saved submap state
#
# Examples:
#   vim-marks.sh after reset && hyprctl dispatch submap JUMP-MARK   # Jump resets submaps
#   vim-marks.sh after NORMAL && hyprctl dispatch submap SET-MARK   # Set goes to NORMAL
#   bind = , ESCAPE, exec, $HYPRVIM_MARKS exit                      # Exit to saved submap
#
################################################################################

set -euo pipefail

# Source shared utilities
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
source "$SCRIPT_DIR/lib/core.sh"
source "$SCRIPT_DIR/lib/ui.sh"
source "$SCRIPT_DIR/lib/state.sh"

# Initialize script
init_script "marks"

# Configuration
MARKS_FILE="${XDG_RUNTIME_DIR:-/tmp}/hyprvim/marks.json"
NOTIFY_ENABLED="${HYPRVIM_MARK_NOTIFY:-0}"

# Parse arguments
ACTION="${1:-}"
MARK="${2:-}"

# Check dependencies
require_cmd jq hyprctl

################################################################################
# Action: Set Mark
################################################################################

set_mark() {
  local mark="$1"

  # Validate mark character
  if [ -z "$mark" ]; then
    notify_error "Mark character required" "$NOTIFY_ENABLED"
  fi

  # Get current window information
  local workspace window monitor class title timestamp

  workspace=$(hyprctl activeworkspace -j 2>/dev/null | jq -r '.id // empty')
  window=$(hyprctl activewindow -j 2>/dev/null | jq -r '.address // empty')
  monitor=$(hyprctl monitors -j 2>/dev/null | jq -r '.[] | select(.focused) | .name // empty')
  class=$(hyprctl activewindow -j 2>/dev/null | jq -r '.class // empty')
  title=$(hyprctl activewindow -j 2>/dev/null | jq -r '.title // empty')
  timestamp=$(date +%s)

  # Check if valid data
  if [ -z "$window" ] || [ -z "$workspace" ]; then
    notify_error "No active window found" "$NOTIFY_ENABLED"
  fi

  ensure_json_file "$MARKS_FILE"

  # Update mark in JSON (atomic write via temp file)
  local temp_file="${MARKS_FILE}.tmp"

  jq --arg mark "$mark" \
    --arg ws "$workspace" \
    --arg win "$window" \
    --arg mon "$monitor" \
    --arg cls "$class" \
    --arg ttl "$title" \
    --arg ts "$timestamp" \
    '.[$mark] = {
         workspace: ($ws | tonumber),
         window: $win,
         monitor: $mon,
         class: $cls,
         title: $ttl,
         timestamp: ($ts | tonumber)
       }' "$MARKS_FILE" >"$temp_file"

  # Move and Truncate long titles for display
  mv "$temp_file" "$MARKS_FILE"
  local display_title="${title:0:30}"
  [ "${#title}" -gt 30 ] && display_title="${display_title}..."

  notify_success "Mark '$mark' → $class (ws:$workspace)" "$NOTIFY_ENABLED"
  dispatch_to_after_submap "$MARKS_FILE"
}

################################################################################
# Action: Jump to Mark
################################################################################

jump_mark() {
  local mark="$1"

  if [ -z "$mark" ]; then
    notify_error "Mark character required" "$NOTIFY_ENABLED"
  fi

  if [ ! -f "$MARKS_FILE" ]; then
    notify_error "No marks set" "$NOTIFY_ENABLED"
  fi

  # Read mark data
  local mark_data
  mark_data=$(jq -r --arg mark "$mark" '.[$mark] // empty' "$MARKS_FILE")

  if [ -z "$mark_data" ]; then
    notify_error "Mark '$mark' not set" "$NOTIFY_ENABLED"
  fi

  # Parse mark data
  local workspace window monitor class title
  workspace=$(echo "$mark_data" | jq -r '.workspace')
  window=$(echo "$mark_data" | jq -r '.window')
  monitor=$(echo "$mark_data" | jq -r '.monitor')
  class=$(echo "$mark_data" | jq -r '.class')
  title=$(echo "$mark_data" | jq -r '.title')

  # Check if monitor exists
  if ! hyprctl monitors -j | jq -e --arg mon "$monitor" '.[] | select(.name == $mon)' >/dev/null 2>&1; then
    notify_info "Monitor '$monitor' not found, using current monitor" "$NOTIFY_ENABLED"
  else
    hyprctl dispatch focusmonitor "$monitor" 2>/dev/null || true
  fi

  # Switch to workspace
  hyprctl dispatch workspace "$workspace" 2>/dev/null || notify_error "Failed to switch to workspace $workspace" "$NOTIFY_ENABLED"

  # Check if window still exists
  if hyprctl clients -j 2>/dev/null | jq -e --arg addr "$window" '.[] | select(.address == $addr)' >/dev/null; then
    # Window exists, focus it
    hyprctl dispatch focuswindow "address:$window" 2>/dev/null || notify_error "Failed to focus window" "$NOTIFY_ENABLED"

    local display_title="${title:0:30}"
    [ "${#title}" -gt 30 ] && display_title="${display_title}..."
    notify_success "Jumped to '$mark' → $class" "$NOTIFY_ENABLED"
  else
    # Window closed - delete stale mark and notify
    local temp_file="${MARKS_FILE}.tmp"
    jq --arg mark "$mark" 'del(.[$mark])' "$MARKS_FILE" >"$temp_file"
    mv "$temp_file" "$MARKS_FILE"
    notify_info "Mark '$mark' deleted (window no longer exists)" "$NOTIFY_ENABLED"
  fi
  dispatch_to_after_submap "$MARKS_FILE"
}

################################################################################
# Action: List Marks
################################################################################

list_marks() {
  if [ ! -f "$MARKS_FILE" ]; then
    [ -n "$NOTIFY_ENABLED" ] && notify-send -t 3000 "Marks" "No marks set" 2>/dev/null || true
    echo "No marks set"
    return
  fi

  local mark_count
  mark_count=$(jq '. | length' "$MARKS_FILE")

  if [ "$mark_count" -eq 0 ]; then
    [ -n "$NOTIFY_ENABLED" ] && notify-send -t 3000 "Marks" "No marks set" 2>/dev/null || true
    echo "No marks set"
    return
  fi

  # Build the marks list for notification
  local marks_list
  marks_list=$(jq -r 'to_entries | sort_by(.key) | .[] |
      "\(.key): \(.value.title | .[0:30]) (ws:\(.value.workspace))"' \
    "$MARKS_FILE")

  # Send notification with the marks list if enabled
  [ -n "$NOTIFY_ENABLED" ] && notify-send -t 5000 "Marks ($mark_count)" "$marks_list" 2>/dev/null || true

  # Always echo for terminal use
  echo "Marks ($mark_count):"
  echo "$marks_list"
}

################################################################################
# Action: Delete Mark
################################################################################

delete_mark() {
  local mark="$1"

  if [ -z "$mark" ]; then
    notify_error "Mark character required" "$NOTIFY_ENABLED"
  fi

  if [ ! -f "$MARKS_FILE" ]; then
    notify_error "No marks set" "$NOTIFY_ENABLED"
  fi

  # Check if mark exists
  if ! jq -e --arg mark "$mark" '.[$mark]' "$MARKS_FILE" >/dev/null 2>&1; then
    notify_error "Mark '$mark' not set" "$NOTIFY_ENABLED"
  fi

  # Delete mark (atomic write)
  local temp_file="${MARKS_FILE}.tmp"
  jq --arg mark "$mark" 'del(.[$mark])' "$MARKS_FILE" >"$temp_file"
  mv "$temp_file" "$MARKS_FILE"

  notify_success "Deleted mark '$mark'" "$NOTIFY_ENABLED"
  dispatch_to_after_submap "$MARKS_FILE"
}

################################################################################
# Action: Clear All Marks
################################################################################

clear_marks() {
  if [ ! -f "$MARKS_FILE" ]; then
    notify_info "No marks to clear" "$NOTIFY_ENABLED"
    return
  fi

  local mark_count
  mark_count=$(jq '. | length' "$MARKS_FILE")

  if [ "$mark_count" -eq 0 ]; then
    notify_info "No marks to clear" "$NOTIFY_ENABLED"
    return
  fi

  # Clear all marks
  echo '{}' >"$MARKS_FILE"
  notify_success "Cleared $mark_count marks" "$NOTIFY_ENABLED"
  dispatch_to_after_submap "$MARKS_FILE"
}

################################################################################
# Main
################################################################################

case "$ACTION" in
set)
  set_mark "$MARK"
  ;;
jump)
  jump_mark "$MARK"
  ;;
list)
  list_marks
  ;;
delete)
  delete_mark "$MARK"
  ;;
clear)
  clear_marks
  ;;
after)
  set_after_submap "$MARKS_FILE" "$MARK"
  ;;
exit)
  dispatch_to_after_submap "$MARKS_FILE"
  ;;
"")
  notify_error "Action required: set, jump, list, delete, clear, after, exit" "$NOTIFY_ENABLED"
  ;;
*)
  notify_error "Unknown action: $ACTION" "$NOTIFY_ENABLED"
  ;;
esac
