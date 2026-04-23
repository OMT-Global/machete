#!/usr/bin/env bats

load helper

setup() {
  setup_test_repo
  install_fake_brew
}

teardown() {
  teardown_test_repo
}

@test "diff succeeds for a matching tracked dotfile" {
  mkdir -p "${TEST_REPO}/dotfiles/.ssh" "${HOME}/.ssh"
  echo "Host example" > "${TEST_REPO}/dotfiles/.ssh/config"
  cp "${TEST_REPO}/dotfiles/.ssh/config" "${HOME}/.ssh/config"

  run "${TEST_REPO}/machete" diff .ssh/config

  assert_success
  assert_output_contains ".ssh/config: matches"
  assert_output_contains "No differences found."
}

@test "diff fails for a missing tracked dotfile" {
  echo "set number" > "${TEST_REPO}/dotfiles/.vimrc"

  run "${TEST_REPO}/machete" diff .vimrc

  assert_failure
  assert_output_contains ".vimrc: missing from"
  assert_output_contains "Differences found."
}

@test "diff compares Brewfile against filtered brew bundle dump" {
  cat > "${TEST_REPO}/Brewfile" <<'BREWFILE'
brew "git"
cask "ghostty"
BREWFILE
  write_fake_brew_dump <<'BREW_DUMP'
tap "homebrew/bundle"
brew "git"
cask "ghostty"
BREW_DUMP

  run "${TEST_REPO}/machete" diff --brew

  assert_success
  assert_output_contains "Brewfile: matches current brew bundle dump"
  assert_output_contains "No differences found."
}
