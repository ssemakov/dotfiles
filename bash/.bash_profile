
# If not running interactively, don't do anything
case $- in
    *i*) ;;
      *) return;;
esac

# don't put duplicate lines or lines starting with space in the history.
# See bash(1) for more options
HISTCONTROL=ignoreboth

# for setting history length see HISTSIZE and HISTFILESIZE in bash(1)
HISTSIZE=10000
HISTFILESIZE=20000
HISTTIMEFORMAT="%m/%d/%Y% %T  "
HISTIGNORE='ls:l:ll:la:pwd:date:'

# append to the history file, don't overwrite it
shopt -s histappend

if [ -f ~/.bash_aliases ]; then
    . ~/.bash_aliases
fi

# get the prompt set up for git
function parse_git_branch {
  git branch 2>/dev/null | grep '^*' | colrm 1 2 | sed 's_\(.*\)_(\1)_'
}

function git_dirty {
  git diff --quiet HEAD &>/dev/null
  [ $? == 1 ] && echo "!"
}

GREEN="\[\033[01;32m\]"
BLUE="\[\033[01;34m\]"
RED="\[\033[0;31m\]"
YELLOW="\[\033[0;33m\]"
GRAY="\[\033[1;30m\]"
LIGHT_GRAY="\[\033[0;37m\]"
NONE="\[\033[0m\]"

export PS1="$BLUE\w$GRAY \$(~/.rvm/bin/rvm-prompt i v g):$GREEN\$(parse_git_branch)$RED\$(git_dirty)$NONE\$ "

if [ -f ~/.git-completion.bash ]; then
  . ~/.git-completion.bash
fi

export PATH=/opt/local/bin:/opt/local/sbin:$PATH

source ~/.profile

[[ -s "$HOME/.rvm/scripts/rvm" ]] && source "$HOME/.rvm/scripts/rvm" # Load RVM into a shell session *as a function*

export JAVA_HOME="/Library/Java/JavaVirtualMachines/jdk1.8.0_40.jdk/Contents/Home"
export POSTGRES_USER=ssemakov

test -e "${HOME}/.iterm2_shell_integration.bash" && source "${HOME}/.iterm2_shell_integration.bash"
export PATH="/usr/local/sbin:$PATH"
