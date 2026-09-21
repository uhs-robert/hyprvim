# HyprVim Command Reference (`:`)

## File / Window

| Command | Description                                                  |
| ------- | ------------------------------------------------------------ |
| `:w`    | Save window (Ctrl+S) _(alias: `save`, `write`)_              |
| `:wq`   | Save, then close window _(alias: `save_quit`, `write_quit`)_ |
| `:q`    | Close window _(alias: `close`, `quit`)_                      |
| `:q!`   | Kill window _(alias: `kill`)_                                |
| `:qa`   | Close every window in workspace _(alias: `close_workspace`)_ |
| `:qa!`  | Kill every window in workspace _(alias: `kill_workspace`)_   |
| `:only` | Close every other window in workspace                        |

## Layout

| Command                             | Description                                        |
| ----------------------------------- | -------------------------------------------------- |
| `:split`                            | Preselect next window below _(alias: `sp`)_        |
| `:vsplit`                           | Preselect next window right _(alias: `vs`, `vsp`)_ |
| `:float`                            | Toggle floating _(alias: `f`)_                     |
| `:float on\|off\|toggle`            | Set the floating state                             |
| `:fullscreen`                       | Toggle fullscreen _(alias: `fs`)_                  |
| `:fullscreen fullscreen\|maximized` | Set the fullscreen mode                            |
| `:pin`                              | Toggle pin above workspaces                        |
| `:center`                           | Center window _(alias: `c`)_                       |
| `:pseudo`                           | Toggle pseudotiling                                |
| `:zorder top\|bottom`               | Alter the window z-order                           |
| `:swap DIR`                         | Swap window in a direction                         |

## Navigation

| Command            | Description                                          |
| ------------------ | ---------------------------------------------------- |
| `:window SELECTOR` | Focus a window by selector _(alias: `focus`)_        |
| `:workspace N`     | Focus a workspace _(alias: `ws`)_                    |
| `:workspace_next`  | Focus the next workspace _(alias: `tabn`, `tn`)_     |
| `:workspace_prev`  | Focus the previous workspace _(alias: `tabp`, `tp`)_ |
| `:monitor NAME`    | Focus a monitor _(alias: `mon`)_                     |
| `:special NAME`    | Toggle a special workspace                           |

## Window Move

| Command              | Description                                                    |
| -------------------- | -------------------------------------------------------------- |
| `:move X Y`          | Move window by pixels                                          |
| `:move_workspace N`  | Move window to a workspace _(alias: `move_to_workspace`)_      |
| `:move_workspace! N` | Move window to a workspace, keep focus here _(alias: `move!`)_ |
| `:move_monitor NAME` | Move window to a monitor _(alias: `send_monitor`)_             |
| `:move_special NAME` | Move window to a special workspace _(alias: `send_special`)_   |

## Window Resize

| Command            | Description                                   |
| ------------------ | --------------------------------------------- |
| `:resize_width N`  | Shrink the width _(alias: `resize`)_          |
| `:resize_height N` | Shrink the height _(alias: `vresize`)_        |
| `:size W H`        | Set the window size _(alias: `resize_exact`)_ |

## Window Properties

| Command                       | Description                                            |
| ----------------------------- | ------------------------------------------------------ |
| `:opacity A [I] [F] \| reset` | Set window opacity                                     |
| `:opacity_active V`           | Set active opacity _(alias: `active_opacity`)_         |
| `:opacity_inactive V`         | Set inactive opacity _(alias: `inactive_opacity`)_     |
| `:opacity_fullscreen V`       | Set fullscreen opacity _(alias: `fullscreen_opacity`)_ |
| `:dim`                        | Toggle window dimming                                  |
| `:dim on\|off`                | Set window dimming                                     |
| `:prop PROP VALUE`            | Set a window property                                  |

## Workspace

| Command        | Description                  |
| -------------- | ---------------------------- |
| `:rename NAME` | Rename the current workspace |
| `:gaps N`      | Set gaps in and out          |

## System

| Command     | Description                                                   |
| ----------- | ------------------------------------------------------------- |
| `:reload`   | Reload hyprland config _(alias: `r`)_                         |
| `:lock`     | Lock the session                                              |
| `:update`   | Update hyprvim                                                |
| `:logout`   | Log out of the session                                        |
| `:reboot`   | Restart the machine _(alias: `restart`)_                      |
| `:shutdown` | Power off _(alias: `poweroff`)_                               |
| `:picker`   | Pick a color to the clipboard _(alias: `hyprpicker`, `pick`)_ |

## Apps

| Command     | Description                                  |
| ----------- | -------------------------------------------- |
| `:edit`     | Open the editor in a terminal _(alias: `e`)_ |
| `:terminal` | Open a terminal _(alias: `t`)_               |
| `:help`     | Show the command reference _(alias: `h`)_    |

## Shell

| Command | Description                                          |
| ------- | ---------------------------------------------------- |
| `:!cmd` | Run a shell command and show its output, e.g. `:!ls` |

## Search / Replace

| Command | Description                                  |
| ------- | -------------------------------------------- |
| `:%s/`  | Trigger the editor find and replace (Ctrl+H) |

## Prompt

| Command  | Description                                                                                     |
| -------- | ----------------------------------------------------------------------------------------------- |
| `Tab`    | Complete; with fzf installed this opens a searchable menu, and a second Tab completes arguments |
| `Escape` | Dismiss the command bar without running anything                                                |
