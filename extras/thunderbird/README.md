# Tbkeys

`tbkeys` is a Thunderbird add-on that lets you define custom keybindings using a JSON map. It is aimed at power users who want Vim-like navigation and actions inside Thunderbird without leaving the keyboard. It focuses on app navigation; actual text editing should be handled by HyprVim.

Repo: [wshanks/tbkeys](https://github.com/wshanks/tbkeys)

## What does this config do

The `keys.json` file provides a Vim-flavored keymap for Thunderbird's main 3-pane window:

- Vim-style motions for the folder tree and message list by simulating arrow/home/end/page keys (`h/j/k/l`, `gg`, `G`, `ctrl+u`, `ctrl+d`).
- Fast focus jumps to the folder list, thread list, and message pane (`g f`, `g i`, `g m`).
- Common mail actions mapped to single keys or small chords (reply, reply-all, forward, delete, archive, mark read/unread, toggle panes, quick filter, compose).
- Unsets a handful of default single-key shortcuts to avoid accidental triggers.

## Installation

1. Install the `tbkeys` add-on in Thunderbird (the full version is required).
2. Open the Add-ons Manager, select `tbkeys`, and open its preferences.
3. Paste the contents of `extras/thunderbird/keys.json` into the **Main window key bindings** field.
4. Save the preferences and test in the main Thunderbird window.

## Usage

- Use `shift+h` and `shift+l` to focus the folder list or thread list quickly.
- Use `h/j/k/l` to move in the folder tree and message list.
- Use `gg`/`G` and `ctrl+u`/`ctrl+d` for top/bottom and page navigation.
- Use `g f`, `g i`, `g m` to focus the folder list, thread list, or message pane.
- Use `dd` to delete, `x` to archive, `r`/`R` to reply/reply-all, `f` to forward, `c` to compose.
- Use `t f`/`t m` to toggle the folder and message panes, and `/` to toggle the quick filter bar.
- Use `u` to undo.
- Use `q` to close an open message tab and refresh mail.
