---
name: Fix the system not the symptom (repos.yaml + context)
description: Two open issues — repos.yaml not consulted for git ops, context detection needs model-aware max_tokens
type: project
---

**repos.yaml underuse:** Agents have repos.yaml loaded in prime context but don't consult it before git operations. The fix isn't "remember to check repos.yaml" — it's making the tooling enforce it. Candidates: a `pf git diff` wrapper that reads repos.yaml, or a pre-commit hook that validates PR base branches match repos.yaml.

**Why:** SOUL.md principle #1: "Fix the system, not the symptom." A memory note telling agents to check repos.yaml is instructional, not automatic. Agents under context pressure will skip it. The fix should be in the pipeline.

**How to apply:** Next session should evaluate whether `pf git` commands (status, diff, branches) should auto-resolve base branches from repos.yaml, so agents never need to think about it. Also: context_window.py needs model detection from transcript JSONL to set max_tokens dynamically instead of hardcoding 1M.
