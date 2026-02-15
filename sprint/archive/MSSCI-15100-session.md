# Session: MSSCI-15100 — Replace handoff-marker.sh with gate-aware Python CLI

## Story
- **ID:** 105-4 / MSSCI-15100
- **Epic:** 105 — Script-First Handoff
- **Title:** Replace handoff-marker.sh with gate-aware Python CLI
- **Points:** 2
- **Workflow:** trivial (SM → Dev → Reviewer → SM)
- **Priority:** P1
- **Status:** in_progress
- **Assignee:** keithavery (keith.avery@1898andco.io)

## Description

Replace `handoff-marker.sh` (the last remaining bash script in the handoff chain) with a Python CLI command `pf handoff marker`. The existing `pf handoff` CLI already has `resolve-gate` and `complete-phase` — this adds the third subcommand to complete the Python migration.

## Acceptance Criteria

- [ ] `pf handoff marker {next_agent}` generates the same CYCLIST marker output as `handoff-marker.sh`
- [ ] Supports environment detection (Cyclist vs terminal) like current script
- [ ] Context checking (high context usage warning) preserved
- [ ] All agent .md files updated to reference `pf handoff marker` instead of `handoff-marker.sh`
- [ ] Old `handoff-marker.sh` removed from `pennyfarthing-dist/scripts/core/`
- [ ] Smoke test: run `pf handoff marker dev` and verify output matches expected format

## Technical Notes

**Key files:**
- `pennyfarthing/pennyfarthing-dist/scripts/core/handoff-marker.sh` — current script to replace
- `pennyfarthing/pennyfarthing_scripts/handoff/` — existing Python CLI module (add `marker.py` here)
- `pennyfarthing/pennyfarthing_scripts/handoff/cli.py` — add `marker` subcommand
- `pennyfarthing/pennyfarthing-dist/agents/*.md` — update exit protocols to use `pf handoff marker`

**Related stories:**
- 105-1: Created handoff-cli.sh with resolve-gate and complete-phase (DONE)
- 105-2: Updated agent exit protocols across all agent files (DONE)
- 105-3: End-to-end handoff smoke test (DONE)

## Workflow Tracking
**Phase:** finish
**Phase Started:** 2026-02-15T11:40:17Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-02-15T06:07:00Z | 2026-02-15T11:08:25Z | 5h 1m |
| implement | 2026-02-15T11:08:25Z | 2026-02-15T11:23:41Z | 15m 16s |
| review | 2026-02-15T11:23:41Z | 2026-02-15T11:30:50Z | 7m 9s |
| implement | 2026-02-15T11:30:50Z | 2026-02-15T11:35:39Z | 4m 49s |
| review | 2026-02-15T11:35:39Z | 2026-02-15T11:40:17Z | 4m 38s |
| finish | 2026-02-15T11:40:17Z | - | - |

### Handoff History
| From | To | Gate | Status | Timestamp |
|------|-----|------|--------|-----------|
| setup (sm) | implement (dev) | skip | PASSED | 2026-02-15T11:08:25Z |
| implement (dev) | review (reviewer) | tests_pass | PASSED | 2026-02-15T11:23:41Z |

