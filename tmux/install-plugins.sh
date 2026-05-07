#!/usr/bin/env bash
# Bootstrap TPM and install all plugins declared in ~/.tmux.conf.
set -euo pipefail

TPM_DIR="${HOME}/.tmux/plugins/tpm"

if [[ ! -d "${TPM_DIR}" ]]; then
  echo "Cloning TPM into ${TPM_DIR}"
  git clone https://github.com/tmux-plugins/tpm "${TPM_DIR}"
else
  echo "TPM already present; updating"
  git -C "${TPM_DIR}" pull --ff-only
fi

echo "Installing plugins"
"${TPM_DIR}/bin/install_plugins"

echo "Updating plugins"
"${TPM_DIR}/bin/update_plugins" all

echo "Done. Reload tmux config with: tmux source-file ~/.tmux.conf"
