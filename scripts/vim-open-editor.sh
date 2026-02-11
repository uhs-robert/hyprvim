#!/usr/bin/env bash
# scripts/vim-open-editor.sh
#
# HyprVim Open Editor - Edit text anywhere in Wayland with vim/nvim
#
# Opens a floating terminal with vim/nvim to edit temporary text buffers.
# After editing, the content is automatically pasted back to the focused window.
# Supports both clipboard paste (default) and keystroke mode for compatibility.
#
# Usage: vim-open-editor.sh [OPTIONS]
# Environment:
#   HYPRVIM_EDITOR  - Editor to use (vim or nvim, default: nvim)
#   HYPRVIM_PROMPT  - Prompt tool for dialogs (auto-detected if not set)
#   TERMINAL        - Terminal emulator (required if not using --term)

set -euo pipefail

ASK_EXT=false
REMOVE_TMP=false
KEYSTROKE_MODE=false
COPY_SELECTED=false

TERM_CLASS="hyprvim-open-vim"
TERMINAL_CMD=""
TERM_OPTS=(--class hyprvim-open-vim -e)
TMPFILE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/hyprvim-open-vim"
EDITOR_CMD="${HYPRVIM_EDITOR:-nvim}"
PROMPT_CMD="${HYPRVIM_PROMPT:-}"

# Detect or validate the terminal emulator to use for launching the editor
# Checks if TERMINAL_CMD is already set (via --term flag), otherwise falls back to $TERMINAL
# Exits with error if no terminal is configured
detect_terminal() {
  if [[ -n "$TERMINAL_CMD" ]]; then
    return
  fi

  # Use $TERMINAL if set
  if [[ -n "${TERMINAL:-}" ]]; then
    TERMINAL_CMD="$TERMINAL"
    return
  fi

  echo "Error: No terminal specified. Set \$TERMINAL or use --term <terminal>"
  exit 1
}

# Auto-detect an available prompt/dialog tool for user input
# Checks for PROMPT_CMD (set via $HYPRVIM_PROMPT), otherwise searches for available tools
# Supported tools (in order): rofi, wofi, tofi, fuzzel, dmenu, zenity, kdialog
# Exits with error if no compatible prompt tool is found
detect_prompt() {
  if [[ -n "$PROMPT_CMD" ]]; then
    return
  fi

  # Auto-detect available prompt tools in order of preference
  local prompt_tools=("rofi" "wofi" "tofi" "fuzzel" "dmenu" "zenity" "kdialog")

  for tool in "${prompt_tools[@]}"; do
    if command -v "$tool" &>/dev/null; then
      PROMPT_CMD="$tool"
      return
    fi
  done

  echo "Error: No prompt tool found. Install one of: ${prompt_tools[*]}"
  exit 1
}

# Verify that all required command-line tools are installed
# Checks for: editor (vim/nvim), wtype, and optionally wl-paste (for clipboard operations)
# Exits with error message if any required dependency is missing
check_deps() {
  local deps=("$EDITOR_CMD" "wtype")

  if ! $KEYSTROKE_MODE || $COPY_SELECTED; then
    deps+=("wl-paste")
  fi

  for cmd in "${deps[@]}"; do
    if ! command -v "$cmd" &>/dev/null; then
      echo "Error: '$cmd' is required but not installed."
      exit 1
    fi
  done
}

# Kill any existing hyprvim-open-vim instance to prevent multiple windows
# Searches for processes with the terminal class name and terminates them
# Exits after killing to prevent launching a new instance on top of cleanup
kill_existing_instance() {
  # Find terminal windows with our class name, not the script itself
  local pids
  pids=$(pgrep -f "class.*$TERM_CLASS" 2>/dev/null || true)

  if [[ -n "$pids" ]]; then
    echo "An existing instance was found and terminated."
    echo "$pids" | xargs -r kill -9
    exit 1
  fi
}

# Create a temporary file in the cache directory for editing
# Generates timestamp-based filename, optionally with extension if --ask-ext is used
# Sets restrictive permissions (user-only read/write) for security
create_tmpfile() {
  mkdir -p "$TMPFILE_DIR"
  local filename
  filename="doc-$(date +"%y%m%d%H%M%S")"
  if $ASK_EXT && [[ -n "${EXT:-}" ]]; then
    filename="$filename.$EXT"
  fi
  TMPFILE="$TMPFILE_DIR/$filename"
  touch "$TMPFILE"
  chmod og-rwx "$TMPFILE"
}

# Display usage information and available command-line options
# Shows configured editor and explains all flags (--ask-ext, --rm-tmp, etc.)
# Exits after displaying help
show_help() {
  echo "hyprvim-open-vim <OPTIONS>"
  echo ""
  echo "Editor: $EDITOR_CMD (set via \$HYPRVIM_EDITOR in init.conf, defaults to nvim)"
  echo ""
  echo "--ask-ext"
  echo "  Prompt for a file extension when creating the temporary buffer. Useful if you want syntax highlighting (.py, .rs, .md, etc.). "
  echo ""
  echo "--rm-tmp"
  echo "  Automatically delete the temporary file after use instead of leaving it in cache directory. "
  echo ""
  echo "--copy-selected"
  echo "  Copy the currently selected text with Ctrl + C and start editing it"
  echo ""
  echo "--keystroke-mode"
  echo "  Switches from clipboard-paste to **direct keystroke mode** using wtype."
  echo "  - Useful in cases where pasting is blocked, unreliable, or when working inside apps that don't accept clipboard input. (e.g: a Terminal; because they take a CTRL+SHIFT+V) "
  echo "  - Note: Slower than clipboard paste, since it needs to send individual keystrokes "

  echo "--term <terminal>"
  echo "  Choose which terminal emulator to launch the editor in (uses \$TERMINAL if not specified). "
  echo ""
  exit 0
}

