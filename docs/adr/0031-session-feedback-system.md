# ADR-0031: Story Session Feedback System

**Status:** Proposed
**Date:** 2026-02-27
**Author:** architect (Gaius Octavian)
**PRD:** sprint/planning/session-feedback-prd.md

## Context

The boss reviews PRs to understand what happened during story delivery. Session files capture workflow mechanics faithfully — phases, assessments, handoffs — but lack structured feedback about upstream effects discovered during implementation: spec gaps, architecture issues, documentation drift. The tier model (`docs/initiatives/lifecycle-composition/lifecycle-tier-work-products.md`, lines 228-248) defines "Delivery Finding" as the missing upward-flowing artifact, but it is unimplemented.

Today, when a TEA agent discovers a spec ambiguity, a Dev agent finds that an ADR recommendation doesn't hold, or a Reviewer flags documentation drift, these observations are buried in free-text assessment prose. The boss must read all three assessments to extract findings that matter for future planning. Nothing flows upward.

Additionally, the boss does not use Pennyfarthing directly. The PR description is the primary artifact the boss reads. The PR must be self-contained, human-readable, free of framework jargon, and must include everything the boss needs to understand what the story did and what it revealed.

### Decision Drivers

1. Session file is the source of truth — findings belong with the story context that produced them
2. PR description is the boss-facing artifact — generated from the session file, not hand-written
3. `gh` cannot edit PR descriptions after creation — PR must be created late (after all content exists)
4. Agents know what they found — self-reporting is more reliable than retroactive LLM scanning
5. Pure markdown — no YAML blocks, no schema validation complexity, strictly human-readable
6. Backward compatible — 90+ archived sessions must continue to parse; new sections are additive

## Considered Options

### Option A: SM Retroactive Scan (Rejected)

SM scans free-text assessments at finish time using LLM classification to extract findings.

**Rejected because:** The agent who found the issue is the best person to describe it. Retroactive scanning loses fidelity, misses unreported observations, and requires NLP-class work from a Haiku subagent. Agents already know what they found — we should ask them to report it, not guess after the fact.

### Option B: YAML Blocks in Session Files (Rejected)

Agents write structured YAML code blocks with typed fields (type, urgency, source, affected_spec, etc.).

**Rejected because:** LLMs get YAML indentation wrong. Colons in descriptions break parsing. Adds schema validation overhead. The consumer is a human reading a PR — markdown list items serve that purpose without the fragility.

### Option C: Agent Self-Report + Late PR Creation (Selected)

Agents append markdown findings to a `## Delivery Findings` section during their phase. SM compiles an `## Impact Summary` at finish time. SM creates the PR with a full body generated from the session file, translated into boss-readable language.

## Decision Outcome

**Selected: Option C — Agent Self-Report with Late PR Creation**

### Architecture

```
TEA writes assessment + appends to ## Delivery Findings
Dev writes assessment + appends to ## Delivery Findings
Reviewer writes assessment + appends to ## Delivery Findings
         │
         ▼
    Session File (source of truth)
         │
         ▼
    SM Finish Phase:
    1. Read session file + all findings
    2. Compile ## Impact Summary (from findings)
    3. Generate PR body (translate to boss-readable)
    4. Create PR with full body
    5. Run preflight
         │
         ▼
    PR Description (boss reads this)
```

### Session File Section Order

```
# Story {ID}: {Title}
Header fields (Jira, Epic, Points, etc.)
---
## Description
## Acceptance Criteria
## Technical Context
## Delivery Findings          ← NEW (agents append here)
## Impact Summary             ← NEW (SM compiles at finish)
## TEA Assessment
## Dev Assessment
## Reviewer Assessment
## Phase Log
```

### Finding Format

Each finding is a markdown list item:

```markdown
- **{Type}** ({urgency}): {One sentence description}.
  Affects `{relative/path/to/doc.md}` ({what needs to change}).
  *Found by {Agent} during {human-phase-name}.*
```

- **Types:** Gap, Conflict, Question, Improvement
- **Urgency:** blocking, non-blocking
- **Human phase names:** test design, implementation, code review (no framework jargon)

If an agent has no findings:

```markdown
- No upstream findings during {human-phase-name}.
```

### Impact Summary Format

SM compiles from Delivery Findings:

```markdown
## Impact Summary

**Upstream Effects:** {N} findings ({N} Gap, {N} Conflict, {N} Question, {N} Improvement)
**Blocking:** {None | list of blocking items}

- **{Type}:** {description}. Affects `{path}`.

**Docs that may need updating:**
- `{path}` — {reason}
```

### PR Body Structure

Generated from session file. Zero framework jargon.

| Framework Term | PR Body Term |
|---------------|-------------|
| TEA / red phase | Test design |
| Dev / green phase | Implementation |
| Reviewer / review phase | Code review |
| SM / finish phase | Story completion |
| Acceptance Criteria | Requirements |

```markdown
## Summary
{story title}

## What Was Done
- **Requirements:** {N}/{N} met
- **Tests:** {from TEA assessment}
- **Implementation:** {from Dev assessment}
- **Review:** {verdict from Reviewer}

## What This Work Revealed
{Impact Summary content}

## Docs That May Need Updating
{deduplicated doc references from findings}

## Details
### Test Design
{TEA assessment, cleaned}
### Implementation
{Dev assessment, cleaned}
### Code Review
{Reviewer assessment, cleaned}
### Full Findings
{Delivery Findings section, verbatim}
```

### Workflow Change: Late PR Creation

**Constraint:** `gh` cannot edit PR descriptions after creation.

**Before:** sm-finish creates PR with minimal body → preflight → merge.
**After:** SM finish compiles Impact Summary → generates PR body → creates PR with full body → preflight → merge.

Reviewer reviews the branch diff (`git diff develop...HEAD`), not a PR. The PR is created after review approval, representing completed and reviewed work.

## Consequences

### Positive

- Boss gets a self-contained, readable PR description with full story context
- Upstream findings captured systematically — no more lost observations
- Session file is the single source of truth; PR body is a generated view
- Agents self-report findings when they have full context (not SM guessing later)
- Pure markdown — no YAML parsing, no schema validation fragility
- Backward compatible — new sections are additive, all existing parsers unaffected

### Negative

- Every agent's exit behavior changes (must write to Delivery Findings section)
- SM finish phase becomes more complex (compilation + PR body generation)
- Reviewer no longer has a PR during review phase (reviews branch diff instead)
- `reviewer-preflight` must handle missing PR_NUMBER gracefully

### Risks and Mitigations

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| Agents forget to write findings | High (new behavior) | R3: "No findings" is explicit. Exit gate checks for entry. |
| Reviewer-preflight fails without PR | Medium | Make PR_NUMBER optional. Step 5 conditional. |
| In-flight stories lack new sections | Medium | SM finish handles missing section — generates PR from assessments only. |
| SM uses framework jargon in PR | Low | Translation map explicit in sm-finish definition. |

## Implementation Consistency Rules

> These rules prevent agents from making conflicting choices.

- **R1:** Finding format is fixed (see Finding Format above). Types and urgency are enumerated.
- **R2:** Agents ONLY append to `## Delivery Findings`. Never edit, never remove another agent's entries.
- **R3:** "No findings" is an explicit entry. Distinguishes "checked and found nothing" from "forgot to check."
- **R4:** Doc references use relative paths from project root.
- **R5:** PR body uses zero framework jargon. Translation map is authoritative.
- **R6:** Impact Summary is compiled from findings, not editorial. SM reads verbatim.

## Files Affected

| File | Change |
|------|--------|
| `agents/sm-finish.md` | PR creation moves after summary compilation; `--body` includes full session content |
| `agents/reviewer-preflight.md` | `PR_NUMBER` becomes optional; step 5 conditional |
| `agents/reviewer.md` | Remove `PR_NUMBER` from required params; add finding-capture template |
| `agents/sm-setup.md` | Add `## Delivery Findings` placeholder to session template |
| `agents/tea.md` | Add finding-capture to assessment template |
| `agents/dev.md` | Add finding-capture to assessment template |
| `agents/sm.md` | Add Impact Summary compilation + PR body generation to finish flow |
| `guides/session-artifacts.md` | Document new sections |
| `src/pf/sprint/story_finish.py` | No change needed (already finds PR by branch) |

## Related Decisions

- ADR-0009: Session File Coordination — establishes session file as coordination artifact
- ADR-0025: Script-First Gate Extraction — gate pattern used for exit checks
- Tier Model: `docs/initiatives/lifecycle-composition/lifecycle-tier-work-products.md` — defines Delivery Finding artifact (lines 228-248)
