---
story_id: "135-1"
jira_key: "MSSCI-15781"
title: "Create sprint findings aggregation script"
epic_id: "135"
epic_title: "Sprint Findings Aggregation"
points: 2
priority: p2
status: in_progress
repos: "pennyfarthing"
workflow: "tdd"
phase: setup
branch: "feat/135-1-sprint-findings-aggregation"
assigned_to: "keith.avery@1898andco.io"
date_started: "2026-02-28"
---

# 135-1: Create sprint findings aggregation script

**Jira:** MSSCI-15781
**Epic:** 135 — Sprint Findings Aggregation
**Points:** 2
**Workflow:** tdd
**Phase:** finish
**Branch:** `feat/135-1-sprint-findings-aggregation` (from `develop` in pennyfarthing/)
**Repos:** pennyfarthing

---

## Epic Context

Epic 135 enables sprint retrospectives to surface cross-story patterns from aggregated findings. By collecting R1-format delivery findings from all archived sessions in a sprint, the retro agent can identify systemic issues — recurring gaps, common conflict patterns, frequently-affected paths — that individual story reviews would miss.

## Story Context

Story 135-1 creates the aggregation script that:
- Scans archived session files for a given sprint
- Parses `## Delivery Findings` sections using the existing `parse_delivery_findings()` from `pf.findings.capture`
- Aggregates findings across all stories into a sprint-level summary
- Groups by type, urgency, affected path, and agent
- Outputs a structured report suitable for retro consumption

### Technical Approach

The aggregation module lives at `pennyfarthing-dist/src/pf/findings/aggregate.py` alongside the existing findings modules. It reuses `parse_delivery_findings()` for parsing and adds cross-story grouping logic. A CLI command `pf sprint findings` exposes it.

## Acceptance Criteria

- [ ] Script reads all archived sessions for a specified sprint
- [ ] Parses R1-format findings from each session's `## Delivery Findings` section
- [ ] Aggregates findings with cross-story grouping (by type, path, agent)
- [ ] Identifies recurring patterns (same path/type across multiple stories)
- [ ] Outputs structured aggregation report (markdown + JSON modes)
- [ ] Handles sprints with zero findings gracefully
- [ ] Unit tests cover parsing, aggregation, and edge cases

## Workflow Tracking

**Workflow:** tdd
**Phase:** finish
**Phase Started:** 2026-02-28T07:10:49Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-02-28T06:50:04Z | 2026-02-28T06:52:18Z | 2m 14s |
| red | 2026-02-28T06:52:18Z | 2026-02-28T07:02:19Z | 10m 1s |
| green | 2026-02-28T07:02:19Z | 2026-02-28T07:06:38Z | 4m 19s |
| verify | 2026-02-28T07:06:38Z | 2026-02-28T07:09:01Z | 2m 23s |
| review | 2026-02-28T07:09:01Z | 2026-02-28T07:10:49Z | 1m 48s |
| finish | 2026-02-28T07:10:49Z | - | - |

## SM Assessment — Setup Phase

Story 135-1 claimed in Jira (MSSCI-15781), session file created, branch `feat/135-1-sprint-findings-aggregation` checked out from `develop` in pennyfarthing/. This story creates a sprint findings aggregation script at `pf/findings/aggregate.py` that reuses `parse_delivery_findings()` from `pf.findings.capture` to collect and group R1-format findings across all archived sessions for a sprint. CLI exposure via `pf sprint findings`. Handing to TEA for red phase — test design for aggregation logic, pattern detection, and output formatting.

---

## Delivery Findings

Agents record upstream observations discovered during their phase.
Each finding is one list item. Use "No upstream findings" if none.

**Types:** Gap, Conflict, Question, Improvement
**Urgency:** blocking, non-blocking

<!-- Agents: append findings below this line. Do not edit other agents' entries. -->

### TEA (test design)
- **Question** (non-blocking): Session file naming in archive uses Jira key (`MSSCI-XXXXX-session.md`) but story context references by story ID — Dev should ensure `collect_session_files()` maps between the two using sprint-completed YAML. Affects `pennyfarthing-dist/src/pf/findings/aggregate.py` (map jira_key → story_id from completed YAML entries). *Found by TEA during test design.*

### Dev (implementation)
- No upstream findings during implementation.

