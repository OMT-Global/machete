#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${REPO_DIR}/scripts/lib/snapshot-tags.sh"

echo "==> Creating rollback snapshot"
SNAPSHOT_TAG="$(create_snapshot_tag "${REPO_DIR}" "sync")"
echo "  - ${SNAPSHOT_TAG}"

echo "==> Pulling latest from remote"
cd "${REPO_DIR}"

if ! git remote get-url origin >/dev/null 2>&1; then
  echo "No remote configured; nothing to pull."
  exit 0
fi

if [[ -n "$(git status --porcelain 2>/dev/null)" ]]; then
  echo ""
  echo "Warning: you have uncommitted local changes."
  echo "Stashing them before pull, then restoring."
  git stash push -m "machete sync auto-stash $(date +%Y-%m-%d-%H%M%S)"
  STASHED=1
else
  STASHED=0
fi

git pull --ff-only

if [[ "${STASHED}" -eq 1 ]]; then
  echo "==> Restoring stashed changes"
  git stash pop
fi

echo "==> Re-applying setup"
MACHETE_SKIP_SNAPSHOT_TAG=1 "${REPO_DIR}/scripts/setup.sh"
