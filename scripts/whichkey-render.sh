#!/usr/bin/env bash
# hypr/.config/hypr/hyprvim/scripts/whichkey-render.sh
################################################################################
# whichkey-render.sh - Render which-key HUD for active submap
################################################################################
#
# Usage:
#   whichkey-render.sh <submap>   - Render which-key for given submap
#   whichkey-render.sh ""         - Hide which-key
#   whichkey-render.sh info       - Re-show which-key for current submap
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
# Info Command - Re-show Current Submap
################################################################################

if [[ "${1:-}" == "--info" ]] || [[ "${1:-}" == "info" ]]; then
  # Try to get current submap from state file
  current_submap=""
  if [[ -f "$STATE_DIR/current-submap" ]]; then
    current_submap=$(cat "$STATE_DIR/current-submap" 2>/dev/null || echo "")
  fi

  # Determine which submap to show
  if [[ -n "$current_submap" ]] && [[ "$current_submap" != "reset" ]]; then
    target_submap="$current_submap"
  else
    target_submap="GLOBAL"
  fi

  # Render the submap
  "$0" "$target_submap" || true

  # Start keyboard monitor to auto-dismiss on any keypress
  MONITOR_PID_FILE="$STATE_DIR/whichkey-info-monitor.pid"
  (
    # Create named pipe
    PIPE=$(mktemp -u)
    mkfifo "$PIPE"
    trap 'rm -f "$PIPE"' EXIT

    sleep 0.2

    # Start libinput and wait for one keypress
    (stdbuf -oL libinput debug-events 2>&1 | grep --line-buffered -E 'KEYBOARD_KEY.*pressed' >"$PIPE") &
    LIBINPUT_PID=$!

    # Read one keypress
    read -r line <"$PIPE"

    # Kill libinput
    pkill -P $LIBINPUT_PID 2>/dev/null || true
    kill $LIBINPUT_PID 2>/dev/null || true

    # Hide which-key (use "hide" to preserve state)
    "$0" "hide" >/dev/null 2>&1 || true
    rm -f "$MONITOR_PID_FILE"
  ) &
  echo $! >"$MONITOR_PID_FILE"

  exit 0
fi

################################################################################
# Submap Processing
################################################################################

submap="${1:-}"

# Save current submap to state for info command
if [[ -n "$submap" ]] && [[ "$submap" != "reset" ]] && [[ "$submap" != "GLOBAL" ]] && [[ "$submap" != "hide" ]]; then
  echo "$submap" >"$STATE_DIR/current-submap"
elif [[ -z "$submap" ]] || [[ "$submap" == "reset" ]]; then
  # Clear state when exiting vim mode (but not when just hiding)
  rm -f "$STATE_DIR/current-submap"
fi

# Normalize special values to empty for hiding
[[ "$submap" == "reset" ]] && submap=""
[[ "$submap" == "hide" ]] && submap=""

# Hide when no submap (but not GLOBAL)
if [[ -z "$submap" ]]; then
  eww -c "$EWW_DIR" update visible=false >/dev/null 2>&1 || true
  for pos in bottom-right bottom-center top-center bottom-left top-right top-left center; do
    eww -c "$EWW_DIR" close "whichkey-$pos" >/dev/null 2>&1 || true
  done
  exit 0
fi

################################################################################
# Build Key Bindings JSON
################################################################################

# Get focused monitor
screen="$(hyprctl -j monitors | jq -r '.[] | select(.focused) | .id' 2>/dev/null || echo 0)"

# Set title (use friendly name for GLOBAL)
if [[ "$submap" == "GLOBAL" ]]; then
  title="Global Bindings"
else
  title="$submap"
fi

# Query Hyprland bindings and format for eww
items="$(
  hyprctl binds -j |
    jq -c --arg sm "$submap" '
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
)"

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

# Auto-detect overflow for non-center positions
# Center positions use multi-column layout and won't overflow
# Non-center positions use single column and may overflow
if [[ "$POSITION" != *"center"* ]]; then
  monitor_height=$(hyprctl -j monitors | jq -r '.[] | select(.focused) | .height' 2>/dev/null || echo 1080)

  # Estimate widget height for single-column layout
  estimated_height=$((16 + 30 + (num_items * 26) + 50 + 40))
  max_allowed_height=$((monitor_height * 80 / 100))

  if [[ "$estimated_height" -gt "$max_allowed_height" ]]; then
    POSITION="bottom-center"
  fi
fi

WINDOW="whichkey-${POSITION}"

################################################################################
# Render Window
################################################################################

# Close other positions and open the configured one
for pos in bottom-right bottom-center top-center bottom-left top-right top-left center; do
  [[ "whichkey-$pos" != "$WINDOW" ]] && eww -c "$EWW_DIR" close "whichkey-$pos" >/dev/null 2>&1 || true
done

eww -c "$EWW_DIR" open --screen "$screen" "$WINDOW" >/dev/null 2>&1 || true

# For center layouts, distribute items across 4 columns
if [[ "$POSITION" == *"center"* ]]; then
  col1=$(echo "$items" | jq -c '[to_entries | .[] | select(.key % 4 == 0) | .value]')
  col2=$(echo "$items" | jq -c '[to_entries | .[] | select(.key % 4 == 1) | .value]')
  col3=$(echo "$items" | jq -c '[to_entries | .[] | select(.key % 4 == 2) | .value]')
  col4=$(echo "$items" | jq -c '[to_entries | .[] | select(.key % 4 == 3) | .value]')
  eww -c "$EWW_DIR" update title="$title" col1="$col1" col2="$col2" col3="$col3" col4="$col4" visible=true
else
  eww -c "$EWW_DIR" update title="$title" items="$items" visible=true
fi
