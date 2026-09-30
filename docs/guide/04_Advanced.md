## 📌 Marks

Marks allow you to save and jump to specific locations across workspaces and monitors.

### Mark Management

| Key             | Description                                    |
| --------------- | ---------------------------------------------- |
| `m<letter>`     | Save current position (e.g., `ma`, `mb`, `m1`) |
| `` `<letter> `` | Jump to a mark (e.g., `` `a ``, `` `b ``)      |
| `''` or ``` `` ```| Jump to the last focused window                 |
| `gm`            | List all saved marks                           |
| `dm<letter>`    | Delete mark (e.g., `dma`)                      |
| `dm+backspace`  | Clear all marks                                |

### Supported Marks

- `a-z` - Lowercase letter marks
- `A-Z` - Uppercase letter marks
- `0-9` - Number marks

**Example workflow:**

```text
ma          - Set mark 'a' at current location
(navigate elsewhere, switch workspaces)
`a          - Jump back to mark 'a'
gm          - List all marks
dma         - Delete mark 'a'
```

> [!NOTE]
> Marks are stored in tmpfs and cleared on reboot.

## 📋 Registers

Registers provide vim-like multi-clipboard management for storing and retrieving text.

### Using Registers

| Key    | Description                         |
| ------ | ----------------------------------- |
| `"ayy` | Yank current line to register **a** |
| `"add` | Delete line to register **a**       |
| `"ap`  | Paste from register **a**           |

Prefix any yank, delete, or paste operation with `"<register>`:

### Special Registers

| Register | Name       | Description                                   |
| -------- | ---------- | --------------------------------------------- |
| `""`     | Unnamed    | Default register, syncs with system clipboard |
| `"0`     | Yank       | Last yanked text, preserved during deletes    |
| `"_`     | Black Hole | Delete without affecting clipboard            |
| `"/`     | Search     | Last search term (read-only)                  |
| `"a-z`   | Named      | User-defined storage registers                |
| `"1-9`   | Numbered   | Available for additional storage              |

### Register Workflow Example

```text
yy          -- Yank line to unnamed ("") and yank (0) registers
dd          -- Delete line to unnamed (""), register 0 still has yank
"0p         -- Paste the yanked line (not the deleted one)
"ayy        -- Yank another line to register a
"_dd        -- Delete line without overwriting clipboard
"ap         -- Paste from register a
```

**Note:** Registers are stored in tmpfs and cleared on reboot.

## ✏️ Edit Text in Vim/Nvim

Sometimes the Vim-mode layer just doesn't cut it, for when you need macros and the full power of Vim.

Select any text and then activate this keybind to send the text to Vim/Nvim. From there, make your edits. Save and close to paste back.

| Key                  | Description                               |
| -------------------- | ----------------------------------------- |
| `leader + N` or `gn` | Open editor with selection in NORMAL mode |
| `leader + I` or `gi` | Open editor with selection in INSERT mode |

### Opening Full Vim/Neovim

Opens Vim/Nvim in a floating window. How it works:

- Automatically grabs selected text (if any), opens in NORMAL mode
- Edit with full Vim features and your personal config
- On save (`:w`), pastes content back to the focused window
- Perfect for complex form fields, multi-line edits, syntax highlighting, or writing a GitHub wiki in markdown

### Configuration

```lua
require("lua/plugins/hyprvim").setup({
  applications = {
    editor = "nvim", -- or "vim"
  },
})
```

### Flags

You can manually invoke this script outside of HyprVim. See [hyprland basics for quick access to hyprvim scripts](https://github.com/uhs-robert/hyprvim/tree/main/extras/hyprland-basics)

- `--ask-ext` - Prompt for file extension (enables syntax highlighting)
- `--keystroke-mode` - For terminals that don't accept clipboard paste
- `--insert-mode` - Start the editor in INSERT mode instead of NORMAL mode

<!-- Page Nav -->
<div align=right><a href="05_WhichKey.md"><i><b>>> Next: Go to WhichKey</b></i></a></div>
<!-- Page Nav -->
