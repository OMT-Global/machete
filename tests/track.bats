#!/usr/bin/env bats

load helper

setup() {
  setup_test_repo
}

teardown() {
  teardown_test_repo
}

@test "track copies a home file into dotfiles and symlinks it back" {
  echo 'alias gs="git status"' > "${HOME}/.zshrc"

  run "${TEST_REPO}/machete" track .zshrc

  assert_success
  [[ -f "${TEST_REPO}/dotfiles/.zshrc" ]]
  [[ -L "${HOME}/.zshrc" ]]
  [[ "$(readlink "${HOME}/.zshrc")" == "${TEST_REPO}/dotfiles/.zshrc" ]]
  assert_output_contains "Tracked .zshrc"
}

@test "track accepts home-relative paths and nested files" {
  mkdir -p "${HOME}/.config/ghostty"
  echo "theme = dark" > "${HOME}/.config/ghostty/config"

  run "${TEST_REPO}/machete" track ~/.config/ghostty/config

  assert_success
  [[ -f "${TEST_REPO}/dotfiles/.config/ghostty/config" ]]
  [[ -L "${HOME}/.config/ghostty/config" ]]
}

@test "untrack removes the repo copy and restores a regular home file" {
  mkdir -p "${TEST_REPO}/dotfiles/.ssh" "${HOME}/.ssh"
  echo "Host example" > "${TEST_REPO}/dotfiles/.ssh/config"
  ln -s "${TEST_REPO}/dotfiles/.ssh/config" "${HOME}/.ssh/config"

  run "${TEST_REPO}/machete" untrack .ssh/config

  assert_success
  [[ ! -e "${TEST_REPO}/dotfiles/.ssh/config" ]]
  [[ -f "${HOME}/.ssh/config" ]]
  [[ ! -L "${HOME}/.ssh/config" ]]
  grep -Fxq "Host example" "${HOME}/.ssh/config"
  assert_output_contains "Untracked .ssh/config"
}

@test "track rejects paths outside the home-relative dotfile space" {
  run "${TEST_REPO}/machete" track ../.zshrc

  assert_failure
  assert_output_contains "Invalid dotfile path"
}

@test "track refuses non-portable auth, session, cache, and env paths" {
  mkdir -p "${HOME}/.codex" "${HOME}/.cache/app"
  echo "token" > "${HOME}/.env"
  echo "session" > "${HOME}/.codex/session.json"
  echo "cache" > "${HOME}/.cache/app/state"

  run "${TEST_REPO}/machete" track .env
  assert_failure
  assert_output_contains "Refusing to track .env: machine-local environment file."
  [[ ! -e "${TEST_REPO}/dotfiles/.env" ]]

  run "${TEST_REPO}/machete" track .codex/session.json
  assert_failure
  assert_output_contains "Refusing to track .codex/session.json: local agent auth, sessions, or cache state."
  [[ ! -e "${TEST_REPO}/dotfiles/.codex/session.json" ]]

  run "${TEST_REPO}/machete" track .cache/app/state
  assert_failure
  assert_output_contains "Refusing to track .cache/app/state: cache directory."
  [[ ! -e "${TEST_REPO}/dotfiles/.cache/app/state" ]]
}
