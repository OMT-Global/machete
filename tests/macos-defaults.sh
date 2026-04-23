#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${REPO_DIR}/scripts/lib/macos-defaults.sh"

assert_contains() {
  local file="$1"
  local expected="$2"

  if ! grep -Fq "$expected" "$file"; then
    echo "Expected ${file} to contain: ${expected}" >&2
    exit 1
  fi
}

assert_not_contains() {
  local file="$1"
  local unexpected="$2"

  if grep -Fq "$unexpected" "$file"; then
    echo "Expected ${file} not to contain: ${unexpected}" >&2
    exit 1
  fi
}

tmpdir="$(mktemp -d "${TMPDIR:-/tmp}/machete-defaults-test.XXXXXX")"
trap 'rm -rf "$tmpdir"' EXIT

CI=true macos_defaults_init "${tmpdir}/minimal.sh"
assert_contains "${tmpdir}/minimal.sh" "Preset: minimal"
assert_contains "${tmpdir}/minimal.sh" "defaults write NSGlobalDomain AppleShowAllExtensions -bool true"
assert_contains "${tmpdir}/minimal.sh" 'defaults write com.apple.screencapture location -string "${HOME}/Desktop"'
assert_not_contains "${tmpdir}/minimal.sh" "ApplePressAndHoldEnabled"
assert_not_contains "${tmpdir}/minimal.sh" "allowApplePersonalizedAdvertising"
test -x "${tmpdir}/minimal.sh"

CI=true macos_defaults_init "${tmpdir}/developer.sh" developer
assert_contains "${tmpdir}/developer.sh" "Preset: developer"
assert_contains "${tmpdir}/developer.sh" "ApplePressAndHoldEnabled"
assert_contains "${tmpdir}/developer.sh" "FXPreferredViewStyle"
assert_contains "${tmpdir}/developer.sh" "com.apple.dock autohide"
assert_contains "${tmpdir}/developer.sh" "com.apple.ActivityMonitor OpenMainWindow"
assert_not_contains "${tmpdir}/developer.sh" "allowApplePersonalizedAdvertising"

CI=true macos_defaults_init "${tmpdir}/privacy.sh" privacy
assert_contains "${tmpdir}/privacy.sh" "Preset: privacy"
assert_contains "${tmpdir}/privacy.sh" "allowApplePersonalizedAdvertising"
assert_contains "${tmpdir}/privacy.sh" "SuppressSearchSuggestions"

for shell_file in \
  "${REPO_DIR}/machete" \
  "${REPO_DIR}/scripts/snapshot.sh" \
  "${REPO_DIR}/scripts/lib/macos-defaults.sh"; do
  bash -n "$shell_file"
done
