# ==============================================================================
# ZSH CONFIGURATION (Custom, Fast, and Clean)
# Compatible with macOS, Linux, and Windows WSL
# ==============================================================================

# ------------------------------------------------------------------------------
# 0. Locale settings (Ensures UTF-8 characters render correctly)
# ------------------------------------------------------------------------------
export LANG="en_US.UTF-8"
export LC_ALL="en_US.UTF-8"

# ------------------------------------------------------------------------------
# 1. History Configuration
# ------------------------------------------------------------------------------
HISTFILE="${HOME}/.zsh_history"
HISTSIZE=10000
SAVEHIST=10000

# History options
setopt appendhistory       # Append to history file, don't overwrite
setopt sharehistory        # Share history across all active sessions
setopt histignorealldups   # Delete old recorded duplicate behavior
setopt histignoredups      # Do not write events to history that are duplicates of previous event
setopt histignorespace     # Don't record commands starting with a space
setopt histreduceblanks    # Remove superfluous blanks before recording to history

# ------------------------------------------------------------------------------
# 2. Completion System (compinit)
# ------------------------------------------------------------------------------
autoload -Uz compinit
if [[ -n ${ZSH_COMPDUMP} ]]; then
    compinit -d "${ZSH_COMPDUMP}"
else
    compinit
fi

# Completion Styling
zstyle ':completion:*' menu select
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|[._-]=* r:|=*' 'l:|=* r:|=*'

# ------------------------------------------------------------------------------
# 3. Key Bindings & Behavior
# ------------------------------------------------------------------------------
# Use emacs keybindings by default (even if EDITOR is set to vi)
bindkey -e

# Up/Down arrow search history based on prefix
autoload -U up-line-or-beginning-search
autoload -U down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search
bindkey '^[[A' up-line-or-beginning-search # Up Arrow
bindkey '^[[B' down-line-or-beginning-search # Down Arrow

# ------------------------------------------------------------------------------
# 4. Plugins (Auto-suggestions & Syntax Highlighting)
# ------------------------------------------------------------------------------
# Default path for custom plugins
ZSH_PLUGIN_DIR="${HOME}/.zsh/plugins"

# Load zsh-autosuggestions
if [[ -f "${ZSH_PLUGIN_DIR}/zsh-autosuggestions/zsh-autosuggestions.zsh" ]]; then
    source "${ZSH_PLUGIN_DIR}/zsh-autosuggestions/zsh-autosuggestions.zsh"
    # Customize autosuggestion color (sleek dark gray)
    ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=8"
fi

# Load zsh-syntax-highlighting
if [[ -f "${ZSH_PLUGIN_DIR}/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]]; then
    source "${ZSH_PLUGIN_DIR}/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
fi

# ------------------------------------------------------------------------------
# 5. Prompt Initialization (Starship)
# ------------------------------------------------------------------------------
if command -v starship &> /dev/null; then
    eval "$(starship init zsh)"
else
    # Fallback prompt if Starship is not installed yet
    PROMPT="%F{cyan}%n%f@%F{blue}%m%f %F{green}%~%f %F{yellow}$%f "
fi

# ------------------------------------------------------------------------------
# 6. Aliases & Functions
# ------------------------------------------------------------------------------
# Default general aliases
alias grep="grep --color=auto"
alias reload="exec zsh"

# Smart Auto-Aliases (Check for modern CLI replacements)
if command -v batcat &> /dev/null; then
    alias cat="batcat --style=plain"
elif command -v bat &> /dev/null; then
    alias cat="bat --style=plain"
fi

if command -v eza &> /dev/null; then
    alias ls="eza --git"
    alias ll="eza -lah --git"
    alias la="eza -a --git"
    alias l="eza -lh --git"
elif command -v exa &> /dev/null; then
    alias ls="exa --git"
    alias ll="exa -lah --git"
    alias la="exa -a --git"
    alias l="exa -lh --git"
else
    alias ls="ls --color=auto"
    alias ll="ls -lAh --color=auto"
    alias la="ls -A --color=auto"
    alias l="ls -lh --color=auto"
fi
