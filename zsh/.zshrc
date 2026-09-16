# If you come from bash you might have to change your $PATH.

# Path to your oh-my-zsh installation.
export ZSH=~/.oh-my-zsh

# Keep custom config in the dotfiles repo without symlinking $ZSH/custom
# (a symlinked custom/ breaks `omz update`'s git autostash). Must be set
# before sourcing oh-my-zsh.sh.
export ZSH_CUSTOM=~/workspace/dotfiles/zsh/.oh-my-zsh/custom

# Set name of the theme to load. Optionally, if you set this to "random"
# it'll load a random theme each time that oh-my-zsh is loaded.
# See https://github.com/robbyrussell/oh-my-zsh/wiki/Themes
#ZSH_THEME="mira-simon"
ZSH_THEME="af-magic"

# Uncomment the following line to use case-sensitive completion.
# CASE_SENSITIVE="true"

# Uncomment the following line to use hyphen-insensitive completion. Case
# sensitive completion must be off. _ and - will be interchangeable.
# HYPHEN_INSENSITIVE="true"

# Uncomment the following line to disable bi-weekly auto-update checks.
# DISABLE_AUTO_UPDATE="true"

# Uncomment the following line to change how often to auto-update (in days).
# export UPDATE_ZSH_DAYS=13

# Uncomment the following line to disable colors in ls.
# DISABLE_LS_COLORS="true"

# Uncomment the following line to disable auto-setting terminal title.
# DISABLE_AUTO_TITLE="true"

# Uncomment the following line to enable command auto-correction.
# ENABLE_CORRECTION="true"

# Uncomment the following line to display red dots whilst waiting for completion.
# COMPLETION_WAITING_DOTS="true"

# Uncomment the following line if you want to disable marking untracked files
# under VCS as dirty. This makes repository status check for large repositories
# much, much faster.
# DISABLE_UNTRACKED_FILES_DIRTY="true"

# Uncomment the following line if you want to change the command execution time
# stamp shown in the history command output.
# The optional three formats: "mm/dd/yyyy"|"dd.mm.yyyy"|"yyyy-mm-dd"
# HIST_STAMPS="mm/dd/yyyy"


# Which plugins would you like to load? (plugins can be found in ~/.oh-my-zsh/plugins/*)
# Custom plugins may be added to ~/.oh-my-zsh/custom/plugins/
# Example format: plugins=(rails git textmate ruby lighthouse)
# Add wisely, as too many plugins slow down shell startup.
plugins=(git bgnotify bundler rails rake-fast ruby rvm tmux vi-mode)

source $ZSH/oh-my-zsh.sh

# Inside nvim's embedded terminal, drop af-magic's COLUMNS-sized dashed
# separator — it renders before the PTY size is settled and misplaces the
# cursor on the first prompt.
if [[ -n "$NVIM" ]]; then
  PS1="${FG[032]}%~\$(git_prompt_info)\$(hg_prompt_info) ${FG[105]}%(!.#.»)%{$reset_color%} "
fi

# User configuration

# export MANPATH="/usr/local/man:$MANPATH"

# You may need to manually set your language environment
# export LANG=en_US.UTF-8

# Preferred editor for local and remote sessions
if [[ -n $SSH_CONNECTION ]]; then
  export EDITOR='vim'
else
  export EDITOR='vim'
fi

# Compilation flags
# export ARCHFLAGS="-arch x86_64"

# ssh
# export SSH_KEY_PATH="~/.ssh/rsa_id"

function git_branch_local_ls() {
  git for-each-ref \
  --format='%(color:blue)%(committerdate:short)%(color:reset) | %(color:red)%(committerdate:relative)%(color:reset) | %(authorname) | %(color:yellow)%(refname:short)%(color:reset)' \
  --sort=-committerdate refs/heads/ | column -t -s '|' | \
  if [ -n "$1" ]
    then
      head -n $1
  else
    head -n 500
  fi
}

# Safehouse sandbox for AI agents (macOS only). Where `safehouse` is absent
# (e.g. Linux dev boxes), the wrappers below are not defined, so `claude`,
# `codex`, etc. fall through to the real binaries unsandboxed.
if command -v safehouse >/dev/null 2>&1; then

safe() {
  "$HOME/workspace/dotfiles/bin/safe" "$@"
}

# Sandboxed — the default. Just type the command name.
claude()   { safe claude "$@"; }
codex()    { safe codex "$@"; }
amp()      { safe amp  "$@"; }
gemini()   { NO_BROWSER=true safe gemini "$@"; }

fi  # command -v safehouse


# Set personal aliases, overriding those provided by oh-my-zsh libs,
# plugins, and themes. Aliases can be placed here, though oh-my-zsh
# users are encouraged to define aliases within the ZSH_CUSTOM folder.
# For a full list of active aliases, run `alias`.

setopt HIST_EXPIRE_DUPS_FIRST
setopt HIST_IGNORE_DUPS
setopt HIST_IGNORE_ALL_DUPS
setopt HIST_FIND_NO_DUPS
setopt HIST_IGNORE_SPACE
setopt HIST_SAVE_NO_DUPS
setopt HIST_REDUCE_BLANKS
setopt HIST_VERIFY
setopt INC_APPEND_HISTORY

autoload -Uz compinit && compinit

export PATH="$PATH:$HOME/.rvm/bin" # Add RVM to PATH for scripting
export HISTSIZE=100000                   # entries kept in memory
export SAVEHIST=$HISTSIZE                # entries kept in the file; omitting it caps at omz's 10000

