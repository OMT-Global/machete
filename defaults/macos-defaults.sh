#!/usr/bin/env bash
set -euo pipefail

# Finder: show all filename extensions
defaults write NSGlobalDomain AppleShowAllExtensions -bool true
# Finder: show hidden files and POSIX path in title
defaults write com.apple.finder AppleShowAllFiles -bool true
defaults write com.apple.finder _FXShowPosixPathInTitle -bool true
# Faster window resizing
defaults write NSGlobalDomain NSWindowResizeTime -float 0.001

# Dock: auto-hide
defaults write com.apple.dock autohide -bool true
defaults write com.apple.dock autohide-delay -float 0
defaults write com.apple.dock autohide-time-modifier -float 0.3
# Screenshots: no shadow
defaults write com.apple.screencapture disable-shadow -bool true

# Restart Dock & Finder to apply some settings
killall Dock Finder SystemUIServer 2>/dev/null || true
