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
  assert_output_contains ".zshrc: symlinked correctly (no checksum baseline"
  assert_output_contains "All checks passed."
}

@test "doctor reports checksum drift for a correctly symlinked dotfile" {
  echo 'alias ll="ls -la"' > "${TEST_REPO}/dotfiles/.zshrc"
  ln -s "${TEST_REPO}/dotfiles/.zshrc" "${HOME}/.zshrc"

  run "${TEST_REPO}/machete" verify --init
  assert_success

  echo 'alias ll="ls -lah"' > "${HOME}/.zshrc"

  run "${TEST_REPO}/machete" doctor

  assert_failure
  assert_output_contains ".zshrc: symlinked correctly (CONTENT DRIFT"
  assert_output_contains "Some checks need attention"
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

@test "doctor inspects the selected profile layout" {
  mkdir -p "${TEST_REPO}/profiles/work/dotfiles" "${TEST_REPO}/profiles/work/defaults"
  : > "${TEST_REPO}/profiles/work/Brewfile"
  cat > "${TEST_REPO}/profiles/work/defaults/macos-defaults.sh" <<'DEFAULTS'
#!/usr/bin/env bash
set -euo pipefail
DEFAULTS
  chmod +x "${TEST_REPO}/profiles/work/defaults/macos-defaults.sh"
  echo 'alias ll="ls -la"' > "${TEST_REPO}/profiles/work/dotfiles/.zshrc"
  ln -s "${TEST_REPO}/profiles/work/dotfiles/.zshrc" "${HOME}/.zshrc"

  run "${TEST_REPO}/machete" doctor --profile work

  assert_success
  assert_output_contains ".zshrc: symlinked correctly"
  assert_output_contains "All checks passed."
}

@test "doctor reports the active layered profile and inspects base plus overlay dotfiles" {
  mkdir -p "${TEST_REPO}/profiles/base/dotfiles/.ssh" "${TEST_REPO}/profiles/work/dotfiles"
  echo 'brew "git"' > "${TEST_REPO}/profiles/base/Brewfile"
  echo "Host base-example" > "${TEST_REPO}/profiles/base/dotfiles/.ssh/config"
  echo "export WORK=1" > "${TEST_REPO}/profiles/work/dotfiles/.profile"
  mkdir -p "${HOME}/.ssh"
  ln -s "${TEST_REPO}/profiles/base/dotfiles/.ssh/config" "${HOME}/.ssh/config"
  ln -s "${TEST_REPO}/profiles/work/dotfiles/.profile" "${HOME}/.profile"

  run "${TEST_REPO}/machete" doctor --profile work

  assert_success
  assert_output_contains "Active profile: work"
  assert_output_contains ".ssh/config: symlinked correctly"
  assert_output_contains ".profile: symlinked correctly"
}
