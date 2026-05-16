# Bootstrap Onboarding

This document is for maintainers and operators of `OMT-Global/machete`. Public users do not need these steps to install or run `machete`; start with the README instead.

## Repo Governance

- Confirm the repository exists at `OMT-Global/machete`.
- Confirm branch protection or rulesets on `main` require one approval and code owner review.
- Confirm branch protection points at the `CI Gate` status.
- Confirm `delete branch on merge` and `allow auto-merge` are enabled.

## Environments

- `dev`: open by default for rapid iteration.
- `stage`: one reviewer required and self-review blocked.
- `prod`: one reviewer required, self-review blocked, deployments limited to `main`.

## Runner Policy

- Required PR checks run on the public-eligible shell-only self-hosted runner lane so `CI Gate` remains available after public visibility is enabled. Keep the exact labels aligned with `.github/workflows/pr-fast-ci.yml` and `tests/public-readiness.sh`.
- Trusted extended validation may use `[self-hosted, synology, shell-only, private]` for shell-safe maintainer jobs.
- Docker, service-container, browser, and `container:` workloads stay on GitHub-hosted runners.
- Keep PR checks cheap. Add heavy validation to `scripts/ci/run-extended-validation.sh` instead of the PR lane.

## Home Profiles

- Run `project-bootstrap plan --manifest ./project.bootstrap.yaml` before applying home profile changes.
- Run `project-bootstrap apply home --manifest ./project.bootstrap.yaml` only after reviewing the bundled profile content.
- The bootstrap manages portable Codex and Claude assets only. Auth, sessions, caches, and machine-local state stay unmanaged.

## Claude Setup

- First-party Claude web sessions should use `bash scripts/claude-cloud/setup.sh` in `claude.ai/code`.
- Interactive Claude work is prepared through `.devcontainer/devcontainer.json`.
- GitHub-hosted Claude automation lives in `.github/workflows/claude.yml` and is intentionally separate from the required PR checks.
- Finish GitHub-side auth by running `/install-github-app` in Claude Code or adding `ANTHROPIC_API_KEY` as a repo secret.
