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

THEME_FILE="${HOME}/.config/hypr/hyprvim/theme.conf"
VARS_FILE="${HOME}/.config/hypr/hyprvim/eww/whichkey/_vars.scss"
USER_SCSS="${HOME}/.config/hypr/hyprvim/whichkey.scss"

if [[ ! -f "$THEME_FILE" ]]; then
  echo "Warning: theme.conf not found, using defaults" >&2
  exit 0
fi

TEMP_FILE=$(mktemp)
trap 'rm -f "$TEMP_FILE"' EXIT

{
  echo "// Auto-generated from theme.conf — do not edit directly"
  echo "// To customize, edit theme.conf and re-run apply-theme.sh"
  echo ""

  while IFS= read -r line; do
    # Skip comments and blank lines
    [[ "$line" =~ ^[[:space:]]*# ]] && continue
    [[ -z "${line//[[:space:]]/}" ]] && continue

    # $name: value;  (color variables — strip trailing semicolon and whitespace)
    if [[ "$line" =~ ^\$([A-Za-z_][A-Za-z0-9_]*)[[:space:]]*:[[:space:]]*(.*) ]]; then
      name="${BASH_REMATCH[1]}"
      value=$(echo "${BASH_REMATCH[2]}" | sed 's/[;[:space:]]*$//')
      echo "\$$name: $value;"

    # $name = value  (other settings, e.g. font size)
    elif [[ "$line" =~ ^\$([A-Za-z_][A-Za-z0-9_]*)[[:space:]]*=[[:space:]]*(.*) ]]; then
      name="${BASH_REMATCH[1]}"
      value=$(echo "${BASH_REMATCH[2]}" | sed 's/[[:space:]]*$//')
      echo "\$$name: $value;"
    fi
  done <"$THEME_FILE"
} >"$TEMP_FILE"

mv "$TEMP_FILE" "$VARS_FILE"

# Create whichkey.scss if it doesn't exist so the eww SCSS import succeeds
# Users copy whichkey.scss.example to this file to add style overrides
if [[ ! -f "$USER_SCSS" ]]; then
  echo "// User style overrides — see whichkey.scss.example for usage" > "$USER_SCSS"
fi

echo "Theme applied successfully"
