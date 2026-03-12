---
stepsCompleted:
  - step-01-init
  - step-02-discovery
  - step-03-success
  - step-04-journeys
  - step-05-domain
  - step-06-innovation-skipped
  - step-07-project-type
  - step-08-scoping
  - step-09-functional
  - step-10-nonfunctional
  - step-11-polish
  - step-12-complete
classification:
  projectType: developer-tool-framework-extension
  domain: developer-productivity-agent-orchestration
  complexity: medium-high
  projectContext: brownfield
inputDocuments:
  - sprint/planning/gate-prd.md
  - sprint/planning/prd-simplify-integration.md
  - sprint/planning/context-gate-prd.md
  - pennyfarthing/pennyfarthing-dist/gates/deviations-logged.md
  - pennyfarthing/pennyfarthing-dist/gates/deviations-audited.md
  - pennyfarthing/pennyfarthing-dist/workflows/tdd.yaml
  - pennyfarthing/pennyfarthing-dist/workflows/tdd-tandem.yaml
documentCounts:
  existingPRDs: 3
  gates: 2
  workflows: 2
workflowType: 'prd'
---

# Product Requirements Document - Specification Fidelity Gates

**Author:** Keith Avery
**Date:** 2026-03-12

## Success Criteria

### User Success

| Criterion | Measure |
|-----------|---------|
| Boss can audit any story without code-diving | Session file Design Deviations section is self-contained: spec source document, original spec text, what changed, why, impact assessment — no external lookups needed |
| Operator gets clear AC deferral prompts | AC-completion gate presents each unmet AC with proposed justification and default action (complete it); operator approves/rejects in real-time before handoff proceeds |
| Forward-looking deviations are visible | When implementation conflicts with a future story's spec or assumptions, the deviation entry references that story, quotes the assumption, and explains the delta |
| No silent spec drift | Zero deviations pass through the pipeline undocumented — every departure from any spec (story context, epic context, PRD, sibling story assumptions) is logged or the gate blocks |
| Architect validates spec alignment before coding starts | New spec-check phase catches structural conflicts and assumption mismatches before TEA writes tests, not after Dev has already built the wrong thing |
| Architect produces definitive deviation manifest after review | New spec-reconcile phase after Reviewer compares final implementation against all specs (story, epic, PRD, sibling assumptions) and produces the audit document the boss reads |

### Business Success

