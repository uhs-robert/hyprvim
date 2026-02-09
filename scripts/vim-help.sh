#!/bin/bash
# hypr/.config/hypr/HyprVim/scripts/vim-help.sh
################################################################################
# vim-help.sh - Display HyprVim keybindings help
################################################################################
#
# Parses bindd statements from .conf files and displays them in a nice format
#
################################################################################

set -euo pipefail

SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
CONF_DIR="$(dirname "$SCRIPT_DIR")"

# Generate help content by parsing bindd statements
generate_help() {
  cat <<'EOF'
# HyprVim Keybindings

**Press `q` to close this help**

---

## 📍 Navigation

### Character Movement
EOF

  # Extract and format bindd entries
  parse_section "vim-modes.conf" "## Char"

  cat <<'EOF'

### Text Movement
EOF
  parse_section "vim-modes.conf" "## Word"
  parse_section "vim-modes.conf" "## Paragraph"

  cat <<'EOF'

### Line Movement
EOF
  parse_section "vim-modes.conf" "## Line"

  cat <<'EOF'

### Page/Document Movement
EOF
  parse_section "vim-modes.conf" "## Page"

  cat <<'EOF'

### Go Motions (g prefix)
EOF
  parse_section "vim-modes.conf" "## G-MOTION"

  cat <<'EOF'

---

## 🔢 Counts

Type numbers before motions/operators to repeat them:
- `5j` - Move down 5 lines
- `3dw` - Delete 3 words
- `10w` - Move forward 10 words

EOF
  parse_section "vim-modes.conf" "## Count"

  cat <<'EOF'

---

## ✂️ Operators

### Delete
EOF
  parse_section "vim-modes.conf" "## Delete"

  cat <<'EOF'

### Change (Delete and enter insert)
EOF
  parse_section "vim-modes.conf" "## Change"

  cat <<'EOF'

### Yank (Copy)
EOF
  parse_section "vim-modes.conf" "## Paste"

  cat <<'EOF'

### Operator + Motion
EOF
  parse_section "vim-modes.conf" "## Mode Switches" | grep -E "(D-MOTION|C-MOTION|Y-MOTION)"

  cat <<'EOF'

**Example usage:**
- `dw` - Delete word
- `3dw` - Delete 3 words
- `dd` - Delete line
- `d$` - Delete to end of line
- `diw` - Delete inner word (text object)
- `daw` - Delete around word (text object)
- `ciw` - Change inner word (delete and enter insert)
- `yy` - Yank (copy) line

---

## ↹ Indent

EOF
  parse_section "vim-modes.conf" "## Indent"

  cat <<'EOF'

---

## 👁️ Visual Mode

EOF
  parse_section "vim-modes.conf" "## Mode Switches" | grep -i visual

  cat <<'EOF'

---

## 📌 Marks

EOF
  parse_section "vim-modes.conf" "## Mark Operations"

  cat <<'EOF'

**Example:**
- `ma` - Set mark 'a' at current location
- `` `a `` - Jump back to mark 'a'
- `dma` - Delete mark 'a'

---

## ✏️ Insert Mode

EOF
  parse_section "vim-modes.conf" "## Enter insert"
  parse_section "vim-modes.conf" "## Open new line"

  cat <<'EOF'

---

## 🔍 Find

EOF
  parse_section "vim-modes.conf" "## Find (f/F/t/T/// ? all use enhanced find)"

  cat <<'EOF'

**Interactive Find:**
- `/`, `f`, `t` - Opens input dialog, searches forward
- `?`, `F`, `T` - Opens input dialog, searches backward
- `*` - Search forward for word under cursor
- `#` - Search backward for word under cursor
- `n` - Next match (in search direction)
- `N` - Previous match (opposite direction)

**Configuration:**
Set `HYPRVIM_PROMPT` environment variable to choose input tool.
Auto-detects: wofi, rofi, tofi, fuzzel, dmenu, zenity, kdialog.

---

## 🔄 Replace

EOF
  parse_section "vim-modes.conf" "## Mode Switches" | grep -i "Replace"

  cat <<'EOF'

**Replace Operations:**
- `r<char>` - Instantly replace character under cursor (no prompt)
- `5r<char>` - Replace 5 characters with same character (prompts for character)
- `R` - Replace forward with string (prompts for replacement text, replaces N chars where N = string length)

**Examples:**
- `rx` - Replace current character with 'x'
- `5ra` - Replace next 5 characters with 'aaaaa'
- `R` then type "hello" - Replace next 5 characters with "hello"

EOF

  ---

  ## ↩️ Undo/Redo

  EOF
  parse_section "vim-modes.conf" "## Undo"

  cat <<'EOF'

---

## 🚪 Exiting

- **ESC** - Return to NORMAL mode from any mode
- **$LEADER + ESC** - Exit vim mode entirely (back to normal Hyprland)
- **ALT + ESC** - Emergency exit (panic button)

---

## 💡 Tips

- Most motions work with counts: `5j`, `3w`, `10k`
- Operators take motions: `d3w` (delete 3 words), `c$` (change to end)
- Text objects: `diw` (delete inner word), `ciw` (change inner word)
- Marks work across workspaces and monitors!

EOF
}

# Parse bindd statements from a specific section
parse_section() {
  local file="$1"
  local section="$2"

  awk -v section="$section" '
    /^## / {
      if (substr($0, 4) == substr(section, 4)) {
        in_section = 1
      } else if (in_section) {
        exit
      }
      next
    }

    in_section && /^bindd/ {
      # Remove bind prefix: "bindd = " or "bindde = "
      sub(/^bindd[e]* = /, "")

      # Split on commas
      split($0, parts, ",")

      # Get mods, key, desc (and trim spaces)
      gsub(/^ +| +$/, "", parts[1])
      gsub(/^ +| +$/, "", parts[2])
      gsub(/^ +| +$/, "", parts[3])

      if (parts[1] == "") {
        printf "- **%s** - %s\n", parts[2], parts[3]
      } else {
        printf "- **%s+%s** - %s\n", parts[1], parts[2], parts[3]
      }
    }
  ' "$CONF_DIR/$file"
}

# Display help
show_help() {
  # Try glow first (nice markdown rendering)
  if command -v glow &>/dev/null; then
    generate_help | glow -p || generate_help | less -R
  # Fall back to bat with paging
  elif command -v bat &>/dev/null; then
    generate_help | bat --language markdown --style plain --paging always
  # Fall back to plain less
  else
    generate_help | less -R
  fi
}

show_help
