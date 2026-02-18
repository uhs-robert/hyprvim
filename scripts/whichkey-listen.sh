#!/usr/bin/env bash
# hypr/.config/hypr/hyprvim/scripts/whichkey-listen.sh
################################################################################
# whichkey-listen.sh - Monitor Hyprland submaps and show which-key HUD
################################################################################
#
# This daemon listens to Hyprland's socket2 for submap change events and
# automatically renders the which-key HUD for transient/menu submaps.
# Sticky/movement submaps (NORMAL, VISUAL, *RESIZE*, etc.) never auto-show.
# Manual toggle is available via: whichkey-render.sh info
#
# Usage:
#   whichkey-listen.sh       - Start daemon (auto-exits if already running)
#
# Environment Variables:
#   EWW_DIR                           - Path to eww configuration directory
#   RENDER                            - Path to whichkey-render.sh
#   WHICHKEY_SHOW_DELAY_MS            - Delay before showing HUD in milliseconds (default: 100)
#   HYPRVIM_WHICHKEY_AUTO_SHOW_ALLOW  - CSV allowlist: only these submaps auto-show
#   HYPRVIM_WHICHKEY_AUTO_SHOW_DENY   - CSV denylist: these submaps never auto-show
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
PENDING_RENDER_PID_FILE="$STATE_DIR/whichkey-pending-render.pid"
WHICHKEY_SHOW_DELAY_MS="${WHICHKEY_SHOW_DELAY_MS:-100}"

mkdir -p "$STATE_DIR"

################################################################################
# Singleton Check
################################################################################

if [[ -f "$PID_FILE" ]]; then
  OLD_PID=$(cat "$PID_FILE")
  if kill -0 "$OLD_PID" 2>/dev/null; then
    exit 0 # Already running
  fi
fi

echo $$ >"$PID_FILE"

trap 'kill_pending_render 2>/dev/null || true; rm -f "$PID_FILE" "$RENDER_TOKEN_FILE" "$PENDING_RENDER_PID_FILE" "$STATE_DIR/current-submap" "$STATE_DIR/whichkey-skip-next" "$STATE_DIR/whichkey-skip-target" "$STATE_DIR/whichkey-visible"' EXIT

################################################################################
# Settings and Initialization
################################################################################

if [[ -f "$SETTINGS_FILE" ]]; then
  ENABLED=$(grep -E '^\$HYPRVIM_WHICH_KEY_ENABLED\s*=' "$SETTINGS_FILE" 2>/dev/null | sed 's/.*=\s*\(.*\)\s*$/\1/' | tr -d ' ' || echo "")
  [[ "$ENABLED" != "1" ]] && exit 0
fi

export HYPRVIM_WHICH_KEY_POSITION="${HYPRVIM_WHICH_KEY_POSITION:-bottom-right}"
# ALLOW/DENY arrive as env vars injected by Hyprland via $HYPRVIM_WHICH_KEY_LISTENER in init.conf
HYPRVIM_WHICHKEY_AUTO_SHOW_ALLOW="${HYPRVIM_WHICHKEY_AUTO_SHOW_ALLOW:-}"
HYPRVIM_WHICHKEY_AUTO_SHOW_DENY="${HYPRVIM_WHICHKEY_AUTO_SHOW_DENY:-}"
if [[ -f "$SETTINGS_FILE" ]]; then
  POSITION=$(grep -E '^\$HYPRVIM_WHICH_KEY_POSITION\s*=' "$SETTINGS_FILE" 2>/dev/null | sed 's/.*=\s*\(.*\)\s*$/\1/' | tr -d ' ' || echo "")
  [[ -n "$POSITION" ]] && export HYPRVIM_WHICH_KEY_POSITION="$POSITION"
fi

XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"

if [[ -z "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
  HYPRLAND_INSTANCE_SIGNATURE=$(hyprctl instances -j 2>/dev/null | jq -r '.[0].instance' 2>/dev/null || echo "")
  if [[ -z "$HYPRLAND_INSTANCE_SIGNATURE" ]]; then
    echo "Error: Could not detect HYPRLAND_INSTANCE_SIGNATURE" >&2
    exit 1
  fi
fi

SOCK="$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"

APPLY_THEME="${HOME}/.config/hypr/hyprvim/scripts/apply-theme.sh"
[[ -x "$APPLY_THEME" ]] && "$APPLY_THEME" >/dev/null 2>&1 || true

eww -c "$EWW_DIR" daemon >/dev/null 2>&1 || true

################################################################################
# Pending Render Management
################################################################################

kill_pending_render() {
  [[ -f "$PENDING_RENDER_PID_FILE" ]] || return 0
  local pid
  pid="$(cat "$PENDING_RENDER_PID_FILE" 2>/dev/null || echo "")"
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

################################################################################
# Auto-Show Policy
################################################################################

# is_in_csv <value> <csv>  — returns 0 if value is an exact match in the CSV list
is_in_csv() {
  local val="$1" csv="$2" entry
  IFS=',' read -ra _entries <<<"$csv"
  for entry in "${_entries[@]}"; do
    entry="${entry// /}" # strip spaces
    [[ "$entry" == "$val" ]] && return 0
  done
  return 1
}

# is_sticky_submap <sm> — built-in deny list for movement/sticky submaps
is_sticky_submap() {
  local sm="${1,,}"
  case "$sm" in
  normal | visual | v-line) return 0 ;;
  esac
  return 1
}

# should_auto_show <sm>  — applies allow/deny precedence rules
# 1. DENY list wins over everything (explicit deny)
# 2. ALLOW list bypasses the built-in sticky check (force-show even if sticky)
# 3. Fallback: built-in sticky matcher (sticky = no auto-show)
should_auto_show() {
  local sm="$1"
  local _deny="${HYPRVIM_WHICHKEY_AUTO_SHOW_DENY:-}"
  local _allow="${HYPRVIM_WHICHKEY_AUTO_SHOW_ALLOW:-}"

  if [[ -n "$_deny" ]] && is_in_csv "$sm" "$_deny"; then
    return 1
  fi

  if [[ -n "$_allow" ]] && is_in_csv "$sm" "$_allow"; then
    return 0
  fi

  is_sticky_submap "$sm" && return 1 || return 0
}

################################################################################
# Main Event Loop
################################################################################

last="__init__"
_wk_token=0
write_token "$_wk_token"

socat - "UNIX-CONNECT:$SOCK" | while IFS= read -r line; do
  case "$line" in
  submap\>\>*)
    sm="${line#submap>>}"

    # Normalize reset-ish values
    [[ "$sm" == "reset" || -z "$sm" ]] && sm=""

    # Skip redundant updates — cancel any pending render but do NOT actively hide.
    # Repeated same-submap events (e.g. NORMAL catchall re-dispatching submap NORMAL
    # on every unbound keypress) must not dismiss a manually-toggled HUD.
    if [[ "$sm" == "$last" ]]; then
      kill_pending_render
      continue
    fi
    last="$sm"

    # Hard-cancel any in-flight delayed render job from the previous submap.
    kill_pending_render

    # Advance token IMMEDIATELY — must happen before any IPC calls.
    _wk_token=$((_wk_token + 1))
    write_token "$_wk_token"
    _my_token="$_wk_token"

    # Always hide existing HUD on any submap change.
    "$RENDER" "hide" >/dev/null 2>&1 || true

    # Track current submap immediately so info/toggle always reflects actual state.
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
      # hide already done above
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
      if [[ "$_skip_applies" -eq 0 ]] && should_auto_show "$sm"; then
        # Capture focused monitor now (token already updated; this is still well before
        # the render delay fires, so focus shouldn't have changed)
        screen_id="$(hyprctl -j monitors | jq -r '.[] | select(.focused) | .name' 2>/dev/null || echo "")"
        # Resolve delay in ms (use one-shot override if set, else global setting)
        _show_delay_ms="${WHICHKEY_SHOW_DELAY_MS}"
        [[ -n "$_next_delay" ]] && _show_delay_ms="$_next_delay"
        _show_delay=$(awk "BEGIN {printf \"%.3f\", ${_show_delay_ms} / 1000}")
        (
          sleep "$_show_delay"
          [[ "$(read_token)" == "$_my_token" ]] || exit 0
          "$RENDER" "$sm" "$screen_id" "$_my_token" || true
        ) &
        echo $! >"$PENDING_RENDER_PID_FILE"
      fi
    else
      # Empty submap — hide already done above
      rm -f "$STATE_DIR/whichkey-skip-next" "$STATE_DIR/whichkey-skip-target"
    fi

    ;;
  esac
done
