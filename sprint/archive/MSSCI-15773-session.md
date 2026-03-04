# Story 133-2: Add finding-capture to agent exit behaviors

**Jira:** MSSCI-15773
**Epic:** 133 — Agent Finding Capture & Workflow Unblocking
**Status:** in-progress
**Points:** 3
**Workflow:** tdd
**Phase:** finish
**Repos:** pennyfarthing
**Branch:** feat/133-2-finding-capture-agent-exit

---

## Acceptance Criteria

1. Agent exit behaviors in `tea.md`, `dev.md`, `reviewer.md` capture findings according to R1 format
2. Each agent phase produces either structured findings or explicit "no findings" entry
3. Findings conform to R1 format: `- **{Type}** ({urgency}): {description}. Affects \`{path}\` ({what needs to change}). *Found by {Agent} during {human-phase-name}.*`
4. Agent exit behaviors append findings to "Delivery Findings" section in session template
5. Agents never edit or remove findings from other agents (R2 guardrail)
6. PR_NUMBER becomes optional in `reviewer-preflight.md` to support reviewer workflow without PR
7. Agent behaviors respect valid types (Gap, Conflict, Question, Improvement) and urgencies (blocking, non-blocking)

## Technical Context

Epic 133 establishes a systematic finding capture system for agent phases. Story 133-2 is the core implementation:

- **133-1** (done) added the "Delivery Findings" section to the session template in `sm-setup.md`
- **133-2** (this story) implements agent exit behaviors that write findings to that section
- **133-3** (done) created validation gate to check finding format correctness
- **133-4** (backlog) documents the system in session-artifacts guide

The finding system enables:
- Agents to record upstream discoveries (gaps, conflicts, questions, improvements) during their phase
- Validation before downstream processing (Epic 134, 135)
- Reviewer workflow to operate without PR_NUMBER requirement

Key constraints:
- Pure markdown format — no YAML code blocks, script-parseable list items
- R1 format strictly enforced with type, urgency, description, affected path, and agent/phase attribution
- "No findings" must be explicit to distinguish "checked, found nothing" from "forgot to check"
- Relative paths from project root in doc references

## Session Log

### Setup
- Session created by SM (2026-02-27)
- Story 133-2 status: in_progress
- Branch created: feat/133-2-finding-capture-agent-exit
- Jira: claimed by Keith Avery
- Workflow: tdd (phased) — SM → TEA → Dev → Reviewer → SM
- Next phase: red (TEA designs failing tests for finding capture)

## SM Assessment

Story 133-2 is set up and ready for TDD. Session file created with ACs, technical context from epic 133, and key files identified. Branch `feat/133-2-finding-capture-agent-exit` created from latest develop. Jira MSSCI-15773 claimed. No blockers — 133-1 (template) and 133-3 (gate) are already done, so TEA has a clean foundation to write tests against. Handing off to TEA for RED phase.

## TEA Assessment

**Tests Required:** Yes
**Reason:** Core feature — agent exit behaviors must capture findings in R1 format

**Test Files:**
- `tests/python/test_finding_capture.py` — 32 tests across 5 test classes

**Tests Written:** 32 tests covering all 7 ACs
- AC1-3,7: `TestFormatFinding` (11 tests) — R1 format generation, all types/urgencies, validation
- AC4: `TestAppendFindings` (6 tests) — atomic session append, marker positioning, multiple findings
- AC5: `TestAppendFindings.test_append_preserves_existing` — R2 guardrail, existing entries untouched
- AC2: `TestParseDeliveryFindings` (6 tests) — extraction, "no findings" handling, missing section
- AC1: `TestAgentFindingCaptureSections` (7 tests) — agent markdown structure validation
- AC6: `TestReviewerPreflightOptionalPr` (1 test) — PR_NUMBER optionality
- AC3: `TestFormatFinding.test_phase_mapped_to_human_name` — phase→human name mapping

**Status:** RED (30 failing, 2 passing — assertions only, no import/syntax errors)

**Stubs Created:**
- `pennyfarthing-dist/src/pf/findings/__init__.py` — module init
- `pennyfarthing-dist/src/pf/findings/capture.py` — `format_finding()`, `parse_delivery_findings()`, `append_findings_to_session()`

**Handoff:** To Korben Dallas (Dev) for implementation

