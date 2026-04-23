#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${REPO_DIR}/scripts/lib/snapshot-tags.sh"

echo "==> Snapshot history"
history="$(list_snapshot_tags "${REPO_DIR}")"

if [[ -z "${history}" ]]; then
  echo "No snapshot tags found."
  exit 0
fi

printf "TAG\tCREATED\tMESSAGE\n"
printf "%s\n" "${history}"
