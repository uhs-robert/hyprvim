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

Built on Hyprland’s native submap system, uses standard keyboard shortcut macros to emulate Vim-style navigation and text editing.

Navigate text, manage selections, and perform text operations using familiar Vim motions without leaving your current application. Think of it as a lightweight, system-wide Vim mode for your desktop.

<https://github.com/user-attachments/assets/735c4930-a527-4f3a-9f1a-308a9c047332>

## ✨ Features

> **📚 Full Reference:** For a complete, searchable reference of all features, visit the [Wiki](https://github.com/uhs-robert/hyprvim/wiki).

- **🚦 Vim Modes** - NORMAL, INSERT, VISUAL, V-LINE, and COMMAND modes
- **🧭 Navigation** - Character (`hjkl`), word (`w/b/e`), line (`0/$`), paragraph (`{}`), page (`Ctrl+d/u`), document (`gg/G`)
- **✂️ Operators** - Delete (`d`), change (`c`), yank (`y`) with motion and text object support
- **📝 Text Objects** - Inner/around word (`iw/aw`), inner/around paragraph (`ip/ap`)
- **🔢 Count Support** - Repeat any motion or operator (e.g., `5j`, `3dw`, `2yy`)
- **📌 Marks** - Save and jump to positions across workspaces/monitors (`m{mark}`, `` `{mark} ``)
- **📋 Registers** - Multi-clipboard with named (`"a-z`) and special registers (`"0`, `"_`, `"/`)
- **🔍 Find/Search** - Interactive search (`/`, `?`, `f`, `t`, `*`, `#`) with next/previous (`n/N`)
- **🔄 Replace** - Character (`r`) and string replacement (`R`)
- **↩️ Undo/Redo** - Standard undo/redo (`u`, `Ctrl+r`)
- **⌨️ Command Mode** - Execute commands (`:w`, `:q`, `:split`, `:float`, `:workspace`, `:reload`, etc.)
- **Open Vim/Nvim Anywhere** - Press `$HYPRVIM_LEADER + N` to open selected text in Vim/Nvim for complex editing. Save/close to paste.

> [!WARNING]
> Just like real Vim, you also need to know how to exit HyprVim: press `$HYPRVIM_LEADER + ESC` or `ALT+ESC`

<details>
<summary><h3>🍭 Extras</h3></summary>
<br>

[All extra configs](extras/) for a better global Vim experience.

To use the extras, refer to their respective documentation.

<!-- extras:start -->

| Tool            | Description                                                               | Extra                                            |
| --------------- | ------------------------------------------------------------------------- | ------------------------------------------------ |
| Hyprland Basics | Hyprland keymap kickstart config for HyprVim (Resize, Move, Windows, etc) | [extras/hyprland-basics](extras/hyprland-basics) |
| Keyd            | System-wide key remaps and tap/hold layers                                | [extras/keyd](extras/keyd)                       |
| Thunderbird     | Keybinds for Vim driven navigation                                        | [extras/thunderbird](extras/thunderbird)         |
| Wl-kbptr        | Keyboard-driven mouse cursor control on Wayland                           | [extras/wl-kbptr](extras/wl-kbptr)               |
| Vimium          | Vim-style navigation for web browsers                                     | [extras/vimium](extras/vimium)                   |
| Waybar Submap   | Waybar submap visual Indicator                                            | [extras/waybar](extras/waybar)                   |

If you'd like an extra config added, raise a feature request and I'll put it together.

<!-- extras:end -->
</details>

## 📦 Installation

### Prerequisites

| Name                                           | Description                                                               |
| ---------------------------------------------- | ------------------------------------------------------------------------- |
| [Hyprland](https://github.com/hyprwm/Hyprland) | Wayland compositor                                                        |
| Bash                                           | For shell scripts                                                         |
| `wl-clipboard`                                 | Wayland clipboard utilities (`wl-copy`, `wl-paste`)                       |
| `jq`                                           | JSON processor for parsing hyprctl output                                 |
| A terminal emulator                            | For the `gh` help viewer                                                  |
| A prompt tool                                  | One of: `rofi`, `wofi`, `tofi`, `fuzzel`, `dmenu`, `zenity`, or `kdialog` |

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

> [!TIP]
> **Verify installation**: Press `SUPER + ESC` and you should enter NORMAL mode. Press `gh` to view the help viewer.

## 🚀 Usage

> **📚 Full Reference:** For a complete reference of all keybindings and commands, visit the [Wiki](https://github.com/uhs-robert/hyprvim/wiki).

### Quick Start

Press `SUPER + ESCAPE` (or your configured leader key + activation key) to enter NORMAL mode.

#### Basic Workflow

1. **Enter NORMAL mode**: `SUPER + ESC`
2. **See all keybindings**: Press `gh` to show help
3. **Navigate**: Use `hjkl`, `w`, `b`, `e` to move around
4. **Select text/items**: Press `v` for visual mode, then navigate to select
5. **Edit**: Use operators like `d`, `c`, `y` with motions or in visual mode
6. **Return to insert**: Press `i`, `a`, or other insert commands
7. **Exit Vim mode**: Press `SUPER + ESC` again

### Marks

Save and jump to window positions across workspaces and monitors using `m{mark}` to set, `` `{mark} `` to jump.

> **📖 Learn more:** [Marks documentation in the wiki](https://github.com/uhs-robert/hyprvim/wiki/Advanced#-marks)

### Registers

Multi-clipboard management with named registers (`"a` - `"z`) and special registers (`""` unnamed, `"0` yank, `"_` black hole). Use `"{register}{operation}` (e.g., `"ayy` to yank to register a, `"ap` to paste from register a).

> **📖 Learn more:** [Registers documentation in the wiki](https://github.com/uhs-robert/hyprvim/wiki/Advanced#-registers)

### Commands

Press `:` in NORMAL mode to execute Vim-style commands. Common commands: `:w` (save), `:q` (quit), `:wq` (save & quit), `:split` (split window), `:float` (toggle floating), `:ws <num>` (switch workspace), `:reload` (reload Hyprland config).

> **📖 Learn more:** [Command Mode documentation in the wiki](https://github.com/uhs-robert/hyprvim/wiki/Modes#-command-mode)

### Access to Common Keyboard Shortcuts Too

HyprVim includes pragmatic pass-through bindings in NORMAL mode for better GUI interaction: `TAB`, `RETURN`, `CTRL+V/X/A/S/W/Z`. This enables seamless dialog navigation and clipboard operations without constantly switching to INSERT mode.

> [!WARNING]
> These may trigger unwanted actions in text editors. Use `i` to enter INSERT mode when editing text, or create override bindings by sourcing a custom config after HyprVim.

## ⚙️ Configuration

HyprVim sets a few defaults in `./init.conf`.

You can override any of these settings by creating your own `./settings.conf` in the `hyprvim` directory:

> [!TIP]
> To override or append keys in each submap, be sure to source your overriding keybindings after HyprVim

1. Copy the example config:
2. Edit `./settings.conf` to override any defaults from `./init.conf`

```bash
cd ~/.config/hypr/hyprvim
cp settings.conf.example settings.conf
```

> [!NOTE]
> For further customization, see extras: [waybar hyprsubmap indicator](./extras/waybar), [keyboard-driven mouse control](./extras/wl-kbptr), [other hyprland submaps](./extras/hyprland-basics), [web browser Vim navigation](./extras/vimium), and [even more](./extras).

## 🗑️ Uninstalling

Removing HyprVim from your system is a three step process:

Remove the source line from your `~/.config/hypr/hyprland.conf`:

```bash
# Remove this line:
source = ~/.config/hypr/hyprvim/init.conf
```

Delete the HyprVim directory:

```bash
rm -rf ~/.config/hypr/hyprvim
```

Reload your Hyprland configuration:

```bash
hyprctl reload
```

## 🤔 Where is the Visual Mode Indicator? (Waybar)

To see which Vim mode you're currently in, add the [Hyprland submap module](https://github.com/Alexays/Waybar/wiki/Module:-Hyprland#submap) to your [Waybar](https://github.com/Alexays/Waybar) configuration. This displays the active submap in your status bar.

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
