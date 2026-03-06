# Workflow Session: architecture

**Workflow:** architecture
**Type:** stepped
**Agent:** architect
**Started:** 2026-03-06T17:18:25Z

## Workflow State
- **Workflow Name:** architecture
- **Type:** stepped
- **Mode:** create
- **Started:** 2026-03-06T17:18:25Z
- **Last Updated:** 2026-03-06T17:47:09Z
- **Current Step:** 9
- **Steps Completed:** [1, 2, 3, 4, 5, 6, 7, 8]
- **Status:** completed
- **Notes:** Session created via pf workflow start

## Progress
- Total Steps: 8
- Completion: 100%

---

## Architecture Session: Benchmark Scenario Baseline

### Inputs Gathered
- PRD: `sprint/planning/benchmark-scenario-baseline-prd.md` (Draft, 2026-03-06)
- Existing ADRs:
  - ADR-0020: Benchmark package extraction (Proposed, superseded by ADR-0026)
  - ADR-0026: Single package consolidation (Accepted) — benchmarking stays in core, loaded on demand
  - ADR-0032: Stepped workflow gate/switch tags — rubric-like gate evaluation patterns
- Dependencies: rubric-anchors.md (Epic 42, done), measurement-framework.md (exists), scenario-builder workflow (v12.5.0)
- Constraints: Depends on Epic 41 (precision/recall) and Epic 44 (multi-judge) for Growth phase

### Stakeholders
- Decision maker: Keith Avery (author, sole maintainer)
- Reviewers: N/A (solo project)

### Key Architectural Decisions Needed
1. **Scenario YAML schema** — standardize all 10 scenarios to consistent structure (detection vs divergent families)
2. **Content sourcing pipeline** — how real-world code (OWASP/CWE/SWE-bench) feeds into scenarios
3. **Gold standard process** — human-graded calibration references per scenario
4. **Scenario builder enforcement** — template updates to block incomplete scenarios
5. **"God lifting rocks" mitigations** — architectural guardrails against AI self-testing bias

### PRD Summary
- **Problem:** 10 benchmark scenarios with inconsistent quality; 2 broken, 5 missing BARS anchors, none have red herrings or difficulty profiles
- **Two families:** Detection (code-review, dev, tea) with precision/recall + Divergent (arch, pm, sm) with persona influence
- **MVP:** Upgrade all 10 to consistent schema, rebuild tw-001 and sm-001, add BARS anchors everywhere
- **Growth:** Red herrings, gold standards, pm-001 gap fill, cross-model calibration
- **Core risk:** "God lifting rocks" — AI designing tests it already knows how to pass

## Architecture Context

### Technical Constraints
- Schema consistency: All 10 scenarios must conform to single YAML schema with required fields per family
- Two scoring families: Detection (precision/recall, severity-weighted) vs Divergent (persona influence, no single correct answer)
- BARS anchors: 4 dimensions × 5 bands, defined in rubric-anchors.md (Epic 42 done)
- Multi-judge: N=1-5 judges, Krippendorff's Alpha ≥ 0.67 target (Epic 44 infra done)
- Content sourcing: Real-world code required — OWASP, CWE, SWE-bench, open-source PRs

### Current Landscape
- Scenario templates: Two in `workflows/scenario-builder/templates/` (code + open-ended)
- Schema validation: `scenarios/schema.yaml` exists but predates new required fields
- Judge skill: Solo, compare, phase-specific, SWE-bench modes
- Scoring modules: multi_judge.py, aggregator.py, integration.py in pf/benchmark/
- Scenario builder: Stepped workflow (8 steps), code and open-ended paths
- Scenarios live in compiled build only — not in pennyfarthing-dist/ source

### Key Concerns
1. **Schema evolution** — New required fields need backward-compatible migration for existing scenarios
2. **"God lifting rocks"** — Core risk requiring architectural guardrails, not just process
3. **Template-schema alignment** — Scenario builder must enforce FR1 fields
4. **Scenario storage** — Only in compiled Electron build, needs clear source-of-truth location
5. **Gold standard bottleneck** — Human grading is serial; support incremental population
6. **Cross-family scoring** — Detection/divergent need different formulas but comparable final scores

### Recent Work Context
- Epic 42 (Anchored Rubric Criteria): Done, archived
- Epic 43 (Red Herrings): 43-1 schema done, 43-2 builder integration done, 43-3 pilot remaining
- Epic 44 (Multi-Judge): 44-1/2/3 done, 44-4 high-variance test remaining
- Epic 45 (Gold Standards): All 4 stories in backlog (P2)
- Epic 46 (Difficulty Profiles): 46-1 schema done, 46-2/46-3 remaining
- Sprint 94% complete (251/267 points), 8 stories / 16 points remaining

