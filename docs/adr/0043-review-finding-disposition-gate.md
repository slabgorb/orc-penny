# ADR-0043: Review-Finding Disposition Gate — Stop the Follow-Up Fan-Out

**Status:** Proposed
**Date:** 2026-08-11
**Author:** DevOps (Lu-Tze) / process improvement
**Relates to:** [SOUL #1 Fix the System](../../SOUL.md), [SOUL #6 Gates Over Goodwill], [SOUL #13 Excellence Over Optimization]

## Context

The review pipeline generates work faster than the team closes it. Epic 162
("Finish & sprint-tooling truthfulness") is the ground-truth evidence:

- **70 stories** in the epic; **~35 backlog stories** had titles ending in
  "(from 162-N review)" — they are review follow-ups, not planned scope.
- The fan-out compounds: 162-1 → 162-18/19/20 → 162-47 → 162-59 → 162-65. Each
  review emits 3–10 findings, each finding becomes a story, and each of *those*
  stories is reviewed and emits more.
- A manual triage pass found **19 stories collapsible into 7** (tight subsystem
  clusters) and **at least 3 self-labelled "chore-grade"** (162-31, 162-52,
  162-66) that never warranted a story at all.

This is not a reviewer-quality problem — the reviewer is doing its job well. It is
a **triage gap**: there is no gate deciding *which findings deserve to become
stories*. Every finding is promoted by default. The backlog therefore measures
reviewer throughput, not remaining product work, and "more stories than we finish"
is the structural result.

Combining stories (done in the 162-71..77 consolidation) treats the symptom for
one epic. This ADR addresses the mechanism.

## Decision

**1. Finding-disposition gate at review exit.**
The reviewer's exit protocol must classify every confirmed finding into exactly
one disposition before writing its verdict:

| Disposition | Meaning | Becomes a story? |
|-------------|---------|------------------|
| **fix-now** | In scope for the current PR; the author addresses it before merge | No — fixed in place |
| **fold** | Belongs with a sibling backlog story on the same seam | No — appended to that story's body |
| **defer** | Real, out-of-scope, worth tracking | Yes — one story, with severity tag |
| **drop** | Chore-grade / speculative / cost > value | No — recorded in the review assessment, not promoted |

**2. Auto-promotion is restricted.** Only findings tagged `[SEC]` or
**correctness** (produces a wrong result / data loss / crash on a real input) may
auto-promote to `defer` stories. Everything else defaults to **drop** unless the
reviewer gives an explicit one-line justification for `defer`. The burden of proof
flips: today a finding must be argued *down*; here it must be argued *up*.

**3. Per-epic follow-up budget (backstop).** An epic accumulates at most **N
review-spawned `defer` stories** (default N=10). Beyond the cap, further deferrals
collapse into a single "review debt" story that forces prioritization instead of
unbounded fan-out.

**4. Chore-grade never gets a story.** A finding the reviewer would label
"chore-grade" rides the next edit of that file (captured in the lang-review
checklist / institutional memory), not a dedicated backlog item.

## Implementation Sketch

- **`pennyfarthing-dist/agents/reviewer.md`** — add a disposition column to the
  subagent assessment table (already has confirmed/dismissed/deferred; add
  fold/drop and the auto-promotion rule) and a closing "Disposition Summary" the
  exit gate reads.
- **`gates/`** — extend the reviewer exit gate to require a disposition for every
  confirmed finding and to reject a `defer` for a non-`[SEC]`/non-correctness
  finding that lacks justification.
- **Sprint tooling gaps this surfaced** (file as their own small stories):
  - `pf sprint story update` cannot set `--type` (the `comment|test|doc|feature|
    fix` classification the user asked for is only writable at `add` time).
  - `pf sprint story update` cannot set `depends_on` (only `add` can), so
    sequencing an existing cluster falls back to priority ordering.
  - There is no "merge stories" command; consolidation is manual add + cancel.

## Consequences

**Positive**
- Backlog size tracks remaining product work, not reviewer throughput.
- Fewer, larger, seam-coherent stories (one PR per subsystem, not per finding).
- Chore-grade churn stops manufacturing coordination overhead.
- Aligns with SOUL #6: the discipline is a gate, not a reviewer's good intentions.

**Negative / Risks**
- A mis-`drop`ped real defect is lost unless the lang-review checklist captures it.
  Mitigation: `[SEC]`/correctness cannot be dropped; drops are recorded in the
  assessment for audit.
- The budget cap (N=10) is arbitrary and needs tuning against real epics.
- Flipping the burden of proof may under-promote genuine tech debt; the `defer`
  justification line is the pressure valve.

**Measurement (SOUL #12).** Track *review-spawned stories created vs closed per
sprint*. The gate works if that ratio crosses ≤ 1.0 and stays there.

## Status Notes

Proposed as a draft during the epic-162 consolidation (2026-08-11). Not yet
accepted — needs Architect + PM review of the auto-promotion rule and budget cap
before the reviewer.md / gate changes are implemented.
