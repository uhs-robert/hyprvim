# HyprVim Release Notes

## Unreleased

### New Features

- **WhichKey on Quickshell** ([#25](https://github.com/uhs-robert/hyprvim/issues/25)): set `which_key.frontend = "quickshell"` and the HUD is drawn by your running [Quickshell](https://quickshell.org) config instead of eww, so it can match the rest of your shell. HyprVim resolves the same items as before, writes them to a JSON file and calls the `hyprvim_whichkey` IPC target; `which_key.quickshell_ipc` points it at a specific instance. The protocol is in the [WhichKey guide](docs/guide/05_WhichKey.md#-quickshell-frontend), and [extras/quickshell](extras/quickshell) has a plain reference component. eww stays the default.
- **Prompt bar on Quickshell** ([#27](https://github.com/uhs-robert/hyprvim/issues/27)): set `prompt.frontend = "quickshell"` and the `:`, find and replace prompts open in your Quickshell config instead of a terminal, with the same completions, argument candidates and history. `:!cmd` output shows in the bar too. HyprVim writes a JSON spec, calls the `hyprvim_prompt` IPC target through `which_key.quickshell_ipc`, and gets the line back through the same callback the terminal uses, so both share one history file; with no instance answering, the terminal bar opens as before. The protocol is in the [Modes guide](docs/guide/03_Modes.md#-quickshell-prompt), and [extras/quickshell](extras/quickshell) has a plain reference component.
- **Commands say what they need**: `Enter` on a command still missing a required argument keeps the line and shows its usage, e.g. `opacity needs: <A [I] [F] | reset [WINDOW]>`, instead of running and failing. The completion menu shows each command's usage between its name and description when there is room. Argument specs take `optional = true`, including in your own `commands`, and the Quickshell prompt spec carries `min_args` and `usage` per completion and `optional` per argument, see the [Modes guide](docs/guide/03_Modes.md#spec).
- **`:silent !cmd`** launches a shell command detached without showing its output, and Tab after `:silent !` completes command names like `:!` does.

## [v4.0.1](https://github.com/uhs-robert/hyprvim/releases/tag/v4.0.1) - 2026-09-22

### Bug Fixes

- **HyprVim no longer hijacks your config's modules** ([#23](https://github.com/uhs-robert/hyprvim/issues/23)): internal modules used generic names like `config` and `lib.utils`, and loading HyprVim evicted and replaced the user's own modules of the same name, so a later `require("config")` in a keybind callback got HyprVim's. Internals now live under `hyprvim.*`, resolved from the install directory without touching `package.path` ([#24](https://github.com/uhs-robert/hyprvim/pull/24)).

> [!NOTE] Only code that required HyprVim internals by their bare names, like `require("vim")`, is affected; use `require("hyprvim.vim")` instead. `require("hyprvim").setup(...)` is unchanged.

## [v4.0.0](https://github.com/uhs-robert/hyprvim/releases/tag/v4.0.0) - 2026-09-21

### Breaking Changes

**`:move` is pixels only.** `:move X Y` nudges the window; send it to a workspace with `:move_workspace N` (was `:move N`). `:move 5` now says what it expected instead of guessing.

**Removed commands.** `:term` is now `:terminal` (or `:t`), `:tab N` is `:workspace N` (or `:ws N`), and `:exit` is gone since `Escape` dismisses the bar.

**Session commands ask first.** `:shutdown`, `:reboot` and `:logout` confirm with `y/N` in the bar. Add a bang, e.g. `:shutdown!`, to skip the question.

**Renamed, old names still work.** Commands now read as families, and every previous name below resolves as an alias:

| Now | Was |
| --- | --- |
| `:window` | `:focus` |
| `:move_workspace`, `:move_workspace!` | `:move_to_workspace`, `:move!` |
| `:move_monitor`, `:move_special` | `:send_monitor`, `:send_special` |
| `:workspace_next`, `:workspace_prev` | `:tabn`, `:tabp` |
| `:resize_width`, `:resize_height`, `:size` | `:resize`, `:vresize`, `:resize_exact` |
| `:opacity_active`, `:opacity_inactive`, `:opacity_fullscreen` | `:active_opacity`, `:inactive_opacity`, `:fullscreen_opacity` |
| `:edit` | `:e` |

### New Features

- **Tab completion.** With [fzf](https://github.com/junegunn/fzf) installed, `Tab` opens a searchable menu of every command and what it does; search matches descriptions too, so `close` finds `:q` and `:only`. A second `Tab` completes arguments: open windows by class and title, workspaces, monitors, layouts, and for `:set` every Hyprland option plus its current value, default and range. Without fzf, `Tab` cycles matches as before.
- **History.** `Up` recalls earlier commands, kept per prompt under `$XDG_STATE_HOME/hyprvim/history` with private permissions. Typos are not recorded.
- **Chaining.** `:float on | center | opacity 0.9` runs several commands in order and stops at the first that fails.
- **Relative values.** `:opacity -0.1`, `:opacity_active +0.05` and `:gaps +2` adjust from the current value.
- **Target any window.** A trailing selector acts on another window without focusing it: `:opacity 0.8 address:0x1234`, `:tag +work class:firefox`.
- **Any Hyprland option.** `:set OPTION VALUE` reaches every setting, and `:layout` switches between dwindle, master, scrolling and monocle.
- **Layout commands.** `:layoutcmd` runs the commands your layout provides, listing only the ones the active layout answers.
- **New commands.** Groups (`:group`, `:group_next`, `:group_prev`, `:group_window N`, `:group_move`, `:group_lock`), `:next` and `:prev`, `:workspace_monitor`, `:workspace_swap`, `:tag`, `:untag`, `:swallow`, `:renderer_reload`, `:submap` (your own submaps included), `:marks`, `:reboot`, `:help COMMAND`, and `:3` to focus workspace 3.
- **Clearer errors.** Commands check their arguments and say what they expected, and an unknown command suggests the nearest one.
- **Richer user commands.** `commands` entries in `setup()` can be a table with a description and argument completions, so your own commands sit in the menu alongside the built-in ones.
- **Nix support.** A flake and Home Manager module, thanks to [@Battguy](https://github.com/Battguy) in [#7](https://github.com/uhs-robert/hyprvim/pull/7).

New options under `prompt`: `completion_menu`, `completion_height`, `history` and `history_size`.

### Bug Fixes

- **Prompt bar restores its size** when another window takes focus while the completion menu is open.
- **`:reload` and `:logout!` no longer block the compositor.** Both shelled out synchronously on Hyprland's thread.

### Internal

- `docs/command-help.md` and `:help` are generated from the command tables, and `scripts/check-commands` keeps them consistent, so the reference can no longer drift from what the commands do.

## [v3.0.0](https://github.com/uhs-robert/hyprvim/releases/tag/v3.0.0) - 2026-09-17

### Breaking Changes

**Default activation chord is now `SUPER + V`, exit is `SUPER + ESCAPE`**

The old `SUPER + ESCAPE` / `SUPER + SHIFT + ESCAPE` pair had no mnemonic plus the exit chord was a bit long/complex. You know it's bad when you're the creator and not even you use the default config! `V` is easy to remember, it stands for Vim mode.

> [!NOTE] Some setups may already bind `SUPER + V` to clipboard history; if yours does, then set `keys.activate` to another free key.

## [v2.1.0](https://github.com/uhs-robert/hyprvim/releases/tag/v2.1.0) - 2026-09-14

### New Features

- **Diagonal cursor movement**: chord binds (for example `H+K`) move the cursor omni-directionally across every speed tier, in addition to the cardinal `H`/`J`/`K`/`L` axes. Both key orderings are bound, since Hyprland chords are order-sensitive.
- **QuickClick submap**: `LEADER+;` gives one-shot label-jump clicking without entering the full Cursor submap. Cursor mode also gains reordered click mappings and right-click variants for `wl-kbptr`.
- **Submap groups sorted into their own section**: nested submaps now sort to the bottom of the which-key list by name instead of being interleaved with plain bindings.
- **Submap exit keys hidden from the list**: `ESC` and `BS` already appear in the HUD footer, so the per-submap exit rows are gone.
- **Configurable row density**: new `$row_padding_y` in `theme.conf` tunes the vertical padding on each key row.

### Bug Fixes

- **Temp files stay private**: clipboard reads, register previews and prompt input used `os.tmpname`, leaving mode-0644 files in `/tmp` holding whatever you copied or typed, under a name any local user could predict. They now live under `$XDG_RUNTIME_DIR/hyprvim/tmp` (0700).
- **Center layouts scale to the item count**: a six-item submap no longer renders as four near-empty columns; the column count follows how many rows actually fit the monitor.
- **Overflow stays on the configured edge**: a long list on a top-anchored HUD no longer flips to bottom-center.
- **Vertical layout kept on more monitors**: panel height was overestimated and rotated monitors reported their unrotated height, so the column fallback fired on screens where the list fit fine. Chrome and row height now come from the measured widget.
- **`BackSpace` labels normalized to `BS`**: non-exit bindings on that key rendered the raw Hyprland name.

### Internal

- Dead which-key panel-width plumbing removed, along with a file handle leaked on every submap change.

## [v2.0.1](https://github.com/uhs-robert/hyprvim/releases/tag/v2.0.1) - 2026-06-16

### Bug Fixes

- **Replace and open-editor no longer break later keystrokes**: `r`/`R` replace and `vim-open-editor` used `wtype`, which swapped Hyprland's active keymap and left subsequent native `send_shortcut` injections (the delete/change cut, paste) silently dropped until reset. Both now use Hyprland's native `send_shortcut` for all key emulation.
- **Updater skips redundant stable updates**: the auto-updater no longer re-fetches and checks out when HEAD is already at or past the latest release tag.

### Removed

- **`wtype` dependency**: no longer required; all keybind emulation now runs through native `send_shortcut`.
- **`input_method` config option**: replace always uses native injection with clipboard paste.

## [v2.0.0](https://github.com/uhs-robert/hyprvim/releases/tag/v2.0.0) - 2026-06-13

### Breaking Changes

- **Lua rewrite for Hyprland 0.55+**: HyprVim is now a modular Lua plugin for Hyprland's new Lua config format. Your config must be migrated to Lua. Legacy `.conf` users should stay on the [`legacy-conf`](https://github.com/uhs-robert/hyprvim/tree/legacy-conf) branch.
- **Install path moved to XDG data dir**: HyprVim now installs to `$XDG_DATA_HOME` instead of the config dir.
- **User theme/config moved to `$XDG_CONFIG_HOME`**: Custom themes and overrides now live under the XDG config directory.

### New Features

- **Auto-updater**: New update checker with `stable`, `nightly`, and `pinned` channels, plus handling for package-managed and detached nightly installs.
- **User-defined commands**: Define your own `:` commands via config. Adds 10+ built-in commands (opacity/dim via `set_prop`, resize, size, gaps, tab, move-pixel, and more) with string workspace selectors. In NORMAL mode, type `:help` to see them all.
- **Command completion cycling**: Repeated `Tab` cycles through completions in the command/prompt bar.
- **User keybind overrides**: New `keymaps` config lets you override submap binds.
- **Public API from `setup()`**: `setup()` now exposes a public API for programmatic use.
- **`*` register and live previews**: Adds the `*` selection register, live register-content previews in the which-key HUD, fallback register labels, numbered-register cycling on yank, and count multipliers for paste.
- **Clipboard persistence**: The system clipboard is now preserved across vim-mode sessions.
- **Configurable replace input**: Non-blocking replace prompts with a configurable input method.
- **Editor returns to submap**: `vim-open-editor` returns to the originating submap on exit.
- **Per-submap which-key timing**: Per-submap `delay_ms` and a global `vim_delay_ms`, with instant HUD display and a slide animation for the which-key layer.
- **New extras**: Tridactyl config and docs; Thunderbird `tbkeys` gains count and visual-mode support. The `wl-kbptr` extra has been removed.

### Improvements

- Bash scripts replaced by Lua modules throughout (window rules, terminal-class detection, theme apply, editor I/O, updater).
- Terminal-based prompt bar replaces the external menu tool; prompts and clipboard I/O migrated to async APIs supporting concurrent prompts.
- Declarative `Submap.define` API with a submap registry and aliases; submap transitions routed through a central Submap API.
- Custom terminal flags and user tables are deep-merged.
- Documentation moved from the GitHub wiki into the repo under `docs/guide` (allowing guides to be version controlled).

### Performance

- **In-process dispatch**: Logic runs natively in Hyprland's Lua runtime instead of spawning a shell (and often `jq`/`hyprctl`) per keystroke, cutting latency across motions, operators, and submap transitions.
- **Leaner which-key HUD**: Register items are built without `jq`, monitor geometry is passed straight to the renderer, redundant shell cleanup calls are removed, and hidden-HUD closes are skipped.
- **Fewer shell round-trips**: Find batches state-file access and the visual-line setup shell call is dropped.
