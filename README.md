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

### After install (manual, machine-specific)

- `chsh -s $(which zsh)` — if zsh isn't already your login shell
- `exec zsh` — load the new config
- Add asdf language plugins per project, e.g. `asdf plugin add ruby`
- WakaTime prompts for an API key on first vim/nvim run (creates `~/.wakatime.cfg`)
