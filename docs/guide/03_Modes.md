HyprVim includes many modes from Vim. The goal is for your muscle memory from Vim to carry over seamlessly.

Some Hyprland and desktop-specific conveniences were added for a better experience and to handle edge cases.

## 👁️ Visual Mode

### Entering VISUAL from NORMAL

| Key       | Description                 |
| --------- | --------------------------- |
| `V`       | Enter visual mode           |
| `SHIFT+V` | Enter line-wise visual mode |

### In VISUAL Mode

- Use navigation keys (`h`, `j`, `k`, `l`, `w`, `b`, etc.) to extend selection
- Press `y` to yank selection
- Press `d` to delete selection
- Press `c` to change selection (delete and enter insert)
- Press `g` to access G-VISUAL for go commands like (`gg`, `gG`, `gs`, `gn`, and `gi`)
- Press `ESC` to return to NORMAL mode

> [!NOTE]
> `gs` surrounds the selected text with character(s)
>
> `gn` and `gi` send the selected text to Vim/Nvim for editing in NORMAL or INSERT mode, respectively

## ✏️ Insert Mode

### Entering INSERT from NORMAL

| Key            | Description                   |
| -------------- | ----------------------------- |
| `I`            | Insert before cursor          |
| `A`            | Insert after cursor           |
| `SHIFT+A`      | Insert at line end            |
| `SHIFT+I`      | Insert at line start          |
| `O`            | Open line below               |
| `SHIFT+O`      | Open line above               |
| `CTRL+O`       | Open line below (Shift+Enter) |
| `CTRL SHIFT+O` | Open line above (Shift+Enter) |

> [!TIP]
> In a chat app? Use [CTRL+O] to append a new line without sending your message.

### In INSERT Mode

- All keys will pass through except for `ESC`. You may type normally, just like in Vim.
- Keep in mind, a submap is still active while in INSERT mode. So, only your `submap_universal` keys from Hyprland will work while in a submap.
- Press `ESC` to return to NORMAL mode.

> [!NOTE]
> [Learn more about bind flags here](https://wiki.hypr.land/Configuring/Basics/Binds/#bind-flags) to make keybinds global to all submaps.

## ⌨️ Command Mode

### Entering COMMAND from NORMAL

| Key | Description          |
| --- | -------------------- |
| `:` | Insert before cursor |

Press `:` from NORMAL mode to enter COMMAND mode.

Command mode provides powerful window management, workspace navigation, and system control.

Press `Escape` to dismiss the bar without running anything. While the completion menu is open, `Escape` closes the menu first and leaves you at the prompt.

Press `Tab` to complete. With [fzf](https://github.com/junegunn/fzf) installed, the prompt bar expands into a searchable menu of commands and their descriptions; `Tab` and `Shift+Tab` move through the list. Pressing `Tab` again after a command name completes its arguments: live workspace and monitor lists, window properties, and the accepted range for free-form values such as `:opacity` (0-1). Searching matches descriptions as well as names, so typing `close` finds `:q`, `:qa` and `:only`. Aliases are searchable but listed beside the command they point at instead of as separate entries. Without fzf, `Tab` cycles through prefix matches instead.

### File Operations

| Command | Description                                 |
| ------- | ------------------------------------------- |
| `:w`    | Save file (Ctrl+S)                          |
| `:wq`   | Save and quit                               |
| `:q`    | Quit window (allows app to prompt for save) |
| `:q!`   | Force quit window (kill immediately)        |
| `:qa`   | Quit all windows in current workspace       |
| `:qa!`  | Force quit all windows in current workspace |

### Window Management

| Command                  | Description                            |
| ------------------------ | -------------------------------------- |
| `:split`, `:sp`          | Split window horizontally              |
| `:vsplit`, `:vsp`, `:vs` | Split window vertically                |
| `:only`                  | Close all other windows (keep current) |

### Window States

| Command              | Description                  |
| -------------------- | ---------------------------- |
| `:float`, `:f`       | Toggle floating mode         |
| `:fullscreen`, `:fs` | Toggle fullscreen            |
| `:pin`               | Pin window to all workspaces |
| `:center`, `:c`      | Center floating window       |
| `:pseudo`            | Toggle pseudo-tiling         |

### Workspace Navigation

| Command        | Description                                |
| -------------- | ------------------------------------------ |
| `:workspace_next`, `:tabn`, `:tn` | Next workspace          |
| `:workspace_prev`, `:tabp`, `:tp` | Previous workspace      |
| `:workspace <num>`, `:ws` | Switch to workspace number (e.g., `:ws 3`) |
| `:move_workspace <num>` | Move window to workspace (e.g., `:move_workspace 5`) |

### System Control

| Command         | Description            |
| --------------- | ---------------------- |
| `:reload`, `:r` | Reload Hyprland config |
| `:lock`         | Lock screen            |
| `:logout`       | Exit Hyprland (asks first) |

### Visual

| Command            | Description                                       |
| ------------------ | ------------------------------------------------- |
| `:opacity <value>` | Set window opacity 0.0-1.0 (e.g., `:opacity 0.8`), or adjust it with `:opacity +0.1` |

### App Launching

| Command       | Description               |
| ------------- | ------------------------- |
| `:edit`, `:e` | Open the editor in a terminal |
| `:terminal`, `:t` | Open a terminal           |

### Utilities

| Command       | Description                              |
| ------------- | ---------------------------------------- |
| `:help`, `:h` | Show keybindings help                    |
| `:%s`, `:s`   | Open native find/replace dialog (Ctrl+H) |

> [!NOTE]
> `%s` only opens the native find/replace dialog. Implementing a scripted find/replace is not only unreliable but also less efficient and could break formatting. You may need to [TAB] through the interface or [drive the mouse cursor with your keyboard](https://github.com/uhs-robert/hyprvim/tree/main/extras/wl-kbptr) to complete the operation.

### Command Examples

```
:w              - Save current file
:wq             - Save and close window
:float          - Toggle floating mode for current window
:ws 3           - Switch to workspace 3
:move_workspace 5 - Move current window to workspace 5
:opacity 0.7    - Set window to 70% opacity
:opacity -0.1   - Make the window 10% more transparent
:opacity 0.8 address:0x1234 - Set another window's opacity without focusing it
:reload         - Reload Hyprland configuration
```

<!-- Page Nav -->
<div align=right><a href="04_Advanced.md"><i><b>>> Next: Go to Advanced</b></i></a></div>
<!-- Page Nav -->
