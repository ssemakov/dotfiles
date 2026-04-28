# If you come from bash you might have to change your $PATH.

# Path to your oh-my-zsh installation.
export ZSH=~/.oh-my-zsh

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
plugins=(git bgnotify bundler rails rake-fast ruby rvm tmux)

source $ZSH/oh-my-zsh.sh

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

# Safehousse sandbox for AI agents

safe() {
  local -a safehouse_args cmd_args

  # Folders always granted read/write access in the sandbox — extend this list as needed
  local -a safehouse_rw_dirs=(
    "$HOME/.crit"
  )

  safehouse_args=(--add-dirs-ro="$HOME/workspace")
  for dir in "${safehouse_rw_dirs[@]}"; do
    [ -d "$dir" ] && safehouse_args+=(--add-dirs="$dir")
  done

  while (( $# )); do
    case "$1" in
      --add-dir)
        shift
        if (( $# == 0 )); then
          echo "safe: --add-dir requires a directory argument" >&2
          return 1
        fi
        safehouse_args+=(--add-dirs-ro="$1")
        ;;
      --add-dir=*)
        safehouse_args+=(--add-dirs-ro="${1#--add-dir=}")
        ;;
      *)
        cmd_args+=("$1")
        ;;
    esac
    shift
  done

  safehouse "${safehouse_args[@]}" "${cmd_args[@]}"
}

# Sandboxed — the default. Just type the command name.
claude()   { safe claude "$@"; }
codex()    { safe codex "$@"; }
amp()      { safe amp  "$@"; }
gemini()   { NO_BROWSER=true safe gemini "$@"; }


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

autoload -Uz compinit && compinit

export PATH="$PATH:$HOME/.rvm/bin" # Add RVM to PATH for scripting
export HISTCONTROL=ignoredups:erasedups  # no duplicate entries
export HISTSIZE=100000                   # big big history
export HISTFILESIZE=100000               # big big history
export PROMPT_COMMAND="history -a; history -c; history -r; $PROMPT_COMMAND"

# asdf — pick whichever install location is present (Homebrew or $HOME)
if [ -f "/opt/homebrew/opt/asdf/libexec/asdf.sh" ]; then
  . "/opt/homebrew/opt/asdf/libexec/asdf.sh"
elif [ -f "$HOME/.asdf/asdf.sh" ]; then
  . "$HOME/.asdf/asdf.sh"
fi

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
AWS_SESSION_TOKEN_TTL=10h
export PATH="/opt/homebrew/opt/mysql@8.4/bin:$PATH"

export WASMTIME_HOME="$HOME/.wasmtime"

export PATH="$HOME/workspace/dotfiles/bin:$HOME/workspace/bin:$WASMTIME_HOME/bin:$HOME/.local/bin:$PATH"

# The next line updates PATH for the Google Cloud SDK.
if [ -f "$HOME/Downloads/google-cloud-sdk/path.zsh.inc" ]; then . "$HOME/Downloads/google-cloud-sdk/path.zsh.inc"; fi

# The next line enables shell command completion for gcloud.
if [ -f "$HOME/Downloads/google-cloud-sdk/completion.zsh.inc" ]; then . "$HOME/Downloads/google-cloud-sdk/completion.zsh.inc"; fi
export PATH="/opt/homebrew/opt/haproxy@2.8/bin:$PATH"

# Ghostty CLI (the `ghostty` binary lives inside the .app bundle)
if [ -d "/Applications/Ghostty.app/Contents/MacOS" ]; then
  export PATH="/Applications/Ghostty.app/Contents/MacOS:$PATH"
fi
