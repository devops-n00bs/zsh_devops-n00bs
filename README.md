# Universal Zsh & Starship Configuration

A lightweight, high-performance, and seamless Zsh terminal configuration designed to work out-of-the-box across **Windows WSL, macOS, and Linux servers** with **zero font dependencies**. 

Unlike other configurations, this setup does not require downloading Nerd Fonts or custom glyph packages. It uses standard text and ASCII symbols that render perfectly in any default terminal emulator.

---

## Key Features

*   **Zero-Font Required**: Optimized layout using standard characters. Perfect for VPS servers and fresh client environments where custom fonts aren't installed.
*   **High Performance**: Custom `.zshrc` built without Oh My Zsh (OMZ) for blazing-fast startup speeds.
*   **Interactive Setup Manager**: A single entry point script `install.sh` manages both installation and complete clean uninstallation.
*   **Seamless Plugins**: Essential plugins like `zsh-autosuggestions` and `zsh-syntax-highlighting` are automatically installed and configured.
*   **Smart Auto CD**: Allows changing directories simply by typing the folder name (no `cd` prefix needed).
*   **Enhanced History & Completion**: Search terminal history using up/down arrow keys based on command prefix, and navigate completions interactively.

---

## Quick Installation

To install or update the configuration on WSL, macOS, or any Linux server, run the following command in your terminal:

```bash
curl -fsSL https://raw.githubusercontent.com/devops-n00bs/zsh_devops-n00bs/main/install.sh | bash
```

Select **Option `1`** (Install/Update) in the interactive menu. Once done, reload the terminal or run:
```bash
exec zsh
```

---

## Clean Uninstallation (Restore Default)

If you wish to completely clean up and revert your shell settings to their original state (as if it was a fresh install), run the same script:

```bash
curl -fsSL https://raw.githubusercontent.com/devops-n00bs/zsh_devops-n00bs/main/install.sh | bash
```

Select **Option `2`** (Uninstall). The script will automatically:
1. Delete custom configurations and cache files (`~/.zshrc`, `~/.config/starship.toml`, `~/.zcompdump*`, `~/.cache/starship`).
2. Remove the installed Starship binary.
3. Clean Zsh command history (`~/.zsh_history`).
4. Revert your default system shell back to `bash` (on Linux/WSL).
5. Automatically exit.

---

## Repository Structure

```text
zsh_devops-n00bs/
├── install.sh         # Interactive setup manager (installation & cleanup)
├── zshrc              # Source Zsh configuration file
└── starship.toml      # Source Starship prompt layout
```

---

## Prompt Layout Legend

Your prompt displays:
`[Directory] [Git Status] > `

### Git Status Indicators:
*   **`git:branch-name`** : Current active Git branch (in purple/magenta).
*   **`?`** (Untracked) : New files created but not yet tracked by Git.
*   **`!`** (Modified) : Tracked files modified but not yet staged (`git add`).
*   **`+`** (Staged) : Changes staged and ready to commit.
*   **`⇡`** (Ahead) : Local commits not yet pushed to GitHub.
*   **`⇣`** (Behind) : Remote changes available on GitHub but not yet pulled.
*   **`$`** (Stashed) : Changes saved temporarily in git stash.

---

## Tips & Troubleshooting

### Viewing Files with Line Numbers (`bat` vs `batcat`)
*   **For Debian/Ubuntu (including WSL)**: The package `bat` is renamed to `batcat` to avoid conflicts. Run `batcat <filename>` to view files with syntax highlighting, line numbers, and borders.
*   **For macOS/other Linux distros**: Run `bat <filename>`.
*   *Note*: The standard `cat` command is aliased to run in `plain` style (`bat --style=plain`) to preserve compatibility with shell scripts while still providing syntax highlighting.

### Understanding `(END)` in the Terminal (Pager)
When viewing long file contents or running git logs/diffs, Zsh will automatically paginate the output using a pager (`less`).
*   **To exit and return to prompt**: Press the **`q`** key on your keyboard.
*   **To navigate**: Use the **Up/Down Arrow keys** or **Spacebar** (to scroll down a page).
