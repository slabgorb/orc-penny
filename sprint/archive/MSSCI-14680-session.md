# Story 97-2: Ship tdd-tandem workflow

**Jira:** MSSCI-14680
**Epic:** epic-97 (CLI Tandem & Shipping Workflow)
**Points:** 2
**Workflow:** trivial
**Phase:** finish
**Repos:** pennyfarthing
**Branch:** feature/97-2-ship-tdd-tandem-workflow

## Acceptance Criteria

- [ ] Create `pennyfarthing-dist/workflows/tdd-tandem.yaml` with standard TDD phase sequence
- [ ] Green phase includes `tandem: { partner: architect, scope: file-watch }`
- [ ] Non-tandem phases (setup, red, review, finish) run identically to standard `tdd.yaml`
- [ ] Triggers use `tags: [tandem]`, NOT `default: true` (opt-in only)
- [ ] Workflow appears in `/workflow list` with description
- [ ] Workflow name is `tdd-tandem` (distinct from `tdd`)

## Context

This story creates a single new YAML file: `pennyfarthing-dist/workflows/tdd-tandem.yaml`. It extends the standard TDD workflow with an Architect tandem (backseat) during the green phase. The file is auto-discovered by `list-workflows.sh`.

### Reference Files
- `pennyfarthing-dist/workflows/tdd.yaml` — Base workflow to extend
- `pennyfarthing-dist/workflows/bdd.yaml` — Another phased workflow example
- `pennyfarthing-dist/scripts/workflow/list-workflows.sh` — Workflow discovery
- `sprint/context/context-epic-97.md` — Full epic context

### Key Design Decisions
- Only the green phase has the `tandem:` block
- `default: false` — users must explicitly opt in via `tandem` tag or workflow selection
- File placement: `pennyfarthing-dist/workflows/` (source of truth)

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/workflows/tdd-tandem.yaml` — New workflow: standard TDD + Architect tandem on green phase

**Tests:** N/A (YAML-only change, validated by workflow discovery)
**PR:** #807 — feat(97-2): ship tdd-tandem workflow
**Branch:** feature/97-2-ship-tdd-tandem-workflow (pushed)

**Verification:**
- `list-workflows.sh` discovers `tdd-tandem` with correct description
- All 6 acceptance criteria met

**Handoff:** To Reviewer for code review

## Reviewer Assessment

**Verdict:** APPROVED
**Data flow traced:** Workflow YAML → list-workflows.sh discovery → `/workflow list` display (correct)
**Pattern observed:** Exact phase-for-phase match with tdd.yaml for non-green phases (verified via diff)
**Error handling:** Declarative YAML — schema validation delegated to BikeLane loader (Epic 95-1)
**Observations:**
- `[VERIFIED]` Non-green phases byte-identical to tdd.yaml at `tdd-tandem.yaml:13-47`
- `[VERIFIED]` Tandem block correctly scoped to green phase only at `tdd-tandem.yaml:32-34`
- `[VERIFIED]` Opt-in triggers (`tags: [tandem]`, `default: false`) at `tdd-tandem.yaml:49-53`
- `[VERIFIED]` Auto-discovery by list-workflows.sh confirmed at runtime
- `[VERIFIED]` Workflow name `tdd-tandem` distinct from `tdd` at `tdd-tandem.yaml:8`

**Handoff:** To SM for finish-story
