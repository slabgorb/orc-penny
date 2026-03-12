# Story 47-2: Write concern manifest and AC manifest for dpgd-116

**Jira:** MSSCI-16295
**Workflow:** trivial
**Phase:** finish
**Repos:** orchestrator
**Branch:** main

## Acceptance Criteria
- [ ] Concern manifest with 8-12 concerns mapped to findings
- [ ] AC manifest with 6-10 acceptance criteria mapped to findings
- [ ] Both written as YAML to `internal/results/manifests/dpgd-116-concern-manifest.yaml` and `dpgd-116-ac-manifest.yaml`
- [ ] Coverage: every finding maps to at least one concern and one AC
- [ ] Manifests are scenario-aware but defect-blind (a PM wouldn't know the seeded issues)

## Context
Create ground truth reference documents for dpgd-116 scenario. The concern manifest captures what a good PM/Architect should flag (error handling, security surface, etc.). The AC manifest captures what acceptance criteria should cover. Both serve as scoring rubrics for stories 47-3 through 47-5.

Key data: `internal/results/pipeline-replay/dpgd-116/control/run-6/score.yaml` has ground truth findings (7 defects). Full context at `sprint/context/context-story-47-2.md`.

## SM Assessment
Trivial 2-pointer. Context doc is thorough — Toby has clear YAML format examples and output paths. Straight to Dev.

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `internal/results/manifests/dpgd-116-concern-manifest.yaml` - 10 concerns mapped to all 7 findings, prioritized by severity
- `internal/results/manifests/dpgd-116-ac-manifest.yaml` - 8 acceptance criteria with full finding coverage and inline coverage verification

**Tests:** N/A (data files, no executable code)
**Branch:** main (not pushed — trivial workflow, orchestrator repo)

**Handoff:** To review phase

## Delivery Findings

<!-- delivery-findings-start -->
### Dev (implementation)
- No upstream findings during implementation.
### Reviewer (code review)
- No upstream findings during code review.
<!-- delivery-findings-end -->

## Reviewer Assessment

**Verdict:** APPROVED

**Observations:**
1. `[VERIFIED]` Coverage: all 7 findings (C1, I1-I6) map to at least one concern and one AC — verified by tracing each finding ID across both manifests
2. `[VERIFIED]` Count: 10 concerns (8-12 range), 8 ACs (6-10 range) — within spec
3. `[VERIFIED]` YAML validity: both files parse cleanly with `yaml.safe_load()`
4. `[VERIFIED]` File paths match spec: `internal/results/manifests/dpgd-116-{concern,ac}-manifest.yaml`
5. `[VERIFIED]` Defect-blindness: concerns are phrased as natural PM/Architect questions about a SIEM client codebase, not reverse-engineered from specific defect descriptions
6. `[MEDIUM]` Minor overlap between config-field-validation and config-secret-lifecycle concerns — both address config silently accepting credential-like fields. Acceptable for rubric granularity but downstream scoring should account for partial overlap.
7. `[VERIFIED]` Schema consistency: both files use scenario_id, manifest_type, version metadata. Concern items have area/description/related_findings/priority. AC items have id/text/related_findings.

**Handoff:** To SM (Leo McGarry) for finish-story