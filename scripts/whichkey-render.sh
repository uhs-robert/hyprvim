#!/usr/bin/env bash
# scripts/whichkey-render.sh
################################################################################
# whichkey-render.sh - Render which-key HUD for active submap
################################################################################
#
# Usage:
#   whichkey-render.sh <submap> [screen] [token]   - Render which-key for given submap
#   whichkey-render.sh ""                          - Hide which-key
#   whichkey-render.sh info                        - Toggle which-key for current submap
#   whichkey-render.sh -c, --close                 - Dismiss which-key if open
#   whichkey-render.sh [-s [TARGET]] [-d <ms>]     - Set one-shot opts for next submap entry
#     -s, --skip [TARGET]   Skip showing HUD for next submap entry (or TARGET-named submap only)
#     --skip=TARGET         Same as --skip TARGET
#     -d, --delay <ms>      Override show delay (ms) for the next submap entry
#
# Environment Variables:
#   EWW_DIR                       - Path to eww configuration directory
#   HYPRVIM_WHICH_KEY_POSITION   - Position: bottom-right, bottom-center, etc.
#
################################################################################

set -euo pipefail

################################################################################
# Configuration
################################################################################

EWW_DIR="${EWW_DIR:-$HOME/.config/hypr/hyprvim/eww/whichkey}"
STATE_DIR="${XDG_RUNTIME_DIR:-/tmp}/hyprvim"
POSITION="${HYPRVIM_WHICH_KEY_POSITION:-bottom-right}"

mkdir -p "$STATE_DIR"

################################################################################
# One-Shot Next-Submap Options
################################################################################
# Flags written to state files are consumed by whichkey-listen.sh on the next
# submap event. Call with only flags (no positional args) to set them.
################################################################################

if [[ "${1:-}" == -* ]]; then
  _write_skip=0
  _write_skip_target=""
  _write_delay=""
  while [[ $# -gt 0 ]]; do
    case "$1" in
    -s | --skip)
      _write_skip=1
      if [[ -n "${2:-}" && "${2:-}" != -* ]]; then
        _write_skip_target="$2"
        shift 2
      else
        shift
      fi
      ;;
    --skip=*)
      _write_skip=1
      _write_skip_target="${1#*=}"
      shift
      ;;
    -d | --delay)
      _write_delay="$2"
      shift 2
      ;;
    --delay=*)
      _write_delay="${1#*=}"
      shift
      ;;
    -c | --close)
      "$0" "hide" >/dev/null 2>&1 || true
      exit 0
      ;;
    *) break ;;
    esac
  done
  [[ "$_write_skip" -eq 1 ]] && touch "$STATE_DIR/whichkey-skip-next"
  [[ -n "${_write_skip_target:-}" ]] && printf '%s\n' "$_write_skip_target" >"$STATE_DIR/whichkey-skip-target"
  [[ -n "$_write_delay" ]] && printf '%s\n' "$_write_delay" >"$STATE_DIR/whichkey-next-delay"
  exit 0
fi

################################################################################
# Info Command - Manual Toggle for Current Submap
################################################################################

if [[ "${1:-}" == "--info" ]] || [[ "${1:-}" == "info" ]]; then
  # Toggle off: if HUD is visible, hide and clear state
  if [[ -f "$STATE_DIR/whichkey-visible" ]]; then
    "$0" "hide" >/dev/null 2>&1 || true
    exit 0
  fi

  # Toggle on: determine target submap
  current_submap=""
  if [[ -f "$STATE_DIR/current-submap" ]]; then
    current_submap=$(cat "$STATE_DIR/current-submap" 2>/dev/null || echo "")
  fi

  # Is global or submap
  if [[ -n "$current_submap" ]] && [[ "$current_submap" != "reset" ]]; then
    target_submap="$current_submap"
  else
    target_submap="GLOBAL"
  fi

  # Query focused monitor
  info_screen="$(hyprctl -j monitors | jq -r '.[] | select(.focused) | .name' 2>/dev/null || echo "")"

  "$0" "$target_submap" "$info_screen" || true
  exit 0
fi

################################################################################
# Submap Processing
################################################################################

submap="${1:-}"
# Monitor name passed from listener (captured at event time to avoid race conditions).
# Falls back to querying focused monitor when called directly.
screen="${2:-}"
# Render token passed from listener background subshell; re-checked before final show
# to abort stale renders that were already in-flight when the submap changed.
render_token="${3:-}"

