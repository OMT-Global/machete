#!/usr/bin/env bash
set -euo pipefail
echo "Generic archetype selected."
bash tests/homebrew-services.sh
bash tests/global-packages.sh
