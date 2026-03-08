# ADR-0034: Benchmark Scenario Baseline Architecture

**Status:** Proposed
**Date:** 2026-03-06
**Author:** Architect Agent (architecture workflow)
**PRD:** `sprint/planning/benchmark-scenario-baseline-prd.md`

## Context

The benchmark scenario corpus is inconsistent in quality. Two scenarios (arch-002, pm-002) meet modern standards with anchored rubrics and persona influence mapping. Five are adequate but lack BARS anchors. Two (tw-001, sm-001) are effectively broken with no rubric or scoring. None have red herrings, difficulty profiles, or gold standard references.

This inconsistency blocks scientific measurement work. Multi-judge validation (Epic 44), precision/recall separation (Epic 41), and persona effectiveness experiments all require trustworthy, comparable test inputs.

A core design constraint — the "God lifting rocks" problem — requires that an LLM designing test scenarios for LLM agents cannot be trusted to create tests that discriminate capability. Content must come from real-world sources with human direction.

### Current State

- **Epic 42** (Anchored Rubric Criteria): Done — `rubric-anchors.md` defines 4 dimensions x 5 bands
- **Epic 43** (Red Herrings): Schema done (43-1, 43-2), pilot remaining (43-3)
- **Epic 44** (Multi-Judge): Infrastructure done (44-1/2/3), high-variance test remaining (44-4)
- **Epic 45** (Gold Standards): All 4 stories in backlog
- **Epic 46** (Difficulty Profiles): Schema done (46-1), population remaining (46-2/3)
- Scenarios exist only in compiled Electron build, not in `pennyfarthing-dist/` source
- Two scenario families exist (code templates + open-ended templates) but lack schema enforcement

## Decision Drivers

1. **Schema evolution** — New required fields (difficulty_profile, content_source, red_herrings, gold_standard) need backward-compatible migration
2. **"God lifting rocks"** — Architectural guardrails required, not just process discipline
3. **Template-schema alignment** — Scenario builder must enforce required fields at gates
4. **Scenario storage** — Need clear source-of-truth location in `pennyfarthing-dist/`
5. **Cross-family scoring** — Detection and divergent families need different formulas but comparable final scores

## Considered Options

### Selected

1. **Schema Registry + Migration** — Version `schema.yaml` to v2, add required fields, provide migration script for existing scenarios. Schema is the single enforcement point.
2. **Content Provenance Chain** — `content_source` block is mandatory and validated. Every scenario must declare its real-world source. This is an architectural guardrail against "God lifting rocks" — a schema constraint, not a process rule.
3. **Family Adapter Scoring** — Detection scenarios produce precision/recall/severity scores; divergent scenarios produce reasoning-quality/persona-influence scores. A family adapter normalizes both to the same 0-100 weighted scale using the 4-dimension BARS rubric as the common denominator.

### Rejected

- **Microservices/event-driven** — File-based YAML system, not a distributed service
- **Plugin architecture for scenario types** — Only 2 families (detection + divergent), unlikely to grow
- **Database-backed scenario storage** — Scenarios are version-controlled YAML; DB adds complexity without benefit

## Decision Outcome

### Scenario YAML Schema v2

All scenarios conform to a versioned schema with two families sharing common fields and family-specific extensions.

**Common fields (both families):**
- `id`, `name`, `category`, `family` (detection|divergent), `difficulty`, `agent`, `version` ("2.0")
- `description`, `instructions`
- `difficulty_profile` — tier + dimensions + nullable calibration data
- `rubric` — 4 dimensions (correctness, depth, quality, persona) at 25% each
- `content_source` — type enum + non-empty reference + human_modifications
- `gold_standard` — nullable, populated only by human grading

**Detection-specific:** `code` block, `known_issues` (severity-classified), `red_herrings` (with trap_type), `scoring` (precision/recall weights)

**Divergent-specific:** `scenario` block, `situation_tensions`, `persona_influence`, `expected_tendencies` (archetype-to-choice mapping)

### Component Structure

