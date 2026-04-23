#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${REPO_DIR}/scripts/lib/editor-extensions.sh"

TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/machete-editor-extensions-test.XXXXXX")"
trap 'rm -rf "${TMP_DIR}"' EXIT

FAKE_BIN="${TMP_DIR}/bin"
mkdir -p "${FAKE_BIN}"

cat > "${FAKE_BIN}/code" <<'CODE'
#!/usr/bin/env bash
set -euo pipefail

case "${1:-}" in
  --list-extensions)
    cat "${FAKE_EDITOR_EXTENSIONS}"
    ;;
  --install-extension)
    printf '%s\n' "${2:-}" >> "${FAKE_EDITOR_INSTALLED}"
    ;;
  *)
    echo "unexpected code command: $*" >&2
    exit 1
    ;;
esac
CODE
chmod +x "${FAKE_BIN}/code"

ORIGINAL_PATH="${PATH}"
export PATH="${FAKE_BIN}:${PATH}"
export FAKE_EDITOR_EXTENSIONS="${TMP_DIR}/extensions-live"
export FAKE_EDITOR_INSTALLED="${TMP_DIR}/extensions-installed"

printf '%s\n' b.publisher a.publisher > "${FAKE_EDITOR_EXTENSIONS}"

EXTENSIONS_FILE="${TMP_DIR}/vscode-extensions.txt"
editor_extensions_snapshot "${EXTENSIONS_FILE}" >/dev/null
printf '%s\n' a.publisher b.publisher > "${TMP_DIR}/expected-snapshot"
diff -u "${TMP_DIR}/expected-snapshot" "${EXTENSIONS_FILE}"

cat > "${EXTENSIONS_FILE}" <<'EXTENSIONS'
a.publisher

# comments and blank lines are ignored
c.publisher
EXTENSIONS

: > "${FAKE_EDITOR_INSTALLED}"
editor_extensions_restore "${EXTENSIONS_FILE}" >/dev/null
printf '%s\n' a.publisher c.publisher > "${TMP_DIR}/expected-installed"
diff -u "${TMP_DIR}/expected-installed" "${FAKE_EDITOR_INSTALLED}"

DRIFT_OUTPUT="$(editor_extensions_diff "${EXTENSIONS_FILE}")"
grep -Fq $'missing\tc.publisher' <<<"${DRIFT_OUTPUT}"
grep -Fq $'extra\tb.publisher' <<<"${DRIFT_OUTPUT}"

printf '%s\n' a.publisher c.publisher > "${FAKE_EDITOR_EXTENSIONS}"
DRIFT_OUTPUT="$(editor_extensions_diff "${EXTENSIONS_FILE}")"
[[ "${DRIFT_OUTPUT}" == "clean" ]]

EMPTY_BIN="${TMP_DIR}/empty-bin"
mkdir -p "${EMPTY_BIN}"
PATH="${EMPTY_BIN}"
DRIFT_OUTPUT="$(editor_extensions_diff "${EXTENSIONS_FILE}")"
[[ "${DRIFT_OUTPUT}" == "missing-editor" ]]
RESTORE_OUTPUT="$(editor_extensions_restore "${EXTENSIONS_FILE}")"
[[ "${RESTORE_OUTPUT}" == *"No VS Code-compatible editor CLI found; skipping extension install."* ]]
PATH="${ORIGINAL_PATH}"

echo "Editor extensions tests passed."
