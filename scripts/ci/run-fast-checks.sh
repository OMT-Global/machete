#!/usr/bin/env bash
set -euo pipefail

echo "Running machete Go-era fast checks."
if [[ "${MACHETE_SKIP_SHELLCHECK:-0}" != "1" ]]; then
  bash scripts/ci/run-shellcheck.sh
fi

echo "Checking Go module metadata."
go mod verify

echo "Running Go vet."
go vet ./...

echo "Running Go tests."
go test -v -race -count=1 ./...

echo "Building machete binary."
mkdir -p dist
go build -o dist/machete ./cmd/machete
