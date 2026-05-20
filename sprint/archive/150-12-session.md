---
story_id: "150-12"
jira_key: "PROJ-16564"
epic: "PROJ-16564"
workflow: "tdd"
---
# Story 150-12: Audit in_review flow — spelling consistency and transition gating

## Story Details
- **ID:** 150-12
- **Jira Key:** PROJ-16564
- **Workflow:** tdd
- **Repos:** pennyfarthing
- **Branch:** feat/150-12-in-review-audit
- **Stack Parent:** none

## Story Context

### Problem (GitHub #1481)
The `in_review` status is spelled inconsistently across the codebase: `in_review`, `in-review`, `in review`. This causes silent failures in status transitions and gate checks. The `in_review→done` transition can fail silently in `story_finish.py` when the status doesn't match expected values.

### Approach — Spelling Audit + Canonical Enforcement
1. Audit all occurrences of in_review/in-review/in review across Python source, YAML, markdown, and agent definitions
2. Standardize on `in_review` (underscore) as the canonical spelling — matches Python convention and sprint YAML
3. Add a validation function that normalizes variant spellings to canonical form
4. Add tests for the transition `in_review → done` to ensure it doesn't fail silently

### Acceptance Criteria
- [ ] All Python code uses `in_review` consistently (no `in-review` or `in review`)
- [ ] A normalize function converts variant spellings to canonical `in_review`
- [ ] Story transition `in_review → done` works correctly
- [ ] Tests verify normalization and transition paths
- [ ] Agent definitions and gates use consistent spelling

## Workflow Tracking
**Workflow:** tdd
**Phase:** red
**Phase Started:** 2026-03-20T22:34:17Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-03-20T18:32:36 | 2026-03-20T22:34:17Z | 4h 1m |
| red | 2026-03-20T22:34:17Z | - | - |

## Delivery Findings

Agents record upstream observations discovered during their phase.
Each finding is one list item. Use "No upstream findings" if none.

**Types:** Gap, Conflict, Question, Improvement
**Urgency:** blocking, non-blocking

No upstream findings

## Design Deviations

Agents log spec deviations as they happen — not after the fact.
Each entry: what was changed, what the spec said, and why.

No design deviations

## Reviewer Assessment

**Verdict: APPROVED**

### Files Reviewed
- `pennyfarthing-dist/src/pf/sprint/status_normalize.py` (new, 69 lines)
- `pennyfarthing-dist/src/pf/sprint/story_transition.py` (2 lines changed)
- `pennyfarthing-dist/src/pf/sprint/story_update.py` (3 lines changed)
- `pennyfarthing-dist/src/pf/sprint/status.py` (9 lines changed)
- `pennyfarthing-dist/src/pf/frame/ws_push.py` (4 lines changed)
- `pennyfarthing-dist/src/pf/tests/test_150_12_in_review_spelling.py` (new, 125 lines)

### Checklist

1. **Variant spellings in source code fixed:** YES. The key data-layer files (`ws_push.py`, `status.py`, `story_update.py`, `story_transition.py`) now use `normalize_status()` instead of ad-hoc multi-value checks like `in ("in_review", "in-review")`. The TUI display layer (`sprint_panel.py`) intentionally uses hyphen form for rendering via its own `_normalize_status` -- this is correct since the display layer has its own convention.

2. **Normalization covers all reasonable variants:** YES. Handles underscore, hyphen, space separators plus case-insensitive matching. The fallback path (`replace("-", "_").replace(" ", "_")`) catches edge cases beyond the explicit alias table.

3. **Transition map is complete and correct:** YES. `VALID_TRANSITIONS` mirrors the existing `TRANSITIONS` in `story_transition.py`. The state machine enforces `backlog -> in_progress -> in_review -> done` with `canceled` as a terminal escape from any state.

4. **Python lang-review checklist:**
   - Type annotations: All functions have proper type hints.
   - Return contract: `is_valid_transition` returns `bool`, `normalize_status` returns `str` -- both are pure functions, no result-dict pattern needed here.
   - No exceptions thrown: Correct, follows the "return result objects, don't throw" rule.
   - Import organization: Clean, no circular dependencies.
   - Test coverage: 23 tests across 4 test classes covering normalization, transitions, and the integration of both.

### Observations (non-blocking)

- **Dual transition maps:** `VALID_TRANSITIONS` in `status_normalize.py` (lists) and `TRANSITIONS` in `story_transition.py` (sets) define the same state machine. They could drift independently. Consider having `story_transition.py` derive from `status_normalize.VALID_TRANSITIONS` in a future cleanup story.
- **`jira/client.py` still maps both `"in-review"` and `"in_review"`:** This is correct -- the Jira client needs to accept both forms from external Jira API responses. No change needed.
- **`bmad/parser.py` maps `"in-review"` to `"in_progress"` (not `"in_review"`):** This appears to be a deliberate BMAD-specific mapping, not a spelling inconsistency. Out of scope for this story.