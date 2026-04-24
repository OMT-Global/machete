#!/usr/bin/env bats

load helper

setup() {
  setup_test_repo
}

teardown() {
  teardown_test_repo
}

@test "profile create scaffolds a named profile and list marks the active profile" {
  run "${TEST_REPO}/machete" profile create work

  assert_success
  [[ -d "${TEST_REPO}/profiles/work/dotfiles" ]]
  [[ -d "${TEST_REPO}/profiles/work/packages" ]]
  [[ -x "${TEST_REPO}/profiles/work/defaults/macos-defaults.sh" ]]

  run "${TEST_REPO}/machete" help --profile work

  assert_success
  [[ "$(cat "${TEST_REPO}/.machete/active-profile")" == "work" ]]

  run "${TEST_REPO}/machete" profile list

  assert_success
  assert_output_contains "* work"
  assert_output_contains "  default"
}
