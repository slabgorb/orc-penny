# Standalone: Add spec deviation tracking to agent session output

**Jira:** MSSCI-16346
**Points:** 3
**Priority:** P2
**Workflow:** standalone
**Status:** done
**Repos:** pennyfarthing
**Branch:** feat/MSSCI-16346-spec-deviation-tracking
**PR:** 1331
**Started:** 2026-03-11
**Completed:** 2026-03-11

---

## Description

Agents (TEA, Dev) log design deviations in real-time during session work. Reviewer audits all deviations before approval. Session template includes Design Deviations section. PR body includes deviations summary. Two new gates enforce logging and auditing.

## Files Changed

| File | Change |
|------|--------|
| pennyfarthing-dist/agents/dev.md | Added deviation-tracking section and exit gate |
| pennyfarthing-dist/agents/reviewer.md | Added deviation-review audit workflow |
| pennyfarthing-dist/agents/sm-finish.md | Include deviations in PR body |
| pennyfarthing-dist/agents/sm-setup.md | Added Design Deviations section to session template |
| pennyfarthing-dist/agents/tea.md | Added deviation-tracking section and exit gate |
| pennyfarthing-dist/gates/deviations-audited.md | New gate: reviewer audited all deviations |
| pennyfarthing-dist/gates/deviations-logged.md | New gate: TEA/Dev logged deviations before handoff |
