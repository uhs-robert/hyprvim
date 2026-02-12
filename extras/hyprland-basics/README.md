# Hyprland Basics

This extra provides a curated set of Hyprland keybindings and submaps that work well with a vim-first workflow. It is intended as a practical baseline you can copy and adapt rather than a full opinionated setup.

Repo: [hyprwm/Hyprland](https://github.com/hyprwm/Hyprland)

## What does this config do

The `keymap.conf` file defines a few focused submaps and a set of core management bindings:

- **Quick Access to HyprVim Scripts**: Direct access to HyprVim utilities outside of vim mode
  - `$HYPRVIM_LEADER+N` - Open vim/nvim editor anywhere (grabs selected text or opens empty)
  - `$HYPRVIM_LEADER+SHIFT+;` - Command mode as quick launcher (exits vim mode after command)
  - Additional examples: Marks operations, find/search, command mode with different return behaviors
- **Resize**: window resize controls with normal/fast/precise steps.
- **Move**: move floating windows with normal/fast/precise steps.
- **Windows**: window focus, workspace navigation, and common window actions.

It aims to give you practical Hyprland ergonomics without forcing a full personal keymap.

## Installation

1. Source the config from your `hyprland.conf`:

```ini
source = ~/.config/hypr/hyprvim/extras/hyprland-basics/keymap.conf
```

1. Reload Hyprland:

```bash
hyprctl reload
```

## Usage

- Use your `$HYPRVIM_LEADER` key to enter submaps (see `keymap.conf` for the exact bindings).
- Each submap has an `ESC` exit back to normal mode.
- Adjust or remove bindings as needed; this is a starter kit.

### Command Mode as Quick Launcher

The command mode binding uses the "after" pattern to control where you return after executing a command:

```bash
# Exit vim mode completely after commands (quick launcher behavior)
$HYPRVIM_COMMAND after reset && $HYPRVIM_COMMAND prompt

# Stay in NORMAL mode after commands (editor-like behavior)
$HYPRVIM_COMMAND after NORMAL && $HYPRVIM_COMMAND prompt

# Or omit "after" to use the default (NORMAL mode)
$HYPRVIM_COMMAND prompt
```

This is useful when using command mode for quick window management (`:float`, `:ws 3`, etc.) rather than text editing.
