# Parked branches

Branches that hold finished work not yet merged. Nothing here is lost: each is on `origin`.

## `fix/qa1-land-stack`

- **Tip:** `37c081b` (13 Oct 2026), "Land QA pass 1 stack: #67-#73 (categories, pay cycle, salary, fingerprint login, inbox)". Same tip locally and on `origin`.
- **State:** not merged. When parked it was 10 commits ahead of and 6 behind the working branch, so a merge needs real conflict resolution. It was deliberately left alone in the 2026-10-24 workspace cleanup.
- **Backend counterpart:** `fix/qa1-land-stack` in `piggybank-backend` (tip `72a23b9`).
- **History:** it was checked out as a worktree at `pb-app-land`, now archived under `../_archive/2026-10-24-qa1-land-worktrees/`. The archive held no unique work.

Resume it without disturbing the main checkout:

```bash
git worktree add ../_worktrees/qa1-land fix/qa1-land-stack
```

Put any parallel-branch worktrees in `../_worktrees/`, not in the scratchpad or at the root of a drive.
