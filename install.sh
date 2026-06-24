#!/usr/bin/env bash
# Bootstrap these dotfiles on a fresh macOS machine.
#
#   git clone <repo> ~/workspace/dotfiles
#   ~/workspace/dotfiles/install.sh
#
# Idempotent: safe to re-run. Existing real files are moved aside into a
# timestamped backup dir before a symlink takes their place; existing symlinks
# are replaced silently.
set -euo pipefail

DOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKUP="$HOME/dotfiles-backup-$(date +%Y%m%d-%H%M%S)"

log()  { printf '\033[1;34m==>\033[0m %s\n' "$*"; }
warn() { printf '\033[1;33m!!\033[0m  %s\n' "$*"; }

# link <source-relative-to-DOT> <absolute-target>
link() {
  local src="$DOT/$1" tgt="$2"
  [ -e "$src" ] || { warn "missing source: $src (skipped)"; return 0; }
  mkdir -p "$(dirname "$tgt")"
  if [ -L "$tgt" ]; then
    rm "$tgt"
  elif [ -e "$tgt" ]; then
    mkdir -p "$BACKUP"
    mv "$tgt" "$BACKUP/"
    warn "backed up existing $tgt -> $BACKUP/"
  fi
  ln -s "$src" "$tgt"
  printf '   %s -> %s\n' "$tgt" "$src"
}

# ---------------------------------------------------------------------------
# 0. OS detection — this repo bootstraps both macOS laptops and Ubuntu devboxes
#    (the devbox AMI's /opt/bin/setup-dotfiles clones this repo and runs
#    install.sh as the ubuntu user at cloud-init: no Homebrew, no SSH agent).
# ---------------------------------------------------------------------------
OS="$(uname -s)"

# ---------------------------------------------------------------------------
# 1. Packages
# ---------------------------------------------------------------------------
if [ "$OS" = "Darwin" ]; then
  if ! command -v brew >/dev/null 2>&1; then
    log "Installing Homebrew"
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  fi
  eval "$(/opt/homebrew/bin/brew shellenv)"

  log "Installing core formulae"
  brew install \
    tmux neovim asdf gh gnupg pinentry-mac difftastic git-lfs deno ripgrep

  log "Installing agent-safehouse (sandbox wrapper used by .zshrc)"
  brew install eugene1g/safehouse/agent-safehouse

  # Optional / work tools — uncomment as needed:
  # brew install mysql@8.4 haproxy@2.8
  # brew install nvm

  git lfs install
else
  # Linux (Ubuntu devbox). No Homebrew. Use apt + the official neovim release.
  # Everything here is non-fatal so a transient failure never blocks the
  # symlink step below (which is what actually puts nvim/ at ~/.config/nvim).
  if sudo -n true 2>/dev/null; then
    log "Installing core apt packages"
    sudo apt-get update -y || warn "apt-get update failed (non-fatal)"
    sudo apt-get install -y \
      git curl ca-certificates tmux zsh gnupg git-lfs ripgrep build-essential \
      || warn "some apt packages failed (non-fatal)"
    git lfs install || warn "git lfs install failed (non-fatal)"
  else
    warn "no passwordless sudo — skipping apt packages (install git/tmux/zsh manually)"
  fi

  # neovim: apt's build is too old for LazyVim — install the official release.
  if ! command -v nvim >/dev/null 2>&1; then
    case "$(uname -m)" in
      x86_64)        NVIM_ASSET=nvim-linux-x86_64 ;;
      aarch64|arm64) NVIM_ASSET=nvim-linux-arm64 ;;
      *)             NVIM_ASSET="" ;;
    esac
    if [ -n "$NVIM_ASSET" ]; then
      log "Installing neovim ($NVIM_ASSET) from official release"
      tmp="$(mktemp -d)"
      if curl -fL "https://github.com/neovim/neovim/releases/latest/download/${NVIM_ASSET}.tar.gz" \
           -o "$tmp/nvim.tar.gz"; then
        if sudo -n true 2>/dev/null; then
          sudo rm -rf "/opt/${NVIM_ASSET}"
          sudo tar -C /opt -xzf "$tmp/nvim.tar.gz"
          sudo ln -sf "/opt/${NVIM_ASSET}/bin/nvim" /usr/local/bin/nvim
        else
          rm -rf "$HOME/.local/${NVIM_ASSET}"; mkdir -p "$HOME/.local" "$HOME/.local/bin"
          tar -C "$HOME/.local" -xzf "$tmp/nvim.tar.gz"
          ln -sf "$HOME/.local/${NVIM_ASSET}/bin/nvim" "$HOME/.local/bin/nvim"
          warn "no sudo — installed nvim to ~/.local/bin (ensure it's on PATH)"
        fi
      else
        warn "could not download neovim (non-fatal)"
      fi
      rm -rf "$tmp"
    else
      warn "unknown arch $(uname -m) — skipping neovim install"
    fi
  fi
