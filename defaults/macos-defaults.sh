#!/usr/bin/env bash
set -euo pipefail

# Finder: show all filename extensions
defaults write NSGlobalDomain AppleShowAllExtensions -bool true

# Dock: auto-hide
defaults write com.apple.dock autohide -bool true

# Restart Dock & Finder to apply some settings
killall Dock Finder 2>/dev/null || true
