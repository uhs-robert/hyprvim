# HyprVim Release Notes

## v1.2.1 — 2026-02-18

### New Features

- **Which-key SCSS overrides**: Users can now drop a `whichkey.scss` into the config dir to customize the HUD appearance without touching upstream styles.

### Bug Fixes

- Count is now correctly preserved through `D`, `C` and `Y` operators and cleared on cancel or sub-entry exit, preventing count leakage across operations.

### Improvements

- Which-key show delay increased to 200ms for a less intrusive feel.
- Theme system simplified with generic variables and auto-apply, reducing duplication across palette definitions.

---

## v1.2.0 — 2026-02-13

### New Features

- **Which-key HUD**: New eww-based HUD displaying available keybindings per submap, driven by Hyprland events. Opt-in via `$HYPRVIM_WHICHKEY = 1` (requires eww).
- **Targeted HUD skip support**: Individual submaps can suppress the which-key HUD for specific transitions.
- **Vim surround**: Add `ys`, `ds`, and `cs` operations to wrap, delete, and change surrounding characters.

### Bug Fixes

- Quoted all `send_shortcut` arguments in `vim-find.sh` and `vim-line-motion.sh`, fixing broken search, word operations, and line motions.
- Eliminated stale which-key HUD using hard PID-based cancellation.
- Fixed HUD appearing on the wrong monitor.
- Fixed HUD resize flash when cycling between submaps.
- Submap state is now preserved correctly when dismissing the which-key overlay.
