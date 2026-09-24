# Quickshell WhichKey

A minimal [Quickshell](https://quickshell.org) component that renders the HyprVim WhichKey HUD. Use it as a drop-in, or as a starting point for a HUD that matches the rest of your shell.

It implements the `hyprvim_whichkey` IPC target described in the [WhichKey guide](../../docs/guide/05_WhichKey.md#-quickshell-frontend), reads the payload HyprVim writes, and takes its colors and font size from `~/.config/hyprvim/theme.conf`.

## Installation

1. Copy `HyprvimWhichKey.qml` into your Quickshell config directory, next to `shell.qml`.

2. Create it once from your `shell.qml`:

```qml
ShellRoot {
  HyprvimWhichKey {}
}
```

3. Switch HyprVim to the Quickshell frontend:

```lua
require("lua/plugins/hyprvim").setup({
  which_key = {
    frontend = "quickshell",
    -- quickshell_ipc = "qs -c myshell ipc", -- when your config is not the default one
  },
})
```

4. Run `hyprctl reload`.

The window uses the `hyprvim-whichkey` layer namespace, which HyprVim already gives a `no_anim` layer rule. It takes no keyboard focus and lets clicks through.