fi

# ---------------------------------------------------------------------------
# 2. oh-my-zsh (framework only; our .zshrc + custom/ replace its defaults)
# ---------------------------------------------------------------------------
if [ ! -d "$HOME/.oh-my-zsh" ]; then
  log "Installing oh-my-zsh"
  RUNZSH=no CHSH=no KEEP_ZSHRC=yes \
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" \
    "" --unattended --keep-zshrc
fi

# ---------------------------------------------------------------------------
# 3. Symlinks
# ---------------------------------------------------------------------------
log "Symlinking dotfiles"

# ~/bin — on PATH via .zshrc; targets of `make install` etc.
mkdir -p "$HOME/bin"

# oh-my-zsh custom dir: replace OMZ's default with ours (themes + aliases)
if [ -L "$HOME/.oh-my-zsh/custom" ]; then
  rm "$HOME/.oh-my-zsh/custom"
elif [ -e "$HOME/.oh-my-zsh/custom" ]; then
  mkdir -p "$BACKUP"; mv "$HOME/.oh-my-zsh/custom" "$BACKUP/oh-my-zsh-custom"
fi
ln -s "$DOT/zsh/.oh-my-zsh/custom" "$HOME/.oh-my-zsh/custom"
printf '   %s -> %s\n' "$HOME/.oh-my-zsh/custom" "$DOT/zsh/.oh-my-zsh/custom"

# zsh / bash
link zsh/.zshrc          "$HOME/.zshrc"
link zsh/.zprofile       "$HOME/.zprofile"
link bash/.bashrc        "$HOME/.bashrc"
link bash/.bash_profile  "$HOME/.bash_profile"
link bash/.bash_aliases  "$HOME/.bash_aliases"

# git
link git/.gitconfig           "$HOME/.gitconfig"
link git/.gitignore_global    "$HOME/.gitignore_global"
link git/.git-completion.bash "$HOME/.git-completion.bash"

# editors / shells / lint tools
link tmux/.tmux.conf      "$HOME/.tmux.conf"
link vim/.vimrc           "$HOME/.vimrc"
link pry/.pryrc           "$HOME/.pryrc"
link rubocop/.rubocop.yml "$HOME/.rubocop.yml"
link asdf/.default-gems   "$HOME/.default-gems"

# XDG configs (cross-platform)
link nvim                   "$HOME/.config/nvim"
link gh/config.yml          "$HOME/.config/gh/config.yml"
link powerline/config_files "$HOME/.config/powerline"

# macOS-only: ghostty (mac terminal), agent-safehouse (mac sandbox), and gpg
# (config points at pinentry-mac). Skipped on Linux.
if [ "$OS" = "Darwin" ]; then
  link ghostty/config                      "$HOME/.config/ghostty/config"
  link agent-safehouse/local-overrides.sb  "$HOME/.config/agent-safehouse/local-overrides.sb"

  # gpg (dir must be 700)
  mkdir -p "$HOME/.gnupg"; chmod 700 "$HOME/.gnupg"
  link gpg/.gnupg/gpg.conf       "$HOME/.gnupg/gpg.conf"
  link gpg/.gnupg/gpg-agent.conf "$HOME/.gnupg/gpg-agent.conf"
fi

# Per-OS shell-local file: COPIED (not symlinked) so each machine can diverge.
# .zshrc sources ~/.zshrc.local at the end. Never overwrite an existing one.
case "$OS" in Darwin) loc=darwin ;; *) loc=linux ;; esac
if [ -e "$HOME/.zshrc.local" ]; then
  warn "~/.zshrc.local exists, leaving as-is"
elif [ -f "$DOT/local/zshrc.local.$loc" ]; then
  cp "$DOT/local/zshrc.local.$loc" "$HOME/.zshrc.local"
  printf '   copied local/zshrc.local.%s -> ~/.zshrc.local\n' "$loc"
fi

