#!/usr/bin/env bash
# hypr/.config/hypr/hyprvim/scripts/apply-theme.sh
################################################################################
# apply-theme.sh - Apply theme colors to eww which-key HUD
################################################################################
#
# Reads all variables from theme.conf and writes them as SCSS variables to
# eww/whichkey/_vars.scss. Users only need to edit theme.conf. Any $variable
# defined in theme.conf is automatically included.
#
# Usage:
#   apply-theme.sh
#
# Files:
#   Input:  ~/.config/hypr/hyprvim/theme.conf
#   Output: ~/.config/hypr/hyprvim/eww/whichkey/_vars.scss
#           ~/.config/hypr/hyprvim/whichkey.scss  (created if missing)
#
################################################################################

set -euo pipefail
shopt -s extglob

THEME_FILE="${HOME}/.config/hypr/hyprvim/theme.conf"
VARS_FILE="${HOME}/.config/hypr/hyprvim/eww/whichkey/_vars.scss"
USER_SCSS="${HOME}/.config/hypr/hyprvim/whichkey.scss"

# Create a file from stdin only if it doesn't already exist.
create_if_missing() {
  local file="$1"
  local label="${2:-$file}"
  if [[ ! -f "$file" ]]; then
    echo "Warning: $label not found, generating default" >&2
    cat >"$file"
  fi
}

create_if_missing "$USER_SCSS" "whichkey.scss" <<'EOF'
// whichkey.scss
//
// User style overrides for the which-key HUD.
// Edit this file to customize layout, spacing, and borders.
// All variables from theme.conf and eww.scss are available here.
//
// Examples:

// Rounder corners
// .wk { border-radius: 16px; }

// Tighter padding
// .wk { padding: 6px 10px; }

// Larger font
// * { font-size: 14px; }

// Custom key label color
// .wk-key { color: $accent; }

// Hide the footer
// .wk-footer { display: none; }
EOF

TEMP_FILE=$(mktemp)
trap 'rm -f "$TEMP_FILE"' EXIT

create_if_missing "$THEME_FILE" "theme.conf" <<'EOF'
# hypr/.config/hypr/hyprvim/theme.conf
#
# Controls the colors and font size of the which-key HUD (eww widget).
# Changes are applied automatically on the next `hyprctl reload`.
#
# Any $variable defined here is automatically passed through to the eww SCSS.

# Theme Colors
$bg_core: #101418;
$bg_border: #5D8BBB;
$fg: #F7EDE1;
$primary: #7FA3C9;
$secondary: #D6CE7C;
$accent: #FFA0A0;
$info: #87CEEB;

# Base font size (all other sizes scale from this)
$base_font_size = 12px
EOF

if [[ -f "$THEME_FILE" ]]; then
  {
    echo "// Auto-generated from theme.conf — do not edit directly"
    echo "// To customize, edit theme.conf and run: hyprctl reload"
    echo ""

    while IFS= read -r line; do
      # Skip comments and blank lines
      [[ "$line" =~ ^[[:space:]]*# ]] && continue
      [[ -z "${line//[[:space:]]/}" ]] && continue

      # $name: value;  (color variables — capture up to semicolon, strip trailing whitespace)
      if [[ "$line" =~ ^\$([A-Za-z_][A-Za-z0-9_]*)[[:space:]]*:[[:space:]]*([^;]*) ]]; then
        name="${BASH_REMATCH[1]}"
        value="${BASH_REMATCH[2]%%*([[:space:]])}"
        echo "\$$name: $value;"

      # $name = value  (other settings, e.g. font size)
      elif [[ "$line" =~ ^\$([A-Za-z_][A-Za-z0-9_]*)[[:space:]]*=[[:space:]]*(.*) ]]; then
        name="${BASH_REMATCH[1]}"
        value="${BASH_REMATCH[2]%%*([[:space:]])}"
        echo "\$$name: $value;"
      fi
    done <"$THEME_FILE"
  } >"$TEMP_FILE"
fi

mv "$TEMP_FILE" "$VARS_FILE"

echo "Theme applied successfully"
