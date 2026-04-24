#!/usr/bin/env bats

load helper

setup() {
  setup_test_repo
}

teardown() {
  teardown_test_repo
}

@test "uninstall defaults to a dry-run dotfiles teardown" {
  echo 'alias gs="git status"' > "${TEST_REPO}/dotfiles/.zshrc"
  echo "export EDITOR=nano" > "${HOME}/.zshrc.bak.20260424010101"
  ln -s "${TEST_REPO}/dotfiles/.zshrc" "${HOME}/.zshrc"

  run "${TEST_REPO}/machete" uninstall

  assert_success
  [[ -L "${HOME}/.zshrc" ]]
  [[ -f "${HOME}/.zshrc.bak.20260424010101" ]]
  assert_output_contains "Dry run only. Re-run with --apply to make changes."
  assert_output_contains "Would remove managed symlink .zshrc"
  assert_output_contains "Would restore backup .zshrc from ${HOME}/.zshrc.bak.20260424010101"
}

@test "uninstall --dotfiles --apply removes a managed symlink and restores the newest backup" {
  echo 'alias gs="git status"' > "${TEST_REPO}/dotfiles/.zshrc"
  echo "export EDITOR=vim" > "${HOME}/.zshrc.bak.20260424010101"
  echo "export EDITOR=nano" > "${HOME}/.zshrc.bak.20260424020202"
  ln -s "${TEST_REPO}/dotfiles/.zshrc" "${HOME}/.zshrc"

  run "${TEST_REPO}/machete" uninstall --dotfiles --apply

  assert_success
  [[ -f "${HOME}/.zshrc" ]]
  [[ ! -L "${HOME}/.zshrc" ]]
  grep -Fxq "export EDITOR=nano" "${HOME}/.zshrc"
  [[ ! -e "${HOME}/.zshrc.bak.20260424020202" ]]
  [[ -e "${HOME}/.zshrc.bak.20260424010101" ]]
  assert_output_contains "remove managed symlink .zshrc"
  assert_output_contains "restore backup .zshrc from ${HOME}/.zshrc.bak.20260424020202"
}

@test "uninstall skips symlinks that do not point into the repo" {
  mkdir -p "${HOME}/.ssh" "${TEST_ROOT}/elsewhere/.ssh" "${TEST_REPO}/dotfiles/.ssh"
  echo "Host elsewhere" > "${TEST_ROOT}/elsewhere/.ssh/config"
  echo "Host repo" > "${TEST_REPO}/dotfiles/.ssh/config"
  ln -s "${TEST_ROOT}/elsewhere/.ssh/config" "${HOME}/.ssh/config"

  run "${TEST_REPO}/machete" uninstall --dotfiles --apply

  assert_success
  [[ -L "${HOME}/.ssh/config" ]]
  [[ "$(readlink "${HOME}/.ssh/config")" == "${TEST_ROOT}/elsewhere/.ssh/config" ]]
  assert_output_contains "skip .ssh/config: symlink points outside the repo"
}
