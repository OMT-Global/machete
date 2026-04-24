#!/usr/bin/env bash
set -euo pipefail

SHELLCHECK_VERSION="${SHELLCHECK_VERSION:-0.11.0}"

shellcheck_command() {
  if command -v shellcheck >/dev/null 2>&1; then
    command -v shellcheck
    return 0
  fi

  local system
  local machine
  system="$(uname -s)"
  machine="$(uname -m)"

  if [[ "${system}" == "Linux" && "${machine}" == "x86_64" ]]; then
    local cache_dir="${RUNNER_TEMP:-${TMPDIR:-/tmp}}/machete-shellcheck-${SHELLCHECK_VERSION}"
    local binary="${cache_dir}/shellcheck-v${SHELLCHECK_VERSION}/shellcheck"

    if [[ ! -x "${binary}" ]]; then
      mkdir -p "${cache_dir}"
      curl -fsSL \
        "https://github.com/koalaman/shellcheck/releases/download/v${SHELLCHECK_VERSION}/shellcheck-v${SHELLCHECK_VERSION}.linux.x86_64.tar.xz" \
        | tar -xJ -C "${cache_dir}"
    fi

    printf '%s\n' "${binary}"
    return 0
  fi

  echo "ShellCheck is required for script linting. Install it with: brew install shellcheck" >&2
  return 127
}

SHELLCHECK_BIN="$(shellcheck_command)"

files=()

add_file() {
  local path="$1"
  [[ -f "${path}" ]] || return 0
  files+=("${path}")
}

add_file "machete"
add_file "defaults/macos-defaults.sh"

if [[ -d "scripts" ]]; then
  while IFS= read -r -d '' script_file; do
    files+=("${script_file}")
  done < <(find scripts -type f -name '*.sh' -print0 | sort -z)
fi

if [[ -d ".githooks" ]]; then
  while IFS= read -r -d '' hook_file; do
    files+=("${hook_file}")
  done < <(find .githooks -type f -print0 | sort -z)
fi

if [[ "${#files[@]}" -eq 0 ]]; then
  echo "No shell scripts found to lint."
  exit 0
fi

echo "Running ShellCheck on ${#files[@]} repo script(s)."
"${SHELLCHECK_BIN}" --severity=warning "${files[@]}"
