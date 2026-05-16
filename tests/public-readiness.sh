#!/usr/bin/env bash
set -euo pipefail

workflow=".github/workflows/pr-fast-ci.yml"

if grep -n "shell-only', 'private\\|ubuntu-latest" "$workflow" >/dev/null; then
  echo "PR Fast CI must use the public shell-only runner group, not private labels or billing-gated GitHub-hosted runners." >&2
  exit 1
fi

grep -q "runs-on: \\['self-hosted', 'synology', 'shell-only', 'public'\\]" "$workflow"
grep -q "The bootstrap docs under \`docs/bootstrap/\` are maintainer/operator notes" README.md
grep -q "Use this checklist after the first bootstrap render" docs/bootstrap/onboarding.md
grep -q "Decision: keep git history as-is and publish with \`.mailmap\` normalization." docs/history-privacy-decision.md

git log --all --use-mailmap --format='%aN <%aE>' | sort -u >"${TMPDIR:-/tmp}/machete-mailmap-authors.$$"
trap 'rm -f "${TMPDIR:-/tmp}/machete-mailmap-authors.$$"' EXIT

if grep -E "you@example\\.com|john\\.m\\.teneyck@gmail\\.com" "${TMPDIR:-/tmp}/machete-mailmap-authors.$$" >/dev/null; then
  echo ".mailmap did not normalize known placeholder or personal author metadata." >&2
  cat "${TMPDIR:-/tmp}/machete-mailmap-authors.$$" >&2
  exit 1
fi
