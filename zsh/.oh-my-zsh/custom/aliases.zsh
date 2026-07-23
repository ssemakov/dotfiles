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

# PR review workspace: worktree + tmux layout for a PR number.
# Run from the repo root; usage: review 1234
# Worktree goes under <repo>/../worktrees/<branch>.
# Layout: left 2/3 nvim | right 1/3 column = pair claude / pair codex / clear.
review() {
    local pr="$1"
    [ -n "$pr" ] || { echo "usage: review <pr-number> | review close"; return 1; }
    [ -n "$TMUX" ] || { echo "review: run inside tmux"; return 1; }

    # review close: kill the CURRENT window, only if it's a review window.
    if [ "$pr" = "close" ]; then
        local wid wname
        wid=$(tmux display-message -p '#{window_id}')
        wname=$(tmux display-message -p '#{window_name}')
        case "$wname" in
            review\ *) tmux kill-window -t "$wid" ;;  # closes all panes + SIGHUPs their processes
            *) echo "review: current window '$wname' is not a review window"; return 1 ;;
        esac
        return 0
    fi

    local repo
    repo=$(git rev-parse --show-toplevel 2>/dev/null) || { echo "review: not in a git repo"; return 1; }
    local branch
    branch=$(gh pr view "$pr" --json headRefName -q .headRefName) || return 1
    [ -n "$branch" ] || { echo "review: no branch for PR $pr"; return 1; }
    local wt="$repo/../worktrees/$branch"

    # Create worktree if missing: local branch first, else track the remote PR branch.
    git -C "$repo" fetch -q origin "$branch"
    if [ ! -d "$wt" ]; then
        git -C "$repo" worktree add -q "$wt" "$branch" 2>/dev/null \
            || git -C "$repo" worktree add -q --track -b "$branch" "$wt" "origin/$branch" \
            || { echo "review: worktree add failed"; return 1; }
    fi

    # Panes by id so send-keys never hits the wrong one (active pane moves per split).
    local left right mid bot
    left=$(tmux new-window -P -F '#{pane_id}' -n "review $pr" -c "$wt")
    right=$(tmux split-window -h -l 33% -P -F '#{pane_id}' -t "$left" -c "$wt")
    mid=$(tmux split-window -v -l 66% -P -F '#{pane_id}' -t "$right" -c "$wt")
    bot=$(tmux split-window -v -l 50% -P -F '#{pane_id}' -t "$mid" -c "$wt")

    tmux send-keys -t "$left"  'nvim' Enter
    tmux send-keys -t "$right" 'pair claude' Enter
    tmux send-keys -t "$mid"   'pair codex' Enter
    # bot stays clear.
    tmux select-pane -t "$left"
}
