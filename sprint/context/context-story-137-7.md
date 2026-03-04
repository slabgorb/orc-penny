---
parent: 137
---

# Story 137-7: Sprint status aggregates all archive files instead of filtering by current sprint

## Business Context

Story 137-7 is a bug fix within Epic 137 (Stepped workflow modernization). The sprint status command is incorrectly aggregating metrics from ALL archive files instead of filtering for only the current sprint. This causes inaccurate status reporting and makes sprint tracking unreliable. The fix requires identifying the sprint status logic, filtering by the active sprint identifier, and validating output against the current sprint context.

## Technical Guardrails

- Bug fix — focus on sprint status filtering logic only
- Don't refactor broader sprint tracking architecture
- Changes to `pf sprint status` command and underlying context aggregation
- Verify with both CLI output and session file tracking
- Ensure filtering applies to all metrics (story counts, points, completion percentage)
- No changes to sprint YAML structure

## Scope Boundaries

**In Scope:**
- Locate sprint status implementation (likely in `src/pf/sprint/` or `packages/core/`)
- Identify how archive files are currently aggregated
- Add filtering by current sprint ID from `current-sprint.yaml`
- Add tests to verify filtering works correctly
- Update any documentation about sprint status behavior

**Out of Scope:**
- Changes to archive file format
- Sprint planning or prioritization logic
- Epic-level status aggregation
- UI changes to BikeRack sprint panel

## AC Context

1. **Sprint status filters by current sprint** — `pf sprint status` only includes stories from active sprint, not archived sprints
2. **Archive files not double-counted** — stories in `sprint/archive/` are excluded from current sprint metrics
3. **All metrics filtered correctly** — story count, point total, and completion percentage reflect current sprint only
4. **Tests pass** — TDD cycle produces failing tests first, then implementation makes them green
5. **Documentation updated** — sprint status behavior documented if applicable

## Testing Acceptance

- RED phase: TEA writes failing tests covering sprint status filtering
- GREEN phase: Dev implements filtering logic to make tests pass
- VERIFY phase: TEA runs full test suite and linting
- Code review: Reviewer checks correctness and no regressions
