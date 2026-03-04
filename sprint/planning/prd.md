---
stepsCompleted:
  - step-01-init
  - step-02-discovery
  - step-03-success
  - step-04-journeys
  - step-05-domain (skipped)
  - step-06-innovation (skipped)
  - step-07-project-type
  - step-08-scoping
  - step-09-functional
  - step-10-nonfunctional
  - step-11-polish
  - step-12-complete
inputDocuments: []
workflowType: 'prd'
documentCounts:
  briefCount: 0
  researchCount: 0
  brainstormingCount: 0
  projectDocsCount: 0
classification:
  projectType: CLI Tool / Developer Tooling
  domain: Developer Experience (DX) / Build Infrastructure
  complexity: Medium
  projectContext: brownfield
---

# Product Requirements Document - Simplify Integration

**Author:** Keith Avery
**Date:** 2026-03-03

## Success Criteria

### User Success (The Agent)

- **TEA verify catches bloat before Reviewer** — Reviewer never has to reject for code quality issues that simplify would have caught
- **No regressions from simplify** — quality-pass gate after simplify ensures tests, lint, and types still pass after any applied fixes
- **Transparent reporting** — TEA summarizes what each teammate found and what was applied/rejected in the session assessment

### Business Success (Framework Health)

- **Faster review cycles** — fewer Dev-Reviewer round-trips on code quality issues
- **Context-efficient** — Haiku teammates keep token costs low; each loads only changed files in isolated context windows
- **Measurable improvement** — can track issues-found-per-story across reuse, quality, and efficiency categories

### Technical Success

- **Fan-out/fan-in pattern** — fits existing infrastructure (team block in workflow YAML, Agent tool with `run_in_background`)
- **No new gates or phases** — extends the existing verify phase, doesn't add workflow complexity
- **Haiku teammates** — follows Rule 7 (never Opus for mechanical tasks)
- **quality-pass is the safety net** — catches any regressions from applied fixes
- **Configurable** — team block can be present or absent; base TDD verify works without it

### Measurable Outcomes

- Reviewer rejections for code quality issues: **reduced 50%+**
- Simplify teammate execution time: **< 30s** (parallel Haiku agents on changed files)
- False positive rate: **< 10%** (suggestions TEA rejects as incorrect)

## Product Scope

### MVP - Minimum Viable Product

- 3 Haiku subagent definitions (`simplify-reuse`, `simplify-quality`, `simplify-efficiency`)
- TEA agent updated to spawn teammates during verify phase and aggregate results
- `tdd` and `tdd-tandem` workflow YAMLs updated with team block on verify phase
- Session assessment template updated to include simplify findings report

### Growth Features (Post-MVP)

- Simplify metrics dashboard in BikeRack GUI
- Custom focus areas per project (`CLAUDE.md` rules fed to teammates)
- Extension to `trivial` and `bdd` workflows
- Historical trend tracking (are agents getting cleaner over time?)

### Won't Have (Explicit Out of Scope)

- No new workflow phases — verify is sufficient
- No new gates — quality-pass already catches regressions
- No changes to Reviewer agent — Reviewer stays adversarial, simplify is constructive
- No simplify on unchanged files — only `git diff` scope

## User Journeys

### Journey 1: TEA Verify with Simplify (Happy Path)

TEA activates for verify phase. Reads session file, sees `team:` block with three simplify teammates. TEA identifies changed files via `git diff`, spawns all three Haiku teammates in parallel with the file list. Each teammate runs its focused analysis, reports findings via structured output. TEA collects all three reports, reviews each suggestion — applies clean wins, rejects false positives (e.g., "that repeated code is intentional"). TEA commits fixes: `refactor: simplify code per verify review`. Quality-pass gate fires — lint, typecheck, tests all green. TEA writes assessment with simplify report section. Hands off to Reviewer. Reviewer gets cleaner code, focuses on logic and security.

### Journey 2: Simplify Finds Nothing (Clean Code)

Dev wrote clean code. TEA spawns three teammates. All three report: no issues found. TEA notes "simplify: clean" in assessment, moves straight to quality-pass gate. Zero overhead beyond the parallel agent spawn time.

### Journey 3: Simplify Causes a Regression (Safety Net)

A simplify teammate suggests removing "redundant" error handling. TEA applies it. Quality-pass gate fires — tests fail. TEA sees the regression, reverts the simplify change, re-runs gate. Gate passes. TEA notes in assessment: "simplify-efficiency suggestion reverted — error handling was intentional, tested by test_error_boundary." Lesson captured.

