# Story 137-1: Research spike — <switch> and <gate> tag design for stepped workflows

**Jira:** MSSCI-15921
**Epic:** 137 — Stepped workflow modernization — gates, AskUserQuestion, and collaboration
**Points:** 1
**Type:** chore
**Priority:** p1
**Workflow:** trivial
**Phase:** finish
**Repos:** pennyfarthing
**Branch:** chore/MSSCI-15921-switch-gate-research

## Description

Audit all stepped workflows for conditional branching patterns (quick-dev mode detection, release prerelease_skip_steps, architecture continuation). Design <switch> tag spec (on, case, default, next) and enhanced <gate> tag spec for stepped context. Prototype both in architecture step-03. Rationalize <output> tag contract: every step declares format, target file, and required sections. Write ADR documenting decisions.

## Acceptance Criteria

- [ ] All stepped workflows audited for conditional branching patterns
- [ ] <switch> tag spec designed (on, case, default, next)
- [ ] Enhanced <gate> tag spec for stepped context designed
- [ ] Both prototyped in architecture step-03
- [ ] <output> tag contract rationalized
- [ ] ADR written documenting decisions

## Technical Approach

Research spike: read existing stepped workflow files, identify patterns, design XML tag specs, write ADR. No implementation code — design output only.

## Delivery Findings

<!-- Delivery Findings: agents append below this line -->

### Reviewer (code review)

- **Gap** (non-blocking): `LOOP`, `EXIT`, and `CONTINUE` special values for `<case next="">` are used in examples but not formally defined. Story 137-3 or 137-4 must specify their semantics before implementing the step engine. Affects `docs/adr/0032-stepped-workflow-switch-gate-output-tags.md` (needs "Special Navigation Values" section). *Found by Reviewer during code review.*
- **Question** (non-blocking): Step-meta `gate: true` vs workflow YAML `gates.after_steps` precedence is unspecified. Step-03 prototype sets `gate: true` but architecture.yaml `after_steps: [2, 4, 6]` excludes step 3. Story 137-3 must resolve whether these are additive or one overrides. Affects `pennyfarthing-dist/workflows/architecture.yaml` and gate validation implementation. *Found by Reviewer during code review.*
- No upstream findings during code review.

### Dev (implementation)

- **Gap** (non-blocking): Architecture step files (step-01 through step-07) use old `<step-meta>` format (`number:` instead of `step:`, missing `workflow:` and `agent:` fields). Affects `pennyfarthing-dist/workflows/architecture/steps/step-01-initialize.md` through `step-07-document.md` (step-03 fixed, 6 remaining). *Found by Dev during implementation.*
- **Improvement** (non-blocking): `<collaboration-menu>` and `<switch>` overlap — `<collaboration-menu>` should be deprecated or defined as syntactic sugar for `<switch>` with all `next="LOOP"` cases. Affects `schemas/workflow-step-schema.md` (needs clarification). *Found by Dev during implementation.*
- **Gap** (non-blocking): `workflow-step-schema.md` does not yet document the `format` or `target` attributes on `<output>`, nor the `<switch>`/`<case>`/`<default>` elements. Story 137-3 or a follow-up should update the schema. Affects `pennyfarthing-dist/schemas/workflow-step-schema.md` (needs new sections). *Found by Dev during implementation.*

## Impact Summary

**Upstream Effects:** 5 findings (3 Gap, 1 Question, 1 Improvement)
**Blocking:** None

- **Gap:** `LOOP`, `EXIT`, and `CONTINUE` special values for `<case next="">` are used in examples but not formally defined. Affects `docs/adr/0032-stepped-workflow-switch-gate-output-tags.md` (needs "Special Navigation Values" section).
- **Question:** Step-meta `gate: true` vs workflow YAML `gates.after_steps` precedence is unspecified. Affects `pennyfarthing-dist/workflows/architecture.yaml` and gate validation implementation.
- **Gap:** Architecture step files (step-01 through step-07) use old `<step-meta>` format. Affects `pennyfarthing-dist/workflows/architecture/steps/step-01-initialize.md` through `step-07-document.md` (6 files need migration).
- **Gap:** `workflow-step-schema.md` does not document `format` or `target` attributes on `<output>`, nor `<switch>`/`<case>`/`<default>` elements. Affects `pennyfarthing-dist/schemas/workflow-step-schema.md`.
- **Improvement:** `<collaboration-menu>` and `<switch>` overlap — needs deprecation clarification. Affects `pennyfarthing-dist/schemas/workflow-step-schema.md`.

**Docs that may need updating:**
- `docs/adr/0032-stepped-workflow-switch-gate-output-tags.md` — Add "Special Navigation Values" section for LOOP, EXIT, CONTINUE semantics
- `pennyfarthing-dist/workflows/architecture/steps/step-01-initialize.md` through `step-07-document.md` — Migrate to new `<step-meta>` format (6 files)
- `pennyfarthing-dist/schemas/workflow-step-schema.md` — Document new `<output>` attributes, `<switch>`/`<case>`/`<default>`, and `<collaboration-menu>` deprecation path

## SM Assessment

1-point research spike, trivial workflow — straight to Korben Dallas (Dev). Pure design output: audit existing stepped workflows, design `<switch>` and `<gate>` tag specs, rationalize `<output>` tag contract, write ADR. No implementation code. Key files to read are in `pennyfarthing/pennyfarthing-dist/workflows/` (stepped workflow YAMLs) and their step files. Branch ready in pennyfarthing repo.

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `docs/adr/0032-stepped-workflow-switch-gate-output-tags.md` — ADR documenting `<switch>`, `<gate>`, and `<output>` tag design with audit findings, specs, migration paths, and consistency rules
- `pennyfarthing-dist/workflows/architecture/steps/step-03-patterns.md` — Prototype demonstrating all three tag specs: `<switch tool="AskUserQuestion">`, `<gate>` with completion criteria, `<output format="markdown" target="{output_file}">`

**Audit Coverage:** 14 stepped workflows, ~90 step files. Found 5 distinct branching patterns: mode detection (quick-dev), user choice menus (6+ workflows), conditional step skipping (release), continuation detection (4 workflows), tri-modal routing (PRD).

**Tests:** N/A (design output only, no implementation code)
**Branch:** `chore/MSSCI-15921-switch-gate-research` (pushed, both repos)

**Handoff:** To Reviewer for review

## Reviewer Assessment

**Verdict:** APPROVED
**Data flow traced:** ADR spec → prototype step-03 → downstream stories 137-2 through 137-5 (specs are implementable)
**Pattern observed:** Clean tag separation — `<output>` for deliverables, `<switch>` for branching, `<gate>` for validation at `step-03-patterns.md:54,82,91`
**Error handling:** Two MEDIUM design clarifications (LOOP/EXIT semantics, gate precedence) — non-blocking, deferred to implementing stories
**Observations:** 10 items (4 VERIFIED, 2 MEDIUM, 2 LOW, 2 VERIFIED-AC)
**Handoff:** To SM for finish-story