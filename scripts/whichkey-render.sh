#!/usr/bin/env bash
# scripts/whichkey-render.sh

set -euo pipefail

EWW_DIR="${EWW_DIR:-$HOME/.config/hypr/hyprvim/eww/whichkey}"
submap="${1:-}"

# Read position setting (default: bottom-right)
POSITION="${HYPRVIM_WHICH_KEY_POSITION:-bottom-right}"
# Convert to window name (e.g., "bottom-center" -> "whichkey-bottom-center")
WINDOW="whichkey-${POSITION}"

# Normalize "reset"
[[ "$submap" == "reset" ]] && submap=""

# Hide/close when no submap - do this FIRST to avoid flash
if [[ -z "$submap" ]]; then
  eww -c "$EWW_DIR" update visible=false >/dev/null 2>&1 || true
  # Close all possible window positions
  for pos in bottom-right bottom-center top-center bottom-left top-right top-left; do
    eww -c "$EWW_DIR" close "whichkey-$pos" >/dev/null 2>&1 || true
  done
  exit 0
fi

# Focused Hyprland monitor id (often matches eww --screen index)
screen="$(hyprctl -j monitors | jq -r '.[] | select(.focused) | .id' 2>/dev/null || echo 0)"

title="$submap"

# Build JSON array for eww `items`
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
            # Only SHIFT: uppercase letters or shift symbols
            if ($k | test("^[a-zA-Z]$")) then
              ($k | ascii_upcase)
            else
              # Shift number/symbol translations
              ($k
                | gsub("^1$"; "!") | gsub("^2$"; "@") | gsub("^3$"; "#")
                | gsub("^4$"; "$") | gsub("^5$"; "%") | gsub("^6$"; "^")
                | gsub("^7$"; "&") | gsub("^8$"; "*") | gsub("^9$"; "(")
                | gsub("^0$"; ")") | gsub("^-$"; "_") | gsub("^=$"; "+")
                | gsub("^\\[$"; "{") | gsub("^\\]$"; "}") | gsub("^\\\\$"; "|")
                | gsub("^;$"; ":") | gsub("^,$"; "<")
                | gsub("^\\.$"; ">") | gsub("^/$"; "?")
              )
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
        | select((.submap // "") == $sm)
        | select((.description // "") != "")
        | [(normalize_key(.key // ""; .modmask // 0)), (.description // "")]
      ]
      # Sort: letters, special chars, modifiers, ESC
      | (map(select(.[0] == "ESC"))) as $esc
      | (map(select(.[0] != "ESC" and (.[0] | test("C-|A-|M-|S-"))))) as $mods
      | (map(select(.[0] != "ESC" and (.[0] | test("C-|A-|M-|S-") | not) and (.[0] | test("^[a-zA-Z]$"))))) as $letters
      | (map(select(.[0] != "ESC" and (.[0] | test("C-|A-|M-|S-") | not) and (.[0] | test("^[a-zA-Z]$") | not)))) as $special
      | ($letters | sort_by(.[0] | ascii_downcase)) + ($special | sort_by(.[0])) + ($mods | sort_by(.[0])) + $esc
    '
)"

# Hide if no bindings to show
if [[ "$(echo "$items" | jq 'length')" -eq 0 ]]; then
  eww -c "$EWW_DIR" update visible=false >/dev/null 2>&1 || true
  # Close all possible window positions
  for pos in bottom-right bottom-center top-center bottom-left top-right top-left; do
    eww -c "$EWW_DIR" close "whichkey-$pos" >/dev/null 2>&1 || true
  done
  exit 0
fi

# Close other positions and open the configured one
for pos in bottom-right bottom-center top-center bottom-left top-right top-left; do
  [[ "whichkey-$pos" != "$WINDOW" ]] && eww -c "$EWW_DIR" close "whichkey-$pos" >/dev/null 2>&1 || true
done
eww -c "$EWW_DIR" open --screen "$screen" "$WINDOW" >/dev/null 2>&1 || true

# For center layouts, distribute items round-robin across 4 columns
if [[ "$POSITION" == *"center"* ]]; then
  col1=$(echo "$items" | jq -c '[to_entries | .[] | select(.key % 4 == 0) | .value]')
  col2=$(echo "$items" | jq -c '[to_entries | .[] | select(.key % 4 == 1) | .value]')
  col3=$(echo "$items" | jq -c '[to_entries | .[] | select(.key % 4 == 2) | .value]')
  col4=$(echo "$items" | jq -c '[to_entries | .[] | select(.key % 4 == 3) | .value]')
  eww -c "$EWW_DIR" update title="$title" col1="$col1" col2="$col2" col3="$col3" col4="$col4" visible=true
else
  eww -c "$EWW_DIR" update title="$title" items="$items" visible=true
fi
