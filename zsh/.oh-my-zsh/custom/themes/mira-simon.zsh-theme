# Based on bira zsh theme with nvm, rvm and jenv support
local return_code="%(?..%{$fg[red]%}%? ↵%{$reset_color%})"

local user_host='%{$terminfo[bold]$fg[green]%}%n@%m%{$reset_color%}'
local current_dir='%{$terminfo[bold]$fg[blue]%} %~%{$reset_color%}'

local rvm_ruby=''
if which rvm-prompt &> /dev/null; then
  rvm_ruby='%{$terminfo[bold]$fg[red]%}‹$(rvm-prompt i v g)›%{$reset_color%}'
else
  if which rbenv &> /dev/null; then
    rvm_ruby='%{$terminfo[bold]$fg[red]%}‹$(rbenv version | sed -e "s/ (set.*$//")›%{$reset_color%}'
  fi
fi

local nvm_node=''
nvm_node='%{$terminfo[bold]$fg[green]%}‹$(nvm_prompt_info)›%{$reset_color%}'

local jenv_java=''
jenv_java='%{$terminfo[bold]$fg[blue]%}‹$(jenv_prompt_info)›%{$reset_color%}'

local venv_python=''
venv_python='%{$terminfo[bold]$fg[blue]%}‹$(virtualenv_info)›%{$reset_color%}'
local git_branch='%{$terminfo[bold]$(git_prompt_info)%{$reset_color%}'

PROMPT="╭─${current_dir}${nvm_node}${rvm_ruby}${git_branch}
╰─%B$%b "
RPS1="${return_code}"

ZSH_THEME_GIT_PROMPT_PREFIX="%{$fg[yellow]%}("
ZSH_THEME_GIT_PROMPT_SUFFIX=") %{$reset_color%}"