## Pattern Analysis

### Selected Patterns
1. **Schema Registry + Migration** — Version schema.yaml v2, add required fields, migration script for existing scenarios. Schema is the single enforcement point.
2. **Content Provenance Chain** — `content_source` mandatory and validated. Architectural guardrail against "God lifting rocks" — schema constraint, not process rule.
3. **Family Adapter Scoring** — Detection (precision/recall/severity) and Divergent (reasoning-quality/persona-influence) normalized to 0-100 via 4-dimension BARS rubric as common denominator.

### Rejected
- Microservices/event-driven (file-based YAML system, not distributed)
- Plugin architecture for scenario types (only 2 families, won't grow)
- Database-backed scenario storage (YAML is version-controlled, DB adds no value)

## Component Design

### Components
1. **Schema Registry** (schema.yaml v2) — required/optional fields per family, version tracking
2. **Scenario Validator** (pf/benchmark/scenario_validator.py) — validates against schema, reports gaps
3. **Scenario Builder** (workflows/scenario-builder/) — stepped workflow enforcing required fields at gates
4. **Detection Adapter** — precision/recall/severity scoring for code scenarios
5. **Divergent Adapter** — reasoning quality/persona influence scoring for open-ended scenarios
6. **Content Provenance** — validates content_source block (real-world sourcing guardrail)
7. **Judge + Multi-Judge** — scores responses using BARS rubric, delegates to family adapter
8. **Gold Standard Store** — human-graded calibration references per scenario YAML

### Boundary Decisions
- Schema is declarative YAML; validator is Python that reads it
- Builder calls validator at gate steps; blocks on missing required fields
- Judge delegates to correct adapter based on `scenario.family` field
- Scenarios live in `pennyfarthing-dist/scenarios/` (source), compiled into builds

### Implementation Consistency Rules
1. All scenarios MUST have `family: detection | divergent` — drives adapter selection
2. `content_source` is required and validated — type enum + non-empty reference
3. BARS dimensions always 4 × 25% — no per-scenario weight customization
4. Detection uses known_issues + red_herrings; divergent uses persona_influence + situation_tensions
5. `difficulty_profile.calibration` starts null — populated only by baseline runs
6. `gold_standard.graded_by` must be human — never "ai" or "auto"

## Interface Definitions

### Scenario YAML Contract (v2)
- Common: id, name, category, family (detection|divergent), difficulty, agent, version, description, instructions, difficulty_profile, rubric (4×25%), content_source, gold_standard
- Detection-specific: code block, known_issues (severity-classified), red_herrings, scoring (precision/recall)
- Divergent-specific: scenario block, situation_tensions, persona_influence, expected_tendencies
- Null semantics: null = "not yet populated" (valid), missing = validation error

### Validator API
- `validate_scenario(path) -> {success, errors[], warnings[]}`
- `validate_all(scenarios_dir) -> {success, results{}}`

### Family Adapter API
- `score_detection(response, scenario) -> {precision, recall, severity_score, weighted_total}`
- `score_divergent(response, scenario) -> {reasoning_quality, persona_influence, weighted_total}`

### Conventions
- snake_case for YAML and Python; result objects `{success, data?, error?}`
- version: "2.0" in scenario YAML; validator checks version
- content_source.reference must be non-empty; rubric weights must sum to 100
- gold_standard.graded_by cannot be "ai"/"auto"/"claude"/"agent"

## Risk Assessment

### Technical Risks
| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| "God lifting rocks" | High | High | Content provenance chain, human-directed seeding, cross-model validation |
| Schema migration breaks runs | High | Medium | Version field, v1 read + v2 write, migration script |
| Central tendency in BARS | Medium | High | Multi-judge N=3-5, gold standard calibration, Alpha ≥ 0.67 |
| Perpetually-null calibration | Medium | Medium | Track null counts in benchmark status |
| Gold standard bottleneck | Medium | High | Top 5 priority, batch grading, incremental population |
| Cross-family scoring inconsistency | Medium | Low | Family adapters normalize to 0-100 via shared BARS |

### AI Implementation Risks
- Agent invents fake content_source references → human review during creation
- Wrong family adapter selected → explicit family field, never inferred
- Agent sets calibration without baselines → only `pf benchmark calibrate` populates
- Red herrings that are actual bugs → human review step in builder
- Agent writes graded_by as "ai" → validator rejects

