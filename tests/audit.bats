#!/usr/bin/env bats

load helper

setup() {
  setup_test_repo
  export MACHETE_AUDIT_BASELINE_MODE=foreground
}

teardown() {
  teardown_test_repo
}

@test "audit builds a baseline on first run and then reports clean state" {
  mkdir -p "${HOME}/.config/tool"
  echo "alpha=1" > "${HOME}/.config/tool/settings.toml"

  run "${TEST_REPO}/machete" audit
  assert_success
  assert_output_contains "No audit baseline found. Building one now..."
  assert_output_contains "Baseline updated for 1 file(s)"

  run "${TEST_REPO}/machete" audit
  assert_success
  assert_output_contains "OK no audit drift found"
}

@test "snapshot refreshes the full-home audit baseline and audit reports grouped changes" {
  mkdir -p "${HOME}/.config/app"
  echo "theme=light" > "${HOME}/.config/app/settings.toml"

  run "${TEST_REPO}/machete" snapshot
  assert_success
  assert_output_contains "Refreshing full-home audit baseline"

  echo "theme=dark" > "${HOME}/.config/app/settings.toml"
  echo "enabled=true" > "${HOME}/.config/app/feature.toml"

  run "${TEST_REPO}/machete" audit --dir "${HOME}/.config"
  assert_failure
  assert_output_contains "NEW FILES"
  assert_output_contains "${HOME}/.config/app/feature.toml"
  assert_output_contains "CHANGED FILES"
  assert_output_contains "${HOME}/.config/app/settings.toml"
}

@test "audit exports csv and reports missing files since the baseline" {
  mkdir -p "${HOME}/.local/state"
  echo "initial" > "${HOME}/.local/state/app.log"

  run "${TEST_REPO}/machete" audit
  assert_success

  rm "${HOME}/.local/state/app.log"

  export_file="${TEST_ROOT}/audit.csv"
  run "${TEST_REPO}/machete" audit --export "${export_file}"
  assert_failure
  assert_output_contains "MISSING FILES"
  assert_output_contains "${HOME}/.local/state/app.log"
  [[ -f "${export_file}" ]]
  grep -Fq "path,status,size,last_hashed" "${export_file}"
  grep -Fq "${HOME}/.local/state/app.log,MISSING" "${export_file}"
}
