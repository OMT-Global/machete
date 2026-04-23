#!/usr/bin/env bats

load helper

setup() {
  setup_test_repo
  install_fake_brew
  install_fake_git
}

teardown() {
  teardown_test_repo
}

@test "doctor reports healthy state" {
  echo 'alias ll="ls -la"' > "${TEST_REPO}/dotfiles/.zshrc"
  ln -s "${TEST_REPO}/dotfiles/.zshrc" "${HOME}/.zshrc"

  run "${TEST_REPO}/machete" doctor

  assert_success
  assert_output_contains "All Brewfile entries installed"
  assert_output_contains ".zshrc: symlinked correctly"
  assert_output_contains "All checks passed."
}

@test "doctor fails when a tracked dotfile is missing from home" {
  echo 'alias ll="ls -la"' > "${TEST_REPO}/dotfiles/.zshrc"

  run "${TEST_REPO}/machete" doctor

  assert_failure
  assert_output_contains ".zshrc: missing from home directory"
  assert_output_contains "Some checks need attention"
}

@test "doctor fails when Brewfile entries are not installed" {
  export FAKE_BREW_BUNDLE_CHECK_EXIT=1

  run "${TEST_REPO}/machete" doctor

  assert_failure
  assert_output_contains "Brewfile drift detected"
  assert_output_contains "Some checks need attention"
}
