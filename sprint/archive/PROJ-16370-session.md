---
story_id: "143-12"
jira_key: "PROJ-16358"
epic: "PROJ-16358"
workflow: "trivial"
---

# Story 143-12: Validate per-role tool restrictions

## Story Details

- **ID:** 143-12
- **Jira Key:** PROJ-16358
- **Epic:** PROJ-16358 (Native Subagent Migration)
- **Workflow:** trivial
- **Stack Parent:** none

## Workflow Tracking

**Workflow:** trivial
**Phase:** finish
**Phase Started:** 2026-03-12T23:57:13Z

### Phase History

| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-03-12T00:00:00Z | 2026-03-12T23:44:29Z | 23h 44m |
| implement | 2026-03-12T23:44:29Z | 2026-03-12T23:52:11Z | 7m 42s |
| review | 2026-03-12T23:52:11Z | 2026-03-12T23:57:13Z | 5m 2s |
| finish | 2026-03-12T23:57:13Z | - | - |

## SM Assessment

Story setup complete. Trivial workflow — routes to Dev for implementation. Story validates that per-role tool restrictions are enforced correctly in agent definitions.

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/src/pf/validate/adapters/agent.py` - Added validate_native_agent() with role-based tool restriction checks, integrated into run()
- `pennyfarthing-dist/src/pf/tests/test_143_12_tool_restrictions.py` - 47 tests covering all role categories, edge cases, integration, and real file validation

**Tests:** 94/94 passing (GREEN) — 47 new + 47 existing (no regressions)
**Branch:** feat/143-12-validate-role-tool-restrictions (pushed)

**Handoff:** To review phase

## Delivery Findings

### Dev (implementation)
- No upstream findings during implementation.

### Reviewer (code review)
- No upstream findings during code review.

## Design Deviations

### Dev (implementation)
- No deviations from spec.

### Reviewer (audit)
- No undocumented deviations found. Dev's "no deviations" claim is accurate — implementation matches story intent directly.

## Reviewer Assessment

**Verdict:** APPROVED

**Observations:**
1. `[VERIFIED]` Data flow: `path.stem.lower()` → role lookup → set membership → role-appropriate error messages. Clean at `agent.py:448-460`.
2. `[VERIFIED]` All 10 native agents categorized in exactly one role set. No gaps.
3. `[VERIFIED]` Error handling: Early returns for missing frontmatter (line 414), None tools (line 430), non-list tools (line 434). All failure paths produce errors.
4. `[VERIFIED]` Field name `allowed-tools` consistent with `loader.py:72` and all epic-143 tests.
5. `[VERIFIED]` `pf validate agent` passes with 37/37 including all 10 native agents (0 errors).

**Specialist Subagent Findings:**
- `[EDGE]` Roles not in either set bypass role checks — dismissed: all 10 native agents ARE categorized, SM has no native file. Empty tools list caught by Read check. Case-insensitive tool names caught by unknown-tools check at `agent.py:443`.
- `[SILENT]` No silent failure concerns — pure validation logic returns explicit error lists, no try/except blocks, no swallowed errors.
- `[TEST]` TestRealNativeAgents manually parses YAML instead of calling validator — dismissed as independent cross-check (test_all_native_agents_pass_validation at line 334 uses the validator directly). Missing empty-list test — dismissed: empty list IS caught by Read check at line 439.
- `[DOC]` No documentation concerns — docstrings present on validate_native_agent(), constants are self-documenting.
- `[TYPE]` No type design concerns — function signature `tuple[list[str], list[str]]` matches existing validate_main_agent/validate_subagent pattern.
- `[SEC]` No security concerns — file paths from trusted `agents/native/` directory, no user-controlled input reaches eval or shell.
- `[SIMPLE]` Suggested DRYing validation loops in run() and unifying role sets into single dict — dismissed as scope creep for 2-point trivial story. Current structure is clear and matches existing patterns.

**Handoff:** To Stilgar for finish-story