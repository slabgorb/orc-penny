# SDD Workflow Design — Superpower Driven Development

**Date:** 2026-04-19
**Status:** Draft — pending user review
**Type:** New phased workflow, opt-in

## Purpose

A phased workflow that parallels `tdd.yaml`, but where pennyfarthing agents explicitly invoke named `superpowers:*` skills during their phases. Composability experiment — the two systems layered. Existing gates verify artifacts; new attestation gates verify that the prescribed skills were invoked.

This is **not** a replacement for `tdd.yaml`. It runs alongside, opt-in via `workflow: sdd` on a story.

## Scope — In

- New workflow YAML: `sdd.yaml` (5 phases)
- One generic gate: `skill-attested` (reads session XML, checks required-skills list)
- Two composite gates: `sdd-red-exit`, `sdd-green-exit` (existing gate + skill-attested)
- Session schema addition: `<skills-invoked>` element
- Per-phase `skills.required` list surfaced through the agent prime context
- ADR documenting the composability experiment

## Scope — Out

- Replacing `tdd.yaml` as the default workflow
- New agent files (SDD reuses existing SM, TEA, Dev, Reviewer)
- Marker files, new hooks, or Skill-tool interception
- Up-front brainstorm/plan phases (that would be a separate workflow; `sdd` keeps the TDD skeleton)
- `spec-check`, `verify`, `spec-reconcile` phases (deliberately dropped vs tdd)

## Workflow Shape

| # | Phase | Agent | Role |
|---|-------|-------|------|
| 1 | setup | sm | Create session, branch, story context |
| 2 | red | tea | Write failing tests |
| 3 | green | dev | Make tests pass |
| 4 | review | reviewer | Adversarial review + merge |
| 5 | finish | sm | Archive session, close story |

**Rework loop:** `review → green` on reviewer verdict `REWORK`, max 3 attempts.

**Triggers:** `types: [feature, enhancement]`, `points.min: 3`, `default: false`. Opt-in.

## Skill-to-Phase Mapping

| Phase | Skills the agent invokes |
|-------|--------------------------|
| setup | — |
| red | `superpowers:test-driven-development` |
| green | `superpowers:test-driven-development`, `superpowers:verification-before-completion`, `superpowers:requesting-code-review` (at exit) |
| review | `superpowers:receiving-code-review` (Dev invokes on rework re-entry, not Reviewer) |
| finish | `superpowers:finishing-a-development-branch` |

**Rationale for exclusions:**
- `brainstorming`, `writing-plans`, `executing-plans`, `subagent-driven-development` — assume a spec/plan lifecycle not present in TDD flow
- `systematic-debugging`, `using-git-worktrees`, `dispatching-parallel-agents` — situational, not phase-bound
- `writing-skills` — meta, irrelevant to feature development

## Gate Composition

Two layers, no new machinery.

### Existing gates unchanged

`tests-fail`, `dev-exit`, `approval`, `status-sync`, `sm-setup-exit` continue to verify artifacts exactly as they do in `tdd.yaml`.

### New gate: `skill-attested`

Reads the session file's `<skills-invoked>` element. Checks that every skill named inside the gate file has an attestation entry for the current phase.

**Required skills are hard-coded per composite gate file.** No gate-runner changes, no parameterization, no resolver plumbing. Each composite gate (`sdd-red-exit`, `sdd-green-exit`) lists its required skills inline. The generic `skill-attested.md` file is a template / reference only — it is not referenced by the workflow YAML directly.

**Attestation format** (session XML):

```xml
<skills-invoked>
  <skill name="test-driven-development" phase="red" at="2026-04-19T14:22:03Z"/>
  <skill name="verification-before-completion" phase="green" at="2026-04-19T15:01:47Z"/>
  <skill name="requesting-code-review" phase="green" at="2026-04-19T15:02:14Z"/>
</skills-invoked>
```

Agent appends one `<skill>` entry per invocation. Gate passes if every required name matches at least one entry for the current phase.

### New composite gates

**`gates/sdd-red-exit.md`** — composite:
- `tests-fail` (existing) — AC coverage, tests RED
- `skill-attested(test-driven-development)`

**`gates/sdd-green-exit.md`** — composite:
- `dev-exit` (existing) — tests pass, clean tree, no debug code
- `skill-attested(test-driven-development, verification-before-completion, requesting-code-review)`

AND semantics — first failure stops the chain. No new machinery; uses the existing composite-gate pattern (same shape as `dev-exit`, `quality-pass`, `release-ready`).

## Files to Create

All paths under `pennyfarthing/pennyfarthing-dist/`:

| Path | Purpose |
|------|---------|
| `workflows/sdd.yaml` | Workflow definition |
| `gates/skill-attested.md` | Generic attestation gate |
| `gates/sdd-red-exit.md` | Composite gate for red phase |
| `gates/sdd-green-exit.md` | Composite gate for green phase |

### Files to Update