# asdf — legacy asdf.sh (<0.16) if present, else shims dir on PATH (>=0.16)
if [ -f "/opt/homebrew/opt/asdf/libexec/asdf.sh" ]; then
  . "/opt/homebrew/opt/asdf/libexec/asdf.sh"
elif [ -f "$HOME/.asdf/asdf.sh" ]; then
  . "$HOME/.asdf/asdf.sh"
elif command -v asdf >/dev/null 2>&1; then
  export PATH="${ASDF_DATA_DIR:-$HOME/.asdf}/shims:$PATH"
fi

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
AWS_SESSION_TOKEN_TTL=10h

export WASMTIME_HOME="$HOME/.wasmtime"

export PATH="$HOME/bin:$HOME/workspace/dotfiles/bin:$HOME/workspace/bin:$WASMTIME_HOME/bin:$HOME/.local/bin:$PATH"

# The next line updates PATH for the Google Cloud SDK.
if [ -f "$HOME/Downloads/google-cloud-sdk/path.zsh.inc" ]; then . "$HOME/Downloads/google-cloud-sdk/path.zsh.inc"; fi

# The next line enables shell command completion for gcloud.
if [ -f "$HOME/Downloads/google-cloud-sdk/completion.zsh.inc" ]; then . "$HOME/Downloads/google-cloud-sdk/completion.zsh.inc"; fi

# Ghostty CLI (the `ghostty` binary lives inside the .app bundle)
if [ -d "/Applications/Ghostty.app/Contents/MacOS" ]; then
  export PATH="/Applications/Ghostty.app/Contents/MacOS:$PATH"
fi

# devbox-cli
export PATH="$HOME/.devbox-cli/bin:$PATH"

# GITHUB_TOKEN for codereview.nvim, read from gh's stored login so no PAT
# lands in a dotfile. gh prefers this env var over its keychain, so run
# `GITHUB_TOKEN= gh auth login` / `... auth switch` when changing accounts.
if command -v gh >/dev/null 2>&1; then
  _gh_token="$(gh auth token 2>/dev/null)"
  [ -n "$_gh_token" ] && export GITHUB_TOKEN="$_gh_token"
  unset _gh_token
fi

# Per-host / per-OS overrides (created by install.sh from local/zshrc.local.<os>).
# Keep machine-specific config here so the committed .zshrc stays portable.
[ -f "$HOME/.zshrc.local" ] && . "$HOME/.zshrc.local"

# opencode
export PATH=/Users/simonsemakov/.opencode/bin:$PATH

# Keybindings last: some hosts' system rc (pulled in by ~/.zshrc.local above)
# re-sources oh-my-zsh or runs `bindkey -e`, clobbering the vi-mode plugin and
# leaving a plain emacs keymap. Re-assert vi keys here so nothing outranks them.
bindkey -v
# KEYTIMEOUT is in 10ms units; 1 makes Esc resolve immediately instead of the
# default 400ms wait-for-an-escape-sequence.
export KEYTIMEOUT=1
bindkey '^P' up-history
bindkey '^N' down-history
bindkey '^R' history-incremental-search-backward
# vicmd's ^P/^N are already up-history/down-history, but its ^R is `redo`,
# and a prompt can open in vicmd (see resume-vi-mode below).
bindkey -M vicmd '^R' history-incremental-search-backward

# cd-from-line: turn the current line (a pipeline ending in a single path on
# stdout) into `cd "$(...)"` and run it — append-only, no jumping to the front.
# Single key (not a chord, not Esc-c): no stray ^D to close the tmux pane, and
# vi-mode's Esc latency stays untouched. ^G's default `list-expand` is rarely used.
cd-from-line() { BUFFER="cd \"\$($BUFFER)\""; zle accept-line; }
zle -N cd-from-line
bindkey -M viins '^G' cd-from-line
bindkey -M vicmd '^G' cd-from-line

# Cursor shape per vi mode (DECSCUSR): block in normal, underline in insert,
# terminal default while a command runs. Hand-rolled rather than omz's
# VI_MODE_SET_CURSOR, which must be set before oh-my-zsh loads and is dead in
# shells whose plugin list dropped vi-mode. This block always runs.
autoload -Uz add-zle-hook-widget
vi-cursor-shape() {
  case ${KEYMAP:-viins} in
    vicmd) print -n '\e[2 q' ;;
    *)     print -n '\e[4 q' ;;
  esac
}
vi-cursor-reset() { print -n '\e[0 q'; }
zle -N vi-cursor-shape
zle -N vi-cursor-reset
add-zle-hook-widget zle-keymap-select vi-cursor-shape
add-zle-hook-widget zle-line-finish   vi-cursor-reset

# Resume each prompt in whichever vi mode the last one ended in. KEYMAP is
# normalized to main/vicmd so a transient keymap (visual, isearch) can't be
# restored into a bare prompt. First prompt of a shell starts in vicmd.
save-vi-mode()   { [[ $KEYMAP == vicmd ]] && _vi_last_keymap=vicmd || _vi_last_keymap=main; }
resume-vi-mode() { zle -K ${_vi_last_keymap:-vicmd}; }
zle -N save-vi-mode
zle -N resume-vi-mode
add-zle-hook-widget zle-line-finish   save-vi-mode
# Registered before vi-cursor-shape so the cursor is painted after the flip.
add-zle-hook-widget zle-line-init     resume-vi-mode
add-zle-hook-widget zle-line-init     vi-cursor-shape
