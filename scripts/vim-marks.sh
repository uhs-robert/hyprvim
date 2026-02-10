#!/bin/bash
# hypr/.config/hypr/hyprvim/scripts/vim-marks.sh
################################################################################
# vim-marks.sh - Window/Workspace mark and teleportation system for Hyprland
################################################################################
#
# Usage:
#   vim-marks.sh set <char>     - Save current window/workspace as mark
#   vim-marks.sh jump <char>    - Jump to saved mark
#   vim-marks.sh list           - List all marks
#   vim-marks.sh delete <char>  - Delete specific mark
#   vim-marks.sh clear          - Clear all marks
#
################################################################################

set -euo pipefail

MARKS_FILE="${XDG_RUNTIME_DIR:-/tmp}/hypr-vim-marks-$USER.json"
ACTION="${1:-}"
MARK="${2:-}"
NOTIFY_ENABLED="${HYPRVIM_MARK_NOTIFY:-}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

################################################################################
# Helper Functions
################################################################################

error() {
  echo -e "${RED}Error: $1${NC}" >&2
  [ -n "$NOTIFY_ENABLED" ] && notify-send -t 2000 -u critical "Mark Error" "$1"
  exit 1
}

success() {
  echo -e "${GREEN}$1${NC}"
  [ -n "$NOTIFY_ENABLED" ] && notify-send -t 1000 -u low "Mark" "$1"
}

info() {
  echo -e "${YELLOW}$1${NC}"
  [ -n "$NOTIFY_ENABLED" ] && notify-send -t 1500 -u normal "Mark" "$1"
}

ensure_marks_file() {
  if [ ! -f "$MARKS_FILE" ]; then
    echo '{}' >"$MARKS_FILE"
  fi
}

################################################################################
# Action: Set Mark
################################################################################

set_mark() {
  local mark="$1"

  # Validate mark character
  if [ -z "$mark" ]; then
    error "Mark character required"
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
    error "No active window found"
  fi
  ensure_marks_file

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

  success "Mark '$mark' → $class (ws:$workspace)"
}

################################################################################
# Action: Jump to Mark
################################################################################

jump_mark() {
  local mark="$1"

  if [ -z "$mark" ]; then
    error "Mark character required"
  fi

  if [ ! -f "$MARKS_FILE" ]; then
    error "No marks set"
  fi

  # Read mark data
  local mark_data
  mark_data=$(jq -r --arg mark "$mark" '.[$mark] // empty' "$MARKS_FILE")

  if [ -z "$mark_data" ]; then
    error "Mark '$mark' not set"
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
    info "Monitor '$monitor' not found, using current monitor"
  else
    hyprctl dispatch focusmonitor "$monitor" 2>/dev/null || true
  fi

  # Switch to workspace
  hyprctl dispatch workspace "$workspace" 2>/dev/null || error "Failed to switch to workspace $workspace"

  # Check if window still exists
  if hyprctl clients -j 2>/dev/null | jq -e --arg addr "$window" '.[] | select(.address == $addr)' >/dev/null; then
    # Window exists, focus it
    hyprctl dispatch focuswindow "address:$window" 2>/dev/null || error "Failed to focus window"

    local display_title="${title:0:30}"
    [ "${#title}" -gt 30 ] && display_title="${display_title}..."
    success "Jumped to '$mark' → $class"
  else
    # Window closed but workspace switched
    info "Window has been closed, switched to workspace $workspace"
  fi
}

################################################################################
# Action: List Marks
################################################################################

list_marks() {
  if [ ! -f "$MARKS_FILE" ]; then
    [ -n "$NOTIFY_ENABLED" ] && notify-send -t 3000 "Marks" "No marks set"
    echo "No marks set"
    return
  fi

  local mark_count
  mark_count=$(jq '. | length' "$MARKS_FILE")

  if [ "$mark_count" -eq 0 ]; then
    [ -n "$NOTIFY_ENABLED" ] && notify-send -t 3000 "Marks" "No marks set"
    echo "No marks set"
    return
  fi

  # Build the marks list for notification
  local marks_list
  marks_list=$(jq -r 'to_entries | sort_by(.key) | .[] |
      "\(.key): \(.value.title | .[0:30]) (ws:\(.value.workspace))"' \
    "$MARKS_FILE")

  # Send notification with the marks list if enabled
  [ -n "$NOTIFY_ENABLED" ] && notify-send -t 5000 "Marks ($mark_count)" "$marks_list"

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
    error "Mark character required"
  fi

  if [ ! -f "$MARKS_FILE" ]; then
    error "No marks set"
  fi

  # Check if mark exists
  if ! jq -e --arg mark "$mark" '.[$mark]' "$MARKS_FILE" >/dev/null 2>&1; then
    error "Mark '$mark' not set"
  fi

  # Delete mark (atomic write)
  local temp_file="${MARKS_FILE}.tmp"
  jq --arg mark "$mark" 'del(.[$mark])' "$MARKS_FILE" >"$temp_file"
  mv "$temp_file" "$MARKS_FILE"

  success "Deleted mark '$mark'"
}

################################################################################
# Action: Clear All Marks
################################################################################

clear_marks() {
  if [ ! -f "$MARKS_FILE" ]; then
    info "No marks to clear"
    return
  fi

  local mark_count
  mark_count=$(jq '. | length' "$MARKS_FILE")

  if [ "$mark_count" -eq 0 ]; then
    info "No marks to clear"
    return
  fi

  # Clear all marks
  echo '{}' >"$MARKS_FILE"
  success "Cleared $mark_count marks"
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
"")
  error "Action required: set, jump, list, delete, clear"
  ;;
*)
  error "Unknown action: $ACTION"
  ;;
esac