# codex: COPY, never symlink (codex writes machine-specific state back to it)
mkdir -p "$HOME/.codex"
if [ -e "$HOME/.codex/config.toml" ]; then
  warn "~/.codex/config.toml exists, leaving as-is"
else
  cp "$DOT/codex/config.toml.template" "$HOME/.codex/config.toml"
  printf '   copied codex/config.toml.template -> ~/.codex/config.toml\n'
fi

# claude: COPY, never symlink (claude writes machine-specific state back, e.g.
# plugin install paths, theme toggles). Template carries only portable prefs +
# declarative enabledPlugins/extraKnownMarketplaces so plugins reinstall on use.
mkdir -p "$HOME/.claude"
if [ -e "$HOME/.claude/settings.json" ]; then
  warn "~/.claude/settings.json exists, leaving as-is"
else
  cp "$DOT/claude/settings.json.template" "$HOME/.claude/settings.json"
  printf '   copied claude/settings.json.template -> ~/.claude/settings.json\n'
fi

# ---------------------------------------------------------------------------
# 4. tmux plugins (TPM) + vim plugins (Vundle)
# ---------------------------------------------------------------------------
log "Installing tmux plugins (TPM)"
bash "$DOT/tmux/install-plugins.sh" || warn "tmux plugin install failed (non-fatal)"

# Legacy vim/Vundle — nvim (LazyVim) installs its own plugins on first launch,
# so this is best-effort and skipped entirely when vim isn't present.
if command -v vim >/dev/null 2>&1; then
  log "Installing vim plugins (Vundle)"
  VUNDLE="$HOME/.vim/bundle/Vundle.vim"
  if [ -d "$VUNDLE/.git" ]; then
    git -C "$VUNDLE" pull --ff-only || warn "could not update Vundle (non-fatal)"
  else
    git clone https://github.com/VundleVim/Vundle.vim.git "$VUNDLE" || warn "could not clone Vundle (non-fatal)"
  fi
  vim +PluginInstall +qall >/dev/null 2>&1 || true
fi

# ---------------------------------------------------------------------------
# 5. Personal repos: crit-vim + pair (clone + install)
# ---------------------------------------------------------------------------
WS="$HOME/workspace"
export PATH="${ASDF_DATA_DIR:-$HOME/.asdf}/shims:$PATH"

# These are SSH clones; at devbox cloud-init there is no SSH agent, so they may
# fail — that's fine, they're optional. Re-run install.sh after SSHing in (agent
# forwarded) to finish them. Nothing here may abort the script.
clone_or_update() {  # clone_or_update <name> <git-url>
  local dir="$WS/$1"
  if [ -d "$dir/.git" ]; then
    log "Updating $1"; git -C "$dir" pull --ff-only || warn "could not fast-forward $1"
  else
    log "Cloning $1"; git clone "$2" "$dir" || warn "could not clone $1 (no SSH agent? skipped)"
  fi
}

clone_or_update crit-vim git@github.com:ssemakov/crit-vim.git
clone_or_update pair     git@github.com:ssemakov/pair.git

if [ -d "$WS/crit-vim" ]; then
  log "Installing crit-vim (CLI + Claude Code skill; nvim plugin spec is symlinked above)"
  ln -sfn "$WS/crit-vim/bin/crit-vim" "$HOME/bin/crit-vim"
  mkdir -p "$HOME/.claude/skills"
  ln -sfn "$WS/crit-vim/integrations/claude-code/skills/crit-vim" "$HOME/.claude/skills/crit-vim"
fi

if [ -d "$WS/pair" ] && command -v asdf >/dev/null 2>&1; then
  log "Installing pair (Go via asdf, then make install -> ~/bin/pair)"
  asdf plugin add golang https://github.com/asdf-community/asdf-golang.git 2>/dev/null || true
  ( cd "$WS/pair" && asdf install golang && make install ) || warn "pair build failed (skipped)"
elif [ -d "$WS/pair" ]; then
  warn "asdf not found — skipping pair build"
fi

# ---------------------------------------------------------------------------
log "Done."
echo
echo "Next steps (manual, machine-specific):"
echo "  - chsh -s \$(which zsh)   # if zsh isn't your login shell"
echo "  - exec zsh                # load the new config"
echo "  - add asdf language plugins per project (e.g. asdf plugin add ruby)"
echo "  - WakaTime will prompt for an API key on first nvim/vim run (~/.wakatime.cfg)"
[ -d "$BACKUP" ] && echo "  - review backed-up originals in: $BACKUP"
