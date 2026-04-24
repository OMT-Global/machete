#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/bats.sh"

echo "Generic archetype selected."
if [[ "${MACHETE_SKIP_SHELLCHECK:-0}" != "1" ]]; then
  bash scripts/ci/run-shellcheck.sh
fi
bash tests/ci-bats-fallback.sh
bash tests/validate-pr-body.sh
run_bats_suite tests
bash tests/homebrew-services.sh
bash tests/global-packages.sh
bash tests/editor-extensions.sh
bash tests/snapshot-tags.sh
bash tests/macos-defaults.sh
