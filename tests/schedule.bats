#!/usr/bin/env bats

load helper

setup() {
  setup_test_repo
}

teardown() {
  teardown_test_repo
}

@test "schedule installs and loads a launch agent for the active profile" {
  install_fake_launchctl
  FAKE_LAUNCHCTL_LOG="${TEST_ROOT}/launchctl.log"
  export FAKE_LAUNCHCTL_LOG

  run "${TEST_REPO}/machete" schedule --hour 6 --minute 45

  assert_success
  plist_path="${HOME}/Library/LaunchAgents/dev.omt-global.machete.schedule.default.plist"
  runner_path="${HOME}/.machete/schedule/default/run.sh"

  [[ -f "${plist_path}" ]]
  [[ -x "${runner_path}" ]]
  grep -Fq "<integer>6</integer>" "${plist_path}"
  grep -Fq "<integer>45</integer>" "${plist_path}"
  grep -Fq "${runner_path}" "${plist_path}"
  grep -Fq "\"${TEST_REPO}/machete\" sync --profile \"default\"" "${runner_path}"
  grep -Fq "\"${TEST_REPO}/machete\" update --profile \"default\"" "${runner_path}"
  grep -Fxq "unload ${plist_path}" "${FAKE_LAUNCHCTL_LOG}"
  grep -Fxq "load ${plist_path}" "${FAKE_LAUNCHCTL_LOG}"
  assert_output_contains "Installed and loaded launchd agent: dev.omt-global.machete.schedule.default"
  assert_output_contains "Scheduled daily sync/update at 06:45 for profile default"
}

@test "schedule uses the persisted active profile in label and runner" {
  install_fake_launchctl
  FAKE_LAUNCHCTL_LOG="${TEST_ROOT}/launchctl.log"
  export FAKE_LAUNCHCTL_LOG

  run "${TEST_REPO}/machete" help --profile work
  assert_success

  run "${TEST_REPO}/machete" schedule

  assert_success
  plist_path="${HOME}/Library/LaunchAgents/dev.omt-global.machete.schedule.work.plist"
  runner_path="${HOME}/.machete/schedule/work/run.sh"

  [[ -f "${plist_path}" ]]
  [[ -x "${runner_path}" ]]
  grep -Fq "\"${TEST_REPO}/machete\" sync --profile \"work\"" "${runner_path}"
  grep -Fq "\"${TEST_REPO}/machete\" update --profile \"work\"" "${runner_path}"
  assert_output_contains "Scheduled daily sync/update at 09:00 for profile work"
}

@test "schedule rejects invalid time values" {
  run "${TEST_REPO}/machete" schedule --hour 24

  assert_failure
  assert_output_contains "Invalid hour: 24"
}
