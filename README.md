<p align="center">
  <img
    src="./assets/logo.png"
    width="auto" height="128" alt="logo" />
</p>
<hr/>
<p align="center">
  <a href="https://github.com/uhs-robert/hyprvim/stargazers"><img src="https://img.shields.io/github/stars/uhs-robert/hyprvim?colorA=192330&colorB=khaki&style=for-the-badge&cacheSeconds=4300" alt="Stargazers"></a>
  <a href="https://github.com/uhs-robert/hyprvim/issues"><img src="https://img.shields.io/github/issues/uhs-robert/hyprvim?colorA=192330&colorB=skyblue&style=for-the-badge&cacheSeconds=4300" alt="Issues"></a>
  <a href="https://github.com/uhs-robert/hyprvim/contributors"><img src="https://img.shields.io/github/contributors/uhs-robert/hyprvim?colorA=192330&colorB=8FD1C7&style=for-the-badge&cacheSeconds=4300" alt="Contributors"></a>
  <a href="https://github.com/uhs-robert/hyprvim/network/members"><img src="https://img.shields.io/github/forks/uhs-robert/hyprvim?colorA=192330&colorB=C799FF&style=for-the-badge&cacheSeconds=4300" alt="Forks"></a>
</p>

## 🌅 Overview

**HyprVim** brings the power of Vim keybindings and motions to your entire Hyprland desktop environment.

Uses Hyprland's submap system to provide vim-style navigation and basic text editing that works across all applications in your Wayland session.

Navigate text, manage selections, and perform text operations using familiar Vim motions without leaving your current application. Think of it as a lightweight, system-wide vim mode for your desktop.

<https://github.com/user-attachments/assets/15d6690e-1981-422d-862a-5f919af98cee>

## ✨ Features

### 🚦 Vim Modes

- **NORMAL Mode**: Primary navigation with `hjkl` movement, word motions (`w`/`b`/`e`), and operators
- **INSERT Mode**: Text insertion with `ESCAPE` bound to return to normal mode
- **VISUAL Mode**: Character-wise visual selection
- **V-LINE Mode**: Line-wise visual selection
- **COUNT Modifier**: Perform operations with `{count}` modifier prefix to repeat actions (e.g., `6dw` to delete next 6 words)
- **OPERATOR Modes**: Operators with motions `{operator}` + `{motion}`/`{text-object)` (e.g., `diw` for delete in word)
  - _Operators Supported:_ `d`, `c`, `y`
  - _Motions Supported:_ `i`, `a`
  - _Text Objects Supported:_ `w`, `p`

### 🧭 Navigation & Motion

- **Character**: `hjkl` for basic movement
- **Word**: `w`, `b`, `e`, `W`, `B`, `E` for word-based navigation
- **Line**: `0`, `^`, `$` for line start/end navigation
- **Paragraph**: `{`, `}` for paragraph start/end navigation
- **Page**: `CTRL+d`, `CTRL+u`, `CTRL+f`, `CTRL+b` for page scrolling
- **Document**: `gg`, `G` for document start/end
- **Extended Motions**: `g` prefix for additional movements (`ge`, `gt`, `gT`)

### 📝 Text Objects & Operators

- **Delete**: `d{motion}`, `dd`, `dw`, `diw`, `daw`, `dip`, `dap`
- **Change**: `c{motion}`, `cc`, `cw`, `ciw`, `caw`, `cip`, `cap` (enters insert mode)
- **Yank**: `y{motion}`, `yy`, `yw`, `yiw`, `yaw`, `yip`, `yap`
- **Inner/A**: `iw`/`aw` for word text objects, `ip`/`ap` for paragraph text objects

### 📌 Mark System

- **Set/Jump/Delete**: `m{a-z,A-Z,0-9}`, `` `{mark} ``, `'{mark}`, `dm{mark}`
- Remembers window/workspace locations across monitors

### 📋️ Register System

- **Named**: `"{a-z}` - 26 named registers
- **Special**: `""` (unnamed/clipboard), `"0` (yank), `"_` (black hole), `"/` (search)
- **Usage**: `"ayy` (yank to a), `"ap` (paste from a), `"_dd` (delete without clipboard)