# Save current submap to state for info command
if [[ -n "$submap" ]] && [[ "$submap" != "reset" ]] && [[ "$submap" != "GLOBAL" ]] && [[ "$submap" != "hide" ]]; then
  echo "$submap" >"$STATE_DIR/current-submap"
elif [[ -z "$submap" ]] || [[ "$submap" == "reset" ]]; then
  rm -f "$STATE_DIR/current-submap"
fi

# Normalize special values to empty for hiding
[[ "$submap" == "reset" ]] && submap=""
[[ "$submap" == "hide" ]] && submap=""

# Hide when no submap (but not GLOBAL)
if [[ -z "$submap" ]]; then
  rm -f "$STATE_DIR/whichkey-visible"
  eww -c "$EWW_DIR" update visible=false >/dev/null 2>&1 || true
  for pos in bottom-right bottom-center top-center bottom-left top-right top-left center; do
    eww -c "$EWW_DIR" close "whichkey-$pos" >/dev/null 2>&1 || true
  done
  exit 0
fi

################################################################################
# Item Builders
################################################################################

# build_mark_items <submap>
# Outputs a JSON items array from live mark state for mark submaps.
# Returns 0 (and prints items) if applicable and marks exist; 1 otherwise.
build_mark_items() {
  local sm="$1"
  local marks_file="${XDG_RUNTIME_DIR:-/tmp}/hyprvim/marks.json"

  [[ "$sm" == "JUMP-MARK" || "$sm" == "SET-MARK" || "$sm" == "DELETE-MARK" ]] || return 1
  [[ -f "$marks_file" ]] || return 1

  local mark_count
  mark_count=$(jq '[to_entries[] | select(.value | type == "object")] | length' "$marks_file" 2>/dev/null || echo 0)
  [[ "$mark_count" -gt 0 ]] || return 1

  jq -c '
    to_entries
    | map(select(.value | type == "object"))
    | map({
        key: .key,
        desc: (
          (.value.class // "?") +
          (if ((.value.title // "") | length) > 0
           then " \u00b7 " + (.value.title | .[0:20])
           else "" end) +
          " [ws:" + (.value.workspace | tostring) + "]"
        ),
        class: ""
      })
    | sort_by(
        if (.key | test("^[a-z]$")) then [0, .key]
        elif (.key | test("^[A-Z]$")) then [1, .key]
        else [2, .key]
        end
      )
  ' "$marks_file" 2>/dev/null
}

# build_register_items <submap>
# Outputs a JSON items array from live register state for GET-REGISTER submap.
# Returns 0 (and prints items) if applicable and registers have content; 1 otherwise.
build_register_items() {
  local sm="$1"
  local registers_dir="${XDG_RUNTIME_DIR:-/tmp}/hyprvim/registers"
  local find_state="${XDG_RUNTIME_DIR:-/tmp}/hyprvim/find-state.json"
  local dq='"'

  [[ "$sm" == "GET-REGISTER" ]] || return 1
  [[ -d "$registers_dir" ]] || return 1

  _reg_read() {
    local f="$1"
    [[ -f "$f" && -s "$f" ]] && head -c 40 "$f" 2>/dev/null | tr '\n\t' '  '
  }

  _reg_item() {
    local key="$1" prefix="$2" content="$3"
    local desc part
    [[ -z "$content" ]] && return 0
    if [[ -n "$prefix" ]]; then
      desc="[$prefix] $content"
    else
      desc="$content"
    fi
    [[ "${#desc}" -gt 45 ]] && desc="${desc:0:42}..."
    part=$(jq -cn --arg k "$key" --arg d "$desc" '{key:$k,desc:$d,class:""}')
    items_json+=("$part")
  }

  local items_json=()
  local n c search_term
  _reg_item "$dq" "default" "$(_reg_read "${registers_dir}/${dq}")"
  _reg_item "0" "yank" "$(_reg_read "$registers_dir/0")"
  for n in 1 2 3 4 5 6 7 8 9; do
    _reg_item "$n" "del" "$(_reg_read "$registers_dir/$n")"
  done
  for c in a b c d e f g h i j k l m n o p q r s t u v w x y z; do
    _reg_item "$c" "" "$(_reg_read "$registers_dir/$c")"
  done
  if [[ -f "$find_state" ]]; then
    search_term=$(jq -r '.find_term // ""' "$find_state" 2>/dev/null || echo "")
    _reg_item "/" "search" "$search_term"
  fi

  [[ "${#items_json[@]}" -gt 0 ]] || return 1
  printf '%s\n' "${items_json[@]}" | jq -sc '.'
}

# build_hyprctl_items <submap>
# Outputs a JSON items array from hyprctl binds. Used as the final fallback.
build_hyprctl_items() {
  local sm="$1"
  hyprctl binds -j |
    jq -c --arg sm "$sm" '
      def normalize_key(key; modmask):
        # Extract modifiers from modmask bitfield
        ((modmask % 2) == 1) as $shift |
        (((modmask / 4 | floor) % 2) == 1) as $ctrl |
        (((modmask / 8 | floor) % 2) == 1) as $alt |
        (((modmask / 64 | floor) % 2) == 1) as $super |

        # Replace special key names with symbols
        (key
          | gsub("SLASH"; "/") | gsub("BACKSLASH"; "\\\\")
          | gsub("COMMA"; ",") | gsub("PERIOD"; ".")
          | gsub("SEMICOLON"; ";") | gsub("APOSTROPHE"; "'\''")
          | gsub("GRAVE"; "`") | gsub("BRACKETLEFT"; "[") | gsub("BRACKETRIGHT"; "]")
          | gsub("MINUS"; "-") | gsub("EQUAL"; "=")
          | gsub("ESCAPE"; "ESC") | gsub("RETURN"; "RET") | gsub("BACKSPACE"; "BS")
          | gsub("tab"; "TAB")
        ) as $k |

        # Determine final key representation
        if (($shift or $ctrl or $alt or $super) | not) then
          # No modifiers: lowercase single letters
          if ($k | test("^[a-zA-Z]$")) then ($k | ascii_downcase) else $k end
        else
          if $shift and (($ctrl or $alt or $super) | not) then
            # Only SHIFT: uppercase letters, shift symbols, or S- prefix
            if ($k | test("^[a-zA-Z]$")) then
              ($k | ascii_upcase)
            else
              # Shift number/symbol translations
              (($k
                | gsub("^1$"; "!") | gsub("^2$"; "@") | gsub("^3$"; "#")
                | gsub("^4$"; "$") | gsub("^5$"; "%") | gsub("^6$"; "^")
                | gsub("^7$"; "&") | gsub("^8$"; "*") | gsub("^9$"; "(")
                | gsub("^0$"; ")") | gsub("^-$"; "_") | gsub("^=$"; "+")
                | gsub("^\\[$"; "{") | gsub("^\\]$"; "}") | gsub("^\\\\$"; "|")
                | gsub("^;$"; ":") | gsub("^,$"; "<")
                | gsub("^\\.$"; ">") | gsub("^/$"; "?")
              ) as $translated
              | if (($translated | test("^[a-zA-Z0-9]$")) | not) and ($translated == $k) then
                  ("S-" + $translated)
                else
                  $translated
                end)
            end
          else
            # Has modifiers: prepend prefixes
            (if $ctrl then "C-" else "" end) +
            (if $alt then "A-" else "" end) +
            (if $super then "M-" else "" end) +
            (if $shift then "S-" else "" end) +
            $k
          end
        end;

      [ .[]
        | select(
            if $sm == "GLOBAL" then
              (.submap // "") == ""
            else
              (.submap // "") == $sm
            end
          )
        | select((.description // "") != "")
        | {
            key: (normalize_key(.key // ""; .modmask // 0)),
            desc: (.description // ""),
            class: (if (.description // "") | startswith("+") then "is-submap" else "" end)
          }
      ]
      # Sort: letters, special chars, modifiers, ESC
      | (map(select(.key == "ESC"))) as $esc
      | (map(select(.key != "ESC" and (.key | test("C-|A-|M-|S-"))))) as $mods
      | (map(select(.key != "ESC" and (.key | test("C-|A-|M-|S-") | not) and (.key | test("^[a-zA-Z]$"))))) as $letters
      | (map(select(.key != "ESC" and (.key | test("C-|A-|M-|S-") | not) and (.key | test("^[a-zA-Z]$") | not)))) as $special
      | ($letters | sort_by(.key | ascii_downcase)) + ($special | sort_by(.key)) + ($mods | sort_by(.key)) + $esc
    '
}

################################################################################
# Build Key Bindings JSON
################################################################################

# Resolve monitor name: use value passed from listener, or query now as fallback
# Monitor name (e.g. "eDP-2", "DP-11") is more reliable than array index for eww --screen
if [[ -z "$screen" ]]; then
  screen="$(hyprctl -j monitors | jq -r '.[] | select(.focused) | .name' 2>/dev/null || echo "")"
fi

# Set title (use friendly name for GLOBAL)
if [[ "$submap" == "GLOBAL" ]]; then
  title="Global Bindings"
else
  title="$submap"
fi

# Get items
items=$(build_mark_items "$submap") ||
  items=$(build_register_items "$submap") ||
  items=$(build_hyprctl_items "$submap")

################################################################################
# Position and Overflow Detection
################################################################################

num_items=$(echo "$items" | jq 'length')

# Hide if no bindings to show
if [[ "$num_items" -eq 0 ]]; then
  eww -c "$EWW_DIR" update visible=false >/dev/null 2>&1 || true
  for pos in bottom-right bottom-center top-center bottom-left top-right top-left center; do
    eww -c "$EWW_DIR" close "whichkey-$pos" >/dev/null 2>&1 || true
  done
  exit 0
fi

# Query monitor dimensions by name (hyprctl reports physical pixels; divide by scale for logical)
monitor_info=$(hyprctl -j monitors | jq -r --arg name "$screen" '.[] | select(.name == $name) | "\(.width)x\(.height)x\(.scale)"' 2>/dev/null || echo "1920x1080x1.0")
monitor_phys_width=$(echo "$monitor_info" | cut -dx -f1)
monitor_phys_height=$(echo "$monitor_info" | cut -dx -f2)
monitor_scale=$(echo "$monitor_info" | cut -dx -f3)
monitor_logical_width=$(echo "$monitor_phys_width $monitor_scale" | awk '{printf "%d", $1 / $2}')
monitor_logical_height=$(echo "$monitor_phys_height $monitor_scale" | awk '{printf "%d", $1 / $2}')

# Auto-detect overflow for non-center positions
# Center positions use multi-column layout and won't overflow
# Non-center positions use single column and may overflow
if [[ "$POSITION" != *"center"* ]]; then
  # Estimate widget height for single-column layout
  estimated_height=$((16 + 30 + (num_items * 26) + 50 + 40))
  max_allowed_height=$((monitor_logical_height * 80 / 100))

  if [[ "$estimated_height" -gt "$max_allowed_height" ]]; then
    POSITION="bottom-center"
  fi
fi

WINDOW="whichkey-${POSITION}"

################################################################################
# Render Window
################################################################################

# Hide first so content resize happens while invisible
eww -c "$EWW_DIR" update visible=false >/dev/null 2>&1 || true

# Update content while hidden
if [[ "$POSITION" == *"center"* ]]; then
  col1=$(echo "$items" | jq -c '[to_entries | .[] | select(.key % 4 == 0) | .value]')
  col2=$(echo "$items" | jq -c '[to_entries | .[] | select(.key % 4 == 1) | .value]')
  col3=$(echo "$items" | jq -c '[to_entries | .[] | select(.key % 4 == 2) | .value]')
  col4=$(echo "$items" | jq -c '[to_entries | .[] | select(.key % 4 == 3) | .value]')
  eww -c "$EWW_DIR" update title="$title" col1="$col1" col2="$col2" col3="$col3" col4="$col4" \
    "panel-width=${monitor_logical_width}px" >/dev/null 2>&1 || true
else
  eww -c "$EWW_DIR" update title="$title" items="$items" >/dev/null 2>&1 || true
fi

# Switch to correct position window if needed
for pos in bottom-right bottom-center top-center bottom-left top-right top-left center; do
  [[ "whichkey-$pos" != "$WINDOW" ]] && eww -c "$EWW_DIR" close "whichkey-$pos" >/dev/null 2>&1 || true
done
eww -c "$EWW_DIR" open --screen "$screen" "$WINDOW" >/dev/null 2>&1 || true

# Re-validate token before making visible: if the submap changed while this
# render was running (hyprctl + jq take ~100ms), bail out instead of flashing
# a stale HUD on screen.
if [[ -n "$render_token" ]]; then
  RENDER_TOKEN_FILE="${STATE_DIR}/whichkey-render-token"
  _cur_tok=$(cat "$RENDER_TOKEN_FILE" 2>/dev/null || echo "")
  [[ "$_cur_tok" == "$render_token" ]] || exit 0
fi

# Show at the correct size
touch "$STATE_DIR/whichkey-visible"
eww -c "$EWW_DIR" update visible=true >/dev/null 2>&1 || true
