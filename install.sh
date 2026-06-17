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
# 1. Homebrew + core packages
# ---------------------------------------------------------------------------
if ! command -v brew >/dev/null 2>&1; then
  log "Installing Homebrew"
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi
eval "$(/opt/homebrew/bin/brew shellenv)"

log "Installing core formulae"
brew install \
  tmux neovim asdf gh gnupg pinentry-mac difftastic git-lfs

log "Installing agent-safehouse (sandbox wrapper used by .zshrc)"
brew install eugene1g/safehouse/agent-safehouse

# Optional / work tools — uncomment as needed:
# brew install mysql@8.4 haproxy@2.8
# brew install nvm

git lfs install

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

# XDG configs
link nvim                                "$HOME/.config/nvim"
link ghostty/config                      "$HOME/.config/ghostty/config"
link gh/config.yml                       "$HOME/.config/gh/config.yml"
link agent-safehouse/local-overrides.sb  "$HOME/.config/agent-safehouse/local-overrides.sb"
link powerline/config_files              "$HOME/.config/powerline"

# gpg (dir must be 700)
mkdir -p "$HOME/.gnupg"; chmod 700 "$HOME/.gnupg"
link gpg/.gnupg/gpg.conf       "$HOME/.gnupg/gpg.conf"
link gpg/.gnupg/gpg-agent.conf "$HOME/.gnupg/gpg-agent.conf"

# codex: COPY, never symlink (codex writes machine-specific state back to it)
mkdir -p "$HOME/.codex"
if [ -e "$HOME/.codex/config.toml" ]; then
  warn "~/.codex/config.toml exists, leaving as-is"
else
  cp "$DOT/codex/config.toml.template" "$HOME/.codex/config.toml"
  printf '   copied codex/config.toml.template -> ~/.codex/config.toml\n'
fi

# ---------------------------------------------------------------------------
# 4. tmux plugins (TPM) + vim plugins (Vundle)
# ---------------------------------------------------------------------------
log "Installing tmux plugins (TPM)"
bash "$DOT/tmux/install-plugins.sh"

log "Installing vim plugins (Vundle)"
VUNDLE="$HOME/.vim/bundle/Vundle.vim"
if [ -d "$VUNDLE/.git" ]; then
  git -C "$VUNDLE" pull --ff-only
else
  git clone https://github.com/VundleVim/Vundle.vim.git "$VUNDLE"
fi
vim +PluginInstall +qall >/dev/null 2>&1 || true

# ---------------------------------------------------------------------------
# 5. Personal repos: crit-vim + pair (clone + install)
# ---------------------------------------------------------------------------
WS="$HOME/workspace"
export PATH="${ASDF_DATA_DIR:-$HOME/.asdf}/shims:$PATH"

clone_or_update() {  # clone_or_update <name> <git-url>
  local dir="$WS/$1"
  if [ -d "$dir/.git" ]; then
    log "Updating $1"; git -C "$dir" pull --ff-only || warn "could not fast-forward $1"
  else
    log "Cloning $1"; git clone "$2" "$dir"
  fi
}

clone_or_update crit-vim git@github.com:ssemakov/crit-vim.git
clone_or_update pair     git@github.com:ssemakov/pair.git

log "Installing crit-vim (CLI + Claude Code skill; nvim plugin spec is symlinked above)"
ln -sfn "$WS/crit-vim/bin/crit-vim" "$HOME/bin/crit-vim"
mkdir -p "$HOME/.claude/skills"
ln -sfn "$WS/crit-vim/integrations/claude-code/skills/crit-vim" "$HOME/.claude/skills/crit-vim"

log "Installing pair (Go via asdf, then make install -> ~/bin/pair)"
asdf plugin add golang https://github.com/asdf-community/asdf-golang.git 2>/dev/null || true
( cd "$WS/pair" && asdf install golang && make install )

# ---------------------------------------------------------------------------
log "Done."
echo
echo "Next steps (manual, machine-specific):"
echo "  - chsh -s \$(which zsh)   # if zsh isn't your login shell"
echo "  - exec zsh                # load the new config"
echo "  - add asdf language plugins per project (e.g. asdf plugin add ruby)"
echo "  - WakaTime will prompt for an API key on first nvim/vim run (~/.wakatime.cfg)"
[ -d "$BACKUP" ] && echo "  - review backed-up originals in: $BACKUP"
