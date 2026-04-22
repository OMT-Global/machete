#!/usr/bin/env bash

bats_command() {
  if command -v bats >/dev/null 2>&1; then
    printf 'bats\n'
    return 0
  fi

  if command -v npx >/dev/null 2>&1; then
    printf 'npx --yes bats@1.13.0\n'
    return 0
  fi

  return 1
}

run_bats_suite() {
  local suite_path="$1"
  local command_line

  if ! command_line="$(bats_command)"; then
    echo "Bats is required for shell tests. Install bats-core or provide npx." >&2
    return 127
  fi

  read -r -a bats_argv <<< "${command_line}"
  "${bats_argv[@]}" "${suite_path}"
}
