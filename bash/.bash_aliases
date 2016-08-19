alias h='history'
alias c='clear'
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'

alias ..="cd .."
alias ~="cd ~/"
alias ll="ls -l"
alias la="ls -a"
alias l='ls -CF'

alias apache-start='launchctl load -w $(brew --prefix httpd22)/homebrew.mxcl.httpd22.plist'
alias apache-stop='launchctl unload $(brew --prefix httpd22)/homebrew.mxcl.httpd22.plist'
alias apache-reload='apache-stop; apache-start'

alias ws='cd ~/workspace'
alias vbuntu='ssh ubuntubox -p 3022'
alias ngx='sudo service nginx restart'
