alias h='history'
alias c='clear'
alias -s log="tail -f"

alias ws='cd ~/workspace'

alias gl="git log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr)%Creset' --abbrev-commit --date=relative \$(git symbolic-ref refs/remotes/origin/HEAD | sed 's@^refs/remotes/origin/@@')..\$(git rev-parse --abbrev-ref HEAD) | cat -n"
alias gd="git branch -d"
alias gD="git branch -D"

# Go forward in Git commit hierarchy towards a particular commit
# Usage: gfwd v1.2.7
gfwd() {
    git checkout $(git rev-list --topo-order HEAD.."$1" | tail -1)
}

# Go back one commit
alias gbck='git checkout HEAD~1'
