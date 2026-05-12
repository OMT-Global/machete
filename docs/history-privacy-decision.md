# Git History Privacy Decision

Decision: keep git history as-is and publish with `.mailmap` normalization.

The current history scan found no committed token or private-key patterns. Author metadata includes personal email addresses and placeholder identities from early bootstrap work. Those identities are not secrets, and rewriting history now would invalidate existing merge and audit references for a low-sensitivity metadata concern.

The repository keeps a `.mailmap` file so public history display and future scans normalize known placeholder or personal identities to durable project identities.

## Verification Commands

Run these before flipping visibility:

```bash
git log --all --format='%an <%ae>' | sort -u
git log --all --use-mailmap --format='%aN <%aE>' | sort -u
bash scripts/check-detect-secrets.sh --all-files
```

Expected result:

- Raw author metadata may include historic personal or placeholder identities.
- Mailmapped author metadata resolves to project-safe identities.
- The secret-pattern scan exits successfully with no findings.
