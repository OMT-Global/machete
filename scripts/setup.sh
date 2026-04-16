#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOTFILES_DIR="${REPO_DIR}/dotfiles"

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
  echo "Xcode Command Line Tools requested. Re-run this command after installation completes."
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

echo "==> Installing Brew packages from Brewfile"
if [[ -f "${REPO_DIR}/Brewfile" ]]; then
  if brew bundle check --file="${REPO_DIR}/Brewfile" --no-upgrade >/dev/null 2>&1; then
    echo "Brewfile already satisfied."
  else
    brew bundle install --file="${REPO_DIR}/Brewfile"
  fi
else
  echo "No Brewfile found in ${REPO_DIR}; skipping brew bundle."
fi

echo "==> Symlinking dotfiles"
if [[ -d "${DOTFILES_DIR}" ]]; then
  while IFS= read -r src; do
    rel="${src#${DOTFILES_DIR}/}"
    dst="${HOME}/${rel}"
    mkdir -p "$(dirname "${dst}")"

    if [[ -e "${dst}" && ! -L "${dst}" ]]; then
      backup="${dst}.bak.$(date +%Y%m%d%H%M%S)"
      echo "  - Backing up ${rel} to ${backup}"
      mv "${dst}" "${backup}"
    fi

    echo "  - Linking ${rel}"
    ln -sfn "${src}" "${dst}"
  done < <(find "${DOTFILES_DIR}" -type f ! -name '.gitkeep' | sort)
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
