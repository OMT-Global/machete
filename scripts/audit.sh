#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${REPO_DIR}/scripts/lib/profiles.sh"

MACHETE_PROFILE="${MACHETE_PROFILE:-$(resolve_profile "${REPO_DIR}")}"
DB_PATH="${MACHETE_CHECKSUM_DB:-${HOME}/.machete/checksums.sqlite}"
SCOPE="home:${HOME}"
AUDIT_DIR="${HOME}"
SINCE=""
EXPORT_PATH=""

usage() {
  cat <<'EOF'
Scan home-directory files and report drift since the last full-home baseline.

Usage:
  ./machete audit
  ./machete audit --since 2024-01-01
  ./machete audit --dir ~/Library
  ./machete audit --export report.csv

Options:
  --since DATE   Only include current-file changes with mtime on or after DATE.
  --dir PATH     Limit the scan to PATH. Defaults to $HOME.
  --export PATH  Write CSV output with path,status,size,last_hashed.
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --since)
      if [[ $# -lt 2 ]]; then
        echo "Missing value for --since" >&2
        exit 1
      fi
      SINCE="$2"
      shift 2
      ;;
    --since=*)
      SINCE="${1#--since=}"
      shift
      ;;
    --dir)
      if [[ $# -lt 2 ]]; then
        echo "Missing value for --dir" >&2
        exit 1
      fi
      AUDIT_DIR="$2"
      shift 2
      ;;
    --dir=*)
      AUDIT_DIR="${1#--dir=}"
      shift
      ;;
    --export)
      if [[ $# -lt 2 ]]; then
        echo "Missing value for --export" >&2
        exit 1
      fi
      EXPORT_PATH="$2"
      shift 2
      ;;
    --export=*)
      EXPORT_PATH="${1#--export=}"
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown audit option: $1" >&2
      echo "" >&2
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
  echo "Python 3 is required for machete audit." >&2
  exit 127
fi

if [[ "${AUDIT_DIR}" == ~* ]]; then
  AUDIT_DIR="${HOME}${AUDIT_DIR#"~"}"
fi

if [[ ! -d "${AUDIT_DIR}" ]]; then
  echo "Audit directory does not exist: ${AUDIT_DIR}" >&2
  exit 1
fi

python_args=(
  "${REPO_DIR}/scripts/cksum.py"
  --db "${DB_PATH}"
  --scope "${SCOPE}"
  --mode audit
  --home "${HOME}"
  --dir "${AUDIT_DIR}"
)

if [[ -n "${SINCE}" ]]; then
  python_args+=(--since "${SINCE}")
fi

if [[ -n "${EXPORT_PATH}" ]]; then
  python_args+=(--export "${EXPORT_PATH}")
fi

exec "${python_bin}" "${python_args[@]}"
