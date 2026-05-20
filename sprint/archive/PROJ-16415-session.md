---
story_id: "147-4"
jira_key: "PROJ-16415"
epic: "PROJ-16411"
workflow: "tdd"
---
# Story 147-4: Create RepoFieldSpec registry in repos_meta.py

## Story Details
- **ID:** 147-4
- **Jira Key:** PROJ-16415
- **Workflow:** tdd
- **Stack Parent:** none

## Workflow Tracking
**Workflow:** tdd
**Phase:** finish
**Phase Started:** 2026-03-13T20:02:57Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-03-13T00:00:00Z | 2026-03-13T19:50:14Z | 19h 50m |
| red | 2026-03-13T19:50:14Z | 2026-03-13T19:55:16Z | 5m 2s |
| green | 2026-03-13T19:55:16Z | 2026-03-13T19:56:57Z | 1m 41s |
| spec-check | 2026-03-13T19:56:57Z | 2026-03-13T19:57:47Z | 50s |
| verify | 2026-03-13T19:57:47Z | 2026-03-13T19:59:24Z | 1m 37s |
| review | 2026-03-13T19:59:24Z | 2026-03-13T20:02:12Z | 2m 48s |
| spec-reconcile | 2026-03-13T20:02:12Z | 2026-03-13T20:02:57Z | 45s |
| finish | 2026-03-13T20:02:57Z | - | - |

## Delivery Findings

Agents record upstream observations discovered during their phase.
Each finding is one list item. Use "No upstream findings" if none.

**Types:** Gap, Conflict, Question, Improvement
**Urgency:** blocking, non-blocking

<!-- Agents: append findings below this line. Do not edit other agents' entries. -->

### TEA (test design)
- **Gap** (non-blocking): `symlinks` field is in `repos.yaml` per-repo data but not parsed into `RepoConfig` dataclass in `repos.py`. AC-5 requires a `symlinks` readonly spec. Dev will need to either add `symlinks` to `RepoConfig` or handle it via `load_repos_yaml_raw()`. Affects `pennyfarthing-dist/src/pf/git/repos.py` (may need symlinks field added). *Found by TEA during test design.*

### Dev (implementation)
- No upstream findings during implementation.

### TEA (test verification)
- No upstream findings during test verification.

### Reviewer (code review)
- No upstream findings during code review.

## Design Deviations

Agents log spec deviations as they happen — not after the fact.
Each entry: what was changed, what the spec said, and why.

<!-- Agents: append deviations below this line. Do not edit other agents' entries. -->

### TEA (test design)
- No deviations from spec.

### Dev (implementation)
- No deviations from spec.

### Reviewer (audit)
- TEA: "No deviations from spec." → ✓ ACCEPTED by Reviewer: agrees, no spec drift in test design
- Dev: "No deviations from spec." → ✓ ACCEPTED by Reviewer: implementation matches AC-5 table exactly, follows settings_meta.py pattern

### Architect (reconcile)
- No additional deviations found.

## Subagent Results

| # | Specialist | Received | Status | Findings | Decision |
|---|-----------|----------|--------|----------|----------|
| 1 | reviewer-preflight | Yes | clean | none | N/A |
| 2 | reviewer-edge-hunter | Yes | findings | 5 | dismissed 5 — all suggest __post_init__ validation absent from parallel SettingSpec; consistent pattern, not a defect |
| 3 | reviewer-silent-failure-hunter | Yes | clean | none | N/A |
| 4 | reviewer-test-analyzer | Yes | findings | 21 | dismissed 21 — tautological/copy-paste findings are style preferences; TEA chose individual tests for AC traceability |
| 5 | reviewer-comment-analyzer | Yes | clean | none | N/A |
| 6 | reviewer-type-design | Yes | findings | 4 | dismissed 4 — stringly-typed widget_type matches SettingSpec pattern; Literal improvement is out of scope |
| 7 | reviewer-security | Yes | clean | none | N/A |
| 8 | reviewer-simplifier | Yes | findings | 3 | dismissed 3 — build function required by AC-4; GLOBAL_REPO_FIELDS required by AC-6; dual data structures serve different access patterns |

