#!/bin/bash
# hypr/.config/hypr/HyprVim/scripts/vim-replace-char-handler.sh
################################################################################
# vim-replace-char-handler.sh - Router for r command (submap vs script)
################################################################################
#
# Routes r command to:
#   - R-CHAR submap (DELETE + pass) for simple r with no count
#   - vim-replace.sh for counted r (e.g., 5r)
#
################################################################################

set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
COUNT_SCRIPT="$SCRIPT_DIR/vim-count.sh"
REPLACE_SCRIPT="$SCRIPT_DIR/vim-replace.sh"

# Peek at count
COUNT_VALUE=$("$COUNT_SCRIPT" peek)

# If no count or count is 1, use submap
if [ -z "$COUNT_VALUE" ] || [ "$COUNT_VALUE" = "1" ]; then
  # Clear count and enter R-CHAR submap
  "$COUNT_SCRIPT" clear
  hyprctl dispatch submap R-CHAR
else
  # Use script for counted replace
  exec "$REPLACE_SCRIPT" char
fi
