#!/usr/bin/env bats

load helper

setup() {
  setup_test_repo
  install_fake_brew
  rm -rf "${TEST_REPO}/Brewfile" "${TEST_REPO}/defaults"
}

teardown() {
  teardown_test_repo
}

prepare_snapshot_inputs() {
  mkdir -p "${HOME}/.ssh"
  echo 'alias gs="git status"' > "${HOME}/.zshrc"
  echo "Host example" > "${HOME}/.ssh/config"

  write_fake_brew_dump <<'BREW_DUMP'
tap "homebrew/bundle"
tap "local/private"
brew "git"
brew "local/private/internal-tool"
cask "ghostty"
BREW_DUMP

  write_fake_services_list <<'SERVICES'
Name Status User File
redis started pheidon ~/Library/LaunchAgents/homebrew.mxcl.redis.plist
postgresql@16 none
SERVICES
}

@test "snapshot creates portable output files" {
  prepare_snapshot_inputs

  run "${TEST_REPO}/machete" snapshot

  assert_success
  [[ -f "${TEST_REPO}/Brewfile" ]]
  [[ -f "${TEST_REPO}/defaults/brew-services.txt" ]]
  [[ -x "${TEST_REPO}/defaults/macos-defaults.sh" ]]
  [[ -f "${TEST_REPO}/dotfiles/.zshrc" ]]
  [[ -f "${TEST_REPO}/dotfiles/.ssh/config" ]]
  grep -Fxq 'brew "git"' "${TEST_REPO}/Brewfile"
  grep -Fxq 'cask "ghostty"' "${TEST_REPO}/Brewfile"
  ! grep -Fq 'local/private' "${TEST_REPO}/Brewfile"
  grep -Fxq "redis" "${TEST_REPO}/defaults/brew-services.txt"
}

@test "snapshot is idempotent on re-run with unchanged inputs" {
  prepare_snapshot_inputs

  run "${TEST_REPO}/machete" snapshot
  assert_success
  find "${TEST_REPO}/Brewfile" "${TEST_REPO}/defaults" "${TEST_REPO}/dotfiles" \
    -type f -print0 | sort -z | xargs -0 sha256sum > "${TEST_ROOT}/first.sha"

  run "${TEST_REPO}/machete" snapshot
  assert_success
  find "${TEST_REPO}/Brewfile" "${TEST_REPO}/defaults" "${TEST_REPO}/dotfiles" \
    -type f -print0 | sort -z | xargs -0 sha256sum > "${TEST_ROOT}/second.sha"

  diff -u "${TEST_ROOT}/first.sha" "${TEST_ROOT}/second.sha"
}

@test "snapshot --profile writes machine state under the named profile and persists it" {
  prepare_snapshot_inputs

  run "${TEST_REPO}/machete" snapshot --profile work

  assert_success
  [[ -f "${TEST_REPO}/profiles/work/Brewfile" ]]
  [[ -f "${TEST_REPO}/profiles/work/defaults/brew-services.txt" ]]
  [[ -f "${TEST_REPO}/profiles/work/dotfiles/.zshrc" ]]
  [[ -x "${TEST_REPO}/profiles/work/defaults/macos-defaults.sh" ]]
  [[ "$(cat "${TEST_REPO}/.machete/active-profile")" == "work" ]]
  [[ ! -f "${TEST_REPO}/Brewfile" ]]
}
