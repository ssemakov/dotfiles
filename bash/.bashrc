
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

alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'

alias l='ls -CF'

if [ -f ~/.bash_aliases ]; then
    . ~/.bash_aliases
fi

if [ -f ~/.git-completion.bash ]; then
  . ~/.git-completion.bash
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


### Added by the Heroku Toolbel
export PATH="/usr/local/heroku/bin:$PATH"
eval `boot2docker shellinit 2>/dev/null`
export GOPATH="$HOME/workspace/go"

export PATH=$PATH:$HOME/.rvm/bin:$HOME/workspace/go/bin:$HOME/Library/Python/2.7/bin:$HOME/.rvm/rubies/ruby-2.2.4/bin
export PATH="/usr/local/sbin:$PATH"

# enable docker environment
eval "$(docker-machine env)"

# enable gpg-agent
eval $(gpg-agent --daemon)
GPG_TTY=$(tty)
export GPG_TTY
if [ -f "${HOME}/.gpg-agent-info" ]; then
	. "${HOME}/.gpg-agent-info"
	export GPG_AGENT_INFO
	export SSH_AUTH_SOCK
fi
# Use console version of pinentry (macosx)
if [[ -n "$SSH_CONNECTION" ]] ;then
	export PINENTRY_USER_DATA="USE_CURSES=1"
fi
