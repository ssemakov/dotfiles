alias tw="cd ~/workspace/trendwave.com && git remote update > /dev/null && git status -sbuno"
alias ems='cd ~/workspace/ems && git remote update > /dev/null && git status -sbuno'
alias pamsg="cd ~/workspace/pa/msging && git status -sbuno"

alias h='history'
alias c='clear'
alias -s log="tail -f"

alias vhlmnt='sshfs ssemakov@192.168.1.107:/home/ssemakov ~/mnt/vhl_ubuntu/'
alias vhlumnt='cd ~/; umount -f ~/mnt/vhl_ubuntu'
alias vhl='vhlumnt; vhlmnt'

alias apache-start='launchctl load -w $(brew --prefix httpd22)/homebrew.mxcl.httpd22.plist'
alias apache-stop='launchctl unload $(brew --prefix httpd22)/homebrew.mxcl.httpd22.plist'
alias apache-reload='apache-stop; apache-start'

alias pg-start='pg_ctl -D /usr/local/var/postgres -l /usr/local/var/postgres/server.log start'
alias pg-stop='pg_ctl -D /usr/local/var/postgres stop -s -m fast'
alias pg-restart='pg-stop; pg-start'

alias ws='cd ~/workspace'
alias vbuntu='ssh ubuntubox -p 3022'

alias gl="git log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr)%Creset' --abbrev-commit --date=relative \$(git symbolic-ref refs/remotes/origin/HEAD | sed 's@^refs/remotes/origin/@@')..\$(git rev-parse --abbrev-ref HEAD) | cat -n"
alias gd="git branch -d"
alias gD="git branch -D"

alias ww='cd ~/wistia/wistia && git remote update > /dev/null && git status -sbuno'
alias slo='cd ~/wistia/slo-scripts && git remote update > /dev/null && git status -sbuno'

# Go forward in Git commit hierarchy towards a particular commit
# Usage: gfwd v1.2.7
gfwd() {
    git checkout $(git rev-list --topo-order HEAD.."$1" | tail -1)
}

# Go back one commit
alias gbck='git checkout HEAD~1'

# Download S3 recording with EngineeringAccess profile
alias dws3='download_s3_recording.sh --profile EngineeringAccess'
