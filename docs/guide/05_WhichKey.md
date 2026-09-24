## 🛟 WhichKey

The WhichKey HUD shows the available bindings for the current submap, including their descriptions.

<https://github.com/user-attachments/assets/7fdb5c63-48a5-4f8f-9280-0da408503d6e>

<p align=center><i>It works for HyprVim submaps and your own submaps too.</i></p>

## ⚙️ Configuration

### Requirements

| Tool                                  | Description                                         |
| ------------------------------------- | --------------------------------------------------- |
| [eww](https://github.com/elkowar/eww) | Renders the HUD overlay (`frontend = "eww"`)        |
| [Quickshell](https://quickshell.org)  | Renders the HUD instead (`frontend = "quickshell"`) |
| `jq`                                  | Builds the item list and the Quickshell payload     |
| `socat`                               | Listens for Hyprland submap changes                 |

You need one of the two renderers, not both.

### Setup

Enable WhichKey from your Lua config:

```lua
require("lua/plugins/hyprvim").setup({
  which_key = {
    enabled = true,
    frontend = "eww",
    quickshell_ipc = "qs ipc",
    delay_ms = 0,
    vim_delay_ms = 300,
    position = "bottom-right",
    auto_show = {
      disabled = { "NORMAL", "VISUAL", "V-LINE", "INSERT" },
      enabled = nil,
    },
  },
})
```

The important knobs are:

- `enabled` turns the HUD on or off
- `frontend` picks the renderer: `"eww"` (default) or `"quickshell"`, see [Quickshell Frontend](#-quickshell-frontend)
- `quickshell_ipc` is the command prefix used to reach Quickshell (default `"qs ipc"`)
- `delay_ms` controls the normal submap delay
- `vim_delay_ms` gives operator-pending submaps a different delay
- `position` anchors the HUD
- `auto_show.disabled` suppresses specific submaps
- `auto_show.enabled` whitelists only the listed submaps

### Usage

The HUD auto-shows when you enter a submap and hides when you leave it. Press `SPACE` to toggle it manually from any mode.

HyprVim also binds `leader + SHIFT + SLASH` to toggle WhichKey when the feature is enabled.

Only bindings with a description appear in the HUD. For your own binds in `keymaps`, set a `desc` in the bind options:

```lua
require("lua/plugins/hyprvim").setup({
  keymaps = {
    NORMAL = {
      { "H", function() my_left() end, { desc = "Move left" } },
      { "J", function() my_down() end, { desc = "Move down" } },
      { "SUPER + X", function() my_extra() end, { desc = "Extra action" } },
    },
  },
})
```

Descriptions that start with `+` render in a distinct accent color. HyprVim uses this for submap transition rows.

### Overflow Handling

If the HUD would exceed the available screen height, it automatically switches to a multi-column centered layout.

That layout still has a vertical limit, so keep custom descriptions concise when possible.

## 🧩 Quickshell Frontend

With `frontend = "quickshell"`, HyprVim does not draw anything itself. It resolves the same items the eww HUD shows, writes them to a JSON file and asks your running [Quickshell](https://quickshell.org) config to show them over IPC, so the HUD can match the rest of your shell.

For a working start, copy the reference component from [extras/quickshell](../../extras/quickshell) into your config.

### IPC

Your Quickshell config implements one `IpcHandler` with target `hyprvim_whichkey`:

| Function             | Called when                                                               |
| -------------------- | ------------------------------------------------------------------------- |
| `open(path: string)` | A submap's HUD should appear; read the JSON payload at `path` and show it |
| `close()`            | The HUD should disappear                                                  |

HyprVim runs `<quickshell_ipc> call hyprvim_whichkey open <path>` and `<quickshell_ipc> call hyprvim_whichkey close`. `quickshell_ipc` is passed to `sh` unquoted, so it can hold flags (`qs -c myshell ipc`, `qs ipc --pid 1234`) or a wrapper script (`~/.config/hypr/scripts/qs-ipc`) that finds the right instance.

The calls run in a background process, never on Hyprland's event loop. A `show` that no instance answers leaves the HUD marked hidden, so the next toggle tries again.

### Payload

The payload lives at `$XDG_RUNTIME_DIR/hyprvim/whichkey.json` and is replaced atomically before each `show`, so read it fresh every time (for example `FileView.reload()`).

```json
{
  "version": 1,
  "submap": "DELETE",
  "title": "DELETE",
  "position": "bottom-right",
  "screen": "eDP-1",
  "columns": 1,
  "items": [
    { "key": "d", "desc": "Delete line", "group": false },
    { "key": "i", "desc": "+Inner", "group": true }
  ],
  "footer": [
    { "key": "ESC", "desc": "close" },
    { "key": "BS", "desc": "back" }
  ],
  "theme": {
    "bg_core": "#070C13",
    "primary": "#7FA3C9",
    "base_font_size": "12px"
  }
}
```

| Field      | Meaning                                                                                                                                               |
| ---------- | ----------------------------------------------------------------------------------------------------------------------------------------------------- |
| `version`  | Payload format version, bumped on incompatible changes                                                                                                |
| `submap`   | Submap name, or `GLOBAL` for the global binds                                                                                                         |
| `title`    | Text for the title (`Global Bindings` for `GLOBAL`)                                                                                                   |
| `position` | `which_key.position`, switched to `bottom-center` or `top-center` when a single column would not fit                                                  |
| `screen`   | Monitor name the HUD belongs on (the focused monitor)                                                                                                 |
| `columns`  | Suggested column count, 1 to 4; items fill row by row                                                                                                 |
| `items`    | Rows in display order: `key` (normalized, e.g. `C-x`, `S-TAB`), `desc`, and `group` for rows that enter another submap (their `desc` starts with `+`) |
| `footer`   | Exit keys, which are left out of `items`                                                                                                              |
| `theme`    | Every `$variable` from `theme.conf`, as strings                                                                                                       |

The same auto-show rules, delays, `set_skip`/`set_delay` flags and toggle apply to both frontends.

## 🎨 Styling

WhichKey styling still uses its own theme files. HyprVim reads them from `~/.config/hyprvim/`.

On first run, HyprVim creates:

- `~/.config/hyprvim/theme.conf`
- `~/.config/hyprvim/whichkey.scss`

Edit `theme.conf` for colors and base sizing:

```conf
# ~/.config/hyprvim/theme.conf

$bg_core: #070C13;
$bg_border: #5D8BBB;
$fg: #F7EDE1;
$primary: #7FA3C9;
$secondary: #D6CE7C;
$accent: #FFA0A0;
$info: #B0C8DE;

$base_font_size = 12px
$row_padding_y = 2px
```

`$row_padding_y` is the vertical padding on each key row. Lower it (for example `1px` or `0px`) for a more compact list.

Edit `whichkey.scss` for layout and spacing overrides:

```scss
// ~/.config/hyprvim/whichkey.scss

.wk {
  border-radius: 16px;
}

.wk {
  padding: 6px 10px;
}

.wk-key {
  color: $accent;
}
```

Changes are picked up on the next `hyprctl reload`. `whichkey.scss` only applies to eww; a Quickshell frontend gets the `theme.conf` values in the payload's `theme` field and styles itself.

## ☎️ Calling It Yourself

You can also trigger the HUD from your own Hyprland binds if you need custom integration. The internal entrypoints live under `scripts/` and `whichkey/render.lua`.

For normal use, the built-in `SPACE` toggle and automatic submap display are enough.

Otherwise you may call it manually like so:

```lua
hl.bind("SHIFT + SLASH", function() require("lua.plugins.hyprvim").whichkey.toggle() end, { desc = "Open WhichKey" } )
```

<!-- Page Nav -->
<div align=right><a href="06_Tips-and-Tricks.md"><i><b>>> Next: Go to Tips and Tricks</b></i></a></div>
<!-- Page Nav -->
