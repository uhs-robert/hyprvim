# Waybar Submap

This extra shows the active Hyprland submap in Waybar using the built-in `hyprland/submap` module. It is meant to pair with HyprVim-style submaps so you always know which mode you are in.

Repo: [Alexays/Waybar](https://github.com/Alexays/Waybar)

## What does this config do

The `basic-modules.jsonc` file provides a minimal module definition for `hyprland/submap` with:

- A vim icon prefix (requires [Nerd Font](https://www.nerdfonts.com/font-downloads))
- A visible submap name (truncated)
- A click action to reset back to the default submap (for emergencies)

## Installation

1. Merge the module snippet into your Waybar config (JSONC).

2. Add `hyprland/submap` to a module list, e.g.:

```jsonc
"modules-left": [
  "hyprland/submap",
  "hyprland/workspaces",
  "clock"
]
```

3. Reload Waybar.

## Usage

- The module shows the current submap name whenever you are inside a Hyprland submap.
- Click the module to reset back to the default submap.
- Adjust the icon, color, or placement to match your bar layout.
