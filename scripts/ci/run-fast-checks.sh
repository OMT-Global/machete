#!/usr/bin/env bash
set -euo pipefail
echo "Generic archetype selected."
bats tests
bash tests/homebrew-services.sh
