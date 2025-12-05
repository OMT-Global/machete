#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="${HOME}/mac-setup"

echo "==> Creating repo dir at $REPO_DIR"
mkdir -p "$REPO_DIR"

echo "==> Exporting Homebrew packages to Brewfile"
if command -v brew >/dev/null 2>&1; then
  brew bundle dump --file="$REPO_DIR/Brewfile" --force
else
  echo "Homebrew not found; skipping Brewfile export."
fi

echo "==> Copying common dotfiles"
DOTFILES=(.zshrc .zprofile .gitconfig .gitignore_global .vimrc)
for f in "${DOTFILES[@]}"; do
  if [[ -f "${HOME}/${f}" ]]; then
    echo "  - ${f}"
    cp "${HOME}/${f}" "$REPO_DIR/${f}"
  fi
done

echo "==> Creating macos-defaults.sh template (edit this manually with your tweaks)"
MACOS_DEFAULTS_FILE="$REPO_DIR/macos-defaults.sh"
if [[ ! -f "$MACOS_DEFAULTS_FILE" ]]; then
  cat > "$MACOS_DEFAULTS_FILE" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

# macOS UI / UX defaults you care about.
# Add to this file as you customize your system over time.

# Keyboard: enable key repeat instead of press-and-hold
defaults write -g ApplePressAndHoldEnabled -bool false

# Expand save and print panels by default
defaults write -g NSNavPanelExpandedStateForSaveMode -bool true
defaults write -g NSNavPanelExpandedStateForSaveMode2 -bool true
defaults write -g PMPrintingExpandedStateForPrint -bool true
defaults write -g PMPrintingExpandedStateForPrint2 -bool true

# Finder: show all filename extensions
defaults write NSGlobalDomain AppleShowAllExtensions -bool true

# Dock: auto-hide
defaults write com.apple.dock autohide -bool true

# Restart Dock & Finder to apply some settings
killall Dock Finder 2>/dev/null || true
EOF
  chmod +x "$MACOS_DEFAULTS_FILE"
else
  echo "  - macos-defaults.sh already exists; not overwriting."
fi

cat <<EOF

Done.

Next steps (one time):

  cd "$REPO_DIR"
  git init
  git add .
  git commit -m "Initial mac setup snapshot"

Push this repo to GitHub (private), e.g. omt-global/mac-setup, so new Macs can clone it.

EOF
