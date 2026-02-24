# Tbkeys

`tbkeys` is a Thunderbird add-on that lets you define custom keybindings using a JSON map. It is aimed at power users who want Vim-like navigation and actions inside Thunderbird without leaving the keyboard. It focuses on app navigation; actual text editing should be handled by HyprVim.

Repo: [wshanks/tbkeys](https://github.com/wshanks/tbkeys)

## What does this config do

The `keys.json` file provides a Vim-flavored keymap for Thunderbird's main 3-pane window:

- Vim-style motions for the folder tree and message list by simulating arrow/home/end/page keys (`h/j/k/l`, `gg`, `G`, `ctrl+u`, `ctrl+d`), all with count support (e.g. `5j` moves down 5).
- Count accumulation via digit keys (`1-9` set the count, `0` appends a zero).
- Fast focus jumps to the folder list, thread list, and message pane (`g f`, `g i`, `g m`).
- Visual mode toggled by `v`: motions become range selections while active.
- Tab navigation with `[` (next tab) and `]` (previous tab).
- Common mail actions mapped to single keys or small chords (reply, reply-all, forward, delete, archive, mark read/unread/junk/not-junk, toggle panes, quick filter, compose).
- `j`/`k` scroll the message body when the message pane is focused.
- Unsets a handful of default single-key shortcuts to avoid accidental triggers.

## Installation

1. Install the `tbkeys` add-on in Thunderbird (the full version is required).
2. Open the Add-ons Manager, select `tbkeys`, and open its preferences.
3. Paste the contents of `extras/thunderbird/keys.json` into the **Main window key bindings** field.
4. Save the preferences and test in the main Thunderbird window.

## Usage

- Use `shift+h` and `shift+l` to focus the folder list or thread list quickly.
- Use `h/j/k/l` to move in the folder tree and message list; prefix with a count (e.g. `5j`) to repeat.
- Use `j`/`k` to scroll the message body when the message pane is focused.
- Use `gg`/`G` and `ctrl+u`/`ctrl+d` for top/bottom and page navigation.
- Use `g f`, `g i`, `g m` to focus the folder list, thread list, or message pane.
- Use `[`/`]` to cycle through open tabs.
- Use `v` to enter visual mode (motions extend the selection); press `esc` or `v` again to exit.
- Use `dd` to delete, `x` to archive, `r`/`R` to reply/reply-all, `f` to forward, `c` to compose.
- Use `m r`/`m u` to mark read/unread, `m j`/`m J` to mark as junk/not-junk, `m R` to mark all read.
- Use `t f`/`t m` to toggle the folder and message panes, and `/` to toggle the quick filter bar.
- Use `u` to undo.
- Use `q`, `ctrl+h`, `ctrl+c`, or `ctrl+x` to close a tab and refresh mail.
- Use `o` or `ctrl+l` to open the selected message.
