# dotfiles

Here are my dotfiles that I use on Mac and Linux systems. Organized by application type.

## Install

On a fresh **macOS** machine:

```sh
git clone <this-repo> ~/workspace/dotfiles
~/workspace/dotfiles/install.sh
```

`install.sh` is idempotent (safe to re-run). It will:

- Install Homebrew (if missing) and the core formulae:
  `tmux neovim asdf gh gnupg pinentry-mac difftastic git-lfs`, plus
  `agent-safehouse` (the sandbox wrapper used by `.zshrc`).
- Install oh-my-zsh (framework only — our `.zshrc` and `custom/` replace its defaults).
- Symlink every config into this repo. Existing **real** files are moved aside
  into `~/dotfiles-backup-<timestamp>/` first; existing symlinks are replaced silently.
- Copy `codex/config.toml.template` → `~/.codex/config.toml` (copied, **not**
  symlinked — codex writes machine-specific state back to it).
- Install tmux plugins (TPM) and vim plugins (Vundle).

Optional/work-specific tools (mysql, haproxy, nvm) are left commented out in
`install.sh` — uncomment them there if needed.

## tmux workspaces (`review` / `create` / `work`)

Defined in `zsh/.oh-my-zsh/custom/aliases.zsh`; all run inside tmux. Each opens
a window: nvim (3/5 wide) | right column with `pair claude` (4/9), `pair codex`
(4/9), and a free pane (1/9). CLI panes run `pair last <cli> || pair <cli>`, so
reopening a branch resumes its previous sessions. Requires the `pair` wrapper,
built separately (`make install` in `~/workspace/pair`).

- `review <pr>` — worktree for the PR's head branch, under
  `<repo>/../worktrees/<branch>`.
- `create <branch>` — worktree for feature work. A new branch starts from
  freshly fetched `origin/main` with no upstream; an existing worktree gets an
  ff-only pull when clean.
- `work` — the same layout in the current directory, on the checked-out branch.
- `review close` / `create close` — close the current workspace window. The
  worktree is removed when clean and kept when dirty.

Every `review`/`create` run also prunes worktrees whose PR is merged or closed,
skipping dirty trees and worktrees open in a tmux pane. Pruning loses no agent
state: pair keys sessions by worktree path and branch, and the path is
deterministic per branch, so recreating the workspace restores them.

### After install (manual, machine-specific)

- `chsh -s $(which zsh)` — if zsh isn't already your login shell
- `exec zsh` — load the new config
- Add asdf language plugins per project, e.g. `asdf plugin add ruby`
- WakaTime prompts for an API key on first vim/nvim run (creates `~/.wakatime.cfg`)
