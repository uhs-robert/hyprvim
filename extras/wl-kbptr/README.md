# wl-kbptr

`wl-kbptr` (Wayland Keyboard Pointer) lets you control the mouse pointer with the keyboard on Wayland. It can jump the cursor to regions and trigger clicks, which makes it a great companion for HyprVim when you want mouse-like precision without leaving the keyboard.

Repo: [moverest/wl-kbptr](https://github.com/moverest/wl-kbptr)

## What does this config do

This config adds a Hyprland submap (`Cursor`) that provides keyboard-driven pointer control:

- Jump the cursor using `wl-kbptr` in floating or tile modes (with optional click).
- Move the pointer with `wlrctl` using `hjkl`, with fast/precise variants on Shift/Ctrl.
- Trigger left/middle/right clicks from the keyboard.
- Exit cleanly back to normal bindings.

It is designed to be a lightweight extra that saves the day when you just need to click something.

## Installation

1. Install `wl-kbptr` and `wlrctl` for your distro.
2. Ensure your compositor supports the required wlroots protocols.
3. Source this config from Hyprland:

```ini
source = ~/.config/hypr/HyprVim/extras/wl-kbptr/wl-kbptr.conf
```

Reload Hyprland:

```bash
hyprctl reload
```

## Usage

- Enter the `Cursor` submap (see your leader bindings in the config).
- Use `h/j/k/l` to move the pointer, `Shift` for faster motion, `Ctrl` for precision.
- Use `Space` for click, `s`/`d`/`f` for left/middle/right click.
- Use `a`/`q` (and their Shift/Ctrl variants) to jump the cursor via `wl-kbptr`.
- Press `Esc` to exit the submap.
