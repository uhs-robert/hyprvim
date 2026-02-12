#!/bin/bash
# hypr/.config/hypr/hyprvim/scripts/lib/ui.sh
################################################################################
# User interface functions for HyprVim scripts
################################################################################
#
# Provides: Prompts, notifications, user input, colored output
# Dependencies: core.sh (for log_error)
#
################################################################################

set -euo pipefail

################################################################################
# Terminal Color Codes
################################################################################

export COLOR_RED='\033[0;31m'
export COLOR_GREEN='\033[0;32m'
export COLOR_YELLOW='\033[1;33m'
export COLOR_BLUE='\033[0;34m'
export COLOR_RESET='\033[0m'

################################################################################
# User Input/Prompt Functions
################################################################################

# Detect available prompt tool
# Returns: tool name (rofi, wofi, tofi, fuzzel, dmenu, kdialog, zenity, or empty)
detect_prompt_tool() {
  # Prefer environment variable override
  if [ -n "${HYPRVIM_PROMPT:-}" ] && command -v "$HYPRVIM_PROMPT" &>/dev/null; then
    echo "$HYPRVIM_PROMPT"
    return 0
  fi

  # Fallback to auto-detect available tools
  for candidate in rofi wofi tofi fuzzel dmenu kdialog zenity; do
    if command -v "$candidate" &>/dev/null; then
      echo "$candidate"
      return 0
    fi
  done

  echo ""
  return 1
}

# Get user input using available prompt tool
# Usage: get_user_input "Prompt text" "window-class" ["placeholder/help text"]
# Returns: user input string
get_user_input() {
  local prompt="${1:-Input: }"
  local window_class="${2:-hyprvim-prompt}"
  local placeholder="${3:-}"
  local tool

  tool=$(detect_prompt_tool)

  if [ -z "$tool" ]; then
    notify-send "HyprVim" "No input tool found. Install wofi, rofi, tofi, fuzzel, dmenu, zenity, or kdialog." 2>/dev/null || true
    return 1
  fi

  local input=""
  case "$tool" in
  rofi)
    local rofi_args=(
      -dmenu -p "$prompt" -lines 0
      -theme-str 'window { location: north; anchor: north; y-offset: 10%; x-offset: 0%; width: 600px; height: 40px; border: 1px; }'
      -theme-str 'mainbox { children: [inputbar]; padding: 0px; spacing: 0px; border: 0px; }'
      -theme-str 'inputbar { padding: 8px 12px; children: [prompt,entry]; border: 0px; orientation: horizontal; }'
      -theme-str 'prompt { padding: 0px 0px 0px 0px; vertical-align: 0.5; }'
      -theme-str 'entry { vertical-align: 0.5; placeholder: "'"$placeholder"'"; }'
    )
    input=$(echo "" | rofi "${rofi_args[@]}")
    ;;
  wofi)
    input=$(echo "" | wofi --dmenu --prompt "$prompt" --lines 0 --gtk-application-id "$window_class")
    ;;
  tofi)
    local tofi_args=(--prompt-text "$prompt")
    [ -n "$placeholder" ] && tofi_args+=(--placeholder-text "$placeholder")
    input=$(echo "" | tofi "${tofi_args[@]}")
    ;;
  fuzzel)
    input=$(echo "" | fuzzel --dmenu --prompt "$prompt" --app-id "$window_class")
    ;;
  dmenu)
    input=$(echo "" | dmenu -p "$prompt" -class "$window_class")
    ;;
  kdialog)
    input=$(kdialog --inputbox "$prompt" --class "$window_class" 2>/dev/null)
    ;;
  zenity)
    input=$(zenity --entry --title="HyprVim" --text="$prompt" --class="$window_class" 2>/dev/null)
    ;;
  esac

  echo "$input"
}

# Get user selection from a list of options
# Usage: get_user_selection "Prompt text" "option1" "option2" "option3"
# Returns: selected option
get_user_selection() {
  local prompt="$1"
  shift
  local options=("$@")
  local tool

  tool=$(detect_prompt_tool)

  if [ -z "$tool" ]; then
    # Fallback: return first option
    echo "${options[0]}"
    return 0
  fi

  local choice=""
  local options_str
  options_str=$(printf "%s\n" "${options[@]}")

  case "$tool" in
  rofi)
    choice=$(
      echo "$options_str" | rofi -dmenu -p "$prompt" \
        -theme-str 'window { location: center; anchor: center; width: 400px; }' \
        -theme-str "listview { lines: ${#options[@]}; }"
    )
    ;;
  wofi)
    choice=$(echo "$options_str" | wofi --dmenu --prompt "$prompt" --gtk-application-id hyprvim-select)
    ;;
  tofi)
    choice=$(echo "$options_str" | tofi --prompt-text "$prompt")
    ;;
  fuzzel)
    choice=$(echo "$options_str" | fuzzel --dmenu --prompt "$prompt" --app-id hyprvim-select)
    ;;
  dmenu)
    choice=$(echo "$options_str" | dmenu -p "$prompt" -class hyprvim-select)
    ;;
  *)
    # Fallback: return first option
    choice="${options[0]}"
    ;;
  esac

  echo "$choice"
}

# Get launcher command for application launcher
# Returns: launcher command string (e.g., "rofi -show drun")
get_launcher_command() {
  local tool
  tool=$(detect_prompt_tool)

  if [ -z "$tool" ]; then
    return 1
  fi

  case "$tool" in
  rofi)
    echo "rofi -show drun"
    ;;
  wofi)
    echo "wofi --show drun"
    ;;
  tofi)
    echo "tofi-drun --drun-launch=true"
    ;;
  fuzzel)
    echo "fuzzel"
    ;;
  dmenu)
    echo "dmenu_run"
    ;;
  *)
    # Fallback: try to use the tool with -show drun
    echo "$tool -show drun"
    ;;
  esac
}

################################################################################
# Notification and Terminal Output Helpers
################################################################################

# Error with colored output, notification, and exit
# Usage: notify_error "message" [notify_enabled]
notify_error() {
  local message="$1"
  local notify_enabled="${2:-1}"

  echo -e "${COLOR_RED}Error: $message${COLOR_RESET}" >&2
  log_error "$message"

  if [ "$notify_enabled" = "1" ]; then
    notify-send -t 2000 -u critical "HyprVim Error" "$message" 2>/dev/null || true
  fi

  exit 1
}

# Success with colored output and optional notification
# Usage: notify_success "message" [notify_enabled]
notify_success() {
  local message="$1"
  local notify_enabled="${2:-1}"

  echo -e "${COLOR_GREEN}$message${COLOR_RESET}"

  if [ "$notify_enabled" = "1" ]; then
    notify-send -t 1000 -u low "HyprVim" "$message" 2>/dev/null || true
  fi
}

# Info with colored output and optional notification
# Usage: notify_info "message" [notify_enabled]
notify_info() {
  local message="$1"
  local notify_enabled="${2:-1}"

  echo -e "${COLOR_YELLOW}$message${COLOR_RESET}"

  if [ "$notify_enabled" = "1" ]; then
    notify-send -t 1500 -u normal "HyprVim" "$message" 2>/dev/null || true
  fi
}

################################################################################
# Export Functions
################################################################################

export -f detect_prompt_tool
export -f get_user_input
export -f get_user_selection
export -f get_launcher_command
export -f notify_error
export -f notify_success
export -f notify_info