### Journey 4: Human Operator Reviewing Results

The human operator opens the session file after a story completes. The TEA Assessment has a new section:

```
### Simplify Report
- **Reuse:** Extracted shared validation to `validate_input()` (3 call sites)
- **Quality:** Renamed `x` → `config_path` in 2 files
- **Efficiency:** No issues found
- **Applied:** 2/2 suggestions | **Rejected:** 0
```

Visible exactly what simplify did and whether it's earning its keep.

### Journey 5: Workflow Without Simplify (Trivial/Chore)

A 1-point chore goes through the `trivial` workflow. No verify phase, no simplify teammates. Nothing changes for small work. Simplify only activates on TDD workflows where the verify phase exists.

### Journey Requirements Summary

| Capability | Revealed By |
|-----------|-------------|
| Teammate spawning in verify phase | Journey 1 |
| Changed file discovery (`git diff`) | Journey 1 |
| Structured finding reports | Journeys 1, 2 |
| TEA aggregation and judgment | Journey 1 |
| Regression detection and rollback | Journey 3 |
| Session assessment simplify section | Journeys 1, 2, 3, 4 |
| Workflow-level configurability | Journey 5 |

## Project Type: CLI Tool / Developer Tooling

### Command Structure

No new CLI commands. Simplify integration is invisible to the user — it runs automatically when TEA enters the verify phase on workflows with a `team:` block containing simplify teammates. No flags, no config, no opt-in beyond the workflow YAML.

### Architecture Pattern

Fan-out/fan-in within an existing workflow phase:

```
TEA (verify leader, Opus)
  ├── simplify-reuse (Haiku, background)
  ├── simplify-quality (Haiku, background)
  └── simplify-efficiency (Haiku, background)
       │
       └── TEA aggregates → applies/rejects → quality-pass gate
```

### Integration Points

| Integration Point | Mechanism | Existing? |
|-------------------|-----------|-----------|
| Workflow YAML `team:` block | `tdd.yaml`, `tdd-tandem.yaml` verify phase | Yes (extend) |
| TEA agent verify behavior | `agents/tea.md` | Yes (extend) |
| Subagent definitions | `agents/simplify-*.md` | No (create 3 new) |
| Session assessment template | TEA assessment in session file | Yes (extend) |
| Changed file discovery | `git diff --name-only` | Yes (reuse) |

## Detailed Scoping

### Phase 1: MVP

| Deliverable | Priority | Effort | Dependencies |
|------------|----------|--------|--------------|
| `simplify-reuse.md` agent definition | P0 | 1pt | None |
| `simplify-quality.md` agent definition | P0 | 1pt | None |
| `simplify-efficiency.md` agent definition | P0 | 1pt | None |
| TEA agent verify phase update | P0 | 2pt | Agent defs |
| `tdd.yaml` verify team block | P0 | 1pt | Agent defs |
| `tdd-tandem.yaml` verify team block | P0 | 1pt | Agent defs |
| TEA assessment template update | P1 | 1pt | TEA update |

**Total MVP: ~8 points**

### Phase 2: Growth

| Deliverable | Priority | Effort |
|------------|----------|--------|
| BikeRack simplify metrics panel | P2 | 3pt |
| CLAUDE.md rule injection to teammates | P2 | 2pt |
| `bdd.yaml` / `bdd-tandem.yaml` extension | P2 | 1pt |
| `trivial.yaml` review-phase integration | P3 | 2pt |
| Historical trend tracking | P3 | 3pt |

## Functional Requirements

### FR-1: Simplify Teammate Agent Definitions

Three Haiku subagent definitions at `pennyfarthing-dist/agents/`:

**FR-1.1: `simplify-reuse.md`**
- Receives: list of changed files (from `git diff --name-only`)
- Analyzes: duplicated logic, extractable helpers, shared patterns across changed files
- Returns: structured findings with file paths, line references, and suggested extractions
- Does NOT: modify files directly — reports only

**FR-1.2: `simplify-quality.md`**
- Receives: list of changed files
- Analyzes: naming conventions, readability, code structure, dead code, unnecessary comments
- Returns: structured findings with specific improvements and rationale
- Does NOT: enforce style rules already covered by lint (eslint, ruff) — focuses on semantic quality

