---
story_id: "148-29"
jira_key: "MSSCI-16421"
epic: "MSSCI-16421"
workflow: "trivial"
---

# Story 148-29: Bug: Peloton skill recurses when invoked from consumer projects

## Story Details

- **ID:** 148-29
- **Jira Key:** MSSCI-16421
- **Epic:** MSSCI-16421
- **Workflow:** trivial
- **Stack Parent:** none
- **Points:** 1

## Workflow Tracking

**Workflow:** trivial
**Phase:** finish
**Phase Started:** 2026-03-23T09:59:51Z

### Phase History

| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-03-23 | 2026-03-23T09:47:49Z | 9h 47m |
| implement | 2026-03-23T09:47:49Z | 2026-03-23T09:51:28Z | 3m 39s |
| review | 2026-03-23T09:51:28Z | 2026-03-23T09:59:51Z | 8m 23s |
| finish | 2026-03-23T09:59:51Z | - | - |

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

## Impact Summary

**Upstream Effects:** No upstream effects noted
**Blocking:** None

## Design Deviations

Agents log spec deviations as they happen — not after the fact.
Each entry: what was changed, what the spec said, and why.

<!-- Agents: append deviations below this line. Do not edit other agents' entries. -->

### Dev (implementation)
- No deviations from spec.

### Reviewer (audit)
- No undocumented deviations found.

## Sm Assessment

**Story:** 148-29 — Bug: Peloton skill recurses when invoked from consumer projects
**Workflow:** trivial (phased) → implement phase routes to Dev
**Branch:** `feat/148-29-peloton-skill-recursion-fix` on pennyfarthing repo (targets develop)
**Jira:** MSSCI-16421

### Bug Report
Consumer projects report the Peloton skill recurses when invoked. Investigate the skill definition at `pennyfarthing-dist/skills/pf-peloton.*` for recursive invocation patterns — likely the skill calls itself or triggers a loop through agent/skill dispatch.

### Routing
1-point trivial bug → Dev implements fix directly, then Reviewer reviews.

**Handoff to:** Dev (the White Rabbit) for implement phase

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/skills/pf-peloton/peloton.md` — Replaced 3 subcommand `<run>` blocks (lines 25, 42, 52) with markdown code blocks. The peloton skill was the only skill with multiple `<run>` tags — the skill system executes each `<run>` block it encounters, causing the agent to loop through start/start/status/stop in sequence. Now only the top-level `<run>` (line 15: `pf peloton start`) remains executable.

**Tests:** N/A — skill definition change, no Python tests to run
**Branch:** feat/148-29-peloton-skill-recursion-fix (pushed)

**Handoff:** To the Queen of Hearts (Reviewer) for review

## Subagent Results

| # | Specialist | Received | Status | Findings | Decision |
|---|-----------|----------|--------|----------|----------|
| 1 | reviewer-preflight | Yes | clean | none (102 pre-existing frame_routes failures unrelated) | N/A |
| 2 | reviewer-edge-hunter | Skipped | disabled | N/A | Disabled via settings |
| 3 | reviewer-silent-failure-hunter | Skipped | disabled | N/A | Disabled via settings |
| 4 | reviewer-test-analyzer | Skipped | disabled | N/A | Disabled via settings |
| 5 | reviewer-comment-analyzer | Skipped | disabled | N/A | Disabled via settings |
| 6 | reviewer-type-design | Skipped | disabled | N/A | Disabled via settings |
| 7 | reviewer-security | Skipped | disabled | N/A | Disabled via settings — markdown-only change, no code |
| 8 | reviewer-simplifier | Skipped | disabled | N/A | Disabled via settings |
| 9 | reviewer-rule-checker | Skipped | disabled | N/A | Disabled via settings |

**All received:** Yes (1 returned, 1 disabled overridden to skip for markdown-only, 7 disabled via settings)
**Total findings:** 0 confirmed, 0 dismissed, 0 deferred

## Reviewer Assessment

**Verdict:** APPROVED

1. [VERIFIED] Top-level `<run>` block preserved — `peloton.md:15-17` still has `<run>pf peloton start</run>`, the one executable block that should fire on `/pf-peloton` invocation.

2. [VERIFIED] All three subcommand `<run>` blocks replaced with ` ```bash ` code blocks — diff shows `-<run>` → `+```bash` at lines 25, 42, 52. Content within blocks is verbatim unchanged.

3. [VERIFIED] pf-peloton was the only skill with multiple `<run>` blocks — [EDGE] grep of all skills showed 4 occurrences in peloton vs 1 in every other skill. Root cause confirmed.

4. [VERIFIED] No other files changed — diff is scoped to exactly one file, `pennyfarthing-dist/skills/pf-peloton/peloton.md`. [SIMPLE] Minimal fix, no scope creep.

5. [VERIFIED] No test regressions — 3933 passed, 102 failed are all pre-existing `test_frame_routes.py` failures. [TEST] No peloton-related tests exist (skill is a markdown definition, not code). [DOC] Documentation content preserved. [TYPE] N/A — no code. [SEC] N/A — no code execution changes. [SILENT] N/A — no error handling paths in markdown. [RULE] N/A — no Python/code rules apply to markdown.

**Data flow traced:** User invokes `/pf-peloton` → skill system reads `peloton.md` → finds single `<run>` block → executes `pf peloton start` → CLI outputs TeamCreate prompt. Previously: skill system found 4 `<run>` blocks → executed all sequentially → recursion/loop.

**Pattern observed:** Good — consistent with all other skills (one `<run>` block per skill file).

**Error handling:** N/A — markdown change only.

**Handoff:** To the Mad Hatter (SM) for finish-story