# Vim & Neovim Configuration Guide

This module provides a universal, plug-less `.vimrc` configuration designed to be modern, keyboard-optimized, and fully integrated with system clipboards across Windows WSL, macOS, and Linux servers.

---

## 1. Features & Design Decisions

### A. Zero-Plugin Architecture
Optimized to run instantly without downloading third-party plugin managers (like vim-plug or packer). All advanced visual features and key mappings are coded natively.

### B. Premium ASCII Statusline
A custom statusline displays:
- **Left**: Current mode (NORMAL, INSERT, REPLACE, VISUAL, etc.) in a bold, highlight-styled block.
- **Center**: Active filename, modified flag (`[+]`), and read-only status.
- **Right**: File format (unix/dos), percentage, line/column position.

### C. System Clipboard Integration
WSL, Linux, and macOS have distinct clipboard mechanisms. This configuration maps clipboard commands automatically depending on the environment:
- **WSL**: Pipes visual selection directly to `clip.exe` and pastes via PowerShell clipboard buffer queries.
- **macOS**: Utilizes `pbcopy` and `pbpaste`.
- **Linux**: Integrates with `xclip` or `xsel` automatically.

---

## 2. Keyboard Shortcuts & Flow

The `<Leader>` key is mapped to **`Space`** (the spacebar).

### File Operations
| Shortcut | Vim Command | Description |
| --- | --- | --- |
| **`Space` + `w`** | `:w` | Save file |
| **`Space` + `q`** | `:q` | Quit file |
| **`Space` + `x`** | `:x` | Save and Quit file |

### Window / Pane Splits
| Shortcut | Vim Command | Description |
| --- | --- | --- |
| **`Space` + `vs`** | `:vsplit` | Split window vertically (side-by-side) |
| **`Space` + `hs`** | `:split` | Split window horizontally (top-and-bottom) |
| **`Ctrl` + Left Arrow** | `<C-w>h` | Focus left pane |
| **`Ctrl` + Right Arrow**| `<C-w>l` | Focus right pane |
| **`Ctrl` + Up Arrow**   | `<C-w>k` | Focus upper pane |
| **`Ctrl` + Down Arrow** | `<C-w>j` | Focus lower pane |

### Editing & Search
| Shortcut | Description |
| --- | --- |
| **`Esc`** or **`Space` + `c`** | Clear search highlighting |
| **`Ctrl + C`** (in Visual mode) | Copy selection to system clipboard |
| **`Ctrl + V`** (in Insert mode) | Paste text directly from system clipboard |

---

## 3. Configuration & Files

- **`~/.vimrc`**: The primary configuration file containing UI properties, splits mapping, and clipboard logic.
- **`~/.config/nvim/init.vim`**: Neovim configuration which automatically references and sources `~/.vimrc` to maintain unified settings across both text editors.

---

## 4. Troubleshooting & FAQs

### Clipboard copy/paste is not working in Vim?
Standard minimal Vim installations on Linux/Debian do not compile with clipboard support (`-clipboard`). 
Our installer script automatically detects this and installs **`vim-gtk3`** (on Debian/Ubuntu systems) along with `xclip` to guarantee `+clipboard` compilation support.
