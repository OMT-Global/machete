#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${REPO_DIR}/scripts/lib/brew-services.sh"

TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/machete-homebrew-services-test.XXXXXX")"
trap 'rm -rf "${TMP_DIR}"' EXIT

FAKE_BIN="${TMP_DIR}/bin"
mkdir -p "${FAKE_BIN}"

cat > "${FAKE_BIN}/brew" <<'BREW'
#!/usr/bin/env bash
set -euo pipefail

case "${1:-}" in
  services)
    case "${2:-}" in
      list)
        cat "${FAKE_BREW_SERVICES_LIST}"
        ;;
      start)
        printf '%s\n' "${3:-}" >> "${FAKE_BREW_STARTED}"
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
        grep -Fxq "${3:-}" "${FAKE_BREW_INSTALLED}"
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

export PATH="${FAKE_BIN}:${PATH}"
export FAKE_BREW_SERVICES_LIST="${TMP_DIR}/services-list"
export FAKE_BREW_INSTALLED="${TMP_DIR}/installed"
export FAKE_BREW_STARTED="${TMP_DIR}/started"

assert_file_equals() {
  local expected_file="$1"
  local actual_file="$2"

  diff -u "${expected_file}" "${actual_file}"
}

printf '%s\n' \
  'Name Status User File' \
  'redis started pheidon ~/Library/LaunchAgents/homebrew.mxcl.redis.plist' \
  'postgresql@16 none' \
  'nginx started pheidon ~/Library/LaunchAgents/homebrew.mxcl.nginx.plist' \
  > "${FAKE_BREW_SERVICES_LIST}"

SERVICES_FILE="${TMP_DIR}/brew-services.txt"
brew_services_snapshot "${SERVICES_FILE}"
printf '%s\n' nginx redis > "${TMP_DIR}/expected-snapshot"
assert_file_equals "${TMP_DIR}/expected-snapshot" "${SERVICES_FILE}"

printf '%s\n' redis nginx > "${FAKE_BREW_INSTALLED}"
: > "${FAKE_BREW_STARTED}"
cat > "${SERVICES_FILE}" <<'SERVICES'
redis
missing-service

# comments and blank lines are ignored
nginx
SERVICES

RESTORE_OUTPUT="$(brew_services_restore "${SERVICES_FILE}")"
printf '%s\n' redis nginx > "${TMP_DIR}/expected-started"
assert_file_equals "${TMP_DIR}/expected-started" "${FAKE_BREW_STARTED}"
grep -Fq 'missing-service: not installed; skipping.' <<<"${RESTORE_OUTPUT}"

printf '%s\n' \
  'Name Status User File' \
  'redis started pheidon ~/Library/LaunchAgents/homebrew.mxcl.redis.plist' \
  'nginx none' \
  > "${FAKE_BREW_SERVICES_LIST}"

brew_services_saved_service_states "${SERVICES_FILE}" > "${TMP_DIR}/states"
grep -Fq $'running\tredis' "${TMP_DIR}/states"
grep -Fq $'missing\tmissing-service' "${TMP_DIR}/states"
grep -Fq $'stopped\tnginx' "${TMP_DIR}/states"

echo "Homebrew services tests passed."