| Criterion | Measure |
|-----------|---------|
| Retroactive deviation hunts eliminated | No more post-hoc "add retroactive design deviations to all N session archives" commits |
| External review surprise findings reduced | Deviations caught by pipeline before external reviewers surface them (baseline: PR #50's 13+6 findings, PR #52's 8 findings) |
| Boss trusts pipeline output | Boss can approve/reject work based on session file alone, without re-reading specs himself |
| Simplify no longer introduces uncontrolled drift | Projects that disable simplify see zero agent-initiated "improvements" beyond what the spec requires |

### Technical Success

| Criterion | Measure |
|-----------|---------|
| Deviation gates wired and enforced | `deviations-logged` blocks TEA and Dev exit; `deviations-audited` blocks Reviewer approval — no bypass |
| AC-completion gate with human-in-loop | Gate fails → agent proposes default (do it) → operator prompted → approval/rejection recorded in session file |
| Simplify is project-configurable | `repos.yaml` per-repo setting `simplify_enabled: true/false`; OFF = simplify teammates don't spawn; default OFF. Checked into git — shared across team. |
| Deviation format is structured and machine-parseable | Each entry has: spec source, spec text, implementation delta, rationale, severity, forward-impact tag (none/minor/breaking + affected story) |
| Architect spec-check phase integrated into TDD | New phase between setup and RED with its own gate; validates story context assumptions against sibling stories and epic spec |
| Architect spec-reconcile phase integrated into TDD | New phase after Reviewer, before SM finish; compares final implementation against all specs and produces definitive deviation manifest. Gate: `spec-reconcile-pass` |
| Story context declares assumptions | Required `## Assumptions` section lists what this story assumes about sibling stories' outputs — structural anchor for forward-looking comparison |

### Measurable Outcomes

- 100% of stories have deviation documentation at handoff (gate-enforced)
- 100% of deferred ACs have operator-approved justifications recorded in session
- 0 retroactive deviation documentation passes needed post-merge
- Deviation entries parseable by external tooling (structured markdown with consistent field format)
- Forward-looking conflicts caught before RED phase (Architect spec-check gate)
- Definitive deviation manifest produced after Reviewer phase (Architect spec-reconcile gate)

## Product Scope

### MVP — Must Have

1. **Wire deviation gates into TDD workflow** — `deviations-logged` on TEA exit (red) and Dev exit (green); `deviations-audited` on Reviewer exit (before approval). `tdd.yaml` only (tandem workflows removed, see #9). **Upgrade `deviations-logged` to validate entry format** — each entry must have spec source, spec text, implementation delta, rationale, severity, and forward-impact tag or the gate fails.
2. **Create AC-completion gate (standalone)** — composable gate, reads story ACs from context, requires each marked DONE/DEFERRED/DESCOPED, deferred requires operator real-time approval with default "do it". Can be referenced from any workflow phase.
3. **Simplify toggle in repos.yaml** — per-repo `simplify_enabled` setting, checked into git. Workflows read it at runtime. Default OFF. When OFF, simplify teammates not spawned in verify phase.
4. **Enhanced deviation entry format** — spec source document, original spec text, implementation delta, rationale, severity (minor/major), forward-impact tag (none/minor/breaking + affected story ID)
5. **Update TEA and Dev agent definitions** — mandate deviation logging against all available specs (story context, epic context, sibling story ACs). Explicit instruction: never assume simplification is acceptable.
6. **Add Architect spec-check phase to TDD workflow** — new phase between setup and RED. Architect loads story context assumptions, sibling story ACs from sprint YAML, and flags forward-looking conflicts. Gate: `spec-check-pass`.
7. **Add Architect spec-reconcile phase to TDD workflow** — new phase after Reviewer, before SM finish. Architect compares final implementation against all specs (story context, epic context, PRD, sibling assumptions). Produces the definitive deviation manifest — the audit document the boss reads. Gate: `spec-reconcile-pass`.
8. **Add `## Assumptions` section to story context schema** — required section declaring what this story assumes about sibling stories' outputs. Populated by PM during context creation.
9. **Remove tandem workflows** — delete `tdd-tandem.yaml`, `review-tandem.yaml`, `bdd-tandem.yaml`. Tandem pattern needs a full rethink now that Architect has explicit phases. Future epic.

### Growth — Should Have

- Forward-looking scan subagent (Haiku, runs post-Dev-exit, cross-references all sibling story contexts — not just ACs)
- Deviation summary report generator (aggregate across stories in an epic for boss review)
- Tooling-friendly export (JSON/YAML alongside markdown for boss's tooling)
- Interface contracts file per epic (shared file listing data structures/APIs downstream stories depend on)

### Won't Have (Explicit Out of Scope)

- Automated deviation severity scoring by LLM
- Boss-facing dashboard or UI
- Changes to Reviewer agent behavior beyond stamping deviations
- Pre-computed dependency graphs (assumptions section covers this more simply)
- Simplify agent deletion (they still exist, just toggled off by default)
- Tandem workflow rethink (future epic — needs redesign now that Architect has explicit phases)
- BDD workflow updates (separate effort once TDD pattern is proven)

## User Journeys

### Journey 1: The Operator — AC Deferral During Green Phase (Happy Path)

You're watching Dev work on story 5-1 (AxiQL Parser). Dev finishes implementation and hits the AC-completion gate. The gate scans story context — 14 ACs. 11 are DONE. Three are flagged:

- **AC-10 (graceful shutdown):** Dev proposes DEFERRED — "Requires binary entrypoint; this crate ships as library-only at scaffold stage. Story 8.1 delivers the server binary."
- **AC-11 (rate limiting):** Dev proposes DEFERRED — "tower-governor dep added but not wired. Needs Story 1.20 config infrastructure first."
- **AC-14 (config loading):** Dev proposes DEFERRED — "Hardcoded defaults. Story 1.20 is explicit prerequisite."

Default action for each: **complete it**. You review. AC-10 and AC-14 are genuinely blocked by prerequisites — you approve the deferrals. AC-11 though — the dependency is already in Cargo.toml, it should be wired or removed. You reject the deferral. Dev gets sent back to either wire it or remove the dead dependency.

Gate re-runs. 12 DONE, 2 approved DEFERRED, 0 unaccounted. Passes. Dev exits to TEA verify.

**Reveals:** Real-time operator approval UX, default "do it" forcing agents to justify, operator judgment as quality filter.

### Journey 2: The Boss — Auditing a Completed Story

Your boss opens the session archive for story 5-1 after the PR is up. He goes straight to **## Design Deviations** — the definitive manifest produced by Architect spec-reconcile.

He sees structured entries:

```
- **FieldRef internal representation**
  - Spec source: context-story-5-1.md, Task 1.2
  - Spec text: "segments: Vec<String> with array_index: Option<usize>"
  - Implementation: "segments: Vec<FieldSegment> where FieldSegment is enum of Named(String) | Index(String, String)"
  - Rationale: Enum handles multiple array indices and bracket-quoted vendor extension keys
  - Severity: major
  - Forward impact: minor — Story 5.2 assumes FieldRef iteration; enum is iterable, no breaking change
  - Affected stories: 5-2 (assumption: "FieldRef segments are iterable")
```

He can read this without opening the code, without reading the story context, without diffing the spec. Each entry is self-contained. He flags two entries he wants to discuss, leaves the rest. Done in 5 minutes.

**Reveals:** Self-contained deviation entries, structured format, forward-impact tags, boss workflow is read-and-assess only.

### Journey 3: The Architect — Spec-Check Before RED (Preventive)

Architect activates for spec-check on story 5-2 (AxiQL Optimizer). Loads story 5-2's context, reads the `## Assumptions` section:

- "Assumes 5-1 delivers `Regex { pattern: String, flags: String }` per original spec"
- "Assumes 5-1 FieldRef uses `Vec<String>` segments"

Architect loads story 5-1's session archive (already completed). Checks deviations. Finds:
- FieldRef changed to `Vec<FieldSegment>` — flagged as minor forward impact on 5-2
- Regex flattened to `Regex(String)` — not flagged as forward impact, but 5-2 explicitly assumes the two-field version

Architect flags the Regex assumption as **broken** — 5-2's assumption doesn't match 5-1's implementation. Recommends: update 5-2 story context assumptions before TEA writes tests against the wrong shape.

Gate passes with the finding documented. TEA reads the Architect's output and writes tests against the *actual* Regex shape, not the outdated assumption.

**Reveals:** Assumptions section as structural anchor, cross-story deviation propagation, spec-check preventing wasted test effort.

### Journey 4: The Architect — Spec-Reconcile After Reviewer (Auditive)

Story 5-2 is done. Reviewer approved. Architect activates for spec-reconcile. This is the final pass.

Architect loads: story 5-2 context, epic context, the original PRD section for AxiQL, sibling story ACs for 5-1 and 5-3. Compares the final implementation against all of them.

TEA and Dev already logged 8 deviations during their phases. Architect reviews each — confirms 7 are accurately documented. Finds one Dev missed: the optimizer's cost model uses a simplified heuristic instead of the full cost-based approach specified in AC-6. Architect adds it under `### Architect (reconcile)` with full spec reference.

Architect also checks all AC deferral justifications logged during the gate — confirms they're still accurate post-review. Produces the definitive manifest. Gate passes.

This is what the boss reads.

**Reveals:** Architect as final authority on deviation completeness, catches what agents missed, reconcile manifest supersedes in-flight deviation logs.

### Journey 5: The Operator — Simplify Toggle (Configuration)

You're setting up a new project for axiathon. You run `pf init`. The default `repos.yaml` has `simplify_enabled: false`. You leave it. When TEA hits verify phase, the workflow reads the config — no simplify teammates spawn. Verify runs quality-pass only.

Later, on the pennyfarthing framework itself, you want simplify on — the framework benefits from refactoring suggestions. You set `simplify_enabled: true` in pf-1's `repos.yaml`. Simplify teammates spawn during verify.

Two projects, different policies, one setting.

**Reveals:** Project-level toggle, default OFF, per-project autonomy.

### Journey 6: TEA — Deviation Logging During RED Phase (Agent Experience)

TEA activates for story 5-1 RED phase. Reads story context, epic context, sibling story ACs. Writes tests for each AC.

For AC-1 (query syntax), spec says `!` should be supported as NOT alternative. TEA decides not to write a test for `!` — it's ambiguous with `!=`. TEA must log this immediately:

```
- **No `!` as NOT alternative**
  - Spec source: context-story-5-1.md, AC-1
  - Spec text: "Support `!` as NOT alternative"
  - Implementation: Not tested — omitted from test suite
  - Rationale: Ambiguous with `!=` prefix; deferred to avoid parser ambiguity
  - Severity: minor
  - Forward impact: none
```

The `deviations-logged` gate at TEA exit checks for the `### TEA (test design)` section — it's there with entries. Gate passes. Without this section, TEA cannot hand off to Dev.

**Reveals:** Real-time deviation logging by agents, gate enforcement, structured format even for test omissions.

### Journey Requirements Summary

| Capability | Revealed By |
|-----------|-------------|
| AC-completion gate with real-time operator approval | Journey 1 |
| Default "do it" with agent justification for deferrals | Journey 1 |
| Self-contained deviation entries (no external lookups) | Journey 2 |
| Structured, machine-parseable deviation format | Journey 2 |
| Forward-impact tags on deviation entries | Journeys 2, 3 |
| `## Assumptions` section in story context | Journey 3 |
| Architect spec-check phase (preventive) | Journey 3 |
| Architect spec-reconcile phase (auditive, definitive manifest) | Journey 4 |
| Reconcile catches deviations agents missed | Journey 4 |
| Project-level simplify toggle in repos.yaml | Journey 5 |
| Real-time deviation logging by TEA and Dev (gate-enforced) | Journey 6 |
| `deviations-logged` gate blocks handoff without documentation | Journey 6 |

## Technical Architecture

### Design Principles

- **Consistency and excellence over cost optimization** — extra Architect phases, additional gate checks, and human-in-loop prompts are all worth it. Do not optimize for token cost or agent invocation count at the expense of spec fidelity. Optimize only when a concrete bottleneck emerges.
- **Human-in-loop is expected** — the operator is present and watching. Blocking the pipeline to ask for AC deferral approval is by design, not a latency problem.
- **Graceful degradation for missing context** — when sibling stories lack context documents, fall back to story titles and ACs from sprint YAML. Partial information is better than no forward-looking comparison.
- **Session file size is a future concern** — deviation manifests will grow session files. When this becomes a problem, scripts will slice and dice. Do not prematurely constrain the deviation format for size reasons.

### Workflow Architecture

Updated TDD flow: `SM (setup) → Architect (spec-check) → TEA (red) → Dev (green) → TEA (verify) → Reviewer → Architect (spec-reconcile) → SM (finish)`

Tandem workflows (`tdd-tandem.yaml`, `review-tandem.yaml`, `bdd-tandem.yaml`) are removed. The tandem observation pattern — where a partner agent watches in the background — needs a full rethink now that Architect has explicit phases with gates. This is a future epic, not part of this PRD.

### Gate Architecture

| Gate | Type | Phase | Purpose |
|------|------|-------|---------|
| `spec-check-pass` | New | After setup | Architect validates assumptions vs sibling stories |
| `deviations-logged` (tea) | Existing, unwired | After RED | TEA logged deviation section |
| `ac-completion` | New, standalone | After GREEN | All ACs accounted for with operator approval |
| `deviations-logged` (dev) | Existing, unwired | After GREEN | Dev logged deviation section |
| `quality-pass` | Existing | After VERIFY | Lint, typecheck, tests |
| `deviations-audited` | Existing, unwired | After REVIEW | Reviewer stamped all deviations |
| `spec-reconcile-pass` | New | After REVIEW | Architect final spec comparison |

`ac-completion` is a standalone composable gate — not embedded in `dev-exit`. Can be referenced from any workflow phase independently.

### Configuration Integration

`simplify_enabled` lives in `.pennyfarthing/repos.yaml` as a per-repo setting:

```yaml
## orchestrator
  simplify_enabled: false  # default

## pennyfarthing
  simplify_enabled: true   # framework benefits from refactoring suggestions
```

Checked into git. Shared across team. Workflow engine reads it at runtime when TEA enters verify phase.

### Migration Impact

- Axiathon PRs already moved to draft status in anticipation of pipeline changes
- Existing `tdd.yaml` gets two new phases and stricter gates — version bump required
- Tandem workflow files deleted — any stories referencing `tdd-tandem` workflow need reassignment to `tdd`
- No backward compatibility shim — clean cut

## Implementation Strategy

### MVP Strategy

**Approach:** Problem-solving MVP — enforce spec fidelity end to end. Gates check, agents document, Architect audits, operator approves. Every deviation is visible.

**Core journeys supported:** All 6

### Dependency Graph & Sequencing

```
Phase A (independent, start immediately):
  #4  Enhanced deviation entry format (format spec)
  #8  Assumptions section in context schema
  #9  Remove tandem workflows (deletion + story reassignment)
  #3  Simplify toggle in repos.yaml

Phase B (depends on #4):
  #5  Update TEA and Dev agent definitions
  #1  Wire + upgrade deviation gates (format validation)
  #2  AC-completion gate (standalone)

Phase C (depends on #5, #1, #8):
  #6  Architect spec-check phase
  #7  Architect spec-reconcile phase
```

**Critical path:** #4 → #5 → #1 → #7

Phase A items are all independent — can be done in parallel or any order. Phase B needs the format spec from #4. Phase C needs agents updated and gates wired before Architect phases make sense.

### Risk Mitigation

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| Agents don't follow deviation format consistently | High — defeats purpose | Medium | Gate validates format structure, not just existence (Principle 6: Gates Over Goodwill) |
| Sibling stories lack context for forward-looking comparison | Medium | High (early epics) | Graceful degradation to story titles + ACs from sprint YAML |
| Tandem removal breaks stories assigned to tdd-tandem | Low | Low | Reassign to tdd — new tdd is strictly better |
| Architect reconcile produces different findings than in-flight logs | Medium (confusing) | Medium | Reconcile manifest is authoritative; in-flight logs are working notes |
| AC-completion prompts interrupt operator flow | Low | Low | Operator is present and watching — this is by design |

## Functional Requirements

### FR-1: Deviation Entry Format Specification

Each deviation entry in the session file must contain these fields:

```markdown
- **{Short description}**
  - Spec source: {document path, section/AC reference}
  - Spec text: "{quoted original specification}"
  - Implementation: {what was actually built/tested}
  - Rationale: {why the deviation was made}
  - Severity: {minor | major}
  - Forward impact: {none | minor | breaking} — {affected story IDs and assumptions if not none}
```

TEA entries go under `### TEA (test design)`. Dev entries under `### Dev (implementation)`. Architect reconcile entries under `### Architect (reconcile)`.

### FR-2: Deviation Gate Format Validation

`deviations-logged` gate upgraded from existence check to format validation:
- Each entry must have all 6 fields (spec source, spec text, implementation, rationale, severity, forward impact)
- Missing fields → gate fails with specific recovery: "Entry '{description}' missing: {field list}"
- "No deviations from spec." is still valid (auto-pass with zero entries)

### FR-3: AC-Completion Gate

Standalone composable gate:
- Reads AC list from story context document
- Each AC must be marked: `DONE`, `DEFERRED {justification}`, or `DESCOPED {justification}`
- `DEFERRED` entries prompt the operator in real-time for approval. Default action presented: "complete it"
- Operator approves → recorded in session. Operator rejects → gate fails, agent must address the AC.
- Gate output includes full AC accountability table in session file

### FR-4: Architect Spec-Check Phase

New TDD phase between setup and RED:
- Loads: story context (including `## Assumptions`), epic context, sibling story ACs from sprint YAML, prior sibling session archives (for completed stories' deviation manifests)
- For stories without context docs: falls back to story titles + ACs from sprint YAML
- Validates each assumption against available data
- Flags broken assumptions (prior story deviated from what this story assumes)
- Flags forward-looking conflicts
- Gate: `spec-check-pass` — passes with findings documented, fails only if story context is missing or assumptions section absent

### FR-5: Architect Spec-Reconcile Phase

New TDD phase after Reviewer, before SM finish:
- Loads: story context, epic context, PRD references, sibling story ACs, all in-flight deviation logs from TEA and Dev
- Compares final implementation against all specs
- Reviews each TEA/Dev deviation entry for accuracy and completeness
- Adds any deviations TEA/Dev missed under `### Architect (reconcile)`
- Reviews AC deferral justifications for continued accuracy post-review
- Produces the **definitive deviation manifest** — this is what the boss reads
- Gate: `spec-reconcile-pass` — passes when manifest is complete

### FR-6: Assumptions Section in Story Context

New required section in story context schema:
- `## Assumptions` — lists what this story assumes about sibling stories' outputs
- Each assumption references: sibling story ID, what's assumed, which spec/AC it's based on
- Populated by PM during context creation
- Validated by context gate (section must exist and be non-empty, or explicitly "No cross-story assumptions")

### FR-7: Simplify Toggle

- New `simplify_enabled` field in `.pennyfarthing/repos.yaml` per-repo config
- Default: `false`
- When `false`: TEA verify phase skips simplify teammate spawning
- When `true`: current behavior (simplify-reuse, simplify-quality, simplify-efficiency spawn as teammates)
- Workflow engine reads repos.yaml at TEA verify phase entry

### FR-8: Tandem Workflow Removal

- Delete: `tdd-tandem.yaml`, `review-tandem.yaml`, `bdd-tandem.yaml`
- Reassign any stories with `workflow: tdd-tandem` to `workflow: tdd`
- No replacement in this PRD — tandem rethink is a future epic

### FR-9: TDD Workflow Update

Updated `tdd.yaml` phases:

```yaml
phases:
  - name: setup        # SM
  - name: spec-check   # Architect (NEW)
  - name: red          # TEA
  - name: green        # Dev
  - name: verify       # TEA
  - name: review       # Reviewer
  - name: reconcile    # Architect (NEW)
  - name: finish       # SM
```

Gates per phase as documented in Gate Architecture table. Version bump required.

## Non-Functional Requirements

### Reliability

| Requirement | Measure |
|-------------|---------|
| Gate failures are recoverable | Agent receives specific error message identifying which field is missing or which AC is unaccounted; agent can fix and re-trigger gate without restarting the phase |
| No silent gate bypass | If a gate script fails to execute (crash, missing file), the phase blocks — never auto-passes |
| Graceful degradation for missing context | Spec-check falls back to story titles and ACs from sprint YAML when context docs are missing (see also: Design Principles). Missing context is logged as a finding, not a crash |
| Idempotent gate checks | Running a gate twice on the same session file produces the same result — no side effects from re-runs |

### Integration

| Requirement | Measure |
|-------------|---------|
| Deviation format is machine-parseable | Strict markdown structure per FR-1; parseable by regex or simple parser — no prose-only blocks (see also: Technical Success criteria) |
| Gate contracts are composable | `ac-completion` gate works standalone — any workflow phase can reference it without coupling to dev-exit |
| Session file is the single coordination artifact | All deviation data, AC status, and gate results live in the session file — no external state files |
| repos.yaml is read at runtime | `simplify_enabled` is read fresh at TEA verify entry, not cached at workflow start — config changes between phases take effect |

### Performance (By Design)

| Requirement | Note |
|-------------|------|
| Architect phases add pipeline latency | Two additional agent invocations per story (spec-check + spec-reconcile). This is acceptable — excellence over optimization (Principle 13). No performance target needed. |
| AC-completion gate blocks for operator input | Human-in-loop is by design, not a latency problem. No timeout — waits for operator response. |