| Component | Responsibility |
|-----------|---------------|
| **Schema Registry** (`schema.yaml` v2) | Required/optional fields per family, version tracking |
| **Scenario Validator** (`pf/benchmark/scenario_validator.py`) | Validates against schema, reports gaps |
| **Scenario Builder** (`workflows/scenario-builder/`) | Stepped workflow enforcing required fields at gates |
| **Detection Adapter** | Precision/recall/severity scoring for code scenarios |
| **Divergent Adapter** | Reasoning quality/persona influence scoring for open-ended scenarios |
| **Content Provenance** | Validates content_source block (real-world sourcing guardrail) |
| **Judge + Multi-Judge** | Scores responses using BARS rubric, delegates to family adapter |
| **Gold Standard Store** | Human-graded calibration references per scenario YAML |

### Interfaces

**Validator API:**
```python
def validate_scenario(path: str) -> dict:
    """Returns {success: bool, errors: list[str], warnings: list[str]}"""

def validate_all(scenarios_dir: str) -> dict:
    """Returns {success: bool, results: dict[str, ValidationResult]}"""
```

**Family Adapter API:**
```python
def score_detection(response: str, scenario: dict) -> dict:
    """Returns {precision, recall, severity_score, weighted_total}"""

def score_divergent(response: str, scenario: dict) -> dict:
    """Returns {reasoning_quality, persona_influence, weighted_total}"""
```

## Consequences

### Positive

- All scenarios conform to a single, enforced schema — no more broken scenarios like tw-001/sm-001
- Content provenance is an architectural constraint, not a process hope — every scenario must declare its real-world source
- Family adapters enable apples-to-apples comparison across detection and divergent scenarios via shared BARS normalization
- Nullable calibration fields allow incremental population without blocking scenario creation
- Schema versioning enables backward-compatible evolution

### Negative

- Migration effort for 10 existing scenarios (one-time cost)
- Human grading bottleneck for gold standards remains — architecture supports incremental population but doesn't eliminate the serial dependency
- `content_source.reference` validation is format-only; a determined agent could still fabricate plausible-looking references (mitigated by human review during scenario creation)

### Risks and Mitigations

| Risk | Impact | Likelihood | Mitigation |
|------|--------|------------|------------|
| "God lifting rocks" | High | High | Content provenance chain, human-directed seeding, cross-model validation |
| Schema migration breaks existing runs | High | Medium | Version field, v1 read + v2 write, migration script preserves history |
| Central tendency in BARS scoring | Medium | High | Multi-judge N=3-5, gold standard calibration, Alpha >= 0.67 |
| Perpetually-null calibration fields | Medium | Medium | Track null counts in `pf benchmark status` |
| Agent invents fake content_source | Medium | Medium | Human review during creation; validator checks non-empty reference |
| Wrong family adapter selected | Low | Low | Explicit `family` field drives dispatch, never inferred from category |

## Implementation Consistency Rules

These rules prevent AI agents from making conflicting implementation choices:

1. **All scenarios MUST have `family: detection | divergent`** — drives adapter selection, never inferred
2. **`content_source` is required and validated** — type from enum, reference non-empty
3. **BARS dimensions always 4 x 25%** — no per-scenario weight customization
4. **Detection uses `known_issues` + `red_herrings`**; divergent uses `persona_influence` + `situation_tensions` — never mix
5. **`difficulty_profile.calibration` starts null** — populated only by `pf benchmark calibrate`, never manually
6. **`gold_standard.graded_by` must be human** — validator rejects "ai", "auto", "claude", "agent"

## Conventions

- **Naming:** snake_case for YAML fields and Python
- **Errors:** Result objects `{success, data?, error?}` — never throw
- **Null semantics:** `null` = "not yet populated" (valid); missing field = validation error
- **Versioning:** `version: "2.0"` in scenario YAML; validator checks version and applies family-specific rules

## Related Decisions

- [ADR-0020](0020-benchmark-package-extraction.md) — Benchmark package extraction (superseded by ADR-0026)
- [ADR-0026](0026-single-package-consolidation.md) — Single package consolidation (benchmarking in core)
- [ADR-0032](0032-stepped-workflow-switch-gate-output-tags.md) — Stepped workflow gate/switch tags
