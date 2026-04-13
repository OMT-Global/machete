#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOTFILES=(.zshrc .zprofile .zshenv .profile .gitconfig .gitignore_global .tmux.conf)

find_brew_bin() {
  if command -v brew >/dev/null 2>&1; then
    command -v brew
    return 0
  fi

  if [[ -x /opt/homebrew/bin/brew ]]; then
    echo /opt/homebrew/bin/brew
    return 0
  fi

  if [[ -x /usr/local/bin/brew ]]; then
    echo /usr/local/bin/brew
    return 0
  fi

  return 1
}

echo "==> Ensuring Xcode Command Line Tools are installed"
if ! xcode-select -p >/dev/null 2>&1; then
  xcode-select --install || true
  echo "Xcode Command Line Tools requested. Re-run this script after installation completes."
  exit 1
fi

if ! BREW_BIN="$(find_brew_bin)"; then
  echo "==> Ensuring Homebrew is installed"
  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  BREW_BIN="$(find_brew_bin)"
fi

eval "$("$BREW_BIN" shellenv)"

if ! command -v brew >/dev/null 2>&1; then
  echo "Homebrew not found even after install attempt; aborting."
  exit 1
fi

echo "==> Installing Brew packages from Brewfile (if present)"
if [[ -f "${REPO_DIR}/Brewfile" ]]; then
  if brew bundle check --file="${REPO_DIR}/Brewfile" --no-upgrade >/dev/null 2>&1; then
    echo "Brewfile already satisfied."
  else
    brew bundle install --file="${REPO_DIR}/Brewfile"
  fi
else
  echo "No Brewfile found in ${REPO_DIR}, skipping brew bundle."
fi

echo "==> Symlinking dotfiles"
for f in "${DOTFILES[@]}"; do
  if [[ -f "${REPO_DIR}/${f}" ]]; then
    echo "  - Linking ${f}"
    ln -sfn "${REPO_DIR}/${f}" "${HOME}/${f}"
  fi
done

echo "==> Applying macOS defaults (if macos-defaults.sh exists)"
if [[ -x "${REPO_DIR}/macos-defaults.sh" ]]; then
  "${REPO_DIR}/macos-defaults.sh"
else
  echo "No macos-defaults.sh found or it is not executable; skipping."
fi

echo "==> All done. Open a new terminal to pick up your shell config."
