#!/bin/bash
# hypr/.config/hypr/hyprvim/scripts/lib/clipboard.sh
################################################################################
# Clipboard functions for HyprVim scripts
################################################################################
#
# Provides: Clipboard operations (copy, paste, backup, restore)
# Dependencies: core.sh (for require_cmd)
#
################################################################################

set -euo pipefail

################################################################################
# Clipboard Helpers
################################################################################

# Clipboard copy - automatically handles single chars with text/plain
# Usage: clipboard_copy "text"
clipboard_copy() {
  local text="$1"
  require_cmd wl-copy

  # Single character: use --type text/plain to fix wl-copy issues
  if [[ ${#text} -eq 1 ]]; then
    echo -n "$text" | wl-copy --type text/plain
  else
    echo -n "$text" | wl-copy
  fi
}

# Copy text to clipboard with specific type
# Usage: clipboard_copy_typed "text" "text/plain"
clipboard_copy_typed() {
  local text="$1"
  local type="${2:-text/plain}"
  require_cmd wl-copy
  echo -n "$text" | wl-copy --type "$type"
}

# Get text from clipboard
# Usage: clipboard_paste
clipboard_paste() {
  require_cmd wl-paste
  wl-paste 2>/dev/null || echo ""
}

################################################################################
# Clipboard Backup/Restore
################################################################################

# Backup current clipboard to a temp file
# Usage: backup_clipboard "/path/to/backup/file"
backup_clipboard() {
  local backup_file="$1"
  clipboard_paste >"$backup_file"
}

# Restore clipboard from backup file
# Usage: restore_clipboard "/path/to/backup/file"
restore_clipboard() {
  local backup_file="$1"
  if [[ -f "$backup_file" ]]; then
    local content
    content=$(<"$backup_file")
    clipboard_copy "$content"
    rm -f "$backup_file"
  fi
}

################################################################################
# Selection Helpers
################################################################################

# Get selected text using primary selection or copy fallback
# Usage: get_selection [--select-word]
# Options:
#   --select-word: If no selection, select current word before copying
# Returns: Selected text (exits 1 if no selection found)
get_selection() {
  local select_word=false
  if [[ "${1:-}" == "--select-word" ]]; then
    select_word=true
  fi

  # Save current clipboard
  local saved_clipboard
  saved_clipboard=$(wl-paste --no-newline 2>/dev/null || true)

  # Try primary selection first (instant, no copy needed)
  local selected
  selected=$(wl-paste -p --no-newline 2>/dev/null || true)

  # If no primary selection, try copying with retries
  if [[ -z "$selected" ]]; then
    # Select word if requested
    if $select_word; then
      require_cmd hyprctl
      hyprctl dispatch sendshortcut CTRL+SHIFT, LEFT, activewindow >/dev/null 2>&1
      sleep 0.05
      hyprctl dispatch sendshortcut CTRL+SHIFT, RIGHT, activewindow >/dev/null 2>&1
      sleep 0.05
    fi

    # Try copy with retries and verification
    for attempt in 1 2 3; do
      hyprctl dispatch sendshortcut CTRL, C, activewindow >/dev/null 2>&1
      sleep 0.$attempt

      local new_clipboard
      new_clipboard=$(wl-paste --no-newline 2>/dev/null || true)

      if [[ -n "$new_clipboard" ]] && [[ "$new_clipboard" != "$saved_clipboard" ]]; then
        selected="$new_clipboard"
        break
      fi
    done
  fi

  # Restore original clipboard
  if [[ -n "$saved_clipboard" ]]; then
    echo -n "$saved_clipboard" | wl-copy -n
  else
    wl-copy -c 2>/dev/null || true
  fi

  # Return selection
  if [[ -n "$selected" ]]; then
    echo "$selected"
    return 0
  else
    return 1
  fi
}

# Paste text to window while preserving clipboard
# Usage: paste_to_window "text" [window_address]
paste_to_window() {
  local text="$1"
  local window="${2:-activewindow}"
  require_cmd hyprctl

  # Save clipboard
  local saved_clipboard
  saved_clipboard=$(wl-paste --no-newline 2>/dev/null || true)

  # Copy text and paste
  echo -n "$text" | wl-copy -n
  hyprctl dispatch sendshortcut CTRL, V, "$window" >/dev/null 2>&1

  # Wait for paste to complete
  sleep 0.1

  # Restore clipboard
  if [[ -n "$saved_clipboard" ]]; then
    echo -n "$saved_clipboard" | wl-copy -n
  else
    wl-copy -c 2>/dev/null || true
  fi
}

################################################################################
# Export Functions
################################################################################

export -f clipboard_copy
export -f clipboard_copy_typed
export -f clipboard_paste
export -f backup_clipboard
export -f restore_clipboard
export -f get_selection
export -f paste_to_window
