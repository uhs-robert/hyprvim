#!/usr/bin/env bash
# hypr/.config/hypr/hyprvim/scripts/apply-theme.sh
################################################################################
# apply-theme.sh - Apply theme colors to eww which-key HUD
################################################################################
#
# Reads color definitions from theme.conf and generates SCSS variables for the
# eww which-key widget. This ensures the HUD colors match the current theme.
#
# Usage:
#   apply-theme.sh    - Read theme.conf and update eww.scss
#
# Files:
#   Input:  ~/.config/hypr/hyprvim/theme.conf
#   Output: ~/.config/hypr/hyprvim/eww/whichkey/eww.scss
#
################################################################################

set -euo pipefail

################################################################################
# Configuration
################################################################################

THEME_FILE="${HOME}/.config/hypr/hyprvim/theme.conf"
SCSS_FILE="${HOME}/.config/hypr/hyprvim/eww/whichkey/eww.scss"

################################################################################
# Read Theme Colors
################################################################################

# Check if theme file exists
if [[ ! -f "$THEME_FILE" ]]; then
  echo "Warning: theme.conf not found, using defaults" >&2
  exit 0
fi

# Parse theme.conf and extract colors and font size
# Colors use ':' separator, font size uses '=' separator
bg_core=$(grep '^\$bg_core' "$THEME_FILE" | sed 's/.*:\s*\(.*\)\s*$/\1/' | tr -d ' ')
bg_border=$(grep '^\$bg_border' "$THEME_FILE" | sed 's/.*:\s*\(.*\)\s*$/\1/' | tr -d ' ')
fg=$(grep '^\$fg' "$THEME_FILE" | sed 's/.*:\s*\(.*\)\s*$/\1/' | tr -d ' ')
primary=$(grep '^\$primary' "$THEME_FILE" | sed 's/.*:\s*\(.*\)\s*$/\1/' | tr -d ' ')
secondary=$(grep '^\$secondary' "$THEME_FILE" | sed 's/.*:\s*\(.*\)\s*$/\1/' | tr -d ' ')
accent=$(grep '^\$accent' "$THEME_FILE" | sed 's/.*:\s*\(.*\)\s*$/\1/' | tr -d ' ')
info=$(grep '^\$info' "$THEME_FILE" | sed 's/.*:\s*\(.*\)\s*$/\1/' | tr -d ' ')
base_font_size=$(grep '^\$base_font_size' "$THEME_FILE" | sed 's/.*=\s*\(.*\)\s*$/\1/' | tr -d ' ')

# Default font size if not specified
[[ -z "$base_font_size" ]] && base_font_size="12px"

################################################################################
# Generate SCSS File
################################################################################

TEMP_FILE=$(mktemp)

# Write color and font size definitions
cat >"$TEMP_FILE" <<EOF
// Semantic color definitions (auto-generated from theme.conf)
\$bg_core: $bg_core;
\$bg_border: $bg_border;
\$fg: $fg;
\$primary: $primary;
\$secondary: $secondary;
\$accent: $accent;
\$info: $info;

// Font sizing (all sizes scale from base using rem)
* {
  font-size: $base_font_size;
}

\$title_font_size: 1.08rem;    // ~13px at 12px base
\$base_font_size: 1rem;        // Base size
\$footer_font_size: 0.92rem;   // ~11px at 12px base
EOF

# Append everything after the color definitions
sed -n '/^\.whichkey {/,$p' "$SCSS_FILE" >>"$TEMP_FILE"

# Replace original file
mv "$TEMP_FILE" "$SCSS_FILE"

echo "Theme applied successfully"
