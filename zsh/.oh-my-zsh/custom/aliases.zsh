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

# Worktree workspaces: worktree + tmux layout, under <repo>/../worktrees/<branch>.
# review 1234        - review a PR
# create simon/foo   - feature work: new branch off fresh origin/main, or existing branch
# review/create close - close current window; worktree is removed if clean, kept if dirty.
# Layout: left 2/3 nvim | right 1/3 column = pair claude / pair codex / clear.

# Panes by id so send-keys never hits the wrong one (active pane moves per split).
_wt_layout() {
    local name="$1" wt="$2"
    local left right mid bot
    left=$(tmux new-window -P -F '#{pane_id}' -n "$name" -c "$wt")
    right=$(tmux split-window -h -l 33% -P -F '#{pane_id}' -t "$left" -c "$wt")
    mid=$(tmux split-window -v -l 66% -P -F '#{pane_id}' -t "$right" -c "$wt")
    bot=$(tmux split-window -v -l 50% -P -F '#{pane_id}' -t "$mid" -c "$wt")

    tmux send-keys -t "$left"  'nvim' Enter
    tmux send-keys -t "$right" 'pair claude' Enter
    tmux send-keys -t "$mid"   'pair codex' Enter
    # bot stays clear.
    tmux select-pane -t "$left"
}

# Does any tmux pane have its cwd inside $1?
_wt_busy() {
    local p
    for p in ${(f)"$(tmux list-panes -a -F '#{pane_current_path}' 2>/dev/null)"}; do
        [[ "$p" == "$1" || "$p" == "$1"/* ]] && return 0
    done
    return 1
}

# Close the CURRENT review/create window; remove its worktree when clean.
# Safe to prune: Claude/Codex sessions are keyed by cwd path, and the wt path is
# deterministic per branch, so re-running review/create restores resumable state.
_wt_close() {
    local wid wname wt main
    wid=$(tmux display-message -p '#{window_id}')
    wname=$(tmux display-message -p '#{window_name}')
    wt=$(git rev-parse --show-toplevel 2>/dev/null)
    # Workspace window = named "review ..." or cwd inside a worktrees/ checkout.
    if [[ "$wname" != review\ * && "$wt" != */worktrees/* ]]; then
        echo "close: current window '$wname' is not a review/create window"
        return 1
    fi

    if [[ -n "$wt" && "$wt" == */worktrees/* ]]; then
        if [ -z "$(git -C "$wt" status --porcelain)" ]; then
            # git refuses to remove the worktree its cwd is in -> run from the main repo.
            main=$(git -C "$wt" rev-parse --path-format=absolute --git-common-dir)
            git -C "${main:h}" worktree remove "$wt"
        else
            tmux display-message "close: kept dirty worktree $wt"
        fi
    fi
    tmux kill-window -t "$wid"  # closes all panes + SIGHUPs their processes
}

# Remove worktrees whose PR is merged or closed. Dirty trees survive:
# worktree remove without --force refuses them.
_wt_sweep() {
    local repo="$1" wt br st
    git -C "$repo" worktree list --porcelain | awk '/^worktree /{sub(/^worktree /,""); print}' \
    | while read -r wt; do
        [[ "$wt" == */worktrees/* ]] || continue
        _wt_busy "$wt" && continue  # a tmux pane still lives there
        br=$(git -C "$wt" branch --show-current)
        [ -n "$br" ] || continue
        st=$(cd "$wt" && gh pr view "$br" --json state -q .state 2>/dev/null)
        case "$st" in
            MERGED|CLOSED) git -C "$repo" worktree remove "$wt" 2>/dev/null \
                && echo "pruned $wt ($st PR)" ;;
        esac
    done
}

review() {
    local pr="$1"
    [ -n "$pr" ] || { echo "usage: review <pr-number> | review close"; return 1; }
    [ -n "$TMUX" ] || { echo "review: run inside tmux"; return 1; }
    [ "$pr" = "close" ] && { _wt_close; return $?; }

    local repo
    repo=$(git rev-parse --show-toplevel 2>/dev/null) || { echo "review: not in a git repo"; return 1; }
    _wt_sweep "$repo"
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
    _wt_layout "review $pr" "$wt"
}

create() {
    local branch="$1"
    [ -n "$branch" ] || { echo "usage: create <branch> | create close"; return 1; }
    [ -n "$TMUX" ] || { echo "create: run inside tmux"; return 1; }
    [ "$branch" = "close" ] && { _wt_close; return $?; }

    local repo
    repo=$(git rev-parse --show-toplevel 2>/dev/null) || { echo "create: not in a git repo"; return 1; }
    _wt_sweep "$repo"
    local wt="$repo/../worktrees/$branch"
    git -C "$repo" fetch -q origin

    if [ -d "$wt" ]; then
        # Existing wt: ff-only update; never rebase/merge, never touch a dirty tree.
        if [ -n "$(git -C "$wt" status --porcelain)" ]; then
            echo "create: dirty worktree, skipping pull"
        else
            git -C "$wt" pull -q --ff-only 2>/dev/null \
                || echo "create: diverged from upstream (or no upstream), skipping pull"
        fi
    elif git -C "$repo" show-ref -q --verify "refs/heads/$branch"; then
        git -C "$repo" worktree add -q "$wt" "$branch" || return 1
    elif git -C "$repo" show-ref -q --verify "refs/remotes/origin/$branch"; then
        git -C "$repo" worktree add -q --track -b "$branch" "$wt" "origin/$branch" || return 1
    else
        # New branch off freshly fetched origin/main (no need to pull the main checkout).
        local main
        main=$(git -C "$repo" symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null)
        main=${main#origin/}
        git -C "$repo" worktree add -q --no-track -b "$branch" "$wt" "origin/${main:-main}" \
            || { echo "create: worktree add failed"; return 1; }
    fi
    _wt_layout "$branch" "$wt"
}
