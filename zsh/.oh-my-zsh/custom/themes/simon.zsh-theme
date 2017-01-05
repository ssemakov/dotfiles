RUBY_PREFIX="♦️ "

# RUBY
prompt_ruby() {
  if command -v rvm-prompt > /dev/null 2>&1; then
    echo -n "$(rvm-prompt)"
  fi
}

local ret_status="%(?:%{$fg_bold[green]%}➜ :%{$fg_bold[red]%}➜ )"
local rvm_info=" $(prompt_ruby)"
PROMPT='${ret_status} %{$fg[blue]%}%c%{$reset_color%} ${prompt_ruby}:$(git_prompt_info)'

ZSH_THEME_GIT_PROMPT_PREFIX="%{$fg_bold[green]%}(%{$fg[green]%}"
ZSH_THEME_GIT_PROMPT_SUFFIX="%{$reset_color%} "
ZSH_THEME_GIT_PROMPT_DIRTY="%{$fg[green]%})%{$fg[red]%}✗"
ZSH_THEME_GIT_PROMPT_CLEAN="%{$fg[green]%})"
