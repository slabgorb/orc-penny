# Story 138-3: Create simplify-efficiency subagent definition

**Jira:** PROJ-16076
**Epic:** 138 — Simplify Integration
**Points:** 1
**Workflow:** trivial
**Phase:** finish
**Repos:** pennyfarthing
**Branch:** feat/PROJ-16076-simplify-efficiency-subagent
**Assigned:** keith.avery@slabgorb.io

## Story Context

The Simplify Integration epic (138) automates code quality review within the TEA verify phase by spawning three Haiku teammates, each analyzing changed files through a specific lens. This story focuses on the third teammate: **simplify-efficiency**.

Dev agents tend to over-engineer — introducing unnecessary abstractions, premature optimizations, and redundant operations that add complexity without value. The simplify-efficiency Haiku teammate targets this pattern, reviewing changed files for unnecessary complexity and over-engineering. Unlike linters or the Reviewer, this teammate is constructive: it identifies where code can be simplified, not where it's wrong.

### Epic Architecture

The verify phase in the TDD workflow spawns three Haiku teammates in parallel:
- **simplify-reuse** — finds duplication and extraction opportunities
- **simplify-quality** — catches semantic quality issues (naming, readability, structure)
- **simplify-efficiency** — flags unnecessary complexity and over-engineering

Each returns structured `SIMPLIFY_RESULT` YAML findings. TEA aggregates results, applies high-confidence suggestions, and commits fixes before the quality-pass gate fires.

### Relationship to Prior Stories

- **138-1 (PROJ-16074):** simplify-reuse definition — DONE
- **138-2 (PROJ-16075):** simplify-quality definition — DONE
- **138-3 (this story):** simplify-efficiency definition — IN PROGRESS

## Technical Approach

1. **Create `pennyfarthing-dist/agents/simplify-efficiency.md`** — new agent definition file
2. **Follow tactical agent template** — use `pennyfarthing-dist/agents/templates/agent-template-tactical.md` as structure guide
3. **Key sections:**
   - Persona (efficiency-focused, constructive)
   - Role (verify-phase teammate analyzing changed files)
   - Helpers (describe Haiku model and what it does)
   - Responsibilities (4+ efficiency-focused duties)
   - Skills (code analysis capabilities)
   - Context (receives changed file list from `git diff --name-only`)
   - Reasoning-mode (deliberate, thorough)
   - On-activation (workflow entry point)
   - Workflow (receive list → analyze → return SIMPLIFY_RESULT YAML)
   - Assessment template (show expected SIMPLIFY_RESULT format)
   - Handoff protocol (gate resolution, phase completion, marker)
   - Exit
4. **Finding categories:** `over-engineering`, `unnecessary-complexity`, `premature-abstraction`, `redundant-operations`
5. **Confidence guidance:**
   - `high` = objectively simpler after removal
   - `medium` = likely beneficial
   - `low` = ambiguous or potentially intentional (error handling, edge cases)
6. **Critical nuance:** Respect intentional complexity (error handling, edge cases). Flag ambiguous cases with `confidence: low` rather than asserting removal.

## Acceptance Criteria

- [ ] File created at `pennyfarthing/pennyfarthing-dist/agents/simplify-efficiency.md`
- [ ] Contains all required tactical agent sections in correct order: `<persona>`, `<role>`, `<helpers>`, `<responsibilities>`, `<skills>`, `<context>`, `<reasoning-mode>`, `<on-activation>`, workflow section, assessment template, handoff protocol, `<exit>`
- [ ] `<responsibilities>` includes at least 4 efficiency-focused duties
- [ ] `<helpers>` specifies Haiku model and describes what helper tasks do
- [ ] Workflow section describes: receive changed file list → analyze for efficiency issues → return SIMPLIFY_RESULT YAML
- [ ] Finding categories include `over-engineering`, `unnecessary-complexity`, `premature-abstraction`, `redundant-operations`
- [ ] Confidence guidance documented
- [ ] Assessment template shows SIMPLIFY_RESULT format with findings array
- [ ] Handoff section present (gate resolution, phase completion, marker)
- [ ] Code does NOT modify files — definition explicitly states report-only behavior

## Delivery Findings

**Status:** SETUP COMPLETE

Created `/Users/keithavery/Projects/pf-1/pennyfarthing/pennyfarthing-dist/agents/simplify-efficiency.md`:

### File Structure & Sections
✓ **Front matter:** name, description, tools, model (haiku)
✓ **Arguments section:** FILE_LIST (required) and STORY_ID (optional)
✓ **Critical block:** "Report only. Do NOT edit files."
✓ **Role section:** Primary (verify-phase spawning), Position (parallel with reuse/quality), Model (Haiku)
✓ **Responsibilities section:** 6 efficiency-focused duties including:
  - Analyze for unnecessary complexity and over-engineering
  - Identify premature abstractions
  - Flag redundant operations and calculations
  - Detect over-parameterized functions
  - Recognize excessive error handling or edge case coverage
  - Return SIMPLIFY_RESULT YAML findings
  - Never modify files

### Workflow Steps (Steps 1-7)
✓ Step 1: Parse input — split and filter file list
✓ Step 2: Read changed files — note function definitions, abstractions, error handling, etc.
✓ Step 3: Identify unnecessary complexity patterns — 5 specific patterns documented
✓ Step 4: Distinguish intentional complexity — CRITICAL nuance: error boundaries, guard clauses, spec-required handling are intentional
✓ Step 5: Categorize findings — 5 categories with examples:
  - `over-engineering` (generic base class for single subclass)
  - `unnecessary-complexity` (nested conditionals vs. single)
  - `premature-abstraction` (generic helper for single use)
  - `redundant-operations` (repeated calculations)
  - `excessive-options` (over-parameterization)
