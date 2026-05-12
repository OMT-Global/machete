# Next Steps

Maintainer/operator checklist for repository bootstrap work. Public users can ignore this document.

- Keep `project.bootstrap.yaml` aligned with required checks, managed paths, repo visibility, and reviewer policy.
- Run `project-bootstrap plan --manifest ./project.bootstrap.yaml` before applying GitHub or home profile changes.
- Review CODEOWNERS and environment reviewers before changing branch protection or environments.
- Keep the required PR check named `CI Gate`.
