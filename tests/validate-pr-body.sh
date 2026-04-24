#!/usr/bin/env bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VALIDATOR="${PROJECT_ROOT}/scripts/ci/validate-pr-body.sh"
TEST_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/machete-pr-body.XXXXXX")"
trap '/bin/rm -rf "${TEST_ROOT}"' EXIT

pass_body="${TEST_ROOT}/pass.md"
legacy_body="${TEST_ROOT}/legacy.md"
legacy_missing_summary="${TEST_ROOT}/legacy-missing-summary.md"
partial_template="${TEST_ROOT}/partial-template.md"

cat > "${pass_body}" <<'EOF'
## Governing Issue

Closes #17

## Summary

- Adds track and untrack command support.

## Scope

- CLI behavior

## Verification

- [x] I ran the relevant local checks: `bash scripts/ci/run-fast-checks.sh`
- [x] CI is expected to pass: fast PR checks

## Risk / Rollback

- Low risk; revert the branch commit if needed.

## Secrets / Environment

- [x] No real secrets, runtime auth, sessions, caches, or machine-local env files are included.

## Agent Ownership

- [x] I own fixing this PR until it is merge-ready.
- [x] I did not approve my own PR.
EOF

cat > "${legacy_body}" <<'EOF'
Closes #17

Implements the Daedalus-assigned fix for: feat: extensible dotfile tracking via `machete track` / `machete untrack`
EOF

cat > "${legacy_missing_summary}" <<'EOF'
Closes #17
EOF

cat > "${partial_template}" <<'EOF'
Closes #17

## Summary

- Adds track and untrack command support.
EOF

bash "${VALIDATOR}" "${pass_body}" >/dev/null
bash "${VALIDATOR}" "${legacy_body}" >/dev/null

if bash "${VALIDATOR}" "${legacy_missing_summary}" >/dev/null 2>&1; then
  echo "Expected legacy PR body without summary to fail validation." >&2
  exit 1
fi

if bash "${VALIDATOR}" "${partial_template}" >/dev/null 2>&1; then
  echo "Expected partial structured template to fail validation." >&2
  exit 1
fi

echo "PR body validation tests passed."
