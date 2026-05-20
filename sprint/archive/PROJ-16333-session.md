# Standalone: Add reviewer edge case hunter subagent

**Jira:** PROJ-16333
**Points:** 2
**Priority:** P2
**Workflow:** standalone
**Status:** done
**Repos:** pennyfarthing
**Branch:** feat/reviewer-edge-hunter
**PR:** 1323
**Started:** 2026-03-10
**Completed:** 2026-03-10

---

## Description

Add a method-driven edge case hunter subagent to the reviewer agent, inspired by BMAD 6.0.4. Separates mechanical path enumeration (Haiku) from attitude-driven adversarial judgment (Opus). Runs in background alongside reviewer-preflight, outputs structured 4-field JSON.

## Files Changed

| File | Change |
|------|--------|
| `pennyfarthing-dist/agents/reviewer-edge-hunter.md` | New tactical subagent for exhaustive path enumeration |
| `pennyfarthing-dist/agents/reviewer.md` | Wired edge hunter into helpers, params, activation, checklist |
