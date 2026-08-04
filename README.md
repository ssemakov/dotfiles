# dotfiles

Here are my dotfiles that I use on Mac and Linux systems. Organized by application type.

## What's inside

- **zsh/** — oh-my-zsh config. `ZSH_CUSTOM` points into this repo (survives
  `omz update` without symlinking `custom/`). Custom themes
  (bullet-train/mira variants), aliases, and the tmux workspace commands
  (`review` / `create` / `work`, section below). The `safe` wrapper runs AI
  CLIs (`claude`, `codex`) inside the agent-safehouse macOS sandbox, with
  read-only `~/workspace` by default; on machines without `safehouse` the
  real binaries run directly. Per-OS extras live in `local/zshrc.local.*`.
- **nvim/** — LazyVim-based setup. Notable plugins:
  [crit-vim](https://github.com/ssemakov/crit-vim) (inline review
  of agent edits, my project), octo (GitHub PRs), diffview, neotest (rspec + vitest),
  neocodeium, wakatime. **vim/** is the legacy Vundle setup.
- **tmux/** — config + TPM plugins; `bin/tsave` / `bin/trestore` save and
  restore per-window pane layouts.
- **git/** — aliases (`st`, `ci`, `lg`, `dlog` for difftastic log,
  `purge-branches`), difftastic as difftool, global ignores.
- **Agent configs** — `claude/settings.json.template` (plugins: ponytail,
  wakatime, ruby-lsp), `codex/config.toml.template` (copied, machine-local),
  `agent-safehouse/local-overrides.sb` sandbox profile additions.
- **bin/** — utilities: `tsave`/`trestore` (tmux layouts), `fsync`
  (watch-and-sync changed files between two directories), `imgcat`
  (images in tmux), `ecs-deploy`, `reset-yubikey` / `restart-gpg-ssh`.
- **ghostty/** — terminal config (TokyoNight, SSH terminfo integration).
- Plus small configs for asdf, bash, gh, gpg, powerline, pry, rubocop.

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

### After install (manual, machine-specific)

- `chsh -s $(which zsh)` — if zsh isn't already your login shell
- `exec zsh` — load the new config
- Add asdf language plugins per project, e.g. `asdf plugin add ruby`
- WakaTime prompts for an API key on first vim/nvim run (creates `~/.wakatime.cfg`)

## tmux workspaces (`review` / `create` / `work`)

Defined in `zsh/.oh-my-zsh/custom/aliases.zsh`; all run inside tmux. Each opens
a window: nvim (3/5 wide) | right column with `pair claude` (4/9), `pair codex`
(4/9), and a free pane (1/9). CLI panes run `pair last <cli> || pair <cli>`, so
reopening a branch resumes its previous sessions. Requires
[pair](https://github.com/ssemakov/pair) (my project), built separately
(`make install` in its checkout).

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
