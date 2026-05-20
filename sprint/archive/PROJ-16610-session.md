---
story_id: "150-10"
jira_key: "PROJ-16610"
epic: "PROJ-16564"
workflow: "tdd"
---

# Story 150-10: Session files must be append-only — enforce chronological audit trail

## Story Details
- **ID:** 150-10
- **Jira Key:** PROJ-16610
- **Workflow:** tdd
- **Repos:** pennyfarthing
- **Branch:** feat/150-10-session-append-only
- **Stack Parent:** none

## Story Context

### Problem
Agents currently edit previous sections of session files during rework cycles, destroying the chronological audit trail. When a reviewer sends CHANGES_REQUESTED, the dev overwrites their previous assessment instead of appending a new one. This makes it impossible to trace what happened, when, and why.

### Approach — Append-Only Validation Hook
Enforce append-only semantics on session files via a PreToolUse hook that validates Edit/Write operations against `.session/*-session.md` files.

1. Create a validation function `validate_session_append_only(old_content, new_content) -> dict` that:
   - Parses both old and new content into sections (by `##` headings)
   - Verifies no existing section content was modified or deleted
   - Allows new sections to be appended
   - Allows content to be appended WITHIN existing sections (after the last line)
   - Returns `{valid: True/False, violations: [...]}`

2. The hook integration (wiring into PreToolUse) is a separate concern — this story focuses on the validation logic.

### Exceptions
- Workflow Tracking section (phase updates by `complete-phase` are legitimate edits)
- Story Details section (PR field additions are legitimate)
- YAML frontmatter (updated by tooling)

### Acceptance Criteria
- [ ] Validation function detects when existing section content is modified
- [ ] Validation function detects when sections are deleted
- [ ] Appending new sections is allowed
- [ ] Appending within existing sections is allowed
- [ ] Workflow Tracking and Story Details sections are exempt from checks
- [ ] YAML frontmatter changes are exempt
- [ ] Tests cover all cases including edge cases

## Workflow Tracking

**Workflow:** tdd
**Phase:** red
**Phase Started:** 2026-03-20T22:19:51Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-03-20T22:18:05Z | 2026-03-20T22:19:51Z | 1m 46s |
| red | 2026-03-20T22:19:51Z | - | - |

## Delivery Findings

Agents record upstream observations discovered during their phase.
Each finding is one list item. Use "No upstream findings" if none.

**Types:** Gap, Conflict, Question, Improvement
**Urgency:** blocking, non-blocking

<!-- Agents: append findings below this line. Do not edit other agents' entries. -->

## Design Deviations

Agents log spec deviations as they happen — not after the fact.
Each entry: what was changed, what the spec said, and why.

<!-- Agents: append deviations below this line. Do not edit other agents' entries. -->

## Reviewer Assessment

**Verdict: APPROVED**

**Date:** 2026-03-20
**Reviewer:** Internal Code Review (Phase 3)
**Diff reviewed:** `git diff develop...HEAD` (2 files: `append_only.py`, `test_150_10_session_append_only.py`)

### Summary

Clean implementation of append-only validation for session files. The code is well-structured, well-documented, and all 19 tests pass. No regressions in the broader test suite (pre-existing failures in unrelated modules: pptx assembler, frame routes, peloton panes).

### Checklist

- [x] **Section parsing handles edge cases** -- No-section content (preamble) is skipped. Single-section files work. `### ` sub-headings are NOT split on (only `## `), which is correct since session sections use `##`. The regex `^(## .+)$` correctly anchors to line boundaries.
- [x] **Exempt section list is appropriate** -- Workflow Tracking, Story Details, and Phase History match the story's acceptance criteria. Frontmatter is handled separately via `_parse_frontmatter()`, not via the exempt list.
- [x] **Python lang-review compliance** -- `from __future__ import annotations` present. Type hints on all functions. `frozenset` for immutable constant. No bare exceptions. Returns dict (not throws). Docstrings on all public and private functions.
- [x] **No false positives on legitimate updates** -- Trailing whitespace normalization via `.rstrip()` prevents spurious violations. Append-within-section uses `startswith()` which correctly allows any suffix. New sections at end are simply not in `old_sections` so never checked.

### Observations

1. **`lstrip("# ")` on line 53** -- This strips *all* leading `#`, space characters individually (character set, not substring). For `## Design Notes` it produces `Design Notes` which is correct. But a heading like `## # Special` would become `Special` not `# Special`. This is an acceptable edge case since session files don't use headings starting with `#`.

2. **Duplicate section headings** -- If a session file has two sections with the same `##` heading, `new_section_map` keeps only the last one. This could cause a false positive if the first instance was modified but the second was kept. In practice, session files don't have duplicate section headings, so this is a non-issue.

3. **Design Deviations section** -- The `Design Deviations` section in session files contains HTML comments (`<!-- ... -->`). The validation correctly treats these as regular content, so deleting or modifying the comment would trigger a violation. This is the desired behavior.

4. **No `{success, data, error}` pattern** -- The function returns `{valid, violations}` instead of the framework's standard `{success, data, error}` pattern. This is acceptable because the story spec explicitly defines this return shape, and the function is a pure validator, not a CLI/hook command.

### Acceptance Criteria Verification

- [x] Validation function detects when existing section content is modified (TestContentModified: 2 tests)
- [x] Validation function detects when sections are deleted (TestSectionDeleted: 2 tests)
- [x] Appending new sections is allowed (TestNewSectionAppended: 2 tests)
- [x] Appending within existing sections is allowed (TestAppendWithinSection: 2 tests)
- [x] Workflow Tracking and Story Details sections are exempt (TestWorkflowTrackingExempt, TestStoryDetailsExempt: 3 tests)
- [x] YAML frontmatter changes are exempt (TestFrontmatterExempt: 1 test)
- [x] Tests cover all cases including edge cases (19 tests total, including Phase History exempt, trailing whitespace, header rename, multiple violations, empty old content)