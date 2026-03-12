# Standalone: Add reviewer specialist subagents

**Jira:** MSSCI-16335
**Points:** 3
**Priority:** P2
**Workflow:** standalone
**Status:** done
**Repos:** pennyfarthing
**Branch:** feat/MSSCI-16335-reviewer-specialist-subagents
**PR:** 1324
**Started:** 2026-03-10
**Completed:** 2026-03-10

---

## Description

Add 6 specialized reviewer subagents inspired by open-source parallel review toolkits
(pr-review-toolkit from FasterThanLight, Hamy's 9-agent setup). Each runs as Haiku
background subagent during review, outputs structured JSON findings. Reviewer agent
wired to spawn all 8 subagents (including existing preflight + edge-hunter) in parallel.

Motivated by BMAD comparison (epic 142) heatmap showing BMAD's mechanical review
catching findings PF's attitude-driven reviewer missed (I5, I6, I3).

## Files Changed

| File | Change |
|------|--------|
| `pennyfarthing-dist/agents/reviewer-silent-failure-hunter.md` | New — swallowed errors, empty catches |
| `pennyfarthing-dist/agents/reviewer-test-analyzer.md` | New — vacuous assertions, missing edge cases |
| `pennyfarthing-dist/agents/reviewer-comment-analyzer.md` | New — stale/misleading comments |
| `pennyfarthing-dist/agents/reviewer-type-design.md` | New — stringly-typed APIs, missing newtypes |
| `pennyfarthing-dist/agents/reviewer-security.md` | New — injection, auth, secrets, info leakage |
| `pennyfarthing-dist/agents/reviewer-simplifier.md` | New — dead code, over-engineering |
| `pennyfarthing-dist/agents/reviewer.md` | Updated — helpers, params, activation, checklist for 8 subagents |
