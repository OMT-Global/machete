#!/usr/bin/env bats

load helper

setup() {
  setup_test_repo
  install_fake_brew
  install_fake_xcode_select
  export FAKE_BREW_LOG="${TEST_ROOT}/brew.log"
  export FAKE_BREW_INSTALLED_BREWFILE="${TEST_ROOT}/installed.Brewfile"
}

teardown() {
  teardown_test_repo
}

@test "setup applies base and named profile layers" {
  mkdir -p \
    "${TEST_REPO}/profiles/base/dotfiles/.ssh" \
    "${TEST_REPO}/profiles/work/dotfiles" \
    "${TEST_REPO}/profiles/work/defaults"
  cat > "${TEST_REPO}/profiles/base/Brewfile" <<'BASE_BREW'
brew "git"
BASE_BREW
  cat > "${TEST_REPO}/profiles/work/Brewfile" <<'WORK_BREW'
cask "ghostty"
WORK_BREW
  echo "Host base-example" > "${TEST_REPO}/profiles/base/dotfiles/.ssh/config"
  echo "export WORK=1" > "${TEST_REPO}/profiles/work/dotfiles/.profile"
  cat > "${TEST_REPO}/profiles/work/defaults/macos-defaults.sh" <<'DEFAULTS'
#!/usr/bin/env bash
set -euo pipefail
DEFAULTS
  chmod +x "${TEST_REPO}/profiles/work/defaults/macos-defaults.sh"
  export FAKE_BREW_BUNDLE_CHECK_EXIT=1

  run "${TEST_REPO}/machete" setup --profile work

  assert_success
  [[ -L "${HOME}/.ssh/config" ]]
  [[ -L "${HOME}/.profile" ]]
  [[ "$(readlink "${HOME}/.ssh/config")" == "${TEST_REPO}/profiles/base/dotfiles/.ssh/config" ]]
  [[ "$(readlink "${HOME}/.profile")" == "${TEST_REPO}/profiles/work/dotfiles/.profile" ]]
  grep -Fxq 'brew "git"' "${FAKE_BREW_INSTALLED_BREWFILE}"
  grep -Fxq 'cask "ghostty"' "${FAKE_BREW_INSTALLED_BREWFILE}"
}
