---
name: Use repos.yaml for all git operations
description: Agents must read repos.yaml before any git diff/branch/PR operation — it defines branch strategy per repo
type: feedback
---

Always read `.pennyfarthing/repos.yaml` before running git commands across repos. It defines the base branch per repo (orchestrator → `main`, pennyfarthing → `develop`).

**Why:** Dev agent ran `git diff main` inside the pennyfarthing repo (which uses gitflow/develop), saw 276+ commits of divergence, and panicked about a "massive diff." The data was in repos.yaml the whole time — the agent just didn't consult it before running git operations.

**How to apply:** Before any `git diff`, `git log`, `gh pr create`, or branch operation:
1. Read repos.yaml to get the repo's `base_branch`
2. Use that branch for comparisons, not a hardcoded `main`
3. When creating PRs, set `--base` to the repo's base branch from repos.yaml