# Parse command-line arguments and set configuration flags
# Handles: --ask-ext, --rm-tmp, --keystroke-mode, --copy-selected, --term, --help
# Exits with error if unknown arguments are provided
parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
    --ask-ext)
      ASK_EXT=true
      shift
      ;;

    --rm-tmp)
      REMOVE_TMP=true
      shift
      ;;

    --keystroke-mode)
      KEYSTROKE_MODE=true
      shift
      ;;

    --copy-selected)
      COPY_SELECTED=true
      shift
      ;;

    --term)
      if [[ $# -ge 2 && $2 != --* ]]; then
        TERMINAL_CMD="$2"
        shift 2
      else
        echo "Error: --term requires a value."
        exit 1
      fi
      ;;

    --help)
      show_help
      ;;
    *)
      echo "Unknown argument: $1"
      show_help
      exit 1
      ;;
    esac
  done
}

parse_args "$@"
kill_existing_instance
detect_terminal
detect_prompt
check_deps

# Ask for file extension if requested
if $ASK_EXT; then
  case "$PROMPT_CMD" in
  rofi)
    EXT=$(rofi -dmenu -p "File extension:" -lines 1)
    ;;
  wofi)
    EXT=$(wofi --dmenu --lines 1 --prompt "File extension:")
    ;;
  tofi)
    EXT=$(tofi --prompt-text "File extension:")
    ;;
  fuzzel)
    EXT=$(fuzzel --dmenu --prompt "File extension: ")
    ;;
  dmenu)
    EXT=$(dmenu -p "File extension:")
    ;;
  zenity)
    EXT=$(zenity --entry --text "File extension:")
    ;;
  kdialog)
    EXT=$(kdialog --inputbox "File extension:")
    ;;
  esac
fi

create_tmpfile

if $COPY_SELECTED; then
  # Save current clipboard state
  LAST_CLIPBOARD=$(wl-paste --no-newline 2>/dev/null || true)

  # Try primary selection first (instant, no side effects)
  SELECTED_TEXT=$(wl-paste -p --no-newline 2>/dev/null || true)

  # If no primary selection, try copying with retries using hyprctl
  if [[ -z "$SELECTED_TEXT" ]]; then
    # Try Ctrl+C with multiple attempts and verification
    for attempt in 1 2 3; do
      # Send Ctrl+C directly to active window via Hyprland dispatcher
      hyprctl dispatch sendshortcut CTRL, C, activewindow

      # Progressive delay: 0.1s, 0.2s, 0.3s
      sleep 0.$attempt

      # Check if clipboard changed
      NEW_CLIPBOARD=$(wl-paste --no-newline 2>/dev/null || true)

      # If clipboard changed and is not empty, we got something
      if [[ -n "$NEW_CLIPBOARD" ]] && [[ "$NEW_CLIPBOARD" != "$LAST_CLIPBOARD" ]]; then
        SELECTED_TEXT="$NEW_CLIPBOARD"
        break
      fi
    done
  fi

  # Write selected text to temp file if we have any
  if [[ -n "$SELECTED_TEXT" ]]; then
    echo "$SELECTED_TEXT" >"$TMPFILE"
  fi

  # Restore the original clipboard
  if [[ -n "$LAST_CLIPBOARD" ]]; then
    echo -n "$LAST_CLIPBOARD" | wl-copy -n
  else
    # If clipboard was empty, clear it to restore original state
    wl-copy -c 2>/dev/null || true
  fi
fi

# Record file modification time before opening editor
MTIME_BEFORE=$(stat -c %Y "$TMPFILE" 2>/dev/null || echo "0")

# Launch vim/nvim in insert mode, auto-quit on write
"$TERMINAL_CMD" "${TERM_OPTS[@]}" "$EDITOR_CMD" +startinsert +'autocmd BufWritePost <buffer> quit' "$TMPFILE"

# Check if file was actually modified (user saved)
MTIME_AFTER=$(stat -c %Y "$TMPFILE" 2>/dev/null || echo "0")

# Only paste if the file was modified (user saved changes)
if [[ "$MTIME_AFTER" -gt "$MTIME_BEFORE" ]]; then
  TEXT=$(<"$TMPFILE")

  # Paste the text if not empty
  if [ -n "$TEXT" ]; then

    if $KEYSTROKE_MODE; then
      # Keystroke mode - type character by character (doesn't affect clipboard)
      printf '%s' "$TEXT" | wtype -

    else
      # Paste mode - save clipboard, paste, then restore
      CLIPBOARD_BEFORE_PASTE=$(wl-paste --no-newline 2>/dev/null || true)

      # Copy edited text to clipboard and paste via Hyprland dispatcher
      wl-copy -n <"$TMPFILE"
      hyprctl dispatch sendshortcut CTRL, V, activewindow

      # Wait for paste to complete
      sleep 0.1

      # Restore the clipboard to what it was before pasting
      if [[ -n "$CLIPBOARD_BEFORE_PASTE" ]]; then
        echo -n "$CLIPBOARD_BEFORE_PASTE" | wl-copy -n
      fi
    fi

  else
    exit 1
  fi
fi

if $REMOVE_TMP; then
  rm -rf "$TMPFILE"
fi
