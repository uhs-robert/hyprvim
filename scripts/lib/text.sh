#!/bin/bash
# hypr/.config/hypr/hyprvim/scripts/lib/text.sh
################################################################################
# Text utility functions for HyprVim scripts
################################################################################
#
# Provides: Text manipulation and sanitization
#
################################################################################

set -euo pipefail

################################################################################
# Text Helpers
################################################################################

# Remove newlines and trailing whitespace from text
# Usage: sanitize_text "text with\nnewlines  "
sanitize_text() {
  local text="$1"
  printf "%s" "$text" | tr -d '\n' | sed 's/[[:space:]]*$//'
}

# Extract the first word from text
# Usage: first_word "hello world"
first_word() {
  local text="$1"
  text=$(echo "$text" | tr '\n' ' ' | sed 's/[[:space:]]\+/ /g; s/^ //; s/ $//')
  echo "${text%% *}"
}

################################################################################
# Export Functions
################################################################################

export -f sanitize_text
export -f first_word
