# Story 108-1: Migrate tests-fail and approval gates to files

**Jira:** MSSCI-15013
**Epic:** 108 — Full Migration & Cleanup
**Points:** 2
**Workflow:** tdd
**Phase:** finish
**Repos:** orchestrator, pennyfarthing
**Branch:** feature/108-1-migrate-gates-to-files
**Assigned:** keith.avery@1898andco.io

---

## Story Context

This story completes the migration of gate logic from inline definitions in `handoff.md` to declarative gate files. Currently, two gate types remain that need to be extracted to files: `tests_fail` and `approval`. These gates are used across multiple workflow YAMLs (tdd, trivial, bdd, 2party-tdd, tdd-tandem, bdd-tandem, agent-docs). The inline fallback in `handoff-cli.sh` will be removed in the follow-up story (108-2), so all workflows must be updated to reference the new gate files.

## Acceptance Criteria

**AC1: Create gate files**
- Create `pennyfarthing-dist/gates/tests-fail.md` with logic extracted from `handoff.md` tests_fail branch
  - Check for failing tests that cover acceptance criteria from session file
  - Validate test files are committed to the branch
  - Return GATE_RESULT with status: pass or fail and list of test files
- Create `pennyfarthing-dist/gates/approval.md` with logic extracted from `handoff.md` approval branch
  - Check Reviewer Assessment section in session file for explicit APPROVED verdict
  - Handle both APPROVED and REJECTED verdicts
  - Return GATE_RESULT with status and verdict details if rejected

**AC2: Update workflow YAMLs**
- Add `gate.file` entries to all phases using `gate.type: tests_fail` or `gate.type: approval`:
  - `tdd.yaml` → red phase (tests_fail), review phase (approval)
  - `trivial.yaml` → implement phase (tests_pass), review phase (approval)
  - `bdd.yaml` → design phase (design_review), red phase (tests_fail), green phase (tests_pass), review phase (approval)
  - `tdd-tandem.yaml` → red phase (tests_fail), review phase (approval)
  - `bdd-tandem.yaml` → design phase (design_review), red phase (tests_fail), green phase (tests_pass), review phase (approval)
  - `2party-tdd.yaml` → red phase (tests_fail), review phase (approval), others
  - `agent-docs.yaml` → implement phase (validation)
- Maintain both `gate.file` and `gate.type` during transition (will be cleaned up in 108-2)

**AC3: Verify migration**
- All gate files validate with `pf gate validate`
- All workflow YAMLs have been checked for proper gate.file references
- Tests pass for both gate implementations

## Technical Notes

### Key Files
- **Source of truth:** `sprint/context/context-epic-108.md` (has complete gate logic)
- **Workflow YAMLs location:** `pennyfarthing-dist/workflows/`
- **Gate files location:** `pennyfarthing-dist/gates/`
- **Existing gate example:** `gates/tests-pass.md` (created in epic 106)

### Implementation Pattern

Gate files use this XML-based format with `<gate>` root element:
```xml
<gate name="gate-name" model="haiku">
  <purpose>Description of what this gate validates</purpose>
  <pass>Conditions for passing and what to return</pass>
  <fail>Conditions for failing and what to return</fail>
</gate>
```

Return format: `GATE_RESULT with status: pass/fail` plus relevant details.

