# Keyd

`keyd` is a system-wide key remapping daemon for Linux. It lets you define low-level key behaviors (taps, holds, combos) that apply to the whole desktop, before applications see the key events. A common use case for vim users is to remap `Caps Lock` to `Escape`. It's a great complement to HyprVim but not a replacement.

Keyd runs as root so scripting should be handled with care which is why many of the advanced HyprVim features were not added to it.

Repo: [rvaiya/keyd](https://github.com/rvaiya/keyd)

## What does this config do

The file in this folder provides a small, global set of quality-of-life remaps that enhance HyprVim.

The intent is to keep only the most basic features here (for example, quick arrow movement for short actions) so you can make small edits without activating a HyprVim submap.

Current QoL behaviors include:

- `Caps Lock` tap sends `Esc`.
- `Caps Lock` hold acts as `Ctrl`.
- `Tab` hold activates a lightweight "vim lite" layer (or toggle persistent mode - see below).
- **Persistent vim-lite mode**: While holding `Caps Lock` or `Control`, press `Backspace` to permanently enable vim-lite.
- **Global escape hatch**: `ALT+ESCAPE` exits vim-lite from any mode when persistent vim-lite is enabled.

When vim-lite is active, you have:

- **Basic motions**: `h/j/k/l`, `H/L` (line start/end), `0/$`
- **Word motions**: `w/b/e`
- **Paragraph motions**: `J/K/{/}`
- **Document motions**: `gg`, `G`
- **Page/scroll**: `CTRL+d/u` (page down/up), `CTRL+f/b` (scroll down/up)
- **Visual modes**: `v` (character-wise), `V` (line-wise)
  - Visual operations: `d` (delete), `y` (yank), `c` (change), `x` (delete)
- **Text objects**: `iw`, `aw`, `ip`, `ap` (with `c`, `d`, `y` operators in NORMAL mode)
- **Insert modes**: `i`, `a`, `o`, `O`, `I`, `A`
  - From INSERT mode: `CTRL+O` for one-shot NORMAL mode command
- **Basic operations**: `p` (paste), `x/X` (delete char), `u` (undo), `CTRL+r` (redo)
- **Word operations**: `C/D/Y` (change/delete/yank word)
- **Line operations**: `cc` (change line), `dd` (delete line), `yy` (yank line)
- **Operators with text objects** (NORMAL mode):
  - `c` (change): `ciw`, `caw`, `cip`, `cap`
  - `d` (delete): `diw`, `daw`, `dip`, `dap`
  - `y` (yank): `yiw`, `yaw`, `yip`, `yap`
- **Search**: `/` (find), `n/N` (next/prev), `*/#` (search word under cursor)

This file is intentionally minimal, just keybinds and no scripting.

## Installation

1. Install keyd (see the repo above for distro-specific packages).
2. Copy the config to `/etc/keyd/`:
   - If this folder contains `default.conf`, use:
     `sudo cp extras/keyd/default.conf /etc/keyd/default.conf`
   - If it contains a named config (for example `hyprvim.conf`), use:
     `sudo cp extras/keyd/hyprvim.conf /etc/keyd/`
3. Enable and start the service:
   - `sudo systemctl enable --now keyd`
4. Reload after changes:
   - `sudo systemctl restart keyd`

## Usage

- Keep bindings minimal and avoid duplicating HyprVim features.
- Prefer a few universal motion keys (like arrows) for quick, transient actions.
- If you want personal tweaks, keep them in your own keyd config so this repo stays generic.
