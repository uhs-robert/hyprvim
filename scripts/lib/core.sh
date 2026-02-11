#!/bin/bash
# hypr/.config/hypr/hyprvim/scripts/lib/core.sh
################################################################################
# Core utility functions for HyprVim scripts
################################################################################
#
# Provides: Environment setup, logging, dependency checking, initialization
#
################################################################################

set -euo pipefail

################################################################################
# Environment Setup
################################################################################

# Default state directory
export HYPRVIM_STATE_DIR="${XDG_RUNTIME_DIR:-/tmp}/hyprvim"
mkdir -p "$HYPRVIM_STATE_DIR"

# Debug flag (can be overridden per-script)
export HYPRVIM_DEBUG="${HYPRVIM_DEBUG:-0}"

################################################################################
# Logging Functions
################################################################################

# Log debug message if HYPRVIM_DEBUG=1
# Usage: log_debug "message"
log_debug() {
  if [ "${HYPRVIM_DEBUG:-0}" = "1" ]; then
    logger -t "hyprvim-${SCRIPT_NAME:-unknown}" "$*"
  fi
}

# Log error message
# Usage: log_error "error message"
log_error() {
  logger -t "hyprvim-${SCRIPT_NAME:-unknown}" "ERROR: $*" >&2
}

################################################################################
# Dependency Checking
################################################################################

# Check for required commands and exit with notification if missing
# Usage: require_cmd command1 command2 ...
require_cmd() {
  local cmd
  for cmd in "$@"; do
    if ! command -v "$cmd" &>/dev/null; then
      notify-send "HyprVim" "Missing dependency: $cmd" 2>/dev/null || true
      log_error "Missing required command: $cmd"
      hyprctl dispatch submap NORMAL 2>/dev/null || true
      exit 1
    fi
  done
}

################################################################################
# Script Initialization
################################################################################

# Initialize script environment
# Usage: init_script "script-name"
# Sets SCRIPT_NAME and creates state directory
init_script() {
  export SCRIPT_NAME="${1:-hyprvim}"
  mkdir -p "$HYPRVIM_STATE_DIR"
  log_debug "Initialized script: $SCRIPT_NAME"
}

################################################################################
# Sleep and Timing
################################################################################

# Sleep with debug logging
# Usage: sleep_with_debug 0.15
sleep_with_debug() {
  local duration="$1"
  log_debug "sleep ${duration}s"
  sleep "$duration"
}

################################################################################
# Export Functions
################################################################################

export -f log_debug
export -f log_error
export -f require_cmd
export -f init_script
export -f sleep_with_debug
