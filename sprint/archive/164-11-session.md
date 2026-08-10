---
story_id: "164-11"
jira_key: ""
epic: "164"
workflow: "tdd"
---
# Story 164-11: Harden _parse_session section tracker

## Story Details
- **ID:** 164-11
- **Jira Key:** (none)
- **Workflow:** tdd
- **Stack Parent:** none
- **Branch:** feat/164-11-harden-parse-session-section-tracker
- **PR:** (none yet — recorded when the PR is created)

## Workflow Tracking
**Workflow:** tdd
**Phase:** finish
**Phase Started:** 2026-08-10T19:36:12Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-08-10T19:14:15Z | 2026-08-10T19:24:32Z | 10m 17s |
| red | 2026-08-10T19:24:32Z | - | - |

## Technical Context

### Source Location
File: `pennyfarthing/pennyfarthing-dist/src/pf/sprint/story_finish.py`
Function: `_parse_session` (lines 142–183)

### Defect 1: Fenced Code Blocks Not Skipped

**Current Behavior:**
The section tracker treats all lines as potential headings/fields, including lines inside ` ``` ` fenced code blocks. When session markdown contains a fenced code block with heading-like text or field-shaped lines (e.g. `**Branch:** ...` or `## Story Details`), the parser incorrectly interprets those as real sections and fields.

**Example Failure:**
```markdown
## Story Details
- **Branch:** feat/164-11-real

## Implementation Notes
```python
# Here's a snippet showing field syntax:
**Branch:** feat/164-11-wrong (this is just documentation)
```

The parser sees the line inside the fence and may treat it as a field, depending on the iteration order.
```

**Why It Matters (from 155-40 review):**
Agents write rich session documentation with code examples. A code block containing a `**Field:**` line can poison the field extraction if the parser doesn't skip fenced regions.

