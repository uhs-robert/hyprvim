#!/usr/bin/env bash
# hypr/.config/hypr/hyprvim/scripts/whichkey-listen.sh
################################################################################
# whichkey-listen.sh - Monitor Hyprland submaps and show which-key HUD
################################################################################
#
# This daemon listens to Hyprland's socket2 for submap change events and
# automatically renders the which-key HUD for the active submap. It also
# manages a keyboard monitor that auto-hides the HUD when any key is pressed.
#
# Usage:
#   whichkey-listen.sh    - Start daemon (auto-exits if already running)
#
# Environment Variables:
#   EWW_DIR               - Path to eww configuration directory
#   RENDER                - Path to whichkey-render.sh
#   DEBOUNCE_MS           - Debounce delay in milliseconds (default: 35)
#
################################################################################

set -euo pipefail

################################################################################
# Configuration
################################################################################

export EWW_DIR="${EWW_DIR:-$HOME/.config/hypr/hyprvim/eww/whichkey}"
export RENDER="${RENDER:-$HOME/.config/hypr/hyprvim/scripts/whichkey-render.sh}"

SETTINGS_FILE="${HOME}/.config/hypr/hyprvim/settings.conf"
STATE_DIR="${XDG_RUNTIME_DIR:-/tmp}/hyprvim"
PID_FILE="$STATE_DIR/whichkey-listen.pid"
MONITOR_PID_FILE="$STATE_DIR/whichkey-monitor.pid"
DEBOUNCE_MS="${DEBOUNCE_MS:-35}"

mkdir -p "$STATE_DIR"

################################################################################
# Singleton Check
################################################################################

# Check if already running
if [[ -f "$PID_FILE" ]]; then
  OLD_PID=$(cat "$PID_FILE")
  if kill -0 "$OLD_PID" 2>/dev/null; then
    exit 0 # Already running
  fi
fi

# Write our PID
echo $$ >"$PID_FILE"

# Cleanup on exit
trap 'rm -f "$PID_FILE" "$MONITOR_PID_FILE"' EXIT

################################################################################
# Settings and Initialization
################################################################################

# Check if which-key is enabled
if [[ -f "$SETTINGS_FILE" ]]; then
  ENABLED=$(grep -E '^\$HYPRVIM_WHICH_KEY_ENABLED\s*=' "$SETTINGS_FILE" 2>/dev/null | sed 's/.*=\s*\(.*\)\s*$/\1/' | tr -d ' ' || echo "")
  [[ "$ENABLED" != "1" ]] && exit 0
fi

# Read position setting and export for render script
export HYPRVIM_WHICH_KEY_POSITION="${HYPRVIM_WHICH_KEY_POSITION:-bottom-right}"
if [[ -f "$SETTINGS_FILE" ]]; then
  POSITION=$(grep -E '^\$HYPRVIM_WHICH_KEY_POSITION\s*=' "$SETTINGS_FILE" 2>/dev/null | sed 's/.*=\s*\(.*\)\s*$/\1/' | tr -d ' ' || echo "")
  [[ -n "$POSITION" ]] && export HYPRVIM_WHICH_KEY_POSITION="$POSITION"
fi

# Auto-detect Hyprland instance
XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"

if [[ -z "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
  HYPRLAND_INSTANCE_SIGNATURE=$(hyprctl instances -j 2>/dev/null | jq -r '.[0].instance' 2>/dev/null || echo "")
  if [[ -z "$HYPRLAND_INSTANCE_SIGNATURE" ]]; then
    echo "Error: Could not detect HYPRLAND_INSTANCE_SIGNATURE" >&2
    exit 1
  fi
fi

SOCK="$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"

# Apply theme colors before starting eww
APPLY_THEME="${HOME}/.config/hypr/hyprvim/scripts/apply-theme.sh"
[[ -x "$APPLY_THEME" ]] && "$APPLY_THEME" >/dev/null 2>&1 || true

# Ensure eww daemon is up
eww -c "$EWW_DIR" daemon >/dev/null 2>&1 || true

################################################################################
# Keyboard Monitor Function
################################################################################

start_keyboard_monitor() {
  (
    PIPE=$(mktemp -u)
    mkfifo "$PIPE"
    trap 'rm -f "$PIPE"' EXIT

    # Small delay to avoid catching the key that triggered the submap
    sleep 0.2

    # Persistent monitor: hide which-key on any keypress
    (stdbuf -oL libinput debug-events 2>&1 | grep --line-buffered -E 'KEYBOARD_KEY.*pressed' >"$PIPE") &
    LIBINPUT_PID=$!

    while read -r line <"$PIPE"; do
      "$RENDER" "" >/dev/null 2>&1 || true
    done

    # Cleanup
    pkill -P $LIBINPUT_PID 2>/dev/null || true
    kill $LIBINPUT_PID 2>/dev/null || true
  ) &
  echo $! >"$MONITOR_PID_FILE"
}

################################################################################
# Main Event Loop
################################################################################

last="__init__"

socat - "UNIX-CONNECT:$SOCK" | while IFS= read -r line; do
  case "$line" in
  submap\>\>*)
    sm="${line#submap>>}"

    # Normalize reset-ish values
    [[ "$sm" == "reset" || -z "$sm" ]] && sm=""

    # Skip redundant updates
    [[ "$sm" == "$last" ]] && continue
    last="$sm"

    # Kill any existing keyboard monitor
    if [[ -f "$MONITOR_PID_FILE" ]]; then
      MONITOR_PID=$(cat "$MONITOR_PID_FILE" 2>/dev/null)
      if [[ -n "$MONITOR_PID" ]] && kill -0 "$MONITOR_PID" 2>/dev/null; then
        pkill -P "$MONITOR_PID" 2>/dev/null || true
        pkill -P "$MONITOR_PID" libinput 2>/dev/null || true
        kill -TERM "$MONITOR_PID" 2>/dev/null || true
        sleep 0.05
        kill -KILL "$MONITOR_PID" 2>/dev/null || true
      fi
      rm -f "$MONITOR_PID_FILE"
    fi

    # Handle NORMAL mode: save state but don't auto-render
    if [[ "$sm" == "NORMAL" ]]; then
      echo "NORMAL" >"$STATE_DIR/current-submap"
      # Start keyboard monitor anyway (for manual ? triggers)
      start_keyboard_monitor
    elif [[ -n "$sm" ]]; then
      # Render which-key and start monitor for other submaps
      "$RENDER" "$sm" || true
      start_keyboard_monitor
    else
      # Empty submap - just render (will hide)
      "$RENDER" "$sm" || true
    fi

    # Debounce to avoid flicker on rapid transitions
    usleep "$((DEBOUNCE_MS * 1000))" 2>/dev/null || sleep 0.03
    ;;
  esac
done
