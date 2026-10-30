# dotfiles

Here are my dotfiles that I use on Mac and Linux systems. Organized by application type.

## What's inside

- **zsh/** — oh-my-zsh config. `ZSH_CUSTOM` points into this repo (survives
  `omz update` without symlinking `custom/`). Custom themes
  (bullet-train/mira variants), aliases, and the tmux workspace commands
  (`review` / `create` / `work`, section below). The shared `bin/safe` wrapper
  runs AI CLIs (`claude`, `codex`, and Neovim's ACP providers) inside the
  agent-safehouse macOS sandbox, with read-only `~/workspace` by default.
  These entry points refuse to run if Safehouse or the local policy is missing.
  Per-OS extras live in `local/zshrc.local.*`.
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
  (images in tmux), `ecs-deploy`, `reset-yubikey` / `restart-gpg-ssh`,
  `svim-stop` / `svim-start` (manual SketchyVim pause, including from the quick terminal).
- **ghostty/** — terminal config (TokyoNight, SSH terminfo integration).
- **nvim-ovim/** — separate writing profile for ovim, with GitHub themes that
  follow macOS light/dark appearance and Harper grammar checking.
- **ovim/** — Alacritty popup launcher for that profile; **alacritty/** selects
  JetBrainsMono Nerd Font Mono so Neovim icons render correctly.
- **.config/svim/** — [native macOS mode badges and live command/search bar](.config/svim/README.md) for SketchyVim.
- Plus small configs for asdf, bash, gh, gpg, powerline, pry, rubocop.

## Install

On a fresh **macOS** machine:

```sh
git clone <this-repo> ~/workspace/dotfiles
~/workspace/dotfiles/install.sh
```

`install.sh` is idempotent (safe to re-run). It will:

- Install Homebrew (if missing) and the core formulae:
  `tmux neovim asdf gh gnupg pinentry-mac difftastic git-lfs deno ripgrep codex-acp`, plus
  `agent-safehouse` (the sandbox wrapper used by `.zshrc`).
- Install JetBrainsMono Nerd Font for Alacritty.
- Tap and trust `FelixKratz/formulae`, then install SketchyVim (`svim`).
- Exclude Ghostty and Obsidian from SketchyVim and set the macOS text-selection
  color to light brown (`#D2B48C`).
- Install oh-my-zsh (framework only — our `.zshrc` and `custom/` replace its defaults).
- Symlink every config into this repo. Existing **real** files are moved aside
  into `~/dotfiles-backup-<timestamp>/` first; existing symlinks are replaced silently.
- Copy `codex/config.toml.template` → `~/.codex/config.toml` (copied, **not**
  symlinked — codex writes machine-specific state back to it).
- Install tmux plugins (TPM) and vim plugins (Vundle).

Optional/work-specific tools (mysql, haproxy, nvm) are left commented out in
`install.sh` — uncomment them there if needed.

### Agent sandbox

Use Safehouse 0.12.0 or newer (`brew upgrade eugene1g/safehouse/agent-safehouse`).
Restart existing agent sessions after changing the policy or upgrading Safehouse;
running processes retain their original sandbox.

`bin/safe` keeps IP networking for APIs, package downloads, databases, and dev
servers. UNIX socket connections and listeners are denied, except for the macOS
DNS resolver. This is not HTTP-only filtering. Docker sockets, SSH-agent sockets,
tmux/Neovim RPC, and browser integrations requiring UNIX sockets are unavailable.
Keychain and clipboard access remain enabled for the configured ACP providers.

Installed Homebrew software, asdf installations/configuration, `~/.local/bin`,
`~/.cargo/bin`, and rustup toolchains are read-only. Update tools from a trusted
terminal outside the agent sandbox. Homebrew service data under `/opt/homebrew/var`
retains its existing read/write access. Shared caches and agent state remain
writable; this policy does not isolate those between sessions.

Avante defaults to Claude ACP through `bin/safe`, using Claude Code's authentication
rather than its native API provider. Its ACP filesystem callbacks are disabled so
file operations happen inside the agent sandbox. Save buffers before asking the
agent to read their latest contents. Native API providers have tools disabled;
the configured ACP alternatives also use `bin/safe`. Avante no longer auto-approves
permission requests. Codex ACP retains its existing full-access mode inside the
outer sandbox to avoid nesting `sandbox-exec`.

The Avante integration guards its installed ACP client constructor because Avante
does not expose a setting to disable host filesystem callbacks. After plugin
updates, rerun the compatibility check below before using it.

Run these checks from an ordinary terminal, outside another sandbox:

```sh
python3 tests/safehouse.py
nvim --headless -u NONE -i NONE -l tests/avante_safehouse.lua
```

The first check uses disposable files and local servers, including a child process
to check sandbox inheritance. The second exercises the installed Avante ACP client
and configuration without making model requests.

### After install (manual, machine-specific)

- `chsh -s $(which zsh)` — if zsh isn't already your login shell
- `exec zsh` — load the new config
- Add asdf language plugins per project, e.g. `asdf plugin add ruby`
- WakaTime prompts for an API key on first vim/nvim run (creates `~/.wakatime.cfg`)

### ovim writing popup

Enable **Use custom launcher script** in ovim's Edit Popup settings. The installer
links `ovim/terminal-launcher.sh` to
`~/Library/Application Support/ovim/terminal-launcher.sh`, the path ovim runs.
Keep terminal prewarming disabled so each edit uses this launcher.

The launcher runs Alacritty with `NVIM_APPNAME=nvim-ovim`, isolating the config
and plugins from the main LazyVim and browser profiles. It preserves ovim's RPC
connection for live sync; `:wq` saves and returns to the original app.
Themes follow macOS appearance at startup and every three seconds while open.
Wrapped-line `j`/`k`, clipboard paste, and Harper are enabled. Use `<Space>ca`
for grammar fixes and `<Space>cd` for diagnostic details.

Alacritty uses **JetBrainsMono Nerd Font Mono**. Reopen existing Alacritty
windows after installing the font. Native fullscreen Space restrictions still
apply to its popup.

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
  ff-only pull when clean. Opens a single nvim pane, without the agent column.
- `work` — the same layout in the current directory, on the checked-out branch.
- `review close` / `create close` — close the current workspace window. The
  worktree is removed when clean and kept when dirty.

Every `review`/`create` run also prunes worktrees whose PR is merged or closed,
skipping dirty trees and worktrees open in a tmux pane. Pruning loses no agent
state: pair keys sessions by worktree path and branch, and the path is
deterministic per branch, so recreating the workspace restores them.
