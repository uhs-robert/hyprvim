## Configuration

This section assumes that you have installed to the [default location per the installation instructions](https://github.com/uhs-robert/hyprvim/tree/main#-installation).

HyprVim can be configured via an optional `opts` table that you may pass when calling the `setup()` function.

All [default options are listed here](https://github.com/uhs-robert/hyprvim/tree/main#-configuration) and the [raw config code can be found here](../../config.lua).

## Option Groups

### `keys`

Controls the chords used to enter and exit HyprVim.

- `leader` defaults to `SUPER`
- `activate` defaults to `V`
- `exit` defaults to `ESCAPE`

The activation chord starts NORMAL mode from Hyprland. The exit chord leaves HyprVim entirely.

`V` is mnemonic for Vim mode, but some setups already bind `SUPER + V` to clipboard history. If the chord does nothing after install, it is taken by something else. Set `activate` to any free key:

```lua
require("hyprvim").setup({ keys = { activate = "ESCAPE" } })
```

### `applications`

Controls the external programs HyprVim launches.

- `terminal` is used for prompts, the help viewer, and the open-editor flow
- `term_flags` lets you override terminal launch flags (useful for terminals not covered by the built-in table)
- `lock` is the command run by `:lock`
- `editor` is the editor launched by the open-editor feature

### `notifications`

Controls desktop notifications.

- `all = true` enables every notification category
- `marks` shows mark events
- `warnings` shows recoverable warnings
- `errors` shows hard failures

### `prompt`

Controls Tab completion in the `:` command bar.

- `completion_menu = true` opens an [fzf](https://github.com/junegunn/fzf) menu listing every command with its description; the bar grows for the menu and shrinks back on selection. A second `Tab` completes arguments, listing live workspaces and monitors where they apply and showing the accepted values otherwise
- `completion_menu = false`, or fzf not installed, falls back to cycling through prefix matches
- `completion_height` is the pixel height the bar grows to (default 400)
- `history = true` recalls earlier entries with the arrow keys. Each prompt keeps its own file under `$XDG_STATE_HOME/hyprvim/history`, trimmed to `history_size` entries (default 200). The command bar only records entries it recognises, so a typo is not offered back

### `updates`

> [!NOTE]
> Does not apply to users who install from the AUR. Updates are handled by your package manager.

For user who manually install, controls the self-update channel.

- `stable` uses the latest GitHub release
- `nightly` tracks git HEAD
- `off` disables update checks
- Any other string pins a release tag or commit SHA

### `which_key`

Controls the WhichKey HUD. The WhichKey applies to HyprVim submaps as well as your own custom submaps.

- `enabled` turns the HUD on or off
- `frontend` picks the renderer: `"eww"` (default) or `"quickshell"`
- `quickshell_ipc` is the command prefix used to reach Quickshell (default `"qs ipc"`)
- `delay_ms` controls how quickly the HUD appears
- `vim_delay_ms` gives operator-pending submaps a separate delay
- `position` anchors the panel
- `auto_show.disabled` suppresses specific submaps
- `auto_show.enabled` whitelists only the listed submaps

### `keymaps`

Use `keymaps` to override or extend built-in binds. The entries are evaluated inside `hyprland.lua`, so local helper functions are in scope.

```lua
require("lua/plugins/hyprvim").setup({
  keymaps = {
    NORMAL = {
      { "w", function() my_custom_word() end, { desc = "custom word" } },
      { "SUPER + X", function() my_extra_action() end, { desc = "extra action" } },
    },
  },
})
```

Matching keys replace the built-in bind. New keys are appended.

### `commands`

Use `commands` to add or override `:` commands.

```lua
require("lua/plugins/hyprvim").setup({
  commands = {
    browser = function() hl.dispatch(hl.dsp.exec_cmd("firefox")) end,
    files = function() hl.dispatch(hl.dsp.exec_cmd("thunar")) end,
  },
})
```

### `enable_debug`

Turns on verbose logging to the system journal. Useful when you need to inspect failure paths.

### `max_count`

Sets the upper bound for count accumulation. Counts above this are clamped.

## Related Features

### WhichKey

WhichKey is enabled from the `which_key.enabled` option. Requires `eww`, or Quickshell with `which_key.frontend = "quickshell"`.

See [WhichKey](05_WhichKey.md) for setup and styling details.

### Mode Indicator

HyprVim does not ship a mode indicator. Use the one provided by Waybar if you want a status-bar indicator:

- [Waybar Hyprsubmap Indicator](https://github.com/uhs-robert/hyprvim/tree/main/extras/waybar)

### Extras

HyprVim also includes optional extras for a broader desktop workflow:

- [Hyprland Basics](https://github.com/uhs-robert/hyprvim/tree/main/extras/hyprland-basics)
- [Keyboard-driven Mouse Control](https://github.com/uhs-robert/hyprvim/tree/main/extras/wl-kbptr)
- [Web Browser Vim Navigation](https://github.com/uhs-robert/hyprvim/tree/main/extras/vimium)

See [all extras](https://github.com/uhs-robert/hyprvim/tree/main/extras) for the full list.

<div align=right><a href="02_Basics.md"><i>>> Next: Go to Basics</i></a></div>
