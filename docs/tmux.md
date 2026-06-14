# Tmux Configuration Guide

This module provides a universal, fast, and highly customizable Tmux terminal multiplexer configuration. It features keyboard-driven workflows, mouse controls, split pane layouts, and cross-platform system clipboard syncing.

---

## 1. Features & Design Decisions

### A. Prefix Remapping (`Ctrl + A`)
The default prefix is remapped from `Ctrl + B` to `Ctrl + A` (matching GNU Screen conventions), which is much easier to reach on standard keyboard layouts.

### B. Instant Pane Navigation (No Prefix)
To switch between splits, you do not need to press the prefix key combination. You can navigate directly using **`Ctrl` + Arrow Keys** (Left, Right, Up, Down), mirroring the window navigation mappings in our Vim setup.

### C. Visual Theme (Starship Match)
- Status bar is placed at the bottom with a dark theme background (`#1C1C1C`).
- **Left**: Displays active session name (`[Session: name]`) in bold blue/cyan.
- **Center**: Lists windows with active formatting (`cyan` background) and inactive formatting (gray text).
- **Right**: Displays date and clock (`%d-%b-%y %H:%M`).

### D. Copy Mode & Clipboard Integration
- Enables **`vi-keys`** mode for keyboard-driven text selection.
- Integrates with the native system clipboard (WSL `clip.exe`, macOS `pbcopy`, Linux `xclip`).
- Supporting both mouse-drag auto-copy and keyboard-based selection copying.

---

## 2. Keyboard Shortcuts & Flow

All tmux bindings require pressing the prefix key (**`Ctrl + A`**) first, unless specified as *(No Prefix)*.

### Pane Management
| Shortcut | Action |
| --- | --- |
| **`Ctrl + A` then `|`** | Split pane vertically (side-by-side) |
| **`Ctrl + A` then `-`** | Split pane horizontally (top-and-bottom) |
| **`Ctrl` + Arrow Keys** *(No Prefix)* | Move focus between split panes |
| **`Ctrl + A` then `Shift` + Arrow Keys** | Resize active pane by 5 cells in direction |
| **`Ctrl + A` then `r`** | Reload `.tmux.conf` on-the-fly |

### Copy Mode & Text Selection
| Shortcut | Action |
| --- | --- |
| **`Ctrl + A` then `[`** | Enter copy mode |
| **`v`** (inside Copy Mode) | Begin normal visual selection |
| **`Ctrl + V`** (inside Copy Mode) | Toggle rectangular block/area selection |
| **`y`** or **`Enter`** (inside Copy Mode) | Copy selection to system clipboard and exit copy mode |
| **Mouse Drag & Release** | Copy text selection directly to system clipboard |
| **`q`** (inside Copy Mode) | Exit copy mode |

---

## 3. Configuration & Files

- **`~/.tmux.conf`**: The main configuration file. It sets default colors, window base numbering starting at 1, custom keybinds, and platform-aware copy-pipe-and-cancel bindings.

---

## 4. Troubleshooting & FAQs

### Clipboard does not work inside WSL?
Make sure Windows binaries can be executed within WSL (default behavior in WSL). When you release a mouse selection or press `y`, Tmux calls `clip.exe` to bridge the clipboard directly to Windows.

### Mouse mode capture blocks copy paste?
With `set -g mouse on` enabled, dragging the mouse triggers Tmux's internal copy mode. To bypass Tmux's mouse intercept and copy directly using your terminal emulator's native clipboard, hold the **`Shift`** key (on Linux/WSL) or **`Option`** key (on macOS) while dragging the mouse.
