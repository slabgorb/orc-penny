---
story_id: "150-22"
jira_key: null
epic: "MSSCI-16564"
workflow: "trivial"
---
# Story 150-22: Replace MSSCI test fixtures with generic project key (PROJ/DEMO)

## Story Details
- **ID:** 150-22
- **Jira Key:** None (no external Jira issue)
- **Epic:** MSSCI-16564
- **Workflow:** trivial
- **Stack Parent:** none

## Workflow Tracking
**Workflow:** trivial
**Phase:** finish
**Phase Started:** 2026-04-03T12:58:02Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-04-03T00:00:00Z | 2026-04-03T12:54:21Z | 12h 54m |
| implement | 2026-04-03T12:54:21Z | 2026-04-03T12:56:12Z | 1m 51s |
| review | 2026-04-03T12:56:12Z | 2026-04-03T12:58:02Z | 1m 50s |
| finish | 2026-04-03T12:58:02Z | - | - |

## Delivery Findings

Agents record upstream observations discovered during their phase.
Each finding is one list item. Use "No upstream findings" if none.

**Types:** Gap, Conflict, Question, Improvement
**Urgency:** blocking, non-blocking

<!-- Agents: append findings below this line. Do not edit other agents' entries. -->

### Dev (implementation)
- No upstream findings during implementation.

### Reviewer (code review)
- No upstream findings during code review.

## Design Deviations

Agents log spec deviations as they happen — not after the fact.
Each entry: what was changed, what the spec said, and why.

<!-- Agents: append deviations below this line. Do not edit other agents' entries. -->

### Dev (implementation)
- No deviations from spec.

### Reviewer (audit)
- No undocumented deviations found.

## Subagent Results

| # | Specialist | Received | Status | Findings | Decision |
|---|-----------|----------|--------|----------|----------|
| 1 | reviewer-preflight | Yes | clean | none | N/A |
| 2 | reviewer-edge-hunter | Yes | Skipped | disabled | N/A |
| 3 | reviewer-silent-failure-hunter | Yes | Skipped | disabled | N/A |
| 4 | reviewer-test-analyzer | Yes | Skipped | disabled | N/A |
| 5 | reviewer-comment-analyzer | Yes | Skipped | disabled | N/A |
| 6 | reviewer-type-design | Yes | Skipped | disabled | N/A |
| 7 | reviewer-security | Yes | clean | none | N/A |
| 8 | reviewer-simplifier | Yes | Skipped | disabled | N/A |
| 9 | reviewer-rule-checker | Yes | Skipped | disabled | N/A |

**All received:** Yes (2 enabled returned clean, 7 disabled/skipped)
**Total findings:** 0 confirmed, 0 dismissed, 0 deferred

## Reviewer Assessment

**Verdict:** APPROVED

### Observations

1. [VERIFIED] All 9 MSSCI-999xx references replaced with PROJ-999xx — confirmed by grep: zero MSSCI references remain in `pennyfarthing-dist/src/pf/tests/`.

2. [VERIFIED] Replacement is consistent across all contexts — YAML fixture data (lines 48, 55, 62, 69), session fixture frontmatter (lines 82, 118), session fixture markdown (lines 92, 128), and inline comment (line 298). All use PROJ prefix.

3. [VERIFIED] URL in fixture updated correctly — `[PROJ-99902](https://jira.example.com/browse/PROJ-99902)` at line 128. Both display text and href updated.

4. [VERIFIED] 9/9 tests pass — no test depends on the MSSCI prefix specifically. Tests assert on story IDs (200-1, 200-2) and status transitions, not Jira key prefixes.

5. [VERIFIED] No production code modified — change is confined to test fixtures only.

6. [SEC] Security subagent: clean. No security surface in test fixture string replacements.

### Data Flow Trace
Fixture strings → YAML parser in `read_sprint()` → test assertions on status/story_id. The Jira key prefix is opaque to the test logic — it's stored and retrieved but never pattern-matched against MSSCI specifically.

### Error Handling
N/A — no new error paths introduced. Pure string replacement.

### Rule Compliance
- SOUL #2 (One truth): N/A — test fixtures, not definitions
- SOUL #10 (Return results): N/A — no functions modified

### Devil's Advocate

What if this is broken? The only credible risk: some production code pattern-matches on `MSSCI-` prefix specifically (e.g., a regex for Jira key validation). If so, changing fixtures to `PROJ-` could cause tests to exercise a different code path.

Checked: `transition_story()` and `finish_story()` treat `jira_key` as an opaque string — they pass it to the Jira client which is mocked in all tests. The key prefix has no load-bearing significance. The tests assert on transition behavior, not key format. The `jira.example.com` URL in the fixture is display-only markdown, not parsed.

No hidden bombs.

**Handoff:** To SM (the Mad Hatter) for finish-story

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/src/pf/tests/test_147_12_finish_backlog_bridge.py` — replaced 9 MSSCI-999xx fixture keys with PROJ-999xx

**Tests:** 9/9 passing (GREEN)
**Branch:** feat/150-22-replace-mssci-test-fixtures-generic-ids (pushed)

**Handoff:** To Reviewer (the Queen of Hearts) for code review

## Sm Assessment

**Story 150-22** — Replace MSSCI test fixtures with generic project keys (PROJ/DEMO). Trivial 2-point cleanup story. Straight to Dev.

**Routing:** Trivial workflow → Dev (the White Rabbit) for implement phase.