#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "==> Ensuring Xcode Command Line Tools are installed"
if ! xcode-select -p >/dev/null 2>&1; then
  xcode-select --install || true
  echo "Xcode Command Line Tools requested. Re-run this script after installation completes."
  exit 1
fi

echo "==> Ensuring Homebrew is installed"
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || true

# Load brew into this shell (Apple Silicon path)
if [[ -x /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

if ! command -v brew >/dev/null 2>&1; then
  echo "Homebrew not found even after install attempt; aborting."
  exit 1
fi

echo "==> Installing Brew packages from Brewfile (if present)"
if [[ -f "${REPO_DIR}/Brewfile" ]]; then
  brew bundle --file="${REPO_DIR}/Brewfile"
else
  echo "No Brewfile found in ${REPO_DIR}, skipping brew bundle."
fi

echo "==> Symlinking dotfiles"
DOTFILES=(.zshrc .zprofile .gitconfig .gitignore_global .vimrc)
for f in "${DOTFILES[@]}"; do
  if [[ -f "${REPO_DIR}/${f}" ]]; then
    echo "  - Linking ${f}"
    ln -sf "${REPO_DIR}/${f}" "${HOME}/${f}"
  fi
done

echo "==> Applying macOS defaults (if macos-defaults.sh exists)"
if [[ -x "${REPO_DIR}/macos-defaults.sh" ]]; then
  "${REPO_DIR}/macos-defaults.sh"
else
  echo "No macos-defaults.sh found or it is not executable; skipping."
fi

echo "==> All done. Open a new terminal to pick up your shell config."