**FR-1.3: `simplify-efficiency.md`**
- Receives: list of changed files
- Analyzes: unnecessary complexity, redundant operations, over-engineering, premature abstractions
- Returns: structured findings with specific simplifications and rationale
- Respects: intentional complexity (error handling, edge cases) — flags but doesn't force removal

### FR-2: TEA Verify Phase Extension

**FR-2.1: Changed File Discovery**
- TEA runs `git diff --name-only` against the base branch to identify files changed in the story
- Filters out non-code files (images, configs, lockfiles)
- Passes the file list to all three teammates

**FR-2.2: Teammate Spawning**
- TEA spawns all three simplify teammates using the Agent tool with `run_in_background: true`
- Each teammate receives the same file list but analyzes through its specific lens
- Teammates run as Haiku models (Rule 7)

**FR-2.3: Result Aggregation**
- TEA collects results from all three teammates via `TaskOutput`
- Reviews each finding — applies clean wins, rejects false positives
- If applying changes: commits with `refactor: simplify code per verify review`
- If rejecting: documents reason in assessment

**FR-2.4: Regression Safety**
- After applying any simplify fixes, TEA re-runs quality checks before the formal quality-pass gate
- If tests fail post-simplify: TEA reverts the offending change, documents in assessment
- quality-pass gate is the final safety net — unchanged from current behavior

### FR-3: Workflow YAML Updates

**FR-3.1: `tdd.yaml` verify phase**
```yaml
- name: verify
  agent: tea
  input: [implementation, passing_tests]
  output: [quality_verified]
  gate:
    file: gates/quality-pass
    type: quality_pass
    condition: Lint, typecheck, and all tests passing
  team:
    teammates:
      - agent: simplify-reuse
        task: "Review changed files for code duplication and extraction opportunities. Report findings only."
      - agent: simplify-quality
        task: "Review changed files for naming, readability, and structural quality. Report findings only."
      - agent: simplify-efficiency
        task: "Review changed files for unnecessary complexity and over-engineering. Report findings only."
```

**FR-3.2: `tdd-tandem.yaml` verify phase**
Same team block added alongside the existing architect teammate.

### FR-4: Session Assessment Extension

**FR-4.1: Simplify Report Section**
TEA assessment template gains a new section:

```markdown
### Simplify Report
- **Reuse:** {findings summary or "No issues found"}
- **Quality:** {findings summary or "No issues found"}
- **Efficiency:** {findings summary or "No issues found"}
- **Applied:** {N}/{total} suggestions | **Rejected:** {M} ({reasons})
```

### FR-5: Structured Finding Format

Each simplify teammate returns findings in a consistent format:

```yaml
SIMPLIFY_RESULT:
  agent: simplify-reuse | simplify-quality | simplify-efficiency
  status: clean | findings
  findings:
    - file: "path/to/file.ts"
      line: 42
      category: "duplicated-logic" | "naming" | "over-engineering" | etc.
      description: "What was found"
      suggestion: "What to do about it"
      confidence: high | medium | low
```

TEA uses `confidence: high` findings as auto-apply candidates and reviews `medium`/`low` manually.

## Non-Functional Requirements

### NFR-1: Performance

- All three teammates execute in parallel — total simplify time bounded by the slowest teammate
- Target: < 30 seconds for a typical story (10-20 changed files)
- No impact on quality-pass gate execution time (runs after simplify, not during)

### NFR-2: Token Efficiency

- Each Haiku teammate operates in an isolated context window — no cross-contamination
- Teammates receive only the changed file list and file contents — no session history, no story context
- TEA's context grows by ~3 structured result blocks (one per teammate) — minimal overhead

### NFR-3: Reliability

- If a teammate fails or times out, TEA proceeds with available results (partial failure tolerance per fan-out/fan-in pattern)
- quality-pass gate is unmodified — serves as the ultimate reliability backstop
- Teammate failures are logged in the session assessment, not silently swallowed

### NFR-4: Backward Compatibility

- Workflows without `team:` blocks on verify phase work exactly as before
- `trivial` workflow is unaffected (no verify phase)
- TEA agent behavior when no teammates are configured is unchanged
- No changes to any existing gate definitions

### NFR-5: Configurability

- Enabled/disabled by presence of `team:` block in workflow YAML — no runtime config needed
- Future: per-project CLAUDE.md rules can be injected into teammate prompts for project-specific focus areas
