# Public Readiness Notes

This repository is intended to be public once the GitHub visibility switch is complete.

## Maintainer Bootstrap Scope

`project.bootstrap.yaml`, `AGENTS.md`, `CLAUDE.md`, `.github/`, and `docs/bootstrap/` describe repository governance and maintainer workflows. Public users do not need to run bootstrap provisioning before using `machete`.

Maintainers should run `project-bootstrap plan --manifest ./project.bootstrap.yaml` before applying repository policy or home profile changes. Review the plan for managed paths, required checks, runner labels, and home profile outputs before running any `apply` command.

## User Safety Scope

Public users should treat `machete setup`, `sync`, `snapshot`, `track`, `untrack`, `defaults`, `schedule`, `rollback`, `services`, and `update` as mutating commands. The README lists which parts of `$HOME`, Homebrew, launchd, and macOS defaults each command may change.

Read-only inspection starts with:

```bash
./machete doctor
./machete diff
./machete verify
./machete audit
```

## CI And Runner Decision

Required PR validation runs on the `synology-public` self-hosted runner group with labels `[self-hosted, synology, shell-only, public]` so `CI Gate` remains available after the repository becomes public. The runner group allows public repositories and includes `OMT-Global/machete`.

The required PR lane stays shell-only and does not use Docker, service containers, browser infrastructure, or workflow `container:` blocks. Keep higher-risk work in trusted extended validation, nightly work, or manual maintainer workflows.
