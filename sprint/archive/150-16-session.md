---
story_id: "150-16"
jira_key: "none"
epic: "MSSCI-16564"
workflow: "tdd"
---
# Story 150-16: Spec authority hierarchy guide

## Story Details
- **ID:** 150-16
- **Repos:** pennyfarthing
- **Branch:** feat/150-16-spec-authority-guide
- **Workflow:** tdd
- **Phase:** review

## Delivery Findings
No upstream findings.

## Design Deviations
No design deviations.

## Reviewer Assessment

**Verdict: APPROVE**

### Files Reviewed
- `pennyfarthing-dist/guides/spec-authority.md` — guide document (125 lines)
- `pennyfarthing-dist/src/pf/spec/__init__.py` — package init (1 line)
- `pennyfarthing-dist/src/pf/spec/authority.py` — validation functions (77 lines)
- `pennyfarthing-dist/src/pf/tests/test_150_16_spec_authority.py` — tests (269 lines)

### Test Results
28/28 passed, 0 failed, 0 skipped.

### Findings

**No blockers.**

**Suggestions (non-blocking):**

1. **Input validation on level values (LOW).** `check_deviation_required()` accepts any int, including 0, -1, or 99. A `ValueError` for levels outside 1-4 would make misuse obvious. This is a principle-level suggestion (Level 4), not an AC requirement — does not block approval.

2. **Guide could reference agent definitions (LOW).** The guide's "Integration with Workflow" section could link to the TEA, Dev, and Reviewer agent `.md` files so agents can cross-reference. Nice-to-have, not required by ACs.

3. **`get_authority_levels` return type annotation uses `object` (LOW).** The type hint `list[dict[str, object]]` is correct but less specific than `list[dict[str, int | str]]`. Minor ergonomic improvement for callers using type checkers.

### Summary

The guide clearly documents the 4-level hierarchy with concrete examples, an actionable deviation procedure, anti-pattern table, and workflow integration notes. The Python module is minimal and correct — returns defensive copies, uses keyword-only params for clarity, and the deviation check logic (`proposed > current`) correctly models "lower authority overriding higher requires escalation." Tests cover all ACs thoroughly: file existence, content ordering, deviation procedure keywords, structured return data, and boolean logic edge cases. Clean delivery.
