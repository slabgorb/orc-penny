---
story_id: "150-17"
jira_key: "PROJ-16564"
epic: "PROJ-16564"
workflow: "trivial"
---
# Story 150-17: Subagent model defaults — agent definitions should specify sonnet for specialists

## Story Details
- **ID:** 150-17
- **Jira Key:** PROJ-16564
- **Epic:** PROJ-16564 (Prove the Work — PR Explanation Quality)
- **Workflow:** trivial
- **Repos:** pennyfarthing
- **Branch:** feat/150-17-subagent-model-defaults
- **PR:** #1482 - feat(agents): set sonnet model for specialist subagents
- **Stack Parent:** none

## Workflow Tracking
**Workflow:** trivial
**Phase:** setup
**Phase Started:** 2026-03-20T16:37:38Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-03-20T16:37:38Z | - | - |

## Delivery Findings

Agents record upstream observations discovered during their phase.
Each finding is one list item. Use "No upstream findings" if none.

**Types:** Gap, Conflict, Question, Improvement
**Urgency:** blocking, non-blocking

<!-- Agents: append findings below this line. Do not edit other agents' entries. -->

No upstream findings.

## Design Deviations

Agents log spec deviations as they happen — not after the fact.
Each entry: what was changed, what the spec said, and why.

<!-- Agents: append deviations below this line. Do not edit other agents' entries. -->

No design deviations.

## Reviewer Assessment

**Verdict: APPROVED**

**Date:** 2026-03-20
**Reviewer:** Reviewer Agent

### Summary

All changes are correct and consistent. The diff is clean, minimal, and precisely scoped.

### Checklist Results

1. **Reviewer subagents (9 files) -- opus to sonnet:** PASS. All 9 reviewer-* subagent definitions (`reviewer-preflight`, `reviewer-edge-hunter`, `reviewer-silent-failure-hunter`, `reviewer-test-analyzer`, `reviewer-comment-analyzer`, `reviewer-type-design`, `reviewer-security`, `reviewer-simplifier`, `reviewer-rule-checker`) now specify `model: sonnet` in frontmatter. These are analytical subagents that require Sonnet-class capability per project rule "Match model to task."

2. **tandem-backseat -- haiku to sonnet:** PASS. This is an analytical observer role (adversarial review pairing), not a mechanical task. Sonnet is the correct model.

3. **Mechanical subagents still haiku:** PASS. Verified all four remain `model: haiku`:
   - `testing-runner.md` -- haiku
   - `sm-setup.md` -- haiku
   - `sm-finish.md` -- haiku
   - `sm-file-summary.md` -- haiku
   - Also confirmed: `simplify-efficiency.md`, `simplify-quality.md`, `simplify-reuse.md` -- all haiku (mechanical analysis, appropriate)

4. **No missing model frontmatter:** PASS. All subagent files have `model:` in frontmatter. Parent agents (reviewer.md, dev.md, etc.) correctly omit it -- they are top-level agents, not subagents. Native-mode model specs live in `agents/native/`.

5. **Helpers tables match actual subagent models:** PASS for reviewer.md -- updated to `**Model:** sonnet (all reviewer subagents)`. Other parent agents (dev.md, tea.md, architect.md) show `**Model:** haiku` in their helpers tables, which is correct because their subagents ARE haiku (testing-runner, sm-file-summary, etc.).

6. **settings_meta.py fix:** PASS. Changed `("Manual", "manual")` to `("Human", "human")`. Verified against `pr_config.py`: `VALID_PR_MERGE_MODES = {"auto", "human"}`. The old TUI dropdown offered "manual" which would have been rejected by validation and silently fallen back to "auto." This is a legitimate bug fix.

7. **Framework validation:** PASS. `pf validate` errors are all pre-existing (session XML migration, step-meta tags). No new errors introduced by this change.

### Findings

None. Clean change, no concerns.
