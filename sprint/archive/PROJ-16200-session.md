# Standalone: Model story statuses on Jira lifecycle — add in_review support

**Jira:** PROJ-16200
**Points:** 5
**Priority:** P2
**Workflow:** standalone
**Status:** done
**Repos:** pennyfarthing
**Branch:** feat/PROJ-16200-add-in-review-status
**PR:** 1281
**Started:** 2026-03-05
**Completed:** 2026-03-05

---

## Description

Add consistent in_review status handling across Python sprint modules, TypeScript types, workflow gates, and merge-ready gate. Stories now transition to in_review at review phase entry and respect pr_merge mode (human mode leaves stories in in_review until manual merge).

## Files Changed

| File | Change |
|------|--------|
| pennyfarthing-dist/src/pf/sprint/work.py | Block in-review stories from being picked up |
| pennyfarthing-dist/src/pf/sprint/cli.py | Add in_review to sprint data metrics |
| pennyfarthing-dist/src/pf/sprint/status.py | Track and display in_review_points |
| pennyfarthing-dist/src/pf/sprint/story_finish.py | Conditional done transition based on pr_merge mode |
| pennyfarthing-dist/src/pf/handoff/complete_phase.py | Auto-transition to in_review at review phase entry |
| packages/core/src/server/sprint-data.ts | Add in_review to TS types, mapping, interfaces |
| packages/core/src/public/hooks/useSprint.ts | Add in_review to status union |
| packages/cyclist/src/sprint-data.ts | Mirror core sprint-data changes |
| pennyfarthing-dist/gates/status-sync.md | NEW: YAML/Jira status verification gate |
| pennyfarthing-dist/gates/merge-ready.md | Story-status-aware PR blocking |
| pennyfarthing-dist/workflows/tdd.yaml | Wire status-sync entry_gate |
| pennyfarthing-dist/workflows/trivial.yaml | Wire status-sync entry_gate |
| pennyfarthing-dist/workflows/bdd.yaml | Wire status-sync entry_gate |
| pennyfarthing-dist/workflows/bdd-tandem.yaml | Wire status-sync entry_gate |
| pennyfarthing-dist/workflows/bdd-team.yaml | Wire status-sync entry_gate |
| pennyfarthing-dist/workflows/tdd-tandem.yaml | Wire status-sync entry_gate |
| pennyfarthing-dist/workflows/tdd-team.yaml | Wire status-sync entry_gate |
| pennyfarthing-dist/workflows/2party-tdd.yaml | Wire status-sync entry_gate |
| pennyfarthing-dist/workflows/review-tandem.yaml | Wire status-sync entry_gate |
| pennyfarthing-dist/guides/gates.md | Document status-sync gate |