**Implementation Requirement:**
- Maintain fence state (inside/outside fence) as the parser iterates line-by-line
- When inside a fence (detected by triplet backticks ` ``` `), skip field extraction for that line
- Fence state toggles on each triplet-backtick line
- Do NOT extract or set section when inside a fence

### Defect 2: Multiple "Story Details" Headings Can Overwrite

**Current Behavior:**
When a session contains two or more `## Story Details` sections, the parser's current logic allows a LATER occurrence to re-populate and overwrite the `branch` and `pr` fields from the FIRST section.

Looking at the code (lines 160–182):
```python
fields: dict[str, str] = {}
detail_fields: dict[str, str] = {}
# ... iteration ...
if section == "story details":
    detail_fields.setdefault(key, value)
# ... after iteration ...
for key in ("branch", "pr"):
    if key in detail_fields:
        fields[key] = detail_fields[key]
```

The `setdefault` on `detail_fields` is correct (first-wins per field). However, there's **no guard preventing a SECOND `## Story Details` heading from being detected**. The `section` variable is reset every time a line starts with `## `, so a later heading still matches, and `detail_fields` accumulates from BOTH sections.

**Why It Matters (from 155-40 spec):**
The 155-33 template contract places the authoritative branch/PR fields in the FIRST "Story Details" section. Later sections (like "Dev Assessment" or "Delivery Findings") may contain hand-written field lines that should NOT override the official ones. The "first heading wins" rule ensures template-written fields are never overwritten by agent assessment notes.

**Current Logic Flaw:**
- `detail_fields.setdefault()` prevents a field from being overwritten WITHIN the same section
- But when a LATER `## Story Details` heading appears, `section` is updated, and subsequent fields accumulate into the same `detail_fields` dict
- Result: the authority overlay (lines 180–182) uses values from ANY "Story Details" section, not just the FIRST

**Implementation Requirement:**
- Track whether we've already seen a "Story Details" heading
- Once `detail_fields` is populated from the FIRST "Story Details" heading, IGNORE any subsequent headings that also match "story details"
- Later "Story Details" sections should NOT reset or add to `detail_fields`

## Acceptance Criteria

1. **_parse_session skips fenced code blocks:**
   - Branch/PR/section-heading-like lines inside ` ``` ` code fences are NOT parsed as real headings/fields
   - Test: session with `**Branch:**` inside a code block must NOT extract that value
   - Regression: sections and fields outside fences continue to parse correctly

2. **Only the FIRST "Story Details" heading populates the branch/pr overlay:**
   - When a session has multiple "Story Details" sections, only the first one's branch/pr values are captured
   - A second or later "Story Details" section does not overwrite already-captured values
   - Test: session with correct values in Story Details #1 and wrong values in Story Details #2 must resolve to the correct values from #1
   - Regression: sessions with a single Story Details section parse exactly as before

3. **Legit single-Story-Details sessions parse exactly as before (regression):**
   - All existing tests pass without modification
   - Sessions with one Story Details, anchored fields, section authority, and backtick/sentinel handling all work
   - The 155-33 fallback (ONLY Branch field is Dev Assessment hand-written line) still resolves
   - Bulleted and bare line-start fields inside Story Details parse

4. **End-to-end: poison session from 155-40 incident replay:**
   - The 155-40 test fixtures (SESSION_POISONED_WITH_PR, SESSION_POISONED_INCIDENT) must resolve to the REAL branch and PR, not poison prose
   - finish_story on the fixed parser must merge the correct PR, not a scraped number or a prose-derived garbage branch

## Implementation Notes

**Fence State Machine:**
- Add a `in_fence: bool = False` variable before the main loop
- On each line, check if it contains exactly a fenced-code-block marker (triplet backticks, optionally with language tag)
- If yes, toggle `in_fence` and SKIP field/section extraction for that line
- If not and `in_fence` is True, skip all field/section extraction
- If not and `in_fence` is False, proceed with normal extraction

**Story Details Authority:**
- After `section = line[3:].strip().lower()`, check: `if section == "story details" and detail_fields: continue` (or skip the section update)
- Or: add `seen_story_details: bool = False` before the loop; when `section == "story details"`, if `seen_story_details` is True, do NOT update `section`; else set `seen_story_details = True` and proceed
- Ensures only the first occurrence resets/populates `section`

**Test Sources:**
- Existing: `pennyfarthing/pennyfarthing-dist/src/pf/tests/test_155_40_session_field_parse_anchor.py` (all RED and Green guards)
- New or extended: TestFencedCodeBlocks, TestMultipleStoryDetails for the two new defects

## Subagent Results

> Specialist subagents waived per process instructions: diff is ~19 lines (single state-machine toggle + guard flag). All specialist domains were covered inline by Reviewer. Rows marked WAIVED reflect direct Reviewer analysis.

**All received:** Yes

| # | Specialist | Received | Status | Findings | Decision |
|---|-----------|---------|--------|----------|---------|
| 1 | reviewer-preflight | WAIVED | clean | 4/4 tests pass, lint clean | N/A |
| 2 | reviewer-edge-hunter | WAIVED | clean | ~~~-fences unhandled (LOW), unclosed-fence-at-EOF (LOW) — both non-blocking | Accepted |
| 3 | reviewer-silent-failure-hunter | WAIVED | clean | No new swallowed errors introduced; read_text can raise but pre-existing | N/A |
| 4 | reviewer-test-analyzer | WAIVED | clean | 3 RED tests pin the 3 defect scenarios; poison constants distinct from real; regression guard covers AC-3 | N/A |
| 5 | reviewer-comment-analyzer | WAIVED | clean | Inline comments accurate; docstring updated | N/A |
| 6 | reviewer-type-design | WAIVED | clean | Two bool flags — appropriate for local loop state; no type contract violations | N/A |
| 7 | reviewer-security | WAIVED | clean | Parser reads local session files; no injection surface introduced | N/A |
| 8 | reviewer-simplifier | WAIVED | clean | Minimal state (2 bools, 1 stripped-line check); no simpler correct alternative | N/A |
| 9 | reviewer-rule-checker | WAIVED | clean | encoding= present; .js extensions N/A; result objects N/A; no rule violations | N/A |

## Reviewer Assessment

**Verdict:** APPROVED

**Data flow traced:** session file line → `stripped = line.strip()` → fence toggle (line 170) → `if in_fence: continue` (line 173) → heading check (line 175) → `seen_story_details` guard (line 178) → `detail_fields.setdefault` (line 196) → authority overlay (lines 198-200). Safe because fence check fires before any field/heading extraction; `seen_story_details` prevents second Story Details from touching `detail_fields`.

**Pattern observed:** fence-state machine at `story_finish.py:164-174` — `stripped.startswith("```")` toggle with `continue` on fence lines, early-exit on `in_fence`. Clean, minimal state.

**Error handling:** `encoding="utf-8"` present on `read_text` (line 166); `session_path.exists()` guard (line 161); no new error paths introduced.

**Observations:**
1. [VERIFIED] [EDGE] Fence ordering correct — `if in_fence: continue` at line 173 precedes all heading/field logic; a fenced `## Story Details` cannot set `seen_story_details`.
2. [VERIFIED] [EDGE] First-wins correctness — when second Story Details is dropped, `section` retains its prior value; subsequent lines accumulate under that prior section, not `detail_fields`. Authority overlay is clean.
3. [VERIFIED] [EDGE] Language tags handled — `startswith("```")` is a prefix match; `\`\`\`python`, `\`\`\`yaml`, etc. all toggle correctly.
4. [LOW] [EDGE] `~~~` fence variant not handled — not a real risk; agent-generated sessions only emit backtick fences. Deferred.
5. [LOW] [SILENT] Unclosed fence at EOF silently drops subsequent lines — Story Details appears first in template so branch/pr are safe; Dev Assessment fallback fields could be lost. Not a regression from current behavior. Deferred.
6. [VERIFIED] [TEST] Tests genuine — poison constants meaningfully distinct from real values; assertions verify real values win, not just that a non-empty value is returned; regression guard covers AC-3.
7. [VERIFIED] [RULE] `encoding=` project rule satisfied at line 166.
8. [VERIFIED] [SEC] No injection surface: parser reads local session files only; `startswith` check on controlled input.
9. [VERIFIED] [SIMPLE] Minimal state addition: 2 bools (`in_fence`, `seen_story_details`); no over-engineering.
10. [VERIFIED] [DOC] Inline comments accurate and descriptive; docstring updated.
11. [VERIFIED] [TYPE] `in_fence: bool` and `seen_story_details: bool` are correct types for loop-local state flags.

**Handoff:** To SM for finish-story

## Delivery Findings

No upstream findings at this time.

### Reviewer (code review)
- **Gap** (non-blocking): `~~~` fence variant not handled. Affects `story_finish.py:_parse_session`. Agent sessions only emit backtick fences so no real risk; noted for completeness. *Found by Reviewer during code review.*
- **Gap** (non-blocking): Unclosed fence at EOF silently drops all subsequent lines — Dev Assessment fallback fields (155-33 recovery shape) would be lost with no indication. Not a regression; Story Details authority fields are unaffected given normal template order. *Found by Reviewer during code review.*

<!-- Agents: append findings below this line. Do not edit other agents' entries. -->

## Design Deviations

No deviations recorded yet.

<!-- Agents: append deviations below this line. Do not edit other agents' entries. -->

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing/pennyfarthing-dist/src/pf/sprint/story_finish.py` — added `in_fence` toggle and `seen_story_details` flag to `_parse_session`

**Tests:** 27/27 passing (GREEN) — 4 new (164-11) + 14 regression (155-40) + 9 other story_finish/parse_session
**Branch:** feat/164-11-harden-parse-session-section-tracker (pushed)
**Commit:** d57f3e88c

**Handoff:** To Reviewer

## TEA Assessment

**Tests Required:** Yes

**Test Files:**
- `pennyfarthing/pennyfarthing-dist/src/pf/tests/test_164_11_parse_session_fence_and_duplicate_section.py` — 4 tests covering Defects 1a, 1b, 2, and regression guard

**Tests Written:** 4 tests covering 3 ACs

| Test | Class | Status |
|------|-------|--------|
| `test_field_inside_fence_within_story_details_not_parsed` | TestFencedCodeBlocks | RED — fenced poison branch/PR win first-wins: got 'feat/164-11-poison-branch', expected 'feat/164-11-real-branch' |
| `test_story_details_heading_inside_fence_not_treated_as_section` | TestFencedCodeBlocks | RED — fenced `## Story Details` activates section, fenced fields land in detail_fields: got 'feat/164-11-poison-branch' |
| `test_second_story_details_authority_does_not_poison_fallback_pr` | TestMultipleStoryDetails | RED — second Story Details adds PR to detail_fields, authority overlay clobbers fallback: got '999', expected '300' |
| `test_normal_single_story_details_parse_unchanged` | TestSingleStoryDetailsRegression | GREEN — regression guard passes on HEAD |

**Status:** RED (3 failing, 1 green guard — ready for Dev)

**Commit:** de86933ce on `feat/164-11-harden-parse-session-section-tracker`

**Handoff:** To Dev for implementation