## Dev Assessment — Green Phase

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/src/pf/findings/aggregate.py` — full implementation of 4 functions

**Implementation Notes:**
- `collect_session_files()` — scans all `*-session.md` in archive dir, parses YAML frontmatter to extract `story_id`/`jira_key`, matches against `sprint-{YYWW}-completed.yaml`. Handles both Jira-key-named and ordinal-named session files.
- `aggregate_findings()` — reuses `parse_delivery_findings()` from capture module, filters out `type="none"` entries, injects `story_id`, groups into `by_type`/`by_path`/`by_agent` dicts.
- `detect_patterns()` — groups by `(path, type)` tuples, collects unique story_ids per group, filters for count ≥ 2.
- `format_report()` — markdown mode renders structured report with type/path sections and recurring patterns; JSON mode outputs machine-readable dict; unknown format returns error.

**Tests:** 27/27 passing (GREEN)
**Branch:** `feat/135-1-sprint-findings-aggregation` (pushed)

**Handoff:** To Cicero (Reviewer) for code review

## TEA Assessment — Red Phase

**Tests Required:** Yes
**Reason:** Core aggregation logic with multiple functions and data flows

**Test Files:**
- `tests/python/test_sprint_findings_aggregation.py` — 27 tests across 7 test classes

**Tests Written:** 27 tests covering all 7 ACs
- AC1: `TestCollectSessionFiles` (4 tests) — session discovery from sprint-completed YAML
- AC2: `TestAggregateFindings` (6 tests) — R1 parsing, story_id injection, no-findings handling
- AC3: `TestCrossStoryGrouping` (3 tests) — by type, path, and agent grouping
- AC4: `TestDetectPatterns` (4 tests) — recurring path+type detection, edge cases
- AC5: `TestFormatReport` (5 tests) — markdown/JSON output, blocking summary, patterns section
- AC6: `TestZeroFindings` (3 tests) — graceful zero-findings handling
- AC7: `TestEndToEnd` (2 tests) — full pipeline integration

**Status:** RED (27 failing — all on `NotImplementedError`, correct failure mode)

**Stub:** `pennyfarthing-dist/src/pf/findings/aggregate.py` — 4 functions with docstrings and `{success, data?, error?}` return signatures.

**Key Design Decisions:**
- `collect_session_files()` reads `sprint-{YYWW}-completed.yaml` for Jira key → story_id mapping, then locates `{JIRA_KEY}-session.md` files
- `aggregate_findings()` reuses `parse_delivery_findings()` from `pf.findings.capture`, adds `story_id` to each finding dict
- `detect_patterns()` groups by (path, type) tuples and filters for count ≥ 2
- `format_report()` supports "markdown" and "json" output formats

**Handoff:** To Lucius Vorenus (Dev) for implementation

## TEA Assessment — Verify Phase

**Tests:** 27/27 passing (GREEN confirmed)
**Verification:** All 7 ACs covered, implementation matches test expectations

**AC Coverage Verified:**
- AC1: Session discovery from sprint-completed YAML — 4 tests, all pass
- AC2: R1-format parsing with story_id injection — 6 tests, all pass
- AC3: Cross-story grouping by type/path/agent — 3 tests, all pass
- AC4: Recurring pattern detection (path+type ≥2 stories) — 4 tests, all pass
- AC5: Markdown and JSON output formatting — 5 tests, all pass
- AC6: Zero-findings graceful handling — 3 tests, all pass
- AC7: End-to-end pipeline integration — 2 tests, all pass

**Implementation Quality:**
- Follows `{success, data?, error?}` return pattern consistently
- Reuses `parse_delivery_findings()` from capture module — no duplication
- Proper `defaultdict` usage for grouping
- `_parse_frontmatter()` handles malformed YAML gracefully
- JSON serializer uses `default=str` for Path safety

**Handoff:** To Marcus Tullius Cicero (Reviewer) for code review

### TEA (test verification)
- No upstream findings during test verification.

### Reviewer (code review)
- No upstream findings during code review.

## Reviewer Assessment

**Verdict:** APPROVED

**Tests:** 27/27 passing (GREEN)
**Files Changed:** 2 (aggregate.py: 275 lines, test: 684 lines)

**Review Observations:**
| # | Severity | Finding | Location |
|---|----------|---------|----------|
| 1 | [VERIFIED] | Data flow traced: YAML → session discovery → parse → aggregate → detect → format | `aggregate.py` full pipeline |
| 2 | [VERIFIED] | `{success, data?, error?}` return pattern on all 4 public functions | `aggregate.py:33,85,140,181` |
| 3 | [VERIFIED] | `yaml.safe_load` everywhere — no code execution risk | `aggregate.py:34,63` |
| 4 | [VERIFIED] | `json.dumps(default=str)` handles Path objects safely | `aggregate.py:278` |
| 5 | [VERIFIED] | Error handling covers missing files, empty inputs, invalid formats | `aggregate.py:53,65,197` |
| 6 | [LOW] | In-place mutation of parsed finding dicts — safe but latent | `aggregate.py:118` |
| 7 | [LOW] | Silent skip on invalid frontmatter — no logging | `aggregate.py:72-73` |

**Pattern observed:** Clean separation of concerns — four focused functions with single responsibilities, each returning result objects. Good reuse of `parse_delivery_findings()` from capture module. Consistent with framework conventions.

**Error handling:** Missing sprint file → error result. Empty sessions → zero findings. Invalid format → error result. Malformed YAML → skip and continue.

**Handoff:** To Titus Pullo (SM) for finish-story