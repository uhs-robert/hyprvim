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
#   WHICHKEY_SHOW_DELAY_MS            - Delay before showing HUD in milliseconds (default: 200)
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
FOCUSED_MON_FILE="$STATE_DIR/focused-monitor"
WHICHKEY_SHOW_DELAY_MS="${WHICHKEY_SHOW_DELAY_MS:-200}"

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

trap 'rm -f "$PID_FILE" "$RENDER_TOKEN_FILE" "$FOCUSED_MON_FILE" "$STATE_DIR/current-submap" "$STATE_DIR/whichkey-current-window" "$STATE_DIR/whichkey-skip-next" "$STATE_DIR/whichkey-skip-target" "$STATE_DIR/whichkey-visible"' EXIT

################################################################################
# Settings and Initialization
################################################################################

# Require explicit opt-in ($HYPRVIM_WHICH_KEY_ENABLED = 1 in settings.conf) since eww is an optional dependency.
ENABLED=""
if [[ -f "$SETTINGS_FILE" ]]; then
  ENABLED=$(grep -E '^\$HYPRVIM_WHICH_KEY_ENABLED\s*=' "$SETTINGS_FILE" 2>/dev/null | sed 's/.*=\s*\(.*\)\s*$/\1/' | tr -d ' ' || echo "")
fi
[[ "$ENABLED" != "1" ]] && exit 0

# Position defaults to env var
export HYPRVIM_WHICH_KEY_POSITION="${HYPRVIM_WHICH_KEY_POSITION:-bottom-right}"

# ALLOW/DENY arrive as env vars injected by Hyprland via $HYPRVIM_WHICH_KEY_LISTENER in init.conf
HYPRVIM_WHICHKEY_AUTO_SHOW_ALLOW="${HYPRVIM_WHICHKEY_AUTO_SHOW_ALLOW:-}"
HYPRVIM_WHICHKEY_AUTO_SHOW_DENY="${HYPRVIM_WHICHKEY_AUTO_SHOW_DENY:-}"
if [[ -f "$SETTINGS_FILE" ]]; then
  POSITION=$(grep -E '^\$HYPRVIM_WHICH_KEY_POSITION\s*=' "$SETTINGS_FILE" 2>/dev/null | sed 's/.*=\s*\(.*\)\s*$/\1/' | tr -d ' ' || echo "")
  [[ -n "$POSITION" ]] && export HYPRVIM_WHICH_KEY_POSITION="$POSITION"
fi

# Fallback for environments where XDG_RUNTIME_DIR is unset
XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"

# Auto-detect the running Hyprland instance if not already in the environment
if [[ -z "${HYPRLAND_INSTANCE_SIGNATURE:-}" ]]; then
  HYPRLAND_INSTANCE_SIGNATURE=$(hyprctl instances -j 2>/dev/null | jq -r '.[0].instance' 2>/dev/null || echo "")
  if [[ -z "$HYPRLAND_INSTANCE_SIGNATURE" ]]; then
    echo "Error: Could not detect HYPRLAND_INSTANCE_SIGNATURE" >&2
    exit 1
  fi
fi

# socket2 emits compositor events (submap changes, window focus, etc.)
SOCK="$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"

# Apply theme on daemon start so eww picks up current colors
APPLY_THEME="${HOME}/.config/hypr/hyprvim/scripts/apply-theme.sh"
[[ -x "$APPLY_THEME" ]] && "$APPLY_THEME" >/dev/null 2>&1 || true

# Ensure eww daemon is running before we try to open any windows
eww -c "$EWW_DIR" daemon >/dev/null 2>&1 || true

# Seed focused-monitor cache so the first render doesn't get an empty screen
hyprctl -j monitors 2>/dev/null |
  jq -r '.[] | select(.focused) | .name' 2>/dev/null |
  head -1 >"$FOCUSED_MON_FILE" || true

################################################################################
# Pending Render Management
################################################################################

# Atomic token write: write to a temp file then rename
write_token() {
  local tmp="$RENDER_TOKEN_FILE.$$.$RANDOM"
  printf '%s\n' "$1" >"$tmp" && mv -f "$tmp" "$RENDER_TOKEN_FILE"
}

# Read the current render token else default to 0
read_token() {
  cat "$RENDER_TOKEN_FILE" 2>/dev/null || echo 0
}

################################################################################
# Auto-Show Policy
################################################################################

# is_in_csv <value> <csv> - returns 0 if value is an exact match in the CSV list
is_in_csv() {
  local val="$1" csv="$2" entry
  IFS=',' read -ra _entries <<<"$csv"
  for entry in "${_entries[@]}"; do
    entry="${entry// /}" # strip spaces
    [[ "$entry" == "$val" ]] && return 0
  done
  return 1
}

# is_sticky_submap <sm> - built-in deny list for movement/sticky submaps
is_sticky_submap() {
  local sm="${1,,}"
  case "$sm" in
  normal | visual | v-line) return 0 ;;
  esac
  return 1
}

# requires_show_delay <sm> - operator-pending submaps where a delay prevents the HUD from
# flashing when the user types a motion quickly (e.g. dw, ci", yap, G-prefix, r-char)
requires_show_delay() {
  local sm="$1"
  case "$sm" in
  D-MOTION | D-I | D-A | D-G | \
    C-MOTION | C-I | C-A | C-G | \
    Y-MOTION | Y-I | Y-A | Y-G | \
    G-MOTION | G-VISUAL | R-CHAR) return 0 ;;
  esac
  return 1
}

# should_auto_show <sm> - applies allow/deny precedence rules
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
prev_sm=""
_wk_token=0
write_token "$_wk_token"

socat - "UNIX-CONNECT:$SOCK" | while IFS= read -r line; do
  case "$line" in
  focusedmon\>\>*)
    # focusedmon>>MONITOR,WORKSPACE - keep cache current
    mon="${line#focusedmon>>}"
    mon="${mon%%,*}"
    [[ -n "$mon" ]] && printf '%s\n' "$mon" >"$FOCUSED_MON_FILE"
    ;;
  submap\>\>*)
    sm="${line#submap>>}"

    # Normalize reset-ish values
    [[ "$sm" == "reset" || -z "$sm" ]] && sm=""

    # Skip redundant updates. Duplicate submap event is a no-op.
    if [[ "$sm" == "$last" ]]; then
      continue
    fi
    prev_sm="$last"
    last="$sm"

    # Advance token IMMEDIATELY - must happen before any IPC calls
    _wk_token=$((_wk_token + 1))
    write_token "$_wk_token"
    _my_token="$_wk_token"

    # Close only the currently open window
    rm -f "$STATE_DIR/whichkey-visible"
    _cur_win="$(cat "$STATE_DIR/whichkey-current-window" 2>/dev/null || echo "")"
    if [[ -n "$_cur_win" ]]; then
      eww -c "$EWW_DIR" close "$_cur_win" >/dev/null 2>&1 || true
    else
      eww -c "$EWW_DIR" update visible=false >/dev/null 2>&1 || true
    fi

    # Track current submap immediately so info/toggle always reflects actual state
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
        # Resolve delay in ms: one-shot override wins; operator-pending submaps use the
        # global delay to avoid flashing when the user types a motion quickly; everything
        # else (non-HyprVim submaps, marks, GET-REGISTER) shows instantly.
        if [[ -n "$_next_delay" ]]; then
          _show_delay_ms="$_next_delay"
        elif requires_show_delay "$sm"; then
          _show_delay_ms="${WHICHKEY_SHOW_DELAY_MS}"
          # Chained operator-pending (e.g. C-MOTION -> C-I): the initial delay
          # already guarded against accidental display; show the second hop immediately.
          if [[ -n "$prev_sm" ]] && requires_show_delay "$prev_sm"; then
            _show_delay_ms="0"
          fi
        else
          _show_delay_ms="0"
        fi
        _show_delay=$(awk "BEGIN {printf \"%.3f\", ${_show_delay_ms} / 1000}")
        (
          sleep "$_show_delay"
          [[ "$(read_token)" == "$_my_token" ]] || exit 0
          _screen="$(cat "$FOCUSED_MON_FILE" 2>/dev/null || echo "")"
          "$RENDER" "$sm" "$_screen" "$_my_token" || true
        ) &
      fi
    else
      # Empty submap - hide already done above
      rm -f "$STATE_DIR/whichkey-skip-next" "$STATE_DIR/whichkey-skip-target"
    fi

    ;;
  openwindow\>\>*)
    # Auto-hide the HUD when a new window opens so it doesn't block focus
    if [[ -f "$STATE_DIR/whichkey-visible" ]]; then
      rm -f "$STATE_DIR/whichkey-visible"
      _cur_win="$(cat "$STATE_DIR/whichkey-current-window" 2>/dev/null || echo "")"
      if [[ -n "$_cur_win" ]]; then
        eww -c "$EWW_DIR" close "$_cur_win" >/dev/null 2>&1 || true
      else
        eww -c "$EWW_DIR" update visible=false >/dev/null 2>&1 || true
      fi
    fi
    ;;
  esac
done
