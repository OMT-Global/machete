#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "${REPO_DIR}/scripts/lib/brew-services.sh"

if ! command -v brew >/dev/null 2>&1; then
  echo "Homebrew not found; run ./machete setup first."
  exit 1
fi

echo "==> Restoring Homebrew services"
brew_services_restore "$(brew_services_state_file)"
