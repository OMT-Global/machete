## Governing Issue

Closes #56

## Summary

Phase 1 of 14: scaffold Go project structure for machete migration from bash to static Go binary.

- go.mod updated to `github.com/OMT-Global/machete/v2` with cobra dependency
- cmd/machete/main.go: Cobra CLI root with all 17 subcommand stubs
- Makefile: build/install/test/clean targets
- pkg/<x>/doc.go: Documentation packages for all 9 library directories
- .gitignore: build artifact ignores
- All commands are stub implementations delegating to the shell backend

## Scope

- No shell logic changed
- No shell scripts modified
- Pure new scaffolding only

## Verification

- [x] I ran the relevant local checks: `go build ./...` compiles cleanly
- [ ] CI is expected to pass once PR template sections are correct

## Risk / Rollback

Low risk. Pure scaffold with no shell logic changed. Delete branch to rollback.

## Secrets / Environment

- [ ] No real secrets, runtime auth, sessions, caches, or machine-local env files are included.

## Agent Ownership

- [x] I own fixing this PR until it is merge-ready.
- [x] I did not approve my own PR — awaiting review from @jmcte.
