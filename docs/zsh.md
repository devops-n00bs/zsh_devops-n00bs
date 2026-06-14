# Zsh & Starship Configuration Guide

This module provides a lightweight, high-performance Zsh terminal environment with the modern Starship prompt, optimized to run out-of-the-box across Windows WSL, macOS, and Linux servers with **zero custom font dependencies**.

---

## 1. Features & Design Decisions

### A. High Performance (No Oh My Zsh)
Instead of relying on heavy frameworks like Oh My Zsh, this configuration loads a minimal, vanilla `.zshrc` directly, yielding sub-millisecond startup times while maintaining critical functionalities.

### B. Starship Prompt Layout
A two-line prompt designed for maximum readability and zero-font capability:
- **Line 1**: `username` (green for standard users, red for root) + `@hostname` (blue) + `directory` (cyan) + `git info` (magenta).
- **Line 2**: Input character `>` (green on success, red on failure).

### C. Enhanced History & Searching
- **Shared History**: History is instantly shared across all active terminal sessions.
- **Prefix Search**: Type a few characters of a command and press the **Up/Down Arrow keys** to search only matching entries in the history.
- **Auto-deduplication**: Duplicate entries are automatically deleted and not written back to history.

### D. Interactive Auto-Completion
- Auto-completions are fully interactive, style-colored (matching terminal files), and support case-insensitive matching.
- Tab completion menu navigation allows selecting folders using arrows.

---

## 2. Keyboard Shortcuts & Flow

| Shortcut | Action |
| --- | --- |
| **Tab** | Trigger/navigate interactive completion menu |
| **Up / Down Arrow** | Search history by matching prefix |
| **Right Arrow** / **Ctrl + Space** | Accept the full autocompletion suggestion |
| **Ctrl + Right Arrow** | Accept suggestion word-by-word |
| **Ctrl + Left / Right Arrow** | Jump cursor word-by-word |
| **typing a directory name** | `autocd` (changes directory directly without needing `cd`) |

---

## 3. Configuration & Files

- **`~/.zshrc`**: Configures completion settings, key bindings, history, aliases, and loads external plugins.
- **`~/.config/starship.toml`**: Customizes the prompt theme to prevent dependency on Nerd Fonts.
- **`~/.zsh/plugins/`**:
  - `zsh-autosuggestions`: Blazing fast command predictions.
  - `zsh-syntax-highlighting`: Visual feedback for commands (green = valid command, red = invalid).

---

## 4. Troubleshooting & FAQs

### Zsh does not load automatically?
On some Linux environments, `chsh` might fail or require a full logout. As a fallback, our installer adds an auto-forward hook to `~/.bashrc`. If Zsh is installed, it will automatically launch `zsh` on bash startup.

### How to exit paginated output `(END)`?
When a command yields a long list of files or logs, Zsh uses a pager (`less`). 
- Press **`q`** to exit the pager and return to the command prompt.
- Press **Space** to scroll down, or **Up/Down Arrows** to scroll line-by-line.

### CLI Enhancements (`bat` & `eza`)
Our script installs `bat` (syntax highlighted `cat`) and `eza`/`exa` (modern `ls` replacement) automatically if available.
- `ls` / `ll` / `la` / `l` are automatically mapped to use `eza` with git status indicators.
- `cat` is mapped to `bat --style=plain` to preserve scripting functionality while providing syntax highlighting.
