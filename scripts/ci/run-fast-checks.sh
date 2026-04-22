#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/bats.sh"

echo "Generic archetype selected."
bash tests/ci-bats-fallback.sh
run_bats_suite tests
bash tests/homebrew-services.sh
bash tests/global-packages.sh
bash tests/editor-extensions.sh
bash tests/snapshot-tags.sh
