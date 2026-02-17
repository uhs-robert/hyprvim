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
#   WHICHKEY_SHOW_DELAY   - Delay before showing HUD in seconds (default: 0.2)
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
KEYPRESS_PIPE="$STATE_DIR/whichkey-keypress.fifo"
DEBOUNCE_MS="${DEBOUNCE_MS:-35}"
WHICHKEY_SHOW_DELAY="${WHICHKEY_SHOW_DELAY:-0.2}"

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
trap 'exec 3>&- 2>/dev/null; rm -f "$PID_FILE" "$RENDER_TOKEN_FILE" "$KEYPRESS_PIPE"' EXIT

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
# Persistent Keypress Monitor
################################################################################
# A single libinput process runs for the lifetime of the daemon. Because it is
# already running when a submap event arrives, there is zero startup latency and
# the first keypress after entering any submap is always caught.
#
# fd 3 holds the write end of the FIFO open so the reader loop never sees EOF
# when the libinput pipeline is restarted after an unexpected exit.
################################################################################

rm -f "$KEYPRESS_PIPE"
mkfifo "$KEYPRESS_PIPE"
exec 3<>"$KEYPRESS_PIPE" # keepalive: prevents reader from getting EOF on libinput restart

# Reader: on any keypress, cancel any pending delayed render and hide the HUD.
# render "hide" is only called when something might actually be visible
# (token is an integer, meaning a render is pending or the HUD is showing).
(
  while IFS= read -r _; do
    prior=$(cat "$RENDER_TOKEN_FILE" 2>/dev/null || echo "cancelled")
    [[ "$prior" == "cancelled" ]] && continue
    echo "cancelled" >"$RENDER_TOKEN_FILE" 2>/dev/null || true
    "$RENDER" "hide" >/dev/null 2>&1 || true
  done <"$KEYPRESS_PIPE"
) &

# Writer: feed libinput keypress events into the FIFO; restart on failure.
(
  while true; do
    stdbuf -oL libinput debug-events 2>&1 |
      grep --line-buffered -E 'KEYBOARD_KEY.*pressed' \
        >"$KEYPRESS_PIPE" || true
    sleep 0.5
  done
) &

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

    # Capture focused monitor immediately, before any delays, to avoid race conditions
    # Use monitor name (e.g. "eDP-2") because eww --screen accepts names and it's unambiguous
    screen_id="$(hyprctl -j monitors | jq -r '.[] | select(.focused) | .name' 2>/dev/null || echo "")"

    # Advance token — invalidates any in-flight delayed render
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

    if [[ "$sm" == "NORMAL" ]]; then
      : # state saved above; no HUD for NORMAL mode
    elif [[ -n "$sm" ]]; then
      # Delay before showing HUD — the persistent keypress monitor will write
      # "cancelled" to the token file if any key is pressed during the delay
      (
        sleep "$WHICHKEY_SHOW_DELAY"
        [[ "$(cat "$RENDER_TOKEN_FILE" 2>/dev/null)" == "$_my_token" ]] || exit 0
        "$RENDER" "$sm" "$screen_id" || true
      ) &
    else
      # Empty submap — immediately hide, no delay needed
      "$RENDER" "$sm" "$screen_id" || true
    fi

    # Debounce to avoid flicker on rapid transitions
    usleep "$((DEBOUNCE_MS * 1000))" 2>/dev/null || sleep 0.03
    ;;
  esac
done