---

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing_scripts/handoff/marker.py` — New generate_marker() with context/Cyclist/relay detection
- `pennyfarthing_scripts/handoff/cli.py` — Added marker subcommand to handoff CLI group
- `pennyfarthing-dist/scripts/core/handoff-marker.sh` — DELETED (replaced by Python CLI)
- `pennyfarthing-dist/agents/*.md` — All 13 agent files updated to reference `pf handoff marker`
- `pennyfarthing-dist/agents/sm-handoff.md` — Updated output templates
- `pennyfarthing-dist/agents/handoff.md` — Updated output templates
- `pennyfarthing-dist/guides/agent-behavior.md` — Updated exit protocol references
- `pennyfarthing-dist/guides/agent-tag-taxonomy.md` — Updated references
- `pennyfarthing-dist/guides/xml-tags.md` — Updated references
- `pennyfarthing-dist/scripts/core/phase-check-start.sh` — Updated reference
- `pennyfarthing_scripts/tests/test_handoff_e2e.py` — Updated AC4 tests to use Python CLI
- `scripts/validate-refs.js` — Updated pattern matching
- `docs/REFLECTOR-SYSTEM.md` — Updated architecture docs
- `docs/agent-context-heatmap.md` — Updated reference

**Tests:** 24/24 passing (GREEN)
**PR:** #909 — feat(105-4): replace handoff-marker.sh with pf handoff marker CLI
**Branch:** feature/MSSCI-15100-replace-handoff-marker-sh (pushed)

**Handoff:** To Roland Deschain for code review

## Reviewer Assessment

**Verdict:** REJECTED

| Severity | Issue | Location | Fix Required |
|----------|-------|----------|--------------|
| [HIGH] | Stale path prefix in exit-sequence bash blocks: `.pennyfarthing/scripts/core/pf handoff marker` instead of `pf handoff marker` | `dev.md:196`, `tea.md:143`, `ba.md:173`, `tech-writer.md:209`, `devops.md:205`, `ux-designer.md:243`, `pm.md:154`, `architect.md:181`, `orchestrator.md:185` | Remove `.pennyfarthing/scripts/core/` prefix — command is just `pf handoff marker {next_agent}` |
| [VERIFIED] | `marker.py` generate_marker() correctly handles error, no-agent, relay-on/off, Cyclist/non-Cyclist paths | `marker.py:14-93` | — |
| [VERIFIED] | `_block()` handles bool, str, empty-str, numeric, None correctly for YAML output | `marker.py:96-109` | — |
| [VERIFIED] | CLI validation catches missing args with helpful usage message | `cli.py:112-118` | — |
| [VERIFIED] | Tests updated from shell-script invocation to `pf handoff marker` subprocess | `test_handoff_e2e.py:351-406` | — |
| [LOW] | Mixed-type variable `pct` (int or str "unknown") — works via short-circuit but reduces clarity | `marker.py:37-44` | Consider sentinel value or Optional[int] pattern |
| review (reviewer) | implement (dev) | approval | PASSED | 2026-02-15T11:30:50Z |
| implement (dev) | review (reviewer) | tests_pass | PASSED | 2026-02-15T11:35:39Z |

**Data flow traced:** `next_agent` (str) → `generate_marker()` → `check_context()` for env detection → `_block()` YAML formatting → `click.echo()` to stdout. No injection risk — agent name embedded in fixed format strings, not shell-executed (except non-Cyclist relay path which calls `pf agent start`).

**Error handling:** `check_context()` returns `ContextResult` with `.error` field; `generate_marker` degrades to `"unknown"` context percent. `subprocess.run` timeout at 30s with blanket `except Exception`. Acceptable for CLI tool.

**The flaw:** 9 of 13 agent `.md` exit sequences have a botched find-and-replace. The old line:
```
.pennyfarthing/scripts/core/handoff-marker.sh {next_agent}
```
became:
```
.pennyfarthing/scripts/core/pf handoff marker {next_agent}
```
instead of:
```
pf handoff marker {next_agent}
```

Only `sm.md` and `reviewer.md` have the correct command. Agents reading the other 9 files will attempt to execute a nonexistent path.

**Handoff:** Back to Jack Torrance to fix the stale path prefix in 9 agent exit sequences.

---

## Dev Assessment (Round 2)

**Fix Applied:** Removed stale `.pennyfarthing/scripts/core/` prefix from 9 agent exit-sequence bash blocks
**Files Changed:**
- `pennyfarthing-dist/agents/dev.md` — Fixed exit-sequence path
- `pennyfarthing-dist/agents/tea.md` — Fixed exit-sequence path
- `pennyfarthing-dist/agents/ba.md` — Fixed exit-sequence path
- `pennyfarthing-dist/agents/tech-writer.md` — Fixed exit-sequence path
- `pennyfarthing-dist/agents/devops.md` — Fixed exit-sequence path
- `pennyfarthing-dist/agents/ux-designer.md` — Fixed exit-sequence path
- `pennyfarthing-dist/agents/pm.md` — Fixed exit-sequence path
- `pennyfarthing-dist/agents/architect.md` — Fixed exit-sequence path
- `pennyfarthing-dist/agents/orchestrator.md` — Fixed exit-sequence path

**Tests:** 24/24 passing (GREEN)
**Validation:** validate-refs.js — 543 references, 0 issues
**Branch:** feature/MSSCI-15100-replace-handoff-marker-sh (pushed)
**PR:** #909 (updated)

**Handoff:** To Roland Deschain for re-review

---

## Reviewer Assessment (Round 2)

**Verdict:** APPROVED

| Check | Result |
|-------|--------|
| [VERIFIED] | All 9 stale `.pennyfarthing/scripts/core/` prefixes removed from exit-sequence blocks |
| [VERIFIED] | `sm.md` and `reviewer.md` still correct (untouched by fix) |
| [VERIFIED] | Zero references to `handoff-marker.sh` in `pennyfarthing-dist/` |
| [VERIFIED] | Zero `.pennyfarthing/scripts/core/pf handoff` in agent files |
| [VERIFIED] | 24/24 tests GREEN |
| [VERIFIED] | validate-refs.js: 543 references, 0 issues |
| [VERIFIED] | Smoke test: `pf handoff marker dev` correct YAML output |
| [LOW] | Mixed-type `pct` variable in `marker.py:37-44` — acceptable for CLI tool |
| review (reviewer) | finish (sm) | approval | PASSED | 2026-02-15T11:40:17Z |

**Handoff:** To Johnny Smith for story finish

---

**Session created:** 2026-02-15