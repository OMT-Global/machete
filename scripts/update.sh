#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if ! command -v brew >/dev/null 2>&1; then
  echo "Homebrew not found; run ./machete setup first."
  exit 1
fi

echo "==> Updating Homebrew"
brew update

echo "==> Upgrading outdated packages"
brew upgrade

echo "==> Upgrading casks"
brew upgrade --cask --greedy-auto-updates 2>/dev/null || brew upgrade --cask

echo "==> Running bundle to install any new Brewfile entries"
if [[ -f "${REPO_DIR}/Brewfile" ]]; then
  brew bundle --file="${REPO_DIR}/Brewfile"
fi

echo "==> Cleaning up old versions"
brew cleanup --prune=7

echo "==> Running brew doctor"
brew doctor || true

echo ""
echo "==> Update complete."
