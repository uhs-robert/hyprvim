#!/usr/bin/env bash
# hypr/.config/hypr/hyprvim/scripts/vim-surround.sh
################################################################################
# vim-surround.sh - Surround text with character pairs
################################################################################
#
# Usage:
#   vim-surround.sh    - Surround selected text or word with character pair
#
# Examples:
#   Input: (          Output: (text)
#   Input: {          Output: {text}
#   Input: { _        Output: { text }
#   Input: <div>      Output: <div>text</div>
#
################################################################################

set -euo pipefail

# Source shared utilities
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
source "$SCRIPT_DIR/lib/core.sh"
source "$SCRIPT_DIR/lib/hypr.sh"
source "$SCRIPT_DIR/lib/ui.sh"
source "$SCRIPT_DIR/lib/clipboard.sh"

# Initialize script
init_script "surround"

################################################################################
# Helper Functions
################################################################################

# Get matching surround pair
# Single char: uses pair mapping (e.g., "(" -> "( )")
# HTML tags: detects and creates closing tag (e.g., "<div>" -> "<div>" and "</div>")
# Multi char: mirrors or reverses brackets (e.g., "{ " -> "{ " and " }")
get_surround_pair() {
  local input="$1"

  # Single character: use pair mapping
  if [[ ${#input} -eq 1 ]]; then
    case "$input" in
      '('|')') echo "(|)" ;;
      '{'|'}') echo "{|}" ;;
      '['|']') echo "[|]" ;;
      '<'|'>') echo "<|>" ;;
      *) echo "$input|$input" ;;
    esac
    return
  fi

  # HTML/XML tag: <tagname> or <tagname attr="value">
  if [[ "$input" =~ ^\ *\<([a-zA-Z][a-zA-Z0-9:-]*).*\>\ *$ ]]; then
    local tag_name="${BASH_REMATCH[1]}"
    echo "$input|</$tag_name>"
    return
  fi

  # Multi-character: reverse brackets in closing
  local closing="$input"
  closing="${closing//\{/\}}"
  closing="${closing//\(/\)}"
  closing="${closing//\[/\]}"
  closing="${closing//</\>}"
  # Reverse the string for closing
  closing=$(echo "$closing" | rev)

  echo "$input|$closing"
}

################################################################################
# Main Logic
################################################################################

# Get original window
ORIGINAL_WINDOW=$(hyprctl activewindow -j | jq -r '.address')

# Get selected text (or select word if nothing selected)
SELECTED=$(get_selection --select-word) || {
  log_debug "No text selected"
  return_to_normal
  exit 0
}

log_debug "Selected: '$SELECTED'"

# Select the word in the window (viw motion)
log_debug "Selecting word (viw) in window $ORIGINAL_WINDOW..."
hyprctl dispatch sendshortcut CTRL, LEFT, "address:$ORIGINAL_WINDOW" >/dev/null 2>&1
sleep 0.05
hyprctl dispatch sendshortcut CTRL+SHIFT, RIGHT, "address:$ORIGINAL_WINDOW" >/dev/null 2>&1
sleep 0.05

# Exit vim mode for prompt
exit_vim_mode

# Prompt for surround characters
INPUT=$(get_user_input "Surround with:" "hyprvim-surround" "Enter character(s)")

# Return to NORMAL mode
return_to_normal

# If empty or cancelled, abort
if [[ -z "$INPUT" ]]; then
  log_debug "No input provided"
  exit 0
fi

# Get surround pair (delimiter: |)
IFS='|' read -r OPEN CLOSE <<< "$(get_surround_pair "$INPUT")"

# Build wrapped text
WRAPPED="${OPEN}${SELECTED}${CLOSE}"

log_debug "Surrounding with '$OPEN' ... '$CLOSE'"

# Paste (replaces the already-selected word)
paste_to_window "$WRAPPED" "address:$ORIGINAL_WINDOW"

# Return to NORMAL mode
return_to_normal

log_debug "Complete"
