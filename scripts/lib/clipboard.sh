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
# Export Functions
################################################################################

export -f clipboard_copy
export -f clipboard_copy_typed
export -f clipboard_paste
export -f backup_clipboard
export -f restore_clipboard