**All received:** Yes
**Total findings:** 0 confirmed, 33 dismissed (with rationale), 0 deferred

## Reviewer Assessment

**Verdict:** APPROVED

**Observations:**
1. [VERIFIED] Pattern compliance: `repos_meta.py` mirrors `settings_meta.py` structure exactly — dataclass, `_SPECS` list, dict built via loop, builder function. Consistent at `repos_meta.py:28-159` vs `settings_meta.py:50-201`.
2. [VERIFIED] Data flow: `_SPECS` list → `REPO_FIELDS_META` dict (line 158-159) → `build_repo_field_specs()` returns shallow copy (line 171). No mutation risk to source data.
3. [VERIFIED] All 14 AC-5 fields present with correct widget types, groups, options, and read-only flags.
4. [VERIFIED] Error handling: N/A — pure data registry with no I/O, no error paths. Appropriate for the domain.
5. [VERIFIED] Security: No user input, no dynamic execution, no network. Zero attack surface.
6. [LOW] [TEST] Two loop-based tests (`test_input_fields_have_no_options`, `test_switch_fields_have_no_options`) could execute zero assertions if no matching widget types exist. Non-blocking — the registry is static and these types demonstrably exist.
7. [TYPE] `widget_type` as bare `str` rather than `Literal` — consistent with `SettingSpec`. Improvement deferred to a cross-cutting story if needed.

**Handoff:** To the Mad Hatter (SM) for finish-story

## Architect Assessment (spec-check)

**Spec Alignment:** Aligned
**Mismatches Found:** None

All 6 ACs verified against implementation:
- AC-1: File exists at `pennyfarthing-dist/src/pf/bikerack/repos_meta.py`
- AC-2: `RepoFieldSpec` dataclass has all 7 fields with correct types and defaults
- AC-3: `REPO_FIELDS_META` dict populated with 14 field specs, keys match `.field`
- AC-4: `build_repo_field_specs()` returns ordered list with contiguous groups
- AC-5: All 14 fields have correct widget types, groups, options, and read-only flags per spec table
- AC-6: `GLOBAL_REPO_FIELDS` contains `pr_title_format` and `build_order`

**Note on TEA finding (symlinks):** `symlinks` is in `repos.yaml` but not in `RepoConfig`. This is acceptable — the registry defines UI specs, and `symlinks` data can be sourced from `load_repos_yaml_raw()` when ReposPanel (147-5) renders it. No action needed for this story.

**Decision:** Proceed to verify

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/src/pf/bikerack/repos_meta.py` - Populated RepoFieldSpec registry with 14 field specs, GLOBAL_REPO_FIELDS, and build_repo_field_specs()

**Tests:** 83/83 passing (GREEN)
**Branch:** feat/147-4-repo-field-spec-registry (pushed)

**Handoff:** To the Caterpillar (TEA) for verify phase

## TEA Assessment (verify)

**Phase:** finish
**Status:** GREEN confirmed

### Simplify Report

**Teammates:** reuse, quality, efficiency
**Files Analyzed:** 2

| Teammate | Status | Findings |
|----------|--------|----------|
| simplify-reuse | 5 findings | 4 high (test parametrization — dismissed: intentional verbosity for AC traceability), 1 medium (shared base class — dismissed: premature abstraction for 2 instances) |
| simplify-quality | clean | No issues found |
| simplify-efficiency | clean | No issues found |

**Applied:** 0 high-confidence fixes
**Flagged for Review:** 0 medium-confidence findings
**Noted:** 0 low-confidence observations
**Reverted:** 0

**Overall:** simplify: clean (all findings dismissed with rationale)

**Quality Checks:** 83/83 tests passing
**Handoff:** To the Queen of Hearts (Reviewer) for code review

## SM Assessment

**Story:** 147-4 — Create RepoFieldSpec registry in repos_meta.py
**Workflow:** tdd (2pt, standard TDD flow)
**Routing:** SM → TEA → Dev → Reviewer

**Context:** Create a typed registry for repo field specifications, similar to the existing SettingSpec pattern in settings_meta.py. This enables BikeRack TUI to render repo settings with proper widgets.

**Handoff:** To the Caterpillar (TEA) for RED phase — write failing tests.