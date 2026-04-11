#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "==> Ensuring Xcode Command Line Tools are installed"
if ! xcode-select -p >/dev/null 2>&1; then
  xcode-select --install || true
  echo "Xcode Command Line Tools requested. Re-run this script after installation completes."
  exit 1
fi

echo "==> Ensuring Homebrew is installed"
if ! command -v brew >/dev/null 2>&1; then
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# Load brew into this shell (Apple Silicon path)
if [[ -x /opt/homebrew/bin/brew ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

if ! command -v brew >/dev/null 2>&1; then
  echo "Homebrew not found even after install attempt; aborting."
  exit 1
fi

echo "==> Installing Brew packages from Brewfile"
if [[ -f "${REPO_DIR}/Brewfile" ]]; then
  brew bundle --file="${REPO_DIR}/Brewfile"
else
  echo "No Brewfile found in ${REPO_DIR}, skipping brew bundle."
fi

echo "==> Symlinking dotfiles"
DOTFILES_DIR="${REPO_DIR}/dotfiles"
if [[ -d "${DOTFILES_DIR}" ]]; then
  for src in "${DOTFILES_DIR}"/.*; do
    f="$(basename "${src}")"
    [[ "${f}" == "." || "${f}" == ".." || "${f}" == ".gitkeep" ]] && continue
    dst="${HOME}/${f}"
    if [[ -e "${dst}" && ! -L "${dst}" ]]; then
      echo "  - Backing up existing ${f} to ${f}.bak"
      mv "${dst}" "${dst}.bak"
    fi
    echo "  - Linking ${f}"
    ln -sf "${src}" "${dst}"
  done
else
  echo "No dotfiles/ directory found; skipping symlinks."
fi

echo "==> Applying macOS defaults"
DEFAULTS_SCRIPT="${REPO_DIR}/defaults/macos-defaults.sh"
if [[ -x "${DEFAULTS_SCRIPT}" ]]; then
  "${DEFAULTS_SCRIPT}"
else
  echo "No defaults/macos-defaults.sh found or not executable; skipping."
fi

echo ""
echo "==> Setup complete. Open a new terminal to pick up your shell config."
