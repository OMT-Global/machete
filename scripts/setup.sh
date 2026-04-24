#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${REPO_DIR}/scripts/lib/profiles.sh"
MACHETE_PROFILE="${MACHETE_PROFILE:-$(resolve_profile "${REPO_DIR}")}"
DOTFILES_DIR="$(profile_dotfiles_dir "${REPO_DIR}" "${MACHETE_PROFILE}")"
source "${REPO_DIR}/scripts/lib/brew-services.sh"
source "${REPO_DIR}/scripts/lib/dotfiles.sh"
source "${REPO_DIR}/scripts/lib/global-packages.sh"
source "${REPO_DIR}/scripts/lib/editor-extensions.sh"
source "${REPO_DIR}/scripts/lib/snapshot-tags.sh"

if [[ "${MACHETE_SKIP_SNAPSHOT_TAG:-0}" != "1" ]]; then
  echo "==> Creating rollback snapshot"
  if SNAPSHOT_TAG="$(create_snapshot_tag "${REPO_DIR}" "setup")"; then
    echo "  - ${SNAPSHOT_TAG}"
  else
    echo "  - Not in a git worktree; skipping rollback snapshot."
  fi
fi

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
Brewfile_PATH="$(profile_brewfile_path "${REPO_DIR}" "${MACHETE_PROFILE}")"
if [[ -f "${Brewfile_PATH}" ]]; then
  if brew bundle check --file="${Brewfile_PATH}" --no-upgrade >/dev/null 2>&1; then
    echo "Brewfile already satisfied."
  else
    brew bundle install --file="${Brewfile_PATH}"
  fi
else
  echo "No Brewfile found for profile '${MACHETE_PROFILE}'; skipping brew bundle."
fi

echo "==> Restoring global packages"
restore_npm_globals "${REPO_DIR}"
restore_pip_globals "${REPO_DIR}"
restore_cargo_globals "${REPO_DIR}"

echo "==> Symlinking dotfiles"
if [[ -d "${DOTFILES_DIR}" ]]; then
  while IFS= read -r src; do
    rel="${src#${DOTFILES_DIR}/}"
    dst="$(dotfile_home_path "${rel}")"
    mkdir -p "$(dirname "${dst}")"

    if [[ -e "${dst}" && ! -L "${dst}" ]]; then
      backup="${dst}.bak.$(date +%Y%m%d%H%M%S)"
      echo "  - Backing up ${rel} to ${backup}"
      mv "${dst}" "${backup}"
    fi

    echo "  - Linking ${rel}"
    ln -sfn "${src}" "${dst}"
  done < <(dotfiles_list "${DOTFILES_DIR}")
else
  echo "No dotfiles/ directory found; skipping symlinks."
fi

echo "==> Restoring Homebrew services"
brew_services_restore "$(brew_services_state_file)"

editor_extensions_restore "$(editor_extensions_file)"

echo "==> Applying macOS defaults"
DEFAULTS_SCRIPT="$(profile_defaults_script_path "${REPO_DIR}" "${MACHETE_PROFILE}")"
if [[ -x "${DEFAULTS_SCRIPT}" ]]; then
  "${DEFAULTS_SCRIPT}"
else
  echo "No macOS defaults script found for profile '${MACHETE_PROFILE}'; skipping."
fi

echo ""
echo "==> Setup complete. Open a new terminal to pick up your shell config."