| Path | Change |
|------|--------|
| `schemas/session-schema.md` | Document `<skills-invoked>` element |
| `guides/gates.md` | Add `skill-attested` to built-in gates table |
| `CLAUDE.md` (framework) | Note `sdd` as an available workflow |
| `docs/adr/` | New ADR: SDD composability experiment |

## Example — `sdd.yaml` (skeleton)

```yaml
workflow:
  name: sdd
  description: Superpower Driven Development — TDD skeleton with superpowers skill attestation
  version: "1.0.0"

  phases:
    - name: setup
      agent: sm
      output: [session_file, branches, story_context]
      gate:
        file: gates/sm-setup-exit
        type: sm_setup_exit

    - name: red
      agent: tea
      input: [session_file, story_context]
      output: [failing_tests]
      entry_gate:
        file: gates/tea-context
        type: tea_context
      skills:
        # Surfaced to agent prime context as "Skills Required" block.
        # Gate enforcement is separate — see gates/sdd-red-exit.md.
        required:
          - superpowers:test-driven-development
      gate:
        file: gates/sdd-red-exit
        type: sdd_red_exit

    - name: green
      agent: dev
      input: [failing_tests, story_context]
      output: [implementation, passing_tests]
      skills:
        required:
          - superpowers:test-driven-development
          - superpowers:verification-before-completion
          - superpowers:requesting-code-review
      gate:
        file: gates/sdd-green-exit
        type: sdd_green_exit

    - name: review
      agent: reviewer
      input: [implementation, passing_tests]
      output: [approval]
      entry_gate:
        file: gates/status-sync
        type: status_sync
      gate:
        file: gates/approval
        type: approval
        recovery:
          reviewer-verdict:
            action: rework
            target_phase: green
            max_attempts: 3

    - name: finish
      agent: sm
      input: [approval]
      output: [archived_session, story_summary]
      skills:
        required:
          - superpowers:finishing-a-development-branch
      entry_gate:
        file: gates/status-sync
        type: status_sync

  triggers:
    types: [feature, enhancement]
    points:
      min: 3
    default: false
```

## Attestation Protocol

Agent phase prompt (surfaced by prime output) includes a **Skills Required** block derived from `skills.required` in the workflow YAML. After invoking each skill, the agent appends an entry to `<skills-invoked>` in the session file, then runs the exit protocol as usual.

No new tools. No Skill-tool interception. Just disciplined session-file editing — the same coordination channel agents already use for everything else.

If an agent forgets: the composite gate fails at handoff, the agent fixes the attestation (or invokes the missed skill if genuinely skipped), and retries. Same recovery pattern as any gate miss.

## Measurement

What this experiment should tell us (once it's been run on real stories):

- **Does skill invocation change agent behavior?** Compare outputs from `sdd` runs vs `tdd` runs on comparable stories. Pipeline-replay benchmark methodology (per SOUL principle #12).
- **Does the attestation gate create useful friction?** If agents hit the gate repeatedly, the skills are being skipped — tells us which skills agents resist.
- **Is the composability pattern good?** If new composite gates feel natural to define and maintain, it's a reusable pattern for other workflows (BDD, agent-docs, etc.).

## Open Implementation Questions

These surface during planning; flagged here so they don't surprise the plan author:

1. **Prime surfacing `skills.required`.** Does `pf agent start` / the prime pipeline already read arbitrary per-phase fields from workflow YAML and surface them to the agent? If not, a small addition is needed so the agent sees its Skills Required list. If prime only surfaces a known set of fields, we may need to add `skills` to that set, or use a documented existing field.

2. **Session schema validation.** If session XML is schema-validated (via the `pf hooks schema-validation` Write hook), `<skills-invoked>` must be added to the allowed elements before any phase can write it. Check `schemas/session-schema.md`.

3. **Composite gate file format.** Confirm the exact XML shape for declaring a composite gate that chains `tests-fail` + inline skill-attestation checks. Read one existing composite (e.g., `dev-exit.md`, `quality-pass.md`) before authoring the new files.

## Alternatives Considered

- **B2 — Superpowers lifecycle, thinner agents.** Reshape the workflow around superpowers' own brainstorm → plan → execute chain. Rejected for first iteration: too ambitious, harder to evaluate, not a clean A/B against `tdd.yaml`. Revisit after `sdd` runs.
- **Hook-based Skill-tool interception.** Auto-write markers when Skill tool is invoked. Rejected: adds machinery for no benefit. Session-file attestation achieves the same auditability with zero new infrastructure.
- **Replace `tdd.yaml`.** Rejected: premature. Coexistence first, evaluate, then decide.

## Success Criteria

The design is successful if:

1. A story tagged `workflow: sdd` runs end-to-end with no new machinery beyond the files listed
2. Each phase's attestation gate catches a skipped skill without false positives
3. Running the same story under `tdd` and under `sdd` produces measurably different (or measurably identical) outputs — either result is informative
4. The composite-gate pattern (existing gate + `skill-attested`) is reusable for future workflows without modification
