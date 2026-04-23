#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DOTFILES_DIR="${REPO_DIR}/dotfiles"
source "${REPO_DIR}/scripts/lib/brewfile.sh"
source "${REPO_DIR}/scripts/lib/brew-services.sh"
source "${REPO_DIR}/scripts/lib/global-packages.sh"
source "${REPO_DIR}/scripts/lib/editor-extensions.sh"
source "${REPO_DIR}/scripts/lib/snapshot-tags.sh"

WITH_EXTENSIONS=0

usage() {
  cat <<'EOF'
Export current machine state to the repo.

Usage:
  ./machete snapshot [--with-extensions]

Options:
  --with-extensions  Also save VS Code-compatible editor extensions to packages/vscode-extensions.txt
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --with-extensions)
      WITH_EXTENSIONS=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown snapshot option: $1" >&2
      echo "" >&2
      usage >&2
      exit 1
      ;;
    esac
done

echo "==> Creating rollback snapshot"
if SNAPSHOT_TAG="$(create_snapshot_tag "${REPO_DIR}" "snapshot")"; then
  echo "  - ${SNAPSHOT_TAG}"
else
  echo "  - Not in a git worktree; skipping rollback snapshot."
fi

echo "==> Exporting Homebrew packages to Brewfile"
if command -v brew >/dev/null 2>&1; then
  brewfile_dump_filtered "${REPO_DIR}/Brewfile"
  echo "  - Brewfile updated with portable filters"

  echo "==> Exporting Homebrew services to defaults/brew-services.txt"
  if brew_services_snapshot "$(brew_services_state_file)"; then
    echo "  - Homebrew services updated"
  else
    echo "  - brew services list failed; skipping services export."
  fi
else
  echo "  - Homebrew not found; skipping Brewfile export."
fi

echo "==> Exporting global packages"
snapshot_npm_globals "${REPO_DIR}"
snapshot_pip_globals "${REPO_DIR}"
snapshot_cargo_globals "${REPO_DIR}"

if [[ "${WITH_EXTENSIONS}" -eq 1 ]]; then
  echo "==> Exporting editor extensions"
  editor_extensions_snapshot "$(editor_extensions_file)"
fi

echo "==> Copying dotfiles to ${DOTFILES_DIR}"
mkdir -p "${DOTFILES_DIR}"
DOTFILES=(.zshrc .zprofile .gitconfig .gitignore_global .vimrc .ssh/config)
for f in "${DOTFILES[@]}"; do
  src="${HOME}/${f}"
  if [[ -f "${src}" ]]; then
    dst_dir="${DOTFILES_DIR}/$(dirname "${f}")"
    mkdir -p "${dst_dir}"
    cp "${src}" "${DOTFILES_DIR}/${f}"
    echo "  - ${f}"
  fi
done

echo "==> Ensuring defaults/macos-defaults.sh exists"
DEFAULTS_SCRIPT="${REPO_DIR}/defaults/macos-defaults.sh"
if [[ ! -f "${DEFAULTS_SCRIPT}" ]]; then
  echo "  - Creating template (edit to add your preferences)"
  mkdir -p "${REPO_DIR}/defaults"
  cat > "${DEFAULTS_SCRIPT}" <<'DEFAULTS'
#!/usr/bin/env bash
set -euo pipefail

# macOS system preferences.
# Run via: ./machete defaults

# --- Keyboard ---
# Enable key repeat instead of press-and-hold character picker
defaults write -g ApplePressAndHoldEnabled -bool false
# Fast key repeat (lower = faster; 2 is very fast)
defaults write NSGlobalDomain KeyRepeat -int 2
defaults write NSGlobalDomain InitialKeyRepeat -int 15

# --- Dialogs ---
defaults write -g NSNavPanelExpandedStateForSaveMode -bool true
defaults write -g NSNavPanelExpandedStateForSaveMode2 -bool true
defaults write -g PMPrintingExpandedStateForPrint -bool true
defaults write -g PMPrintingExpandedStateForPrint2 -bool true

# --- Finder ---
defaults write NSGlobalDomain AppleShowAllExtensions -bool true
defaults write com.apple.finder AppleShowAllFiles -bool true
defaults write com.apple.finder ShowPathbar -bool true
defaults write com.apple.finder ShowStatusBar -bool true
# Default to list view
defaults write com.apple.finder FXPreferredViewStyle -string "Nlsv"
# No warning when changing file extension
defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false

# --- Dock ---
defaults write com.apple.dock autohide -bool true
defaults write com.apple.dock autohide-delay -float 0
defaults write com.apple.dock show-recents -bool false

# --- Screenshots ---
defaults write com.apple.screencapture location -string "${HOME}/Desktop"
defaults write com.apple.screencapture type -string "png"
defaults write com.apple.screencapture disable-shadow -bool true

# --- Activity Monitor ---
defaults write com.apple.ActivityMonitor OpenMainWindow -bool true
defaults write com.apple.ActivityMonitor ShowCategory -int 0

# --- Apply ---
killall Dock Finder SystemUIServer 2>/dev/null || true
echo "  - macOS defaults applied"
DEFAULTS
  chmod +x "${DEFAULTS_SCRIPT}"
else
  echo "  - defaults/macos-defaults.sh already exists; not overwriting."
fi

echo ""
echo "==> Snapshot complete. Review changes and commit:"
echo "    cd ${REPO_DIR}"
echo "    git diff --stat"
echo "    git add ."
echo "    git commit -m 'snapshot: \$(date +%Y-%m-%d)' && git push"
