#!/usr/bin/env bats

PROJECT_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"

@test "validate-pr-body accepts the structured template" {
  run bash "${PROJECT_ROOT}/scripts/ci/validate-pr-body.sh" - <<'EOF'
## Governing Issue

Closes #24

## Summary

Adds profile-aware machine config handling.

## Scope

- scripts/profile.sh

## Verification

- [x] bash scripts/ci/run-fast-checks.sh

## Risk / Rollback

- Low risk; revert this PR.

## Secrets / Environment

- [x] No real secrets, runtime auth, sessions, caches, or machine-local env files are included.

## Agent Ownership

- [x] I own fixing this PR until it is merge-ready.
- [x] I did not approve my own PR.
EOF

  [ "$status" -eq 0 ]
}

@test "validate-pr-body accepts a concise legacy body with issue link and summary" {
  run bash "${PROJECT_ROOT}/scripts/ci/validate-pr-body.sh" - <<'EOF'
Closes #24

Implements the Daedalus-assigned fix for profile-aware machine configs.
EOF

  [ "$status" -eq 0 ]
}

@test "validate-pr-body rejects a concise body without a meaningful summary" {
  run bash "${PROJECT_ROOT}/scripts/ci/validate-pr-body.sh" - <<'EOF'
Closes #24
EOF

  [ "$status" -eq 1 ]
  [[ "$output" == *"Legacy PR body must include"* ]]
}

@test "validate-pr-body still rejects incomplete structured templates" {
  run bash "${PROJECT_ROOT}/scripts/ci/validate-pr-body.sh" - <<'EOF'
## Governing Issue

Closes #24

## Summary

Adds profile-aware machine config handling.
EOF

  [ "$status" -eq 1 ]
  [[ "$output" == *"Missing required section: ## Scope"* ]]
}
