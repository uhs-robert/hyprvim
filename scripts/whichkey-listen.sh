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
#   whichkey-listen.sh       - Start daemon (auto-exits if already running)
#
# Environment Variables:
#   EWW_DIR                  - Path to eww configuration directory
#   RENDER                   - Path to whichkey-render.sh
#   DEBOUNCE_MS              - Debounce delay in milliseconds (default: 35)
#   WHICHKEY_SHOW_DELAY_MS   - Delay before showing HUD in milliseconds (default: 100)
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
RENDER_TOKEN_FILE="$STATE_DIR/whichkey-render-token"
MONITOR_PID_FILE="$STATE_DIR/whichkey-monitor.pid"
PENDING_RENDER_PID_FILE="$STATE_DIR/whichkey-pending-render.pid"
DEBOUNCE_MS="${DEBOUNCE_MS:-35}"
WHICHKEY_SHOW_DELAY_MS="${WHICHKEY_SHOW_DELAY_MS:-100}"

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
trap 'kill_keypress_monitor 2>/dev/null || true; kill_pending_render 2>/dev/null || true; rm -f "$PID_FILE" "$RENDER_TOKEN_FILE"' EXIT

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
# Per-Submap Keypress Monitor
################################################################################
# A one-shot libinput process is started each time a submap is entered. It
# waits for the first keypress, cancels any pending delayed render, hides the
# HUD, then exits. The monitor is also killed explicitly when the submap resets
# or a new submap fires. This way libinput only runs while a submap is active.
################################################################################

kill_keypress_monitor() {
  [[ -f "$MONITOR_PID_FILE" ]] || return 0
  local pid
  pid=$(cat "$MONITOR_PID_FILE" 2>/dev/null || echo "")
  rm -f "$MONITOR_PID_FILE"
  [[ -z "$pid" ]] && return 0
  pkill -P "$pid" 2>/dev/null || true
  kill "$pid" 2>/dev/null || true
}

kill_pending_render() {
  [[ -f "$PENDING_RENDER_PID_FILE" ]] || return 0
  local pid
  pid=$(cat "$PENDING_RENDER_PID_FILE" 2>/dev/null || echo "")
  rm -f "$PENDING_RENDER_PID_FILE"
  [[ -z "$pid" ]] && return 0
  pkill -P "$pid" 2>/dev/null || true
  kill "$pid" 2>/dev/null || true
}

start_keypress_monitor() {
  kill_keypress_monitor
  (
    _pipe=$(mktemp -u)
    mkfifo "$_pipe"
    trap 'rm -f "$_pipe"; pkill -P $BASHPID 2>/dev/null || true' EXIT INT TERM
    stdbuf -oL libinput debug-events 2>&1 |
      grep --line-buffered -m1 -E 'KEYBOARD_KEY.*pressed' >"$_pipe" &
    # Only act on a real keypress (read returns 0); EOF from being killed returns 1
    IFS= read -r _ <"$_pipe" && {
      echo "cancelled" >"$RENDER_TOKEN_FILE" 2>/dev/null || true
      "$RENDER" "hide" >/dev/null 2>&1 || true
    }
  ) &
  echo $! >"$MONITOR_PID_FILE"
}

################################################################################
# Main Event Loop
################################################################################

last="__init__"
_wk_token=0
echo "$_wk_token" >"$RENDER_TOKEN_FILE"

socat - "UNIX-CONNECT:$SOCK" | while IFS= read -r line; do
  case "$line" in
  submap\>\>*)
    sm="${line#submap>>}"

    # Normalize reset-ish values
    [[ "$sm" == "reset" || -z "$sm" ]] && sm=""

    # Skip redundant updates
    [[ "$sm" == "$last" ]] && continue
    last="$sm"

    # Hard-cancel any in-flight delayed render job from the previous submap.
    # This is the primary guard against stale HUDs — the token check is belt-and-suspenders.
    kill_pending_render

    # Advance token IMMEDIATELY — must happen before any IPC calls.
    # screen_id (hyprctl + jq) takes ~20ms; if it ran first, an in-flight render
    # could complete and pass the late-stage token check during that window.
    _wk_token=$((_wk_token + 1))
    echo "$_wk_token" >"$RENDER_TOKEN_FILE"
    _my_token="$_wk_token"

    # Track current submap immediately so --info always reflects actual state,
    # regardless of whether the HUD has rendered yet
    if [[ -n "$sm" ]]; then
      echo "$sm" >"$STATE_DIR/current-submap"
    else
      rm -f "$STATE_DIR/current-submap"
    fi

    # Read and clear one-shot opts set via: $HYPRVIM_WHICH_KEY -s -d <ms>
    _skip_next=0
    _next_delay=""
    if [[ -f "$STATE_DIR/whichkey-skip-next" ]]; then
      _skip_next=1
      rm -f "$STATE_DIR/whichkey-skip-next"
    fi
    if [[ -f "$STATE_DIR/whichkey-next-delay" ]]; then
      _next_delay=$(cat "$STATE_DIR/whichkey-next-delay" 2>/dev/null || echo "")
      rm -f "$STATE_DIR/whichkey-next-delay"
    fi

    if [[ "$sm" == "NORMAL" ]]; then
      kill_keypress_monitor
      "$RENDER" "hide" >/dev/null 2>&1 || true # no HUD for NORMAL mode; dismiss any prior
    elif [[ -n "$sm" ]]; then
      if [[ "$_skip_next" -eq 1 ]]; then
        kill_keypress_monitor                    # no HUD for this entry, no monitor needed
        "$RENDER" "hide" >/dev/null 2>&1 || true # dismiss any prior HUD
      else
        # Capture focused monitor now (token already updated; this is still well before
        # the render delay fires, so focus shouldn't have changed)
        # Use monitor name (e.g. "eDP-2") because eww --screen accepts names and it's unambiguous
        screen_id="$(hyprctl -j monitors | jq -r '.[] | select(.focused) | .name' 2>/dev/null || echo "")"
        # Resolve delay in ms (use one-shot override if set, else global setting)
        _show_delay_ms="${WHICHKEY_SHOW_DELAY_MS}"
        [[ -n "$_next_delay" ]] && _show_delay_ms="$_next_delay"
        # Floor: DEBOUNCE_MS * 2. First DEBOUNCE_MS lets the next event be
        # processed; second covers token file write completing before the render
        # fires. Raise DEBOUNCE_MS if stale HUDs still appear.
        _floor_ms=$((DEBOUNCE_MS * 2))
        ((_show_delay_ms < _floor_ms)) && _show_delay_ms="$_floor_ms"
        _show_delay=$(awk "BEGIN {printf \"%.3f\", ${_show_delay_ms} / 1000}")
        # Start monitor before the delayed render so it is already listening
        # by the time the HUD appears (covers the delay=0 case too)
        start_keypress_monitor
        (
          sleep "$_show_delay"
          [[ "$(cat "$RENDER_TOKEN_FILE" 2>/dev/null)" == "$_my_token" ]] || exit 0
          "$RENDER" "$sm" "$screen_id" "$_my_token" || true
        ) &
        echo $! >"$PENDING_RENDER_PID_FILE"
      fi
    else
      # Empty submap — kill monitor and immediately hide (screen_id not needed for hide)
      kill_keypress_monitor
      "$RENDER" "" >/dev/null 2>&1 || true
    fi

    # Debounce to avoid flicker on rapid transitions
    usleep "$((DEBOUNCE_MS * 1000))" 2>/dev/null || sleep 0.03
    ;;
  esac
done
