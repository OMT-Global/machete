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
