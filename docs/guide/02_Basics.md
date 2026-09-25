Basic commands required for Vim movement, navigation, operators, counts, and text editing.

## 💻️ Enter Vim Mode

**Default:** The activation chord is `SUPER + V`, which enters NORMAL mode from Hyprland.

> [!IMPORTANT]
> This is configured in `setup({ keys = { ... } })` per [Configuration](01_Configuration.md#configuration).

## 📍 Navigation

| Key         | Description                              |
| ----------- | ---------------------------------------- |
| `H`         | Move left (with count)                   |
| `BACKSPACE` | Move left (with count)                   |
| `J`         | Move down (with count)                   |
| `K`         | Move up (with count)                     |
| `L`         | Move right (with count)                  |
| `SHIFT+H`   | Jump to line start                       |
| `SHIFT+L`   | Jump to line end                         |
| `SHIFT+J`   | Move down and to line start (with count) |
| `SHIFT+K`   | Move up and to line start (with count)   |
| `CTRL+H`    | Ctrl left (with count)                   |
| `CTRL+J`    | Ctrl down (with count)                   |
| `CTRL+K`    | Ctrl up (with count)                     |
| `CTRL+L`    | Ctrl right (with count)                  |

### Text Movement

| Key                  | Description                    |
| -------------------- | ------------------------------ |
| `B`                  | Move back word (with count)    |
| `E`                  | Move to word end (with count)  |
| `W`                  | Move forward word (with count) |
| `SHIFT+B`            | Move back WORD (with count)    |
| `SHIFT+E`            | Move to WORD end (with count)  |
| `SHIFT+W`            | Move forward WORD (with count) |
| `SHIFT+BRACKETLEFT`  | Jump to paragraph start ({)    |
| `SHIFT+BRACKETRIGHT` | Jump to paragraph end (})      |

### Line Movement

| Key           | Description                        |
| ------------- | ---------------------------------- |
| `SHIFT+MINUS` | Jump to first non-blank (^)        |
| `SHIFT+6`     | Jump to first non-blank (^)        |
| `0`           | Jump to line start or append digit |
| `SHIFT+4`     | Jump to line end ($)               |

### Page/Document Movement

| Key           | Description                        |
| ------------- | ---------------------------------- |
| `SHIFT+G`     | Jump to document end               |
| `SHIFT+GRAVE` | Jump to document end (~)           |
| `CTRL+D`      | Scroll down half page (with count) |
| `CTRL+F`      | Scroll down full page (with count) |
| `CTRL+U`      | Scroll up half page (with count)   |
| `CTRL+B`      | Scroll up full page (with count)   |

### Go Motions (g prefix)

| Key       | Description                                               |
| --------- | --------------------------------------------------------- |
| `E`       | Move to end of previous word (ge)                         |
| `SHIFT+T` | Go to previous tab (gT)                                   |
| `T`       | Go to next tab (gt)                                       |
| `G`       | Go to document start (gg)                                 |
| `SHIFT+G` | Go to document end (G)                                    |
| `H`       | Show keybindings help (gh)                                |
| `M`       | Show marks list (gm)                                      |
| `S`       | Surround text with character(s) (gs)                      |
| `N`       | Edit selected text in Vim/Nvim, start in NORMAL mode (gn) |
| `I`       | Edit selected text in Vim/Nvim, start in INSERT mode (gi) |

## 🔢 Counts

Type numbers before motions/operators to repeat them:

- `5j` - Move down 5 lines
- `3dw` - Delete 3 words
- `10w` - Move forward 10 words
- `2dd` - Delete 2 lines
- `4yy` - Yank 4 lines

## ✂️ Operators

### Delete

| Key       | Description                                 |
| --------- | ------------------------------------------- |
| `SHIFT+D` | Delete to line end                          |
| `SHIFT+X` | Delete char before cursor (with count)      |
| `X`       | Delete char in front of cursor (with count) |
| `d`       | Start d-motion (see below)                  |

### Change (Delete and enter insert)

| Key       | Description                |
| --------- | -------------------------- |
| `SHIFT+C` | Change to line end         |
| `c`       | Start c-motion (see below) |

### Yank (Copy)

| Key       | Description                |
| --------- | -------------------------- |
| `P`       | Paste after cursor         |
| `SHIFT+P` | Paste before cursor        |
| `y`       | Start y-motion (see below) |

### Operator + Motion

- `D` - Delete with motion (`dw`, `dd`, `diw`)
- `C` - Change with motion (`cw`, `cc`, `ciw`)
- `Y` - Yank with motion (`yw`, `yy`, `yiw`)

### Text Objects

Text objects allow you to operate on semantic units:

- `iw` - **Inner word** (word without surrounding whitespace)
- `aw` - **Around word** (word with surrounding whitespace)
- `ip` - **Inner paragraph** (paragraph without blank lines)
- `ap` - **Around paragraph** (paragraph with blank lines)

**Example usage:**

```text
dw          - Delete word (from cursor to end)
3dw         - Delete 3 words
dd          - Delete line
d$          - Delete to end of line
diw         - Delete inner word (entire word under cursor)
daw         - Delete around word (word + whitespace)
ciw         - Change inner word (delete and enter insert)
caw         - Change around word
yy          - Yank (copy) line
yiw         - Yank inner word
gs{         - Surround highlighted word in character(s) (e.g., {word})
gs<div>     - Surround highlighted word in html/xml (.e.g, <div>word</div>)
```

## 📄 Common Edit Actions

### Undo/Redo

| Key      | Description |
| -------- | ----------- |
| `U`      | Undo        |
| `CTRL+R` | Redo        |

> [!NOTE]
> Undo/redo depends on application support for Ctrl+Z / Ctrl+Y.

### Replace

- `R` - Replace character (r<char>)
- `SHIFT+R` - Replace forward (R)

#### Replace Operations

| Key        | Description                                             |
| ---------- | ------------------------------------------------------- |
| `r<char>`  | Replace character under cursor instantly (no prompt)    |
| `5r<char>` | Replace 5 characters with same character (prompts once) |
| `R`        | Replace forward with string (prompts for text)          |

#### Replace Examples

```text
rx              - Replace current character with 'x'
5ra             - Replace next 5 characters with 'aaaaa'
R → "hello"     - Replace next 5 characters with "hello"
```

### Indent

| Key            | Description       |
| -------------- | ----------------- |
| `SHIFT+PERIOD` | Indent line (>)   |
| `SHIFT+COMMA`  | Unindent line (<) |

## 🔁 Surround

Wrap text with character pairs from normal or visual mode.

| Key  | Description                        |
| ---- | ---------------------------------- |
| `gs` | Surround word (normal/visual mode) |

### Surround Operations

The surround feature supports:

- **Single characters**: Automatically pairs brackets `( ) { } [ ] < >`
- **Multi-character**: Supports spacing like `{ text }`
- **HTML/XML tags**: Auto-closes tags like `<div>text</div>`
- **Custom text**: Any character sequence

### Surround Examples

```text
gs → (           - Surround word with (word)
gs → {           - Surround word with {word}
gs → { ␣         - Surround word with { word }
gs → <div>       - Surround word with <div>word</div>
gs → **          - Surround word with **word**

Visual mode:
viwgs → "         - Select word, surround with "word"
vjjgs → <p>       - Select 3 lines, surround with <p>lines</p>
```

## 🔍 Find

`f`, `t`, and `/` commands open HyprVim's built-in prompt in the configured terminal from `applications.terminal`, or in Quickshell with `prompt.frontend = "quickshell"` (see [Configuration](01_Configuration.md#prompt)).

| Key           | Description                       |
| ------------- | --------------------------------- |
| `SLASH`       | Search forward (/)                |
| `SHIFT+SLASH` | Search backward (?)               |
| `SHIFT+8`     | Search selected word forward (\*) |
| `SHIFT+3`     | Search selected word backward     |
| `F`           | Find forward (f)                  |
| `SHIFT+F`     | Find backward (F)                 |
| `T`           | Find till forward (t)             |
| `SHIFT+T`     | Find till backward (T)            |
| `N`           | Find next match (n)               |
| `SHIFT+N`     | Find previous match (N)           |
| `SEMICOLON`   | Repeat find in same direction (;) |
| `COMMA`       | Repeat find in opposite direction |

> [!NOTE]
> These operations all rely on the application supporting [CTRL + F]. The `n` and `N` commands use [F3] and [SHIFT + F3] respectively.

## 🚪 Exiting

| Key                 | Description                                           |
| ------------------- | ----------------------------------------------------- |
| `ESC`               | Return to NORMAL mode from any mode                   |
| `leader + activate` | Enter NORMAL mode or exit HyprVim, depending on state |
| `leader + exit`     | Exit Vim mode entirely (back to Hyprland)             |

The default chords are `SUPER + V` and `SUPER + ESCAPE`.

---

<div align=right><a href="03_Modes.md"><i>>> Next: Go to Modes</i></a></div>
