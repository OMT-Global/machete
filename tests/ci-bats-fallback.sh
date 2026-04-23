#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${PROJECT_ROOT}/scripts/ci/lib/bats.sh"

TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/machete-ci-bats.XXXXXX")"
trap '/bin/rm -rf "${TEST_ROOT}"' EXIT

FAKE_BIN="${TEST_ROOT}/bin"
mkdir -p "${FAKE_BIN}"

write_fake_command() {
  local path="$1"
  cat > "${path}" <<'COMMAND'
#!/usr/bin/env bash
exit 0
COMMAND
  chmod +x "${path}"
}

write_fake_command "${FAKE_BIN}/bats"
PATH="${FAKE_BIN}"

if [[ "$(bats_command)" != "bats" ]]; then
  echo "Expected local bats command to be preferred" >&2
  exit 1
fi

/bin/rm -f "${FAKE_BIN}/bats"
PATH="${FAKE_BIN}:/usr/bin:/bin"
write_fake_command "${FAKE_BIN}/npx"
PATH="${FAKE_BIN}"

if [[ "$(bats_command)" != "npx --yes bats@1.13.0" ]]; then
  echo "Expected npx fallback when bats is unavailable" >&2
  exit 1
fi

/bin/rm -f "${FAKE_BIN}/npx"

if bats_command >/dev/null; then
  echo "Expected bats resolution to fail without bats or npx" >&2
  exit 1
fi

echo "Bats resolver tests passed."
