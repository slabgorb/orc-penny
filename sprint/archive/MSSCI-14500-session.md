# Story 86-5: Tandem workflow templates

**Status:** in-progress
**Jira:** MSSCI-14500
**Branch:** feature/MSSCI-14500-tandem-workflow-templates
**Repos:** pennyfarthing
**Workflow:** tdd
**Phase:** review
**Assigned:** keith.avery@1898andco.io
**Sprint:** 2606

---

## Context

Story 86-5 completes Phase 1 of Epic 86 (Agent Collaboration) by shipping pre-built workflow templates with tandem pairing configured for common patterns. Prior work has established the tandem protocol foundation:

**Prior work completed:**
- Story 86-1: Workflow schema `tandem:` block parsing ✓
- Story 86-2: Consultation protocol implementation ✓
- Story 86-3: Dialogue file management ✓
- Story 86-4: Agent tandem awareness (dev.md, tea.md, reviewer.md, architect.md updated) ✓

**What this story delivers:**

Three pre-built workflow templates with tandem consultation configured:

1. **`tdd-tandem.yaml`** — Standard TDD with full tandem chain
   - RED phase: TEA + Architect (file-watch)
   - GREEN phase: Dev + TEA (file-watch)
   - REVIEW phase: Reviewer + PM (file-watch)
   - Target: 5+ point stories where architectural review (green) and design discussion (review) provide high value

2. **`bdd-tandem.yaml`** — BDD with tandem on design and implementation
   - DESIGN phase: UX-Designer + Architect (file-watch)
   - GREEN phase: Dev + UX-Designer (file-watch)
   - REVIEW phase: Reviewer + PM (file-watch)
   - Target: UI/UX-heavy stories where designer-architect pairing shapes implementation

3. **`review-tandem.yaml`** — Focused review workflow with tandem consultation
   - REVIEW phase: Reviewer + Architect (focused architectural audit)
   - Target: Stories primarily needing architectural review, not full tandem chain

**Existing templates to verify:**
- `/Users/keithavery/Projects/pf-1/pennyfarthing/pennyfarthing-dist/workflows/tdd-tandem.yaml` (already exists, created in 86-1)
- `/Users/keithavery/Projects/pf-1/pennyfarthing/pennyfarthing-dist/workflows/bdd-tandem.yaml` (already exists, created in 86-1)
- `/Users/keithavery/Projects/pf-1/pennyfarthing/pennyfarthing-dist/workflows/review-tandem.yaml` (NEW — needs creation)

**Key files that will be created/modified:**
- `pennyfarthing-dist/workflows/review-tandem.yaml` (new)
- Documentation in each workflow: when-to-use guidance, comparison to non-tandem variants
- Ensure `/workflow list` detection tags each tandem workflow with `[tandem]` indicator
- Trigger routing logic: 5+ point stories auto-suggest tandem variants

**Dependencies satisfied:**
- 86-1: `tandem:` block schema → already parsing in BikeLane
- 86-4: Agent tandem awareness → dev, tea, reviewer know how to initiate consultations

**Tandem protocol foundation (from guides/tandem-protocol.md):**
- Backseat observer spawned at phase start if `tandem:` block present
- Observation file created at `.session/{STORY_ID}-tandem-{PARTNER}.md`
- PostToolUse hook injects observations via bell-mode
- Observation scopes: file-watch (git diff), tool-watch (test logs), context-watch (AC coverage)
- All consultation exchanges recorded for audit trail

## Acceptance Criteria

- [x] **Existing workflows verified:** `tdd-tandem.yaml` and `bdd-tandem.yaml` exist and follow spec
- [ ] **`review-tandem.yaml` created** with Reviewer + Architect pairing on review phase
- [ ] **Each template documented** with:
  - Tandem pairings table (phase, primary, partner, scope)
  - When-to-use guidance (which stories benefit from which template)
  - Comparison to non-tandem variant (what questions tandem answers)
  - Example: "Use tdd-tandem for 5+ pt features; tandem helps Dev + Architect align on patterns"
- [ ] **Trigger routing updated** to suggest tandem workflows:
  - 5+ point stories show tdd-tandem as suggested variant
  - UI/UX stories show bdd-tandem as suggested variant
  - Large reviews (10+ pts) show review-tandem as option
- [ ] **`/workflow list` reports tandem indicator:**
  - `tdd-tandem [tandem]` (with explicit tag or visual indicator)
  - `bdd-tandem [tandem]`
  - `review-tandem [tandem]`
- [ ] **Documentation in workflow YAML headers** explains tandem concept and when to use

## Key Findings — Existing Workflow Files

**Status:** tdd-tandem.yaml and bdd-tandem.yaml ALREADY EXIST ✓

Both workflows are fully implemented with `tandem:` blocks on phases:

**tdd-tandem.yaml structure:**
```
setup (SM)
  → red (TEA + Architect tandem, file-watch)
  → green (Dev + TEA tandem, file-watch)
  → review (Reviewer + PM tandem, file-watch)
  → finish (SM)
```

**bdd-tandem.yaml structure:**
```
setup (SM)
  → design (UX-Designer + Architect tandem, file-watch)
  → red (TEA)
  → green (Dev + UX-Designer tandem, file-watch)
  → review (Reviewer + PM tandem, file-watch)
  → finish (SM)
```

**Missing:** review-tandem.yaml (focused review workflow with Architect consultation)

**For TEA to implement:**
1. Verify existing tdd-tandem.yaml and bdd-tandem.yaml meet spec
2. Create review-tandem.yaml with minimal phases (e.g., setup → review → finish)
3. Add inline documentation to each YAML explaining tandem concept and when-to-use
4. Ensure gates match non-tandem variants (gates are tandem-agnostic)
5. Add `[tandem]` tag or similar to trigger metadata for workflow selection UI

---

## TEA Assessment

**Tests Required:** Yes
**Test File:** `packages/core/src/workflow/tandem-workflow-templates.test.ts`

**Tests Written:** 34 tests covering 6 ACs
**Passing:** 17 | **Failing:** 17
**Status:** RED (failing on assertions — ready for Dev)

**Failing tests by category:**
- **AC1 tdd-tandem pairing:** green phase partner is `tea`, should be `architect` (1 fail)
- **AC1 bdd-tandem pairing:** red phase missing tandem block for TEA + Dev (1 fail)
- **AC2 review-tandem:** file does not exist (6 fails)
- **AC3/AC6 documentation:** when-to-use guidance missing from YAML comments (3 fails)
- **AC4 trigger routing:** tdd-tandem `points.min` is 3, should be 5 (2 fails)
- **AC5 tandem indicator:** review-tandem not loadable for tag check (1 fail)
- **Integration:** only 2 tandem workflows found, need 3 (1 fail)

**Dev action items:**
1. Create `review-tandem.yaml` (setup → red → green → review(+architect) → finish)
2. Update tdd-tandem green phase: `partner: tea` → `partner: architect`
3. Add tandem block to bdd-tandem red phase: `tandem: { partner: dev, scope: file-watch }`
4. Change tdd-tandem `triggers.points.min: 3` → `5`
5. Add when-to-use guidance comments to all 3 tandem YAML files
6. Ensure `triggers.tags` includes `'tandem'` on review-tandem

**Handoff:** To Jack Torrance (Dev) for GREEN implementation

---

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/workflows/tdd-tandem.yaml` - Fixed green phase partner (tea → architect), raised points.min (3 → 5), added when-to-use docs
- `pennyfarthing-dist/workflows/bdd-tandem.yaml` - Added tandem block to red phase (TEA + Dev), added when-to-use docs
- `pennyfarthing-dist/workflows/review-tandem.yaml` - Created new workflow (TDD + architect tandem on review), with full docs

**Tests:** 34/34 passing (GREEN)
**PR:** #931 - feat(86-5): implement tandem workflow templates
**Branch:** feature/MSSCI-14500-tandem-workflow-templates (pushed)

**Handoff:** To Roland Deschain (Reviewer) for code review

---

## Reviewer Assessment

**Verdict:** APPROVED

**Data flow traced:** YAML file → loadWorkflowFile() → parseYaml → validateWorkflow() → WorkflowDefinition → routeStoryToWorkflow() (safe: schema validates partner names, scope values, gate types at parse time)

**Pattern observed:** Consistent sibling-workflow pattern — tandem variants mirror base workflow structure with added tandem blocks. Good naming convention `{base}-tandem`. Documentation headers follow established format at `review-tandem.yaml:1-15`.

**Error handling:** Schema validation catches malformed YAML, missing fields, invalid scope values, invalid gate types. loadWorkflowFile handles ENOENT gracefully. No new error paths introduced.

**Observations:**
| Severity | Observation | Location |
|----------|-------------|----------|
| [VERIFIED] | Phase parity matches base workflows | All 3 tandem YAML files |
| [VERIFIED] | Gate types identical to base variants | All 3 tandem YAML files |
| [VERIFIED] | Tandem partner/scope values valid | workflow-schema.ts:416 validates |
| [VERIFIED] | Documentation complete with when-to-use | All 3 YAML comment headers |
| [MEDIUM] | Trigger overlap: review-tandem wins over tdd-tandem for 8+ pt stories with `tandem` tag | review-tandem.yaml:64, tdd-tandem.yaml:69 |
| [LOW] | `default: false` explicit in tdd-tandem but omitted in review-tandem | tdd-tandem.yaml:72 vs review-tandem.yaml |

**Handoff:** To Johnny Smith (SM) for finish-story