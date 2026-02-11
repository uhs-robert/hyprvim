#!/bin/bash
# hypr/.config/hypr/hyprvim/scripts/lib/state.sh
################################################################################
# State management functions for HyprVim scripts
################################################################################
#
# Provides: JSON state management, file utilities
# Dependencies: core.sh (for require_cmd, log_debug)
#
################################################################################

set -euo pipefail

################################################################################
# State Management
################################################################################

# Validate state key is allowed
# Usage: validate_state_key "key_name"
validate_state_key() {
  local key="$1"
  # Allow alphanumeric, underscore, and dash
  if [[ "$key" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    return 0
  else
    log_debug "Invalid state key: '$key'"
    return 1
  fi
}

# Get state value from JSON file
# Usage: get_state "state_file.json" "key" "default_value"
get_state() {
  local state_file="$1"
  local key="$2"
  local default="${3:-}"

  if ! validate_state_key "$key"; then
    echo "$default"
    return 1
  fi

  if [ -f "$state_file" ]; then
    require_cmd jq
    jq -r ".$key // \"$default\"" "$state_file" 2>/dev/null || echo "$default"
  else
    echo "$default"
  fi
}

# Set state value in JSON file
# Usage: set_state "state_file.json" "key" "value"
set_state() {
  local state_file="$1"
  local key="$2"
  local value="$3"

  if ! validate_state_key "$key"; then
    return 1
  fi

  require_cmd jq

  # Initialize state file if it doesn't exist
  if [ ! -f "$state_file" ]; then
    echo '{}' >"$state_file"
  fi

  # Update the key
  jq --arg val "$value" ".$key = \$val" "$state_file" >"${state_file}.tmp" && mv "${state_file}.tmp" "$state_file"
}

################################################################################
# File Management
################################################################################

# Ensure JSON file exists with empty object
# Usage: ensure_json_file "/path/to/file.json"
ensure_json_file() {
  local file="$1"
  if [ ! -f "$file" ]; then
    echo '{}' >"$file"
  fi
}

################################################################################
# Export Functions
################################################################################

export -f validate_state_key
export -f get_state
export -f set_state
export -f ensure_json_file