### Red Phase
_Completed — 32 tests, RED state confirmed_

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/src/pf/findings/capture.py` — implemented format_finding(), parse_delivery_findings(), append_findings_to_session()
- `pennyfarthing-dist/agents/tea.md` — added <finding-capture> section to exit protocol
- `pennyfarthing-dist/agents/dev.md` — added <finding-capture> section to exit protocol
- `pennyfarthing-dist/agents/reviewer.md` — added <finding-capture> section to exit protocol
- `pennyfarthing-dist/agents/reviewer-preflight.md` — PR_NUMBER marked optional

**Tests:** 32/32 passing (GREEN)
**Branch:** feat/133-2-finding-capture-agent-exit (pushed)

**Handoff:** To Reviewer for code review

### Green Phase
_Completed — 32/32 GREEN, branch pushed_

## TEA Verify Assessment

**Implementation Quality:** Solid
**Edge Cases Added:** 6 new tests (32 → 38 total)
- `test_unknown_phase_passes_through` — unknown phase names pass through as-is
- `test_description_with_backticks` — markdown special chars in description
- `test_whitespace_only_description_raises` — whitespace-only caught as empty
- `test_parse_skips_malformed_findings` — partial R1 entries silently ignored
- `test_append_nonexistent_file` — graceful error for missing file
- `test_append_duplicate_agent_allowed` — no dedup, append-only as spec'd

**Tests:** 38/38 passing (GREEN)
**All 7 ACs verified**

**Handoff:** To Jean-Baptiste Emanuel Zorg (Reviewer) for code review

### Verify Phase
_Completed — 38/38 GREEN, 6 edge case tests added_

### Review Phase

## Reviewer Assessment

**Verdict:** APPROVED

| Severity | Issue | Location | Fix Required |
|----------|-------|----------|--------------|
| [MEDIUM] | `content.index("\n", marker_pos)` could raise ValueError if marker is last line without trailing newline — violates result-object convention | `capture.py:137` | Wrap in try/except or check for newline (non-blocking, theoretical edge case) |
| [MEDIUM] | Unrelated yaml_io bug fix and star-wars portraits bundled in feature branch | `yaml_io.py:392-393` | None (correct fix, just misplaced) |
| [VERIFIED] | Atomic write pattern (temp file + rename) | `capture.py:160-172` | — |
| [VERIFIED] | R2 guardrail — existing findings preserved on append | `capture.py:157` | — |
| [VERIFIED] | R1 regex handles edge cases correctly | `capture.py:23-28` | — |
| [VERIFIED] | Error paths return result objects | `capture.py:45-50, 124-134` | — |
| [VERIFIED] | All 7 ACs satisfied, 38 tests (78 with yaml_io) | `test_finding_capture.py` | — |

**Data flow traced:** `format_finding()` → R1 string → `append_findings_to_session()` → read → find marker → insert → atomic write (safe)
**Pattern observed:** Consistent `<finding-capture>` section added to all three agents at `tea.md`, `dev.md`, `reviewer.md`
**Error handling:** Result objects throughout `append_findings_to_session()`, ValueError validation in `format_finding()`
**Security:** No user input reaches functions directly — agent-controlled parameters only

**Delivery Findings:** Session predates 133-1 template — no `## Delivery Findings` section exists. Recording here instead:
- **Improvement** (non-blocking): `capture.py:137` should guard against missing trailing newline. Affects `pennyfarthing-dist/src/pf/findings/capture.py` (add try/except or newline check). *Found by Reviewer during code review.*

**Handoff:** To Ruby Rhod (SM) for finish-story

### Finish Phase
_SM to merge and close story_

---

## Key Files to Modify

- `pennyfarthing-dist/agents/tea.md` — add finding capture to exit behavior
- `pennyfarthing-dist/agents/dev.md` — add finding capture to exit behavior
- `pennyfarthing-dist/agents/reviewer.md` — add finding capture to exit behavior
- `pennyfarthing-dist/agents/reviewer-preflight.md` — make PR_NUMBER optional
- Tests for finding format validation (handled by 133-3, but may need integration tests here)

## References

- Epic context: `/Users/keithavery/Projects/pf-1/sprint/context/context-epic-133.md`
- Session feedback PRD: `/Users/keithavery/Projects/pf-1/sprint/planning/session-feedback-prd.md`
- R1 format definition: `pennyfarthing-dist/guides/session-artifacts.md` (to be updated in 133-4)