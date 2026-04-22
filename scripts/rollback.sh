#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${REPO_DIR}/scripts/lib/snapshot-tags.sh"

requested_tag="${1:-}"

cd "${REPO_DIR}"

if [[ -n "${requested_tag}" ]]; then
  target_tag="${requested_tag}"
  if ! git rev-parse --verify --quiet "refs/tags/${target_tag}" >/dev/null; then
    echo "Snapshot tag not found: ${target_tag}" >&2
    echo "Run './machete history' to list available snapshot tags." >&2
    exit 1
  fi
else
  target_tag="$(latest_snapshot_tag "${REPO_DIR}")"
  if [[ -z "${target_tag}" ]]; then
    echo "No snapshot tags found. Run './machete history' to confirm available rollbacks." >&2
    exit 1
  fi
fi

echo "==> Creating rollback safety snapshot"
safety_tag="$(create_snapshot_tag "${REPO_DIR}" "rollback to ${target_tag}")"
echo "  - ${safety_tag}"

echo "==> Checking out ${target_tag}"
git checkout "${target_tag}"

echo "==> Re-applying setup"
MACHETE_SKIP_SNAPSHOT_TAG=1 "${REPO_DIR}/scripts/setup.sh"

echo ""
echo "==> Rollback complete."
echo "Current repository state is detached at ${target_tag}."
echo "Safety snapshot for the pre-rollback state: ${safety_tag}"
