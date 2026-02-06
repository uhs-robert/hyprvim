<p align="center">
  <img
    src="./assets/logo.png"
    width="auto" height="128" alt="logo" />
</p>
<hr/>
<p align="center">
  <a href="https://github.com/uhs-robert/HyprVim/stargazers"><img src="https://img.shields.io/github/stars/uhs-robert/HyprVim?colorA=192330&colorB=khaki&style=for-the-badge&cacheSeconds=4300" alt="Stargazers"></a>
  <a href="https://github.com/uhs-robert/HyprVim/issues"><img src="https://img.shields.io/github/issues/uhs-robert/HyprVim?colorA=192330&colorB=skyblue&style=for-the-badge&cacheSeconds=4300" alt="Issues"></a>
  <a href="https://github.com/uhs-robert/HyprVim/contributors"><img src="https://img.shields.io/github/contributors/uhs-robert/HyprVim?colorA=192330&colorB=8FD1C7&style=for-the-badge&cacheSeconds=4300" alt="Contributors"></a>
  <a href="https://github.com/uhs-robert/HyprVim/network/members"><img src="https://img.shields.io/github/forks/uhs-robert/HyprVim?colorA=192330&colorB=C799FF&style=for-the-badge&cacheSeconds=4300" alt="Forks"></a>
</p>

## 🌅 Overview

**HyprVim** brings the power of Vim keybindings to your entire Hyprland desktop environment.

Uses Hyprland's submap system to provide vim-style navigation and basic text editing that works across all applications in your Wayland session.

Navigate text, manage selections, and perform text operations using familiar Vim motions without leaving your current application. Think of it as a lightweight, system-wide vim mode for your desktop.

## ✨ Features

### Core Vim Modes

- **NORMAL Mode**: Primary navigation with `hjkl` movement, word motions (`w`/`b`/`e`), and operators
- **VISUAL Mode**: Character-wise visual selection
- **V-LINE Mode**: Line-wise visual selection
- **OPERATOR Modes**: Text operations with motions (d/c/y + motion/text-object)

### Navigation & Motion

- **Character**: `hjkl` for basic movement
- **Word**: `w`, `b`, `e`, `W`, `B`, `E` for word-based navigation
- **Line**: `0`, `^`, `$` for line start/end navigation
- **Page**: `Ctrl+d`, `Ctrl+u`, `Ctrl+f`, `Ctrl+b` for page scrolling
- **Document**: `gg`, `G` for document start/end
- **Extended Motions**: `g` prefix for additional movements (`ge`, `gt`, `gT`)

### Text Objects & Operators

- **Delete**: `d{motion}`, `dd`, `dw`, `diw`, `daw`
- **Change**: `c{motion}`, `cc`, `cw`, `ciw`, `caw` (enters insert mode)
- **Yank**: `y{motion}`, `yy`, `yw`, `yiw`, `yaw`
- **Inner/Around**: `iw`/`aw` for word text objects

### Mark System

- **Set Mark**: `m{a-z,A-Z,0-9}` - Set a mark at current window/workspace
- **Jump to Mark**: `` `{mark} `` or `'{mark}` - Jump to marked location
- **Delete Mark**: `dm{mark}` - Remove a mark

### Additional Operations

- **Numeric Repeats**: `2dw`, `3j`, `5w` - Repeat motions/operators (supports up to 999)
- **Undo/Redo**: `u` for undo, `Ctrl+r` for redo
- **Find**: `/`, `f`, `F`, `t`, `T` open find dialog; `n`/`N` for next/previous
- **Insert**: `i`, `a`, `I`, `A`, `o`, `O` - Enter insert mode at various positions
- **Paste**: `p`, `P` - Paste from clipboard
- **Delete Char**: `x`, `X` - Delete character under/before cursor

### Exit Strategy

