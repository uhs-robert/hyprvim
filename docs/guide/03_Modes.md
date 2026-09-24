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

Separate commands with `|` to run several at once, e.g. `:float on | center | opacity 0.9`. They run in order and stop at the first that fails; write `\|` for a literal pipe. Shell (`:!`, `:silent !`) and substitute (`:%s/`) lines are never split.

`:!cmd` runs a shell command and shows what it printed, and `:silent !cmd` launches it detached without showing anything, e.g. `:silent !firefox`. Tab after `!` completes command names from your `$PATH`.

A bare number focuses that workspace, so `:3` goes to workspace 3. `:set` completes values as well as names: Tab after an option shows its current value, its default and its range, or its choices.

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

## 🧩 Quickshell Prompt

With `prompt.frontend = "quickshell"`, HyprVim hands every prompt (`:`, `f`/`t`/`/`, `R` and the `y/N` confirmations) to your running [Quickshell](https://quickshell.org) config instead of spawning a terminal. HyprVim still runs everything: the bar only edits a line and hands it back, and `:!cmd` output is produced by HyprVim and only displayed by the bar. When no instance answers, the terminal bar opens instead.

For a working start, copy the reference component from [extras/quickshell](../../extras/quickshell) into your config.

### IPC

Your Quickshell config implements one `IpcHandler` with target `hyprvim_prompt`:

| Function                     | Called when                                                                                            |
| ---------------------------- | ------------------------------------------------------------------------------------------------------ |
| `open(path: string): string` | A prompt or command output should appear; read the JSON spec at `path`. Return `ok` once it is shown |
| `close()`                    | The prompt should go away; treat it as a cancel                                                        |

HyprVim runs `<which_key.quickshell_ipc> call hyprvim_prompt open <path>` from a background shell. Anything other than `ok` on stdout, including an instance without the target, opens the terminal bar instead.

### Answering

Every spec carries a `callback`, a Lua call such as `_hv_cb_7("quickshell")`. Dispatch it exactly once, when the prompt ends:

1. On submit, write the entered line to `result_path` (no trailing newline needed).
2. On cancel, write nothing.
3. Run `hyprctl dispatch '<callback>'`.

An empty or missing result file is a cancel. HyprVim then reads the line, records it in the history file and runs it, the same way it does for the terminal bar. For an `output` spec there is nothing to write; dispatch the callback when the output is dismissed so HyprVim can restore the mode.

### Spec

The spec is written to `$XDG_RUNTIME_DIR/hyprvim/tmp/` before each `open` and removed after the callback runs.

```json
{
  "version": 1,
  "kind": "input",
  "title": "Command",
  "label": ":",
  "text": "",
  "chain": true,
  "completions": [
    { "name": "float", "desc": "toggle floating", "takes_args": true, "aliases": ["f"] }
  ],
  "args": {
    "float": [{ "hint": "", "values": [["on", "force floating"]], "source": "" }],
    "window": [{ "hint": "window selector", "values": [], "source": "hyprctl clients ..." }]
  },
  "shell_source": "compgen -c | sort -u",
  "history": ["float on", "ws 3"],
  "result_path": "/run/user/1000/hyprvim/tmp/prompt-input-...",
  "callback": "_hv_cb_7(\"quickshell\")",
  "theme": { "bg_core": "#070C13", "primary": "#7FA3C9", "base_font_size": "12px" }
}
```

| Field          | Meaning                                                                                                                                                                                              |
| -------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `version`      | Spec format version, bumped on incompatible changes                                                                                                                                                  |
| `kind`         | `input` for a prompt, `output` for `:!cmd` output                                                                                                                                                    |
| `title`        | `Command`, `Find`, `Replace`, `Shell` or `Prompt`                                                                                                                                                    |
| `label`        | Prompt text drawn before the line, e.g. `:` or `Log out? [y/N] `                                                                                                                                     |
| `text`         | Initial line; for `output`, the command that ran                                                                                                                                                     |
| `chain`        | Complete only the command after the last `\|`, as the line may chain several                                                                                                                         |
| `completions`  | Command names with a description, whether they take arguments (insert a trailing space) and aliases (searchable, not listed)                                                                         |
| `args`         | Per command, one entry per argument position: `hint` for free-form values, `values` as `[value, description]` pairs, and `source`, a shell command printing `value<TAB>description[<TAB>insert]` lines |
| `shell_source` | Shell command listing executables, for completion after `!` or `silent !`; empty when not offered                                                                                                    |
| `history`      | Earlier entries of this prompt, oldest first                                                                                                                                                         |
| `result_path`  | Where the entered line goes                                                                                                                                                                          |
| `output_path`  | `output` only: file holding the command's combined stdout and stderr, with `[exit N]` appended on failure                                                                                            |
| `callback`     | Lua call to dispatch once, see above                                                                                                                                                                 |
| `theme`        | Every `$variable` from `theme.conf`, as strings                                                                                                                                                      |

Run a `source` with `bash -c`, setting `HV_ARGS` to the arguments typed before its position, and only when that position is being completed: it may be slow. The third field, when present, is what gets inserted instead of the first.

`:!cmd` output is collected before the bar opens, so a long-running command shows nothing until it exits, and interactive programs need a terminal (`:terminal`). Commands with no output never open the bar.

<!-- Page Nav -->
<div align=right><a href="04_Advanced.md"><i><b>>> Next: Go to Advanced</b></i></a></div>
<!-- Page Nav -->
