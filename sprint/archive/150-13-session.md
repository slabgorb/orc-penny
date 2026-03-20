---
story_id: "150-13"
jira_key: "MSSCI-16564"
epic: "MSSCI-16564"
workflow: "tdd"
---
# Story 150-13: Reviewer gate template and docs for specialist tag format

## Story Details
- **ID:** 150-13
- **Jira Key:** MSSCI-16564
- **Workflow:** tdd
- **Repos:** pennyfarthing
- **Branch:** feat/150-13-reviewer-gate-template
- **Stack Parent:** none

## Story Context

### Problem (GitHub #1480)
The reviewer approval gate has conflicting requirements around specialist tag format. The `## Reviewer Assessment` h2 heading's scope ends when the next h2 (`## Subagent Results`) begins, but the gate checks for specialist tags (like `[SEC]`, `[EDGE]`) within the assessment section. Reviewers take 4+ attempts to get the format right because there's no template.

### Approach — Template Function + Gate Documentation
1. Create a template generator that produces a correctly-formatted reviewer assessment skeleton with all specialist tags in the right positions
2. The template respects enabled/disabled subagent toggles
3. Document the expected format in the approval gate file itself

### Implementation
- Add `generate_reviewer_template(enabled_subagents: set[str]) -> str` to a new module `pf.reviewer.template`
- Template includes: `## Reviewer Assessment` with all dispatch tags, `**Specialist findings incorporated:**` line, `### Rule Compliance` section — all BEFORE `## Subagent Results`
- The function reads enabled subagents from settings (or accepts them as parameter)

### Acceptance Criteria
- [ ] Template generator produces valid assessment skeleton
- [ ] All enabled dispatch tags are included in correct position
- [ ] Disabled subagents are excluded from template
- [ ] Template passes the existing approval gate checks in complete_phase.py
- [ ] Tests verify template structure against gate requirements

## Workflow Tracking
**Workflow:** tdd
**Phase:** red
**Phase Started:** 2026-03-20T23:24:59Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-03-20T00:00:00Z | 2026-03-20T23:24:59Z | 23h 24m |
| red | 2026-03-20T23:24:59Z | - | - |

## Delivery Findings

Agents record upstream observations discovered during their phase.
Each finding is one list item. Use "No upstream findings" if none.

**Types:** Gap, Conflict, Question, Improvement
**Urgency:** blocking, non-blocking

No upstream findings yet.

<!-- Agents: append findings below this line. Do not edit other agents' entries. -->

## Design Deviations

Agents log spec deviations as they happen — not after the fact.
Each entry: what was changed, what the spec said, and why.

No deviations yet.

<!-- Agents: append deviations below this line. Do not edit other agents' entries. -->

## Reviewer Assessment

**Verdict:** APPROVED

### Gate Compliance

The template output passes `_check_subagent_dispatch` from `complete_phase.py`. Verified by test 9 which imports and calls the actual gate check function against generated output with all tags enabled. The key structural requirement -- all dispatch tags appearing between `## Reviewer Assessment` and `## Subagent Results` -- is enforced by test 3.

### Circular Import Analysis

- `pf.reviewer.template` imports `_SUBAGENT_SETTING_MAP` from `pf.handoff.complete_phase` (top-level import of a module-level dict).
- `pf.handoff.complete_phase` has zero imports from `pf.reviewer`. Import direction is strictly one-way.
- The settings import (`pf.settings.settings`) inside `_get_enabled_subagents()` is deferred (inside function body), avoiding import-time side effects.
- No circular import risk.

### Python Review Checklist

- [x] `from __future__ import annotations` present
- [x] Type hints on public function signature (`set[str] | None`) and return type (`str`)
- [x] Docstring with Args/Returns on public function
- [x] Module docstring with story reference
- [x] No bare `except` -- uses `except Exception` for settings fallback (matches pattern in `complete_phase.py`)
- [x] No mutable default arguments
- [x] Sorted iteration over `_SUBAGENT_SETTING_MAP` for deterministic output
- [x] Clean separation: `_get_enabled_subagents()` private helper, `generate_reviewer_template()` public API

### Test Quality

- 10 tests covering all acceptance criteria
- Tests import the actual gate check function (`_check_subagent_dispatch`) rather than reimplementing checks
- Mock used correctly in test 9 to control `_get_enabled_subagents` return value
- Edge case covered (empty enabled set)

### Minor Observations (non-blocking)

- The `__init__.py` for `pf.reviewer` is empty, which is fine for now. If more modules are added later, consider re-exporting `generate_reviewer_template` from `__init__.py` for convenience.
- The `_SUBAGENT_SETTING_MAP` import uses a private symbol. This is acceptable since both modules are within the same package and the mapping is stable, but a future story could promote it to a shared constants module if more consumers appear.