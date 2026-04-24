#!/usr/bin/env bats

load helper

setup() {
  setup_test_repo
}

teardown() {
  teardown_test_repo
}

@test "verify initializes and validates tracked dotfiles and Brewfile" {
  echo 'brew "git"' > "${TEST_REPO}/Brewfile"
  echo "export EDITOR=vim" > "${TEST_REPO}/dotfiles/.zshrc"
  cp "${TEST_REPO}/dotfiles/.zshrc" "${HOME}/.zshrc"
  repo_brewfile="$(cd "${TEST_REPO}" && pwd -P)/Brewfile"
  home_zshrc="$(cd "${HOME}" && pwd -P)/.zshrc"

  run "${TEST_REPO}/machete" verify
  assert_failure
  assert_output_contains "NEW ${repo_brewfile}"
  assert_output_contains "NEW ${home_zshrc}"

  run "${TEST_REPO}/machete" verify --init
  assert_success
  assert_output_contains "Baseline updated for 2 file(s)"

  run "${TEST_REPO}/machete" verify
  assert_success
  assert_output_contains "OK no checksum drift found"
}

@test "verify reports changed and missing tracked files" {
  echo 'brew "git"' > "${TEST_REPO}/Brewfile"
  echo "alias ll='ls -la'" > "${TEST_REPO}/dotfiles/.zshrc"
  cp "${TEST_REPO}/dotfiles/.zshrc" "${HOME}/.zshrc"
  repo_brewfile="$(cd "${TEST_REPO}" && pwd -P)/Brewfile"
  home_zshrc="$(cd "${HOME}" && pwd -P)/.zshrc"

  run "${TEST_REPO}/machete" verify --init
  assert_success

  echo "alias ll='ls -lah'" > "${HOME}/.zshrc"
  rm "${TEST_REPO}/Brewfile"

  run "${TEST_REPO}/machete" verify
  assert_failure
  assert_output_contains "CHANGED ${home_zshrc}"
  assert_output_contains "MISSING ${repo_brewfile}"

  run "${TEST_REPO}/machete" verify
  assert_failure
  assert_output_contains "CHANGED ${home_zshrc}"
  assert_output_contains "MISSING ${repo_brewfile}"
}

@test "verify uses the persisted active profile" {
  mkdir -p "${TEST_REPO}/profiles/work/dotfiles"
  echo 'brew "jq"' > "${TEST_REPO}/profiles/work/Brewfile"
  echo "work=true" > "${TEST_REPO}/profiles/work/dotfiles/.profile"
  cp "${TEST_REPO}/profiles/work/dotfiles/.profile" "${HOME}/.profile"

  run "${TEST_REPO}/machete" profile create work
  assert_success

  run "${TEST_REPO}/machete" help --profile work
  assert_success

  run "${TEST_REPO}/machete" verify --init
  assert_success
  assert_output_contains "Baseline updated for 2 file(s)"

  run "${TEST_REPO}/machete" verify
  assert_success
}