> [!NOTE]
> Registers stored in tmpfs, cleared on reboot. See [Using Registers](#register-usage) for detailed examples.

### 🛟 Additional Operations

- **Help**: `gh` - Show keybindings viewer
- **Repeats**: `2dw`, `3j`, `5w` (up to 999)
- **Undo/Redo**: `u`, `Ctrl+r`
- **Find**: `/`, `?`, `f`, `F`, `t`, `T`, `*`, `#`, `n`, `N`
- **Replace**: `r{char}`, `R` (with prompt)
- **Insert**: `i`, `a`, `I`, `A`, `o`, `O`
- **Paste**: `p`, `P`
- **Delete Char**: `x`, `X`
- **Indent**: `>`, `<`

### ‼️ Exiting Vim Mode

Just like real Vim, you also need to know how to exit HyprVim.

- **Return to Normal**: `ESC` - (e.g., VISUAL → NORMAL), NORMAL passes ESC to application
- **Toggle Vim Mode**: `$LEADER + ESC` - Toggle vim mode on/off from anywhere
- **Emergency Exit**: `ALT + ESC` - Immediate return to normal Hyprland bindings

<details>
<summary>🍭 Extras</summary>
<br>

[All extra configs](extras/) for a better global vim experience.

To use the extras, refer to their respective documentation.

<!-- extras:start -->

| Tool            | Description                                                               | Extra                                            |
| --------------- | ------------------------------------------------------------------------- | ------------------------------------------------ |
| Hyprland Basics | Hyprland keymap kickstart config for HyprVim (Resize, Move, Windows, etc) | [extras/hyprland-basics](extras/hyprland-basics) |
| Keyd            | System-wide key remaps and tap/hold layers                                | [extras/keyd](extras/keyd)                       |
| Thunderbird     | Keybinds for vim driven navigation                                        | [extras/thunderbird](extras/thunderbird)         |
| Wl-kbptr        | Keyboard-driven mouse cursor control on Wayland                           | [extras/wl-kbptr](extras/wl-kbptr)               |
| Vimium          | Vim-style navigation for web browsers                                     | [extras/vimium](extras/vimium)                   |
| Waybar Submap   | Waybar submap visual Indicator                                            | [extras/waybar](extras/waybar)                   |

If you'd like an extra config added, raise a feature request and I'll put it together.

<!-- extras:end -->
</details>

## 📦 Installation

### Prerequisites

| Name                                           | Description              |
| ---------------------------------------------- | ------------------------ |
| [Hyprland](https://github.com/hyprwm/Hyprland) | Wayland compositor       |
| Bash                                           | For shell scripts        |
| A terminal emulator                            | For the `gh` help viewer |

### Quick Install

- Clone this repository into your Hyprland config directory:

```bash
cd ~/.config/hypr
git clone https://github.com/uhs-robert/hyprvim.git
```

- Add the following line to your `~/.config/hypr/hyprland.conf`:

```bash
source = ~/.config/hypr/hyprvim/init.conf
```

- Set up any settings in `~/.config/hypr/hyprvim/settings.conf`, see [configuration](#️-configuration)

- Reload your Hyprland configuration:

```bash
hyprctl reload
```

## 🚀 Usage

### Activation

Press `SUPER + ESCAPE` (or your configured leader key + activation key) to enter NORMAL mode.

### Basic Workflow

1. **Enter NORMAL mode**: `SUPER + ESC`
2. **See all keybindings**: Press `gh` to show help
3. **Navigate**: Use `hjkl`, `w`, `b`, `e` to move around
4. **Select text/items**: Press `v` for visual mode, then navigate to select
5. **Edit**: Use operators like `d`, `c`, `y` with motions or in visual mode
6. **Return to insert**: Press `i`, `a`, or other insert commands
7. **Exit vim mode**: Press `SUPER + ESC` again

### Quick Reference

#### Basic operations

`dw` (delete word), `3dw` (delete 3 words), `5j` (move down 5 lines), `ciw` (change word), `Vjjd` (delete 3 lines), `yy` (yank line), `gg` (document start)

#### Marks

`ma` (set), `` `a `` (jump), `dma` (delete) - works across monitors

#### Registers

`"ayy` (yank to a), `"ap` (paste from a), `"_dd` (delete without clipboard), `"0p` (paste last yank)

<a id="register-usage"></a>

<details>
<summary>📋️ Using Registers</summary>
<br>

Registers provide vim-like clipboard management with multiple storage locations:

**Basic Usage:**

- `"ayy` - Yank current line to register a
- `"add` - Delete word to register a
- `"ap` - Paste from register a

**Special Registers:**

- `""` (unnamed) - Default register, always syncs with system clipboard
- `"0` (yank) - Last yanked text, preserved during deletes
- `"_` (black hole) - Delete without affecting any register or clipboard
- `"/` (search) - Last search term (read-only)

**Workflow Example:**

```text
1. yy          - Yank line to unnamed register and register 0
2. dd          - Delete line to unnamed register (register 0 still has yank)
3. "0p         - Paste the yanked line (not the deleted one)
4. "ayy        - Yank another line to register a
5. "_dd        - Delete line without overwriting clipboard
6. "ap         - Paste from register a
```

> Registers are stored in `$XDG_RUNTIME_DIR/hyprvim/registers/` (tmpfs) and are cleared on reboot.

<!-- extras:end -->
</details>

## ⚙️ Configuration

HyprVim sets a few defaults in `./init.conf`.

You can override any of these settings by creating your own `./settings.conf` in the `hyprvim` directory:

- Copy the example config:

```bash
cd ~/.config/hypr/hyprvim
cp settings.conf.example settings.conf
```

- Edit `./settings.conf` to override any defaults from `./init.conf`

> [!TIP]
> To override or append keys in each submap, just source your overriding keybindings after HyprVim

## 🤔 Where is the Visual Mode Indicator? (Waybar)

To see which vim mode you're currently in, add the [Hyprland submap module](https://github.com/Alexays/Waybar/wiki/Module:-Hyprland#submap) to your [Waybar](https://github.com/Alexays/Waybar) configuration. This displays the active submap in your status bar.

Refer to the [waybar extras](/extras/waybar) for detailed installation instructions.

On that note, just check out [all the extras too](/extras)! You never know what you might find.

## ⚠️ Known Limitations

- No macros
- No visual block mode (`Ctrl+v` or `Ctrl+q`)
- Limited text object support (word and paragraph only)
- Registers/marks are stored in tmpfs (not persistent across reboots)
- Find operations use interactive prompts and application find dialogs
- Effectiveness depends on application supporting standard keyboard shortcuts

## 📏 Extending HyprVim

You can extend HyprVim by adding new submaps or referencing the submaps in your own keybinds after sourcing HyprVim.

If you make an enhancement that you think would benefit the community then please submit a pull request and I'll be happy to review it.
