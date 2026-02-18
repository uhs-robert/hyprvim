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
#   DEBOUNCE_MS              - Minimum render delay floor = DEBOUNCE_MS * 2 (default: 35)
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
PENDING_FLAG_FILE="$STATE_DIR/whichkey-pending"
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
trap 'kill_keypress_monitor 2>/dev/null || true; kill_pending_render 2>/dev/null || true; rm -f "$PID_FILE" "$RENDER_TOKEN_FILE" "$MONITOR_PID_FILE" "$PENDING_RENDER_PID_FILE" "$PENDING_FLAG_FILE" "$STATE_DIR/current-submap" "$STATE_DIR/whichkey-skip-next" "$STATE_DIR/whichkey-skip-target"' EXIT

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
# Keypress Monitor
################################################################################
# A single persistent libinput reader runs for the lifetime of the daemon.
# On any keypress it calls cancel_and_hide(), which kills the pending render,
# clears the pending flag, bumps the token, and hides the HUD — but only when
# a submap is actually active (current-submap file exists).
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

keypress_monitor_running() {
  [[ -f "$MONITOR_PID_FILE" ]] || return 1
  local pid
  pid="$(cat "$MONITOR_PID_FILE" 2>/dev/null || echo "")"
  [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null
}

kill_pending_render() {
  rm -f "$PENDING_FLAG_FILE"
  [[ -f "$PENDING_RENDER_PID_FILE" ]] || return 0
  local pid
  pid=$(cat "$PENDING_RENDER_PID_FILE" 2>/dev/null || echo "")
  rm -f "$PENDING_RENDER_PID_FILE"
  [[ -z "$pid" ]] && return 0
  pkill -P "$pid" 2>/dev/null || true
  kill "$pid" 2>/dev/null || true
}

# Atomic token write: write to a temp file then rename (mv is atomic on the
# same filesystem). This avoids any partial-read window during truncate+write.
write_token() {
  local tmp="$RENDER_TOKEN_FILE.$$.$RANDOM"
  printf '%s\n' "$1" >"$tmp" && mv -f "$tmp" "$RENDER_TOKEN_FILE"
}

read_token() {
  cat "$RENDER_TOKEN_FILE" 2>/dev/null || echo 0
}

read_submap() {
  cat "$STATE_DIR/current-submap" 2>/dev/null || echo ""
}

LOCK_FILE="$STATE_DIR/whichkey.lock"

with_lock() {
  flock -x 9
}

cancel_and_hide() {
  # Only act when a submap is active; prevents constant hiding in NORMAL/idle
  [[ -f "$STATE_DIR/current-submap" ]] || return 0

  with_lock 9

  if [[ -f "$PENDING_RENDER_PID_FILE" ]]; then
    local _pr_pid
    _pr_pid="$(cat "$PENDING_RENDER_PID_FILE" 2>/dev/null || echo "")"
    rm -f "$PENDING_RENDER_PID_FILE"
    [[ -n "$_pr_pid" ]] && { pkill -P "$_pr_pid" 2>/dev/null || true; kill "$_pr_pid" 2>/dev/null || true; }
  fi

  rm -f "$PENDING_FLAG_FILE"

  local tok
  tok=$(( $(read_token) + 1 ))
  write_token "$tok" 2>/dev/null || true
  "$RENDER" "hide" >/dev/null 2>&1 || true
}

start_keypress_monitor() {
  kill_keypress_monitor
  (
    set +e
    set +o pipefail

    # Keep fd 9 open so cancel_and_hide() can flock against it
    exec 9>"$LOCK_FILE"

    stdbuf -oL -eL libinput debug-events 2>/dev/null \
      | while IFS= read -r line; do
          [[ "$line" == *KEYBOARD_KEY* && "$line" == *pressed* ]] || continue
          cancel_and_hide
        done
  ) &
  echo $! >"$MONITOR_PID_FILE"
}

################################################################################
# Main Event Loop
################################################################################

last="__init__"
_wk_token=0
write_token "$_wk_token"

# Start the persistent keypress monitor once for the daemon's lifetime
start_keypress_monitor

socat - "UNIX-CONNECT:$SOCK" | while IFS= read -r line; do
  case "$line" in
  submap\>\>*)
    sm="${line#submap>>}"

    # Normalize reset-ish values
    [[ "$sm" == "reset" || -z "$sm" ]] && sm=""

    # Skip redundant updates — but always cancel/hide on repeated NORMAL/reset
    # so Hyprland duplicate events don't leave a stale HUD or pending render.
    if [[ "$sm" == "$last" ]]; then
      if [[ -z "$sm" || "$sm" == "NORMAL" ]]; then
        kill_pending_render
        "$RENDER" "hide" >/dev/null 2>&1 || true
      fi
      continue
    fi
    last="$sm"

    # Hard-cancel any in-flight delayed render job from the previous submap.
    # This is the primary guard against stale HUDs — the token check is belt-and-suspenders.
    kill_pending_render

    # Advance token IMMEDIATELY — must happen before any IPC calls.
    # screen_id (hyprctl + jq) takes ~20ms; if it ran first, an in-flight render
    # could complete and pass the late-stage token check during that window.
    _wk_token=$((_wk_token + 1))
    write_token "$_wk_token"
    _my_token="$_wk_token"

    # Track current submap immediately so --info always reflects actual state,
    # regardless of whether the HUD has rendered yet
    if [[ -n "$sm" ]]; then
      echo "$sm" >"$STATE_DIR/current-submap"
    else
      rm -f "$STATE_DIR/current-submap"
    fi

    # Read one-shot opts set via: $HYPRVIM_WHICH_KEY --skip[=TARGET] -d <ms>
    # Targeted skips (--skip=TARGET) are preserved across non-matching events and only
    # consumed when the named submap arrives. Non-targeted skips apply to the first event.
    _skip_next=0
    _skip_target=""
    _next_delay=""
    if [[ -f "$STATE_DIR/whichkey-skip-next" ]]; then
      _skip_next=1
      _skip_target="$(cat "$STATE_DIR/whichkey-skip-target" 2>/dev/null || echo "")"
      # Non-targeted skip: consume immediately so the first event wins (legacy behavior)
      [[ -z "$_skip_target" ]] && rm -f "$STATE_DIR/whichkey-skip-next"
    fi
    if [[ -f "$STATE_DIR/whichkey-next-delay" ]]; then
      _next_delay=$(cat "$STATE_DIR/whichkey-next-delay" 2>/dev/null || echo "")
      rm -f "$STATE_DIR/whichkey-next-delay"
    fi

    if [[ "$sm" == "NORMAL" ]]; then
      rm -f "$STATE_DIR/whichkey-skip-next" "$STATE_DIR/whichkey-skip-target"
      "$RENDER" "hide" >/dev/null 2>&1 || true # no HUD for NORMAL mode; dismiss any prior
    elif [[ -n "$sm" ]]; then
      # Determine if the skip applies to this submap:
      # - non-targeted skip (_skip_target=""): always applies (file already consumed on read)
      # - targeted skip: only applies when sm matches target; otherwise files survive for next event
      _skip_applies=0
      if [[ "$_skip_next" -eq 1 ]]; then
        if [[ -z "$_skip_target" || "$_skip_target" == "$sm" ]]; then
          rm -f "$STATE_DIR/whichkey-skip-next" "$STATE_DIR/whichkey-skip-target"
          _skip_applies=1
        fi
      fi
      if [[ "$_skip_applies" -eq 1 ]]; then
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
        # Mark pending BEFORE launching the job — closes the race window where
        # a keypress arrives before the flag is written.
        echo 1 >"$PENDING_FLAG_FILE"
        (
          sleep "$_show_delay"
          [[ "$(read_token)" == "$_my_token" ]] || exit 0
          # If keypress already cleared the flag, don't show a stale HUD
          [[ -f "$PENDING_FLAG_FILE" ]] || exit 0
          rm -f "$PENDING_FLAG_FILE"
          "$RENDER" "$sm" "$screen_id" "$_my_token" || true
        ) &
        echo $! >"$PENDING_RENDER_PID_FILE"
      fi
    else
      # Empty submap — immediately hide (screen_id not needed for hide)
      rm -f "$STATE_DIR/whichkey-skip-next" "$STATE_DIR/whichkey-skip-target"
      "$RENDER" "" >/dev/null 2>&1 || true
    fi

    ;;
  esac
done