### Important Notes
- The workflow override from `trivial` to `tdd` means this story will follow the TDD workflow
- Design-review, quality-pass, and validation gates are out of scope for 108-1 (mentioned in epic but not in this story's acceptance criteria)
- Both orchestrator and pennyfarthing repos need changes: orchestrator for sprint tracking, pennyfarthing for the actual implementation
- Haiku is the model for these gates (lightweight validation logic)

### Workflow Updates
Each workflow YAML phase needs the `gate.file` path added alongside existing `gate.type`:
```yaml
gate:
  file: gates/tests-fail    # NEW
  type: tests_fail          # KEEP (for backward compat during transition)
```

### Testing Strategy
- Unit test each gate file independently
- Integration test: run full TDD workflow with new gates
- Verify workflow YAML parsing and gate resolution
- Check that gate files are properly distributed in npm package

### Dependencies Met
- Epic 105 (script infrastructure) ✓
- Epic 106 (gate file format + tests-pass.md) ✓
- Can proceed immediately

## TEA Assessment

**Tests Required:** Yes
**Test Files:**
- `pennyfarthing_scripts/tests/test_108_1_gate_migration.py` — 70 tests (50 failing, 20 passing)

**Tests Written:** 50 failing tests covering 3 ACs
- AC1 (23 tests): Gate file existence and XML structure for tests-fail.md and approval.md
- AC2 (27 tests): gate.file entries in tdd, trivial, bdd, tdd-tandem, bdd-tandem, 2party-tdd, agent-docs workflows
- AC3 (integration): resolve_gate_file() and resolve_gate() return gate_file for migrated phases

**Status:** RED (failing — ready for Dev)
**20 passing tests** verify existing state that must not regress (green phase gate.file from 106, gate.type retention)

**Handoff:** To Dev for implementation

**Dev Notes:**
1. Create `pennyfarthing-dist/gates/tests-fail.md` — use epic context XML template
2. Create `pennyfarthing-dist/gates/approval.md` — use epic context XML template
3. Add `gate.file` to all phases with `gate.type: tests_fail` or `gate.type: approval` across 7 workflow YAMLs
4. Retain `gate.type` alongside `gate.file` (transition period, cleaned up in 108-2)
5. Run: `python3 -m pytest pennyfarthing_scripts/tests/test_108_1_gate_migration.py -v`

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/gates/tests-fail.md` — new gate file for RED state verification
- `pennyfarthing-dist/gates/approval.md` — new gate file for reviewer verdict check
- `pennyfarthing-dist/workflows/tdd.yaml` — added gate.file to red, review phases
- `pennyfarthing-dist/workflows/trivial.yaml` — added gate.file to review phase
- `pennyfarthing-dist/workflows/bdd.yaml` — added gate.file to red, review phases
- `pennyfarthing-dist/workflows/tdd-tandem.yaml` — added gate.file to red, review phases
- `pennyfarthing-dist/workflows/bdd-tandem.yaml` — added gate.file to red, review phases
- `pennyfarthing-dist/workflows/2party-tdd.yaml` — added gate.file to 9 phases
- `pennyfarthing-dist/workflows/agent-docs.yaml` — added gate.file to review phase

**Tests:** 70/70 passing (GREEN)
**PR:** #918 — feat(108-1): migrate tests-fail and approval gates to files
**Branch:** feature/108-1-migrate-gates-to-files (pushed)

**Handoff:** To Reviewer for code review

## Reviewer Assessment

**Verdict:** APPROVED

| # | Severity | Description | Location |
|---|----------|-------------|----------|
| 1 | [VERIFIED] | Gate file XML structure matches `tests-pass.md` pattern | `gates/tests-fail.md:1`, `gates/approval.md:1` |
| 2 | [VERIFIED] | All 7 workflow YAMLs have correct `gate.file` entries (16 insertions) | All workflow YAMLs |
| 3 | [VERIFIED] | `gate.type` retained alongside `gate.file` — backward compat preserved | `test_108_1_gate_migration.py:415` |
| 4 | [VERIFIED] | Data flow: YAML gate.file → resolve_gate() → resolve_gate_file() → abs path | `resolve_gate.py:70`, `gate_file.py:50` |
| 5 | [VERIFIED] | Security: path traversal rejected in _sanitize_gate_name() | `gate_file.py:66-83` |
| 6 | [LOW] | Stale comment `# None for MVP` on gate_file extraction | `resolve_gate.py:70` |
| 7 | [LOW] | Pre-existing: tests_pass phases in trivial/bdd/tandem lack gate.file (from 106) | `trivial.yaml:22` |

**Data flow traced:** `gate.file: gates/tests-fail` → `resolve_gate()` reads YAML → `resolve_gate_file()` strips prefix, searches local then dist → returns found/not_found result. Path traversal blocked.
**Error handling:** Both resolution functions return structured error dicts, no exceptions thrown.
**Tests:** 70/70 passing, covering structure (AC1), wiring (AC2), integration (AC3).

**Handoff:** To SM for finish-story

## Phase Tracking

- **setup:** Branches created, session file created, story mapped
- **red:** Write failing tests for gate logic
- **green:** Implement gate files and update workflow YAMLs
- **review:** Code review and verification of all gate implementations
- **completed:** All gates migrated, YAMLs updated, tests passing