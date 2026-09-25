# Quickshell Components

Minimal [Quickshell](https://quickshell.org) components that draw HyprVim's which-key HUD and prompt bar. Use them as a drop-in, or as a starting point for ones that match the rest of your shell. Both take their colors and font size from `~/.config/hyprvim/theme.conf`.

| File                  | IPC target         | Protocol                                                               |
| --------------------- | ------------------ | ---------------------------------------------------------------------- |
| `HyprvimWhichKey.qml` | `hyprvim_whichkey` | [WhichKey guide](../../docs/guide/05_WhichKey.md#-quickshell-frontend) |
| `HyprvimPrompt.qml`   | `hyprvim_prompt`   | [Modes guide](../../docs/guide/03_Modes.md#-quickshell-prompt)         |

## Installation

1. Copy the files you want into your Quickshell config directory, next to `shell.qml`.

2. Create them once from your `shell.qml`:

```qml
ShellRoot {
  HyprvimWhichKey {}
  HyprvimPrompt {}
}
```

3. Switch HyprVim to the Quickshell frontends:

```lua
require("lua/plugins/hyprvim").setup({
  which_key = {
    frontend = "quickshell",
    -- quickshell_ipc = "qs -c myshell ipc", -- when your config is not the default one
  },
  prompt = { frontend = "quickshell" },
})
```

4. Run `hyprctl reload`.

The which-key window uses the `hyprvim-whichkey` layer namespace, which HyprVim already gives a `no_anim` layer rule. It takes no keyboard focus and lets clicks through.

The prompt bar uses the `hyprvim-prompt` namespace and takes exclusive keyboard focus while it is open. `Tab`/`Shift+Tab` cycle completions, `Up`/`Down` (or `Ctrl+p`/`Ctrl+n`) recall history, `Enter` submits, and `Escape` hides the menu, then cancels.