- **Return to Parent**: `ESC` - Move up one mode level (e.g., VISUAL → NORMAL)
- **Toggle Vim Mode**: `$LEADER + ESC` - Toggle vim mode on/off from anywhere
- **Emergency Exit**: `ALT + ESC` - Immediate return to normal Hyprland bindings

## 📦 Installation

### Prerequisites

- **Hyprland** (Wayland compositor)
- **Bash** (for vim-marks.sh script)

### Quick Install

1. Clone this repository into your Hyprland config directory:

```bash
cd ~/.config/hypr
git clone https://github.com/uhs-robert/HyprVim.git
```

1. Add the following line to your `~/.config/hypr/hyprland.conf`:

```bash
source = ~/.config/hypr/HyprVim/init.conf
```

1. Set up your activation keybinding in `hyprland.conf`:

```bash
# Enter NORMAL mode with SUPER + ESCAPE
bind = SUPER, ESCAPE, submap, NORMAL
```

1. Reload your Hyprland configuration:

```bash
hyprctl reload
```

## 🚀 Usage

### Activation

Press `SUPER + ESCAPE` (or your configured leader key + ESCAPE) to enter NORMAL mode.

### Basic Workflow

1. **Enter NORMAL mode**: `SUPER + ESC`
2. **Navigate**: Use `hjkl`, `w`, `b`, `e` to move around
3. **Select text**: Press `v` for visual mode, then navigate to select
4. **Edit**: Use operators like `d`, `c`, `y` with motions or in visual mode
5. **Return to insert**: Press `i`, `a`, or other insert commands
6. **Exit vim mode**: Press `SUPER + ESC` again

### Example Operations

- `dw` - Delete word
- `3dw` - Delete 3 words
- `5j` - Move down 5 lines
- `10w` - Move forward 10 words
- `ciw` - Change inner word (deletes word and enters insert mode)
- `Vjjd` - Select 3 lines and delete them
- `yy` - Yank (copy) current line
- `gg` - Go to document start
- `ma` - Set mark 'a', then `` `a `` to jump back (see [using marks](#using-marks))

### Using Marks

Marks in HyprVim remember monitor, window, and workspace locations:

- `ma` - Set mark 'a' at current window/workspace
- `` `a `` - Jump to mark 'a'
- `dma` - Delete mark 'a'
- Supports: a-z, A-Z, 0-9

> [!NOTE]
> Works on multi-monitor setups.

## ⚙️ Configuration

### Customizing the Leader Key

By default, HyprVim uses `SUPER` (Windows key) as the leader. To change it, edit `~/.config/hypr/HyprVim/init.conf`:

```bash
# Change leader to ALT instead of SUPER
$LEADER = ALT
```

If you already define `$LEADER` elsewhere in your Hyprland config, comment out the line in `init.conf` to use your existing definition.

### Visual Mode Indicator (Waybar)

To see which vim mode you're currently in, add the [Hyprland submap module](https://github.com/Alexays/Waybar/wiki/Module:-Hyprland#submap) to your [Waybar](https://github.com/Alexays/Waybar) configuration. This displays the active mode in your status bar.

Add this to your `~/.config/waybar/config` in the modules section:

```json
"hyprland/submap": {
  "format": "<span size='11000' foreground='#F8B471'> </span>{}",
  "max-length": 20,
  "tooltip": false,
  "on-click": "hyprctl dispatch submap reset"
}
```

Then add `"hyprland/submap"` to your `modules-left`, `modules-center`, or `modules-right` array.

You can customize the icon, colors, and formatting to match your Waybar theme.

## ⚠️ Known Limitations

- No macros or registers (uses system clipboard)
- No visual block mode (`Ctrl+v`)
- Limited text object support (primarily word objects)
- Character find (`f/F/t/T`) mapped to application find dialog
- Effectiveness depends on application supporting standard shortcuts

### Extending HyprVim

You can extend HyprVim by adding new submaps or referencing the submaps in your own keybinds.

If you make an enhancement that would benefit the community then please submit a pull request.
