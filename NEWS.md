# HyprVim Release Notes

## [v1.2.3](https://github.com/uhs-robert/hyprvim/releases/tag/v1.2.3) — 2026-02-18

### New Features

- **Live register contents in which-key HUD**: The `GET-REGISTER` submap now shows live previews of all named, numbered, default, yank, and search registers (truncated to 40 chars).
- **Stale-close watchdog for which-key render**: A 40ms watchdog closes a stale HUD if the render token has advanced and the window has not changed, eliminating wrong-submap flashes.

### Bug Fixes

- Fixed which-key HUD disappearing during rapid submap transitions. Replaced PID-based cancellation with a token-based self-cancellation model; added a retry loop for empty binds, focused-monitor caching, and earlier token validation.
- Removed which-key trigger from mark operations (`M`, `Ctrl+M`, `'`, `` ` ``); which-key is now limited to operator-pending submaps only.
- Which-key show delay is now applied only to operator-pending submaps (`D-MOTION`, `C-MOTION`, `Y-MOTION`, `G-MOTION`, `R-CHAR`); all other submaps show instantly.

---

## [v1.2.2](https://github.com/uhs-robert/hyprvim/releases/tag/v1.2.2) — 2026-02-18

### New Features

- **Instant which-key for mark submaps**: The which-key HUD now appears immediately (no delay) when entering mark-related submaps, since they are transient and benefit from instant feedback.

### Bug Fixes

- Stale marks are now auto-deleted when their target window is closed, preventing jumps to dead windows.
- The which-key HUD is now auto-hidden when a new window opens, avoiding a stale overlay on window changes.
- Which-key binding is now placed before the `catchall` in all submaps, fixing cases where the trigger was swallowed.
- Fixed which-key rendering for mark submaps.

### Improvements

- Which-key trigger changed from `?` to `SPACE` across all submaps for faster, more natural access.

---

## [v1.2.1](https://github.com/uhs-robert/hyprvim/releases/tag/v1.2.1) — 2026-02-18

### New Features

- **Which-key SCSS overrides**: Users can now drop a `whichkey.scss` into the config dir to customize the HUD appearance without touching upstream styles.

### Bug Fixes

- Count is now correctly preserved through `D`, `C` and `Y` operators and cleared on cancel or sub-entry exit, preventing count leakage across operations.

### Improvements

- Which-key show delay increased to 200ms for a less intrusive feel.
- Theme system simplified with generic variables and auto-apply, reducing duplication across palette definitions.

---

## [v1.2.0](https://github.com/uhs-robert/hyprvim/releases/tag/v1.2.0) — 2026-02-13

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
