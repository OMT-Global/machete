#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${REPO_DIR}/scripts/lib/profiles.sh"

MACHETE_PROFILE="${MACHETE_PROFILE:-$(resolve_profile "${REPO_DIR}")}"
DOTFILES_DIR="$(profile_dotfiles_dir "${REPO_DIR}" "${MACHETE_PROFILE}")"
BREWFILE_PATH="$(profile_brewfile_path "${REPO_DIR}" "${MACHETE_PROFILE}")"
DB_PATH="${MACHETE_CHECKSUM_DB:-${HOME}/.machete/checksums.sqlite}"

canonical_path() {
  local path="$1"
  local dir
  local base

  dir="$(dirname "${path}")"
  base="$(basename "${path}")"

  if [[ -d "${dir}" ]]; then
    (cd "${dir}" && printf '%s/%s\n' "$(pwd -P)" "${base}")
  else
    printf '%s\n' "${path}"
  fi
}

usage() {
  cat <<'EOF'
Verify tracked files against a SHA256 checksum baseline.

Usage:
  ./machete verify
  ./machete verify --init
  ./machete verify --full
  ./machete verify --full --init

Options:
  --init   Record or refresh the checksum baseline.
  --full   Scan all regular files under $HOME instead of tracked machete files.
EOF
}

MODE="verify"
FULL=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --init)
      MODE="init"
      shift
      ;;
    --full)
      FULL=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown verify option: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

python_bin=""
if command -v python3 >/dev/null 2>&1; then
  python_bin="$(command -v python3)"
elif command -v python >/dev/null 2>&1; then
  python_bin="$(command -v python)"
else
  echo "Python 3 is required for machete verify." >&2
  exit 127
fi

scope="profile:${MACHETE_PROFILE}:tracked"

if [[ "${FULL}" -eq 1 ]]; then
  scope="home:${HOME}"
  exec "${python_bin}" "${REPO_DIR}/scripts/cksum.py" \
    --db "${DB_PATH}" \
    --scope "${scope}" \
    --mode "${MODE}" \
    --home "${HOME}"
fi

paths_file="$(mktemp "${TMPDIR:-/tmp}/machete-verify-paths.XXXXXX")"
trap 'rm -f "${paths_file}"' EXIT

if [[ -f "${BREWFILE_PATH}" ]]; then
  printf '%s\0' "$(canonical_path "${BREWFILE_PATH}")" >> "${paths_file}"
fi

if [[ -d "${DOTFILES_DIR}" ]]; then
  while IFS= read -r -d '' src; do
    rel="${src#${DOTFILES_DIR}/}"
    printf '%s\0' "$(canonical_path "${HOME}/${rel}")" >> "${paths_file}"
  done < <(find "${DOTFILES_DIR}" -type f ! -name '.gitkeep' -print0 | sort -z)
fi

"${python_bin}" "${REPO_DIR}/scripts/cksum.py" \
  --db "${DB_PATH}" \
  --scope "${scope}" \
  --mode "${MODE}" \
  --paths-file "${paths_file}"
