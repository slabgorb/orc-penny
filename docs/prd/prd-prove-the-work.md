# PRD: Prove the Work — Measurably Better PR Quality

**Status:** Draft
**Principle:** SOUL.md #14 — Prove the Work
**Date:** 2026-03-16

## Problem Statement

Our TDD pipeline (TEA → Dev → Reviewer) produces PRs that require extensive external review follow-up. The external reviewer (stakeholder) runs reviewer subagents on every PR (~30 min) and consistently finds 10-12 issues per PR. Additionally, the reviewer must do manual follow-up work to understand what was done, why decisions were made, and what downstream effects exist.

**Evidence:**
- PR #50 (Story 5.1): External reviewer ran `check-drift` 6 times, producing 58 drift findings across 10+ follow-up commits. The pipeline APPROVED the PR internally, then the external reviewer found pervasive spec drift.
- PR #55 (Story 5.2): Similar pattern — multiple follow-up commits to understand and fix issues.
- DPGD-116 benchmark: Pipeline detects 54% of known ground-truth findings (4/7). Three findings are missed >70% of the time.

**Impact:** Team distrust of the tooling. The pipeline is supposed to catch issues before external review — instead it creates more work.

## Success Criteria

| Metric | Current | Target | How Measured |
|--------|---------|--------|-------------|
| Findings per PR (external reviewer) | 10-12 | 1-2 | Count from reviewer subagent output |
| DPGD-116 detection rate | 54% | >80% | Pipeline replay benchmark |
| Follow-up commits by reviewer | 5-10 per PR | 0-1 | Git log on PR branch after review |
| Spec drift findings | 30-60 per PR | <5 | check-drift output |
| Reviewer time per PR | ~30 min | <10 min | Stakeholder feedback |

## Two Axes

### Axis 1: Catch More, Catch Earlier

**Goal:** The pipeline catches issues BEFORE the external reviewer sees the PR.

**Current gaps (from DPGD-116 benchmark data, 96 runs):**

| Category | Detection Rate | Root Cause |
|----------|---------------|-----------|
| Error handling discrimination (C1) | 15% | Scouts run pre-Dev; miss patterns Dev introduces |
| Build config hygiene (I3) | 21% | Scouts only scan `*.rs`, not `Cargo.toml` |
| Test quality (I5, I6) | 30-47% | TEA writes weak tests, nobody catches them |
| Serde/config safety (I4) | 86% | Reviewer occasionally reasons itself out of flagging |
| Security (I1, I2) | 95-100% | Working well |

**Approach:**
1. Post-Dev scout pass — catch patterns Dev introduces (already built, needs tuning)
2. Expanded file coverage — scouts see build config files (already built)
3. TEA test validator — catch weak tests before Dev makes them pass (already built)
4. Reviewer bias correction — NOT via more checklist items (run-28 proved this backfires: reviewer fabricates answers to checklist items). Need a different mechanism.

**Key learning from run-28:** Adding checklist items to the reviewer prompt gives the model more opportunities to be confidently wrong. The reviewer hallucinated "All deps use { workspace = true }" as a VERIFIED when it was false. Checklist inflation is counterproductive. The approach must change the reviewer's reasoning, not add more boxes to check.

### Axis 2: Explain the Work

**Goal:** The PR description and session artifacts tell the full story so the external reviewer understands without reverse-engineering.

**Current gaps:**
- Dev Assessment lists files changed but not WHY decisions were made
- Spec deviations are logged but not explained with enough context for outsiders
- Downstream effects on sibling stories are mentioned but not traced
- PR body is a summary, not a narrative the reviewer can follow
- No mapping from "what the spec said" to "what we actually built" to "why the delta exists"

**Approach:**
1. **Impact Summary** — SM finish phase already compiles delivery findings into an impact summary. Enhance this to include: downstream story effects, spec deviation justification, and a "what the reviewer should focus on" section.
2. **PR body template** — Generate PR descriptions from session artifacts that tell the full story: what was built, what deviated from spec, what downstream stories are affected, and what the reviewer should pay attention to.
3. **Spec drift pre-check** — Run a lightweight `check-drift` equivalent BEFORE the PR is created, as part of the Reviewer or Architect phase. Catch drift internally so external reviewer finds <5 items.
4. **Deviation traceability** — Every deviation links back to the spec source with quoted text, the implementation choice, and the forward impact. The Architect reconcile phase already does this — make it more rigorous and surface it in the PR body.

## Epics

### Epic 149: Detection Gap Closure (Axis 1)
Already created. Stories need revision based on run-28 learnings:
- Keep: Post-Dev scouts, expanded file coverage, TEA test validator
- Revert: Reviewer checklist inflation (run-28 regression)
- Add: Alternative reviewer bias correction mechanism (TBD — needs research)

### Epic 150: PR Explanation Quality (Axis 2) — NEW
- Story: Impact Summary enhancement — downstream effects, deviation justification
- Story: PR body template generation from session artifacts
- Story: Internal spec-drift pre-check during review phase
- Story: Deviation traceability improvements in Architect reconcile phase

### Epic 148 (existing): Benchmark TUI Observability
- Story: Wire up OTEL tab (F2) for real-time benchmark debugging
- Enables: Watching agent reasoning in real-time to understand WHY findings are missed

## Dependencies

```
Epic 148 (TUI observability)
    └── Enables debugging for Epic 149 fixes
Epic 149 (Detection gaps)
    └── Axis 1 — fewer findings
Epic 150 (Explanation quality)
    └── Axis 2 — better PR output
Both → Measured by: external reviewer feedback on next 3 PRs
```

## Non-Goals

- Changing the judge scoring rules (measure the pipeline, not the instrument)
- Finding-specific heuristics (must generalize across scenarios)
- Optimizing benchmark cost or speed (excellence over optimization)
- Replacing the external reviewer (the goal is to make their job easier, not eliminate it)

## Open Questions

1. **Reviewer bias mechanism:** Checklist inflation backfired. What alternative approach corrects the reviewer's happy-path bias without giving it more boxes to fabricate answers for? Options: adversarial prompt structure, separate devil's-advocate subagent, or post-review challenge step.
2. **Spec drift pre-check:** Should this be a new pipeline phase, a reviewer subagent, or an Architect responsibility?
3. **PR body generation:** Should this be automatic (generated from session artifacts) or manual (Dev/SM writes it with template guidance)?
