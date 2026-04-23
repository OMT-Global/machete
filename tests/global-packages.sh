#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${REPO_DIR}/scripts/lib/global-packages.sh"

TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/machete-global-packages-test.XXXXXX")"
trap 'rm -rf "${TMP_DIR}"' EXIT

FAKE_BIN="${TMP_DIR}/bin"
mkdir -p "${FAKE_BIN}"

cat > "${FAKE_BIN}/npm" <<'NPM'
#!/usr/bin/env bash
set -euo pipefail

case "$*" in
  "ls -g --depth=0 --parseable=true")
    printf '%s\n' /prefix/lib/node_modules /prefix/lib/node_modules/npm /prefix/lib/node_modules/eslint /prefix/lib/node_modules/prettier
    ;;
  install\ -g*)
    shift 2
    printf '%s\n' "$@" > "${FAKE_NPM_INSTALLED}"
    ;;
  *)
    echo "unexpected npm command: $*" >&2
    exit 1
    ;;
esac
NPM
chmod +x "${FAKE_BIN}/npm"

cat > "${FAKE_BIN}/pip3" <<'PIP'
#!/usr/bin/env bash
set -euo pipefail

case "$*" in
  "list --user --format=freeze")
    printf '%s\n' black==24.4.2 ruff==0.5.0
    ;;
  install\ --user*)
    shift 2
    printf '%s\n' "$@" > "${FAKE_PIP_INSTALLED}"
    ;;
  *)
    echo "unexpected pip command: $*" >&2
    exit 1
    ;;
esac
PIP
chmod +x "${FAKE_BIN}/pip3"

cat > "${FAKE_BIN}/cargo" <<'CARGO'
#!/usr/bin/env bash
set -euo pipefail

case "${1:-}" in
  install)
    if [[ "${2:-}" == "--list" ]]; then
      printf '%s\n' 'ripgrep v14.1.0:' '  rg' 'fd-find v10.1.0:' '  fd'
    else
      printf '%s@%s\n' "${2:-}" "${4:-}" >> "${FAKE_CARGO_INSTALLED}"
    fi
    ;;
  *)
    echo "unexpected cargo command: $*" >&2
    exit 1
    ;;
esac
CARGO
chmod +x "${FAKE_BIN}/cargo"

export PATH="${FAKE_BIN}:${PATH}"
export FAKE_NPM_INSTALLED="${TMP_DIR}/npm-installed"
export FAKE_PIP_INSTALLED="${TMP_DIR}/pip-installed"
export FAKE_CARGO_INSTALLED="${TMP_DIR}/cargo-installed"

assert_file_equals() {
  local expected_file="$1"
  local actual_file="$2"

  diff -u "${expected_file}" "${actual_file}"
}

snapshot_npm_globals "${TMP_DIR}"
printf '%s\n' eslint prettier > "${TMP_DIR}/expected-npm"
assert_file_equals "${TMP_DIR}/expected-npm" "$(npm_packages_file "${TMP_DIR}")"

snapshot_pip_globals "${TMP_DIR}"
printf '%s\n' black==24.4.2 ruff==0.5.0 > "${TMP_DIR}/expected-pip"
assert_file_equals "${TMP_DIR}/expected-pip" "$(pip_packages_file "${TMP_DIR}")"

snapshot_cargo_globals "${TMP_DIR}"
printf '%s\n' fd-find@10.1.0 ripgrep@14.1.0 > "${TMP_DIR}/expected-cargo"
assert_file_equals "${TMP_DIR}/expected-cargo" "$(cargo_packages_file "${TMP_DIR}")"

restore_npm_globals "${TMP_DIR}" >/dev/null
assert_file_equals "${TMP_DIR}/expected-npm" "${FAKE_NPM_INSTALLED}"

restore_pip_globals "${TMP_DIR}" >/dev/null
assert_file_equals "${TMP_DIR}/expected-pip" "${FAKE_PIP_INSTALLED}"

: > "${FAKE_CARGO_INSTALLED}"
restore_cargo_globals "${TMP_DIR}" >/dev/null
assert_file_equals "${TMP_DIR}/expected-cargo" "${FAKE_CARGO_INSTALLED}"

check_saved_vs_current "$(npm_packages_file "${TMP_DIR}")" bash -lc "printf '%s\n' eslint prettier"

echo "Global package tests passed."