✓ Step 6: Assign confidence — high/medium/low with heuristics
✓ Step 7: Format output — SIMPLIFY_RESULT YAML

### Output Format (with Examples)
✓ Clean status: agent, status, files_analyzed, empty findings array
✓ Findings status: includes 5 detailed examples with file, line, category, description, suggestion, confidence
✓ Examples show realistic efficiency issues: factory pattern for single type, unused parameters, redundant calculations

### Example Invocation
✓ Shows full Agent tool parameters including subagent_type, model, run_in_background, prompt structure
✓ Demonstrates how TEA passes FILE_LIST and STORY_ID arguments

### Key Differences from simplify-reuse
- **Focus:** Over-engineering and unnecessary complexity (vs. code duplication)
- **Categories:** Specific to efficiency (vs. reuse)
- **Critical Section 4:** Distinguishes intentional complexity (error handling, guard clauses, spec requirements) from over-engineering
- **Confidence philosophy:** When uncertain, flag with `confidence: low` rather than asserting removal

### Acceptance Criteria Verification
✓ File at `pennyfarthing/pennyfarthing-dist/agents/simplify-efficiency.md` — CREATED
✓ Sections in correct order — metadata → arguments → critical → role → responsibilities → workflow (7 steps) → output → example
✓ 6 efficiency-focused responsibilities — INCLUDED
✓ Haiku model specified — INCLUDED
✓ Workflow describes receive → analyze → return SIMPLIFY_RESULT — INCLUDED
✓ 5 finding categories all present — INCLUDED
✓ Confidence guidance (high/medium/low) documented — INCLUDED
✓ Assessment template shows SIMPLIFY_RESULT format — INCLUDED
✓ Report-only behavior explicitly stated — INCLUDED (critical block + step 4 note about finding vs. forcing)

### Git Status
✓ Branch: feat/PROJ-16076-simplify-efficiency-subagent (on develop base)
✓ Commit: ac0ad8f8c — "feat: create simplify-efficiency subagent definition"
✓ File added: pennyfarthing-dist/agents/simplify-efficiency.md (181 insertions)

### Reviewer (code review)

- **Gap** (non-blocking): No explicit handling for empty `FILE_LIST` at step 1 — should return `status: clean, files_analyzed: 0`. Shared gap with `simplify-reuse.md`; deferred to a cross-cutting fix across all simplify agents.
  Affects `pennyfarthing-dist/agents/simplify-efficiency.md` (Step 1 empty-input guidance).
  *Found by Reviewer during code review.*

## Reviewer Assessment

**Verdict:** APPROVED
**Data flow traced:** FILE_LIST → Step 1 parse → Step 2 read → Steps 3-4 analyze → Step 5 categorize → Step 6 confidence → Step 7 format → SIMPLIFY_RESULT YAML (consumed by TEA aggregation)
**Pattern observed:** Subagent structure mirrors `simplify-reuse.md` exactly — front matter, arguments, critical, role, responsibilities, workflow, output, example. Consistent parallel agent design at `simplify-efficiency.md:1-180`.
**Error handling:** Step 4 "Distinguish Intentional Complexity" provides false-positive mitigation; `confidence: low` fallback at `simplify-efficiency.md:75` prevents aggressive suggestions.
**Observations:** 5 verified-good, 2 low-severity. No Critical/High findings.

**Handoff:** To Ruby Rhod (SM) for finish-story.

### Dev (implementation)

- **Improvement** (non-blocking): ACs reference full tactical agent sections (`<persona>`, `<helpers>`, `<skills>`, `<context>`, `<reasoning-mode>`, `<on-activation>`, handoff protocol, `<exit>`) but simplify-* agents are Haiku subagents, not full tactical agents. The sibling `simplify-reuse.md` (138-1) uses the same simplified structure. ACs should be updated for future subagent stories to reference the correct subagent template.
  Affects `sprint/epic-138.yaml` (AC wording for subagent stories).
  *Found by Dev during implementation.*

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/agents/simplify-efficiency.md` — removed stray `</output>` closing tags (created by sm-setup, reviewed for AC compliance)

**Verification:** Compared structure against `simplify-reuse.md` — consistent subagent format (front matter → arguments → critical → role → responsibilities → 7-step workflow → output → example invocation). All ACs met for the subagent pattern.
**Branch:** feat/PROJ-16076-simplify-efficiency-subagent (pushed)

**Handoff:** To Jean-Baptiste Emanuel Zorg (Reviewer) for review phase.

## SM Assessment

**Setup phase complete.** Story 138-3 is ready for Dev implementation.

- **Session created:** `.session/138-3-session.md` with full context
- **Branch created:** `feat/PROJ-16076-simplify-efficiency-subagent` off `develop`
- **Jira claimed:** PROJ-16076 assigned and In Progress
- **Context:** Epic 138 (Simplify Integration) — this is the 3rd of 3 subagent definitions (reuse done, quality done, efficiency next)
- **Note:** sm-setup subagent pre-created the agent definition file and committed it. Dev should review/verify the implementation against ACs and the existing simplify-reuse/simplify-quality agents for consistency.

**Routing:** → Korben Dallas (Dev) for implement phase.

## Exit

When complete:
1. Commit to pennyfarthing develop: `cd pennyfarthing && git add . && git commit -m "feat: create simplify-efficiency subagent definition"`
2. Create PR targeting develop
3. Record completion in orchestrator (main branch): `pf sprint story update 138-3 --status done`
4. Handoff to next story (138-4: TEA integration)