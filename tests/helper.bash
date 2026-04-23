#!/usr/bin/env bash

PROJECT_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"

setup_test_repo() {
  TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/machete-bats.XXXXXX")"
  TEST_REPO="${TEST_ROOT}/repo"
  TEST_HOME="${TEST_ROOT}/home"
  FAKE_BIN="${TEST_ROOT}/bin"

  mkdir -p "${TEST_REPO}" "${TEST_HOME}" "${FAKE_BIN}"
  cp "${PROJECT_ROOT}/machete" "${TEST_REPO}/"
  cp -R "${PROJECT_ROOT}/scripts" "${TEST_REPO}/scripts"
  [[ ! -f "${PROJECT_ROOT}/Brewfile" ]] || cp "${PROJECT_ROOT}/Brewfile" "${TEST_REPO}/Brewfile"
  [[ ! -d "${PROJECT_ROOT}/defaults" ]] || cp -R "${PROJECT_ROOT}/defaults" "${TEST_REPO}/defaults"
  mkdir -p "${TEST_REPO}/dotfiles"

  git -C "${TEST_REPO}" init --quiet
  git -C "${TEST_REPO}" config user.email "machete-tests@example.invalid"
  git -C "${TEST_REPO}" config user.name "machete tests"
  git -C "${TEST_REPO}" add .
  git -C "${TEST_REPO}" commit --quiet -m "initial fixture"

  export HOME="${TEST_HOME}"
  export PATH="${FAKE_BIN}:${PATH}"
}

teardown_test_repo() {
  [[ -z "${TEST_ROOT:-}" ]] || rm -rf "${TEST_ROOT}"
}

install_fake_brew() {
  cat > "${FAKE_BIN}/brew" <<'BREW'
#!/usr/bin/env bash
set -euo pipefail

find_file_arg() {
  local arg
  while [[ $# -gt 0 ]]; do
    arg="$1"
    case "${arg}" in
      --file=*)
        printf '%s\n' "${arg#--file=}"
        return 0
        ;;
      --file)
        printf '%s\n' "${2:-}"
        return 0
        ;;
    esac
    shift
  done
  return 1
}

case "${1:-}" in
  bundle)
    case "${2:-}" in
      check)
        exit "${FAKE_BREW_BUNDLE_CHECK_EXIT:-0}"
        ;;
      dump)
        destination="$(find_file_arg "$@")"
        if [[ -n "${FAKE_BREW_DUMP_FILE:-}" ]]; then
          cp "${FAKE_BREW_DUMP_FILE}" "${destination}"
        else
          : > "${destination}"
        fi
        ;;
      install)
        printf '%s\n' "$*" >> "${FAKE_BREW_LOG:-/dev/null}"
        ;;
      *)
        echo "unexpected brew bundle command: $*" >&2
        exit 1
        ;;
    esac
    ;;
  outdated)
    [[ ! -f "${FAKE_BREW_OUTDATED_FILE:-}" ]] || cat "${FAKE_BREW_OUTDATED_FILE}"
    ;;
  services)
    case "${2:-}" in
      list)
        [[ ! -f "${FAKE_BREW_SERVICES_LIST:-}" ]] || cat "${FAKE_BREW_SERVICES_LIST}"
        ;;
      start)
        printf '%s\n' "${3:-}" >> "${FAKE_BREW_STARTED:-/dev/null}"
        ;;
      *)
        echo "unexpected brew services command: $*" >&2
        exit 1
        ;;
    esac
    ;;
  list)
    case "${2:-}" in
      --formula|--cask)
        [[ -f "${FAKE_BREW_INSTALLED:-}" ]] && grep -Fxq "${3:-}" "${FAKE_BREW_INSTALLED}"
        ;;
      *)
        echo "unexpected brew list command: $*" >&2
        exit 1
        ;;
    esac
    ;;
  *)
    echo "unexpected brew command: $*" >&2
    exit 1
    ;;
esac
BREW
  chmod +x "${FAKE_BIN}/brew"
}

install_fake_git() {
  cat > "${FAKE_BIN}/git" <<'GIT'
#!/usr/bin/env bash
set -euo pipefail

case "${1:-}" in
  remote)
    [[ "${2:-}" == "get-url" && "${3:-}" == "origin" ]] || exit 1
    [[ "${FAKE_GIT_NO_REMOTE:-0}" == "1" ]] && exit 1
    echo "git@example.invalid:owner/repo.git"
    ;;
  fetch)
    exit 0
    ;;
  branch)
    [[ "${2:-}" == "--show-current" ]] || exit 1
    echo "${FAKE_GIT_BRANCH:-main}"
    ;;
  rev-parse)
    [[ "${2:-}" == "--verify" && "${3:-}" == "--quiet" ]] || exit 1
    exit "${FAKE_GIT_TRACKING_EXIT:-0}"
    ;;
  status)
    [[ "${2:-}" == "--porcelain" ]] || exit 1
    [[ ! -f "${FAKE_GIT_STATUS_FILE:-}" ]] || cat "${FAKE_GIT_STATUS_FILE}"
    ;;
  rev-list)
    [[ "${2:-}" == "--count" ]] || exit 1
    case "${3:-}" in
      HEAD..*) echo "${FAKE_GIT_BEHIND:-0}" ;;
      *..HEAD) echo "${FAKE_GIT_AHEAD:-0}" ;;
      *) echo 0 ;;
    esac
    ;;
  *)
    echo "unexpected git command: $*" >&2
    exit 1
    ;;
esac
GIT
  chmod +x "${FAKE_BIN}/git"
}

write_fake_brew_dump() {
  FAKE_BREW_DUMP_FILE="${TEST_ROOT}/brew-dump"
  export FAKE_BREW_DUMP_FILE
  cat > "${FAKE_BREW_DUMP_FILE}"
}

write_fake_services_list() {
  FAKE_BREW_SERVICES_LIST="${TEST_ROOT}/brew-services-list"
  export FAKE_BREW_SERVICES_LIST
  cat > "${FAKE_BREW_SERVICES_LIST}"
}

assert_success() {
  if [[ "${status}" -ne 0 ]]; then
    printf '%s\n' "${output}"
    return 1
  fi
}

assert_failure() {
  if [[ "${status}" -eq 0 ]]; then
    printf '%s\n' "${output}"
    return 1
  fi
}

assert_output_contains() {
  local expected="$1"

  if [[ "${output}" != *"${expected}"* ]]; then
    printf 'Expected output to contain: %s\n\n%s\n' "${expected}" "${output}"
    return 1
  fi
}
