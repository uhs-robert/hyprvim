#!/usr/bin/env bash
# scripts/whichkey-listen.sh
set -euo pipefail

EWW_DIR="${EWW_DIR:-$HOME/.config/hypr/hyprvim/eww/whichkey}"
RENDER="${RENDER:-$HOME/.config/hypr/hyprvim/scripts/whichkey-render.sh}"
SETTINGS_FILE="${HOME}/.config/hypr/hyprvim/settings.conf"
STATE_DIR="${XDG_RUNTIME_DIR:-/tmp}/hyprvim"
PID_FILE="$STATE_DIR/whichkey-listen.pid"

mkdir -p "$STATE_DIR"

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
trap 'rm -f "$PID_FILE"' EXIT

# Check if which-key is enabled - exit early if not
if [[ -f "$SETTINGS_FILE" ]]; then
  ENABLED=$(grep -E '^\$HYPRVIM_WHICH_KEY_ENABLED\s*=' "$SETTINGS_FILE" 2>/dev/null | sed 's/.*=\s*\(.*\)\s*$/\1/' | tr -d ' ' || echo "")
  [[ "$ENABLED" != "1" ]] && exit 0
fi

# Read position setting once at startup and export for render script
export HYPRVIM_WHICH_KEY_POSITION="${HYPRVIM_WHICH_KEY_POSITION:-bottom-right}"
if [[ -f "$SETTINGS_FILE" ]]; then
  POSITION=$(grep -E '^\$HYPRVIM_WHICH_KEY_POSITION\s*=' "$SETTINGS_FILE" 2>/dev/null | sed 's/.*=\s*\(.*\)\s*$/\1/' | tr -d ' ' || echo "")
  [[ -n "$POSITION" ]] && export HYPRVIM_WHICH_KEY_POSITION="$POSITION"
fi

# Hyprland socket2 path
XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"

# Auto-detect Hyprland instance if not set
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

# Optional: debounce updates (ms) to avoid flicker on rapid transitions
DEBOUNCE_MS="${DEBOUNCE_MS:-35}"

# Keep last submap to avoid redundant work
last="__init__"

socat - "UNIX-CONNECT:$SOCK" | while IFS= read -r line; do
  # Events look like: "submap>>NAME"
  case "$line" in
  submap\>\>*)
    sm="${line#submap>>}"
    # Normalize reset-ish values
    [[ "$sm" == "reset" || -z "$sm" ]] && sm=""
    [[ "$sm" == "$last" ]] && continue
    last="$sm"

    "$RENDER" "$sm" || true
    # tiny debounce
    usleep "$((DEBOUNCE_MS * 1000))" 2>/dev/null || sleep 0.03
    ;;
  esac
done
