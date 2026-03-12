# PRD: Benchmark Scenario Baseline

**Author:** Keith Avery
**Date:** 2026-03-06
**Status:** Draft
**Domain:** AI Evaluation & Measurement
**Project Context:** Brownfield — upgrading 10 existing scenarios across 7 categories

---

## Problem Statement

The benchmark scenario corpus is inconsistent in quality. Two scenarios (arch-002, pm-002) meet modern standards with anchored rubrics and persona influence mapping. Five are adequate but lack anchors. Two (tw-001, sm-001) are effectively broken — no rubric or scoring at all. None have red herrings, difficulty profiles, or gold standard references.

This inconsistency blocks all scientific measurement work. Multi-judge validation (Epic 44), precision/recall separation (Epic 41), and persona effectiveness experiments all require trustworthy, comparable test inputs. The scenarios are the foundation — everything built on top inherits their flaws.

## The "God Lifting Rocks" Problem

A core design constraint: an LLM designing test scenarios for LLM agents will unconsciously create tests it already knows how to pass. This produces benchmarks that measure "can this agent think like Claude" rather than "can this agent do good work."

**Mitigations baked into this PRD:**

1. **Source from real-world code** — OWASP/CWE vulnerability patterns, SWE-bench issues, open-source PRs. The AI assembles and formats; the content comes from human decisions.
2. **Human-directed bug seeding** — User describes failure modes ("add a race condition in the refund path"), AI implements them. Domain expertise directs what goes wrong.
3. **Real project history for open-ended scenarios** — Architecture, PM, and SM scenarios mined from actual Pennyfarthing decisions (installation, packaging, large refactors). Real tensions with known outcomes.
4. **Human-graded gold standards** — User scores 2-3 AI outputs per scenario rather than writing exemplar responses. Calibration comes from human judgment, not AI self-evaluation.
5. **Cross-model-family validation** — Run scenarios across Haiku/Sonnet/Opus. If all models ace a scenario, it doesn't discriminate. (Expand to non-Claude models when available.)

## Success Criteria

### Scenario Consistency
- All scenarios follow identical YAML structure with identical required fields
- All scenarios have BARS-anchored rubrics (4 dimensions: Correctness, Depth, Quality, Persona)
- All scenarios have difficulty profile metadata
- Scoring approaches are consistent within scenario families (detection vs. divergent)

### Trustworthy Results
- Inter-judge agreement on upgraded scenarios: Krippendorff's Alpha >= 0.67
- Score discrimination: >= 0.5 standard deviations between Haiku and Opus per scenario
- Zero scenarios without a complete, weighted rubric

### Coverage
- Each agent role has at least 2 scenarios testing meaningfully different challenges
- Code scenarios sourced from real-world patterns (not AI-invented)
- Open-ended scenarios sourced from real project history

## User Journeys

### Benchmark Runner
Picks a scenario, runs an agent, judges the result, compares across personas. Needs to trust that score differences reflect capability differences, not scenario quality differences.

### Scenario Author
Wants to add a new scenario. Follows the scenario-builder workflow, which enforces required fields (BARS anchors, difficulty profile, content sourcing). Cannot accidentally create another tw-001.

### Measurement Researcher
Filters scenarios by difficulty tier and category, runs experiments, analyzes results. Needs consistent metadata, reliable scoring, and known baseline data.

## Scenario Families

Two distinct families with different required fields:

### Detection Scenarios (code-review, dev, tea, test-writing)
- **Content source:** Real-world code from OWASP, CWE, SWE-bench, open-source repos
- **Bug seeding:** Human-directed — user describes failure modes, AI implements
- **Scoring:** Precision/recall separated (Epic 41 alignment)
- **Red herrings:** Required — code patterns that look suspicious but are correct
- **Rubric:** BARS anchors on all 4 dimensions + severity-weighted issue tracking

### Divergent Scenarios (architecture, pm, sm)
- **Content source:** Real project history — installation dilemmas, packaging decisions, refactor trade-offs
- **No single correct answer** — rubric measures reasoning quality, not conclusions
- **Persona influence mapping:** Required — document how different personas should approach the problem differently
- **Expected tendencies:** Required — what would a conservative vs. bold vs. analytical agent do?
- **Rubric:** BARS anchors on all 4 dimensions + weighted criteria categories

## Current State Assessment

| Scenario | Category | Quality | Key Gaps |
|----------|----------|---------|----------|
| arch-001 | architecture | Adequate | No BARS anchors, checklist scoring |
| arch-002 | architecture | Gold standard | Missing difficulty profile, red herrings |
| cr-001 | code-review | Adequate | No BARS, no depth measurement, no red herrings |
| cr-002 | code-review | Good | Multi-tier scoring but no BARS anchors |
| dev-001 | dev | Adequate | Severity-weighted only, no BARS |
| dev-002 | dev | Good | TDD discipline scoring, no BARS |
| pm-002 | pm | Gold standard | Missing difficulty profile |
| sm-001 | sm | Broken | No scoring formula, no weights, no anchors |
| tea-001 | tea | Adequate | Baseline/bonus structure but no scoring formula |
| tw-001 | test-writing | Broken | No rubric at all |

**Missing scenarios:** pm-001 (gap in PM coverage)

## Functional Requirements

### FR1: Scenario YAML Schema Enforcement
All scenarios must include:
```yaml
scenario:
  id: "{prefix}-{NNN}-{slug}"
  category: "{category}"
  family: "detection | divergent"

  difficulty_profile:
    tier: "easy | medium | hard | extreme"
    dimensions:
      code_complexity: 1-10      # detection only
      domain_knowledge: 1-10
      red_herring_count: N       # detection only
      issue_subtlety: 1-10       # detection only
    calibration:
      control_mean: null         # populated after baseline runs
      control_stddev: null
      n_runs: 0

  rubric:
    dimensions:
      correctness: { weight: 25 }
      depth: { weight: 25 }
      quality: { weight: 25 }
      persona: { weight: 25 }
    # BARS anchors referenced from guides/rubric-anchors.md

  content_source:
    type: "owasp | cwe | swe-bench | oss-pr | project-history | real-incident"
    reference: "URL or description of original source"
    human_modifications: "description of what was changed/seeded"
```

### FR2: Detection Scenario Requirements
- `known_issues[]` with severity classification (critical/high/medium/low)
- `red_herrings[]` with trap_type and location
- Scoring supports separate precision and recall calculation
- Code sourced from real-world patterns with human-directed bug seeding

### FR3: Divergent Scenario Requirements
- `persona_influence` section documenting how different approaches should diverge
- `expected_tendencies` mapping persona archetypes to likely choices
- `situation_tensions[]` documenting the genuine trade-offs with no clean answer
- Content sourced from real project history

### FR4: Gold Standard Process
- Run scenario against control agent, collect 2-3 responses
- Human grades responses (scores + brief rationale)
- Best response stored as calibration reference, not "correct answer"
- Stored in `gold_standard` field per scenario

### FR5: Scenario Builder Workflow Enforcement
- Update scenario-builder templates to require all FR1 fields
- Workflow blocks completion if required fields are empty
- Content sourcing step explicitly asks for real-world source

### FR6: Rebuild Broken Scenarios
- tw-001: Rebuild with real TypeScript code from open-source, proper BARS rubric
- sm-001: Rebuild using real sprint planning situation from project history

## Scope

### MVP — The Baseline
- [ ] Upgrade all 10 existing scenarios to consistent YAML schema (FR1)
- [ ] Add BARS anchors to all scenarios (reference rubric-anchors.md)
- [ ] Add difficulty_profile stubs to all scenarios (calibration data populated later)
- [ ] Rebuild tw-001 from real-world TypeScript code with full rubric
- [ ] Rebuild sm-001 from real project history with weighted scoring
- [ ] Source at least 2 code scenarios from OWASP/CWE patterns
- [ ] Source at least 2 open-ended scenarios from project history (installation, packaging, refactors)
- [ ] Update scenario-builder templates to enforce required fields (FR5)

### Growth — Reliability Layer
- [ ] Add red herrings to all code scenarios
- [ ] Human-grade gold standard responses for top 5 scenarios
- [ ] Fill pm-001 gap with real prioritization scenario
- [ ] Run baseline calibration across Haiku/Sonnet/Opus, populate difficulty_profile.calibration
- [ ] Validate inter-judge agreement >= 0.67 on upgraded scenarios

### Vision — Experimental Readiness
- [ ] Scenario corpus large enough for statistically significant persona comparisons
- [ ] Cross-model-family validation when non-Claude access available
- [ ] Scenario contribution model for other Pennyfarthing consumers
- [ ] Full difficulty stratification enabling context collapse experiments

## Content Sourcing Strategy

### Code Scenarios — Real Vulnerability Patterns
| Source | Best For | Example |
|--------|----------|---------|
| OWASP Top 10 | Security review scenarios | SQL injection, XSS, broken auth |
| CWE Database | Specific vulnerability types | CWE-89 (SQL injection), CWE-362 (race condition) |
| SWE-bench | Real GitHub issues | Bug reproduction from actual repos |
| Open-source PRs | Code review scenarios | Real review comments on real diffs |

### Open-Ended Scenarios — Project History Mining
| Topic Area | Real Tension | Agent |
|------------|-------------|-------|
| Installation | Cross-platform packaging, pipx vs pip vs brew, version conflicts | Architect |
| Packaging | pennyfarthing-dist as single source of truth, symlink topology, consumer init | Architect, PM |
| Large refactors | TypeScript-to-Python CLI migration, strangle vs rewrite, shipping while refactoring | Architect, SM |
| Prioritization | Benchmark reliability epics (41-46) ordering, P0 vs P2, dependency chains | PM |
| Sprint planning | Feature breakdown with real dependencies and capacity constraints | SM |

### Human-in-the-Loop Process
1. AI finds real-world source code or mines project history
2. AI presents clean scaffolding to human
3. Human directs modifications: "add a race condition here," "this reminds me of when we..."
4. AI implements, human reviews for realism
5. Human grades 2-3 AI responses to establish gold standard calibration

## Dependencies

- **rubric-anchors.md** — BARS definitions (exists, completed in Epic 42)
- **measurement-framework.md** — Wallach 4-level framework (exists)
- **persona-effectiveness.md** — Research basis for persona dimension (exists)
- **scenario-builder workflow** — Stepped workflow for creating new scenarios (exists, v12.5.0)
- **Epic 41** (precision/recall) — scoring formula for detection scenarios (planned)
- **Epic 44** (multi-judge) — inter-judge agreement validation (planned, P0)

## Risks

| Risk | Impact | Mitigation |
|------|--------|-----------|
| "God lifting rocks" — AI-designed tests are easy for AI | Benchmarks don't discriminate | Source content externally, human-directed seeding |
| Rubric anchors still produce central tendency | Scores cluster 6-7 despite BARS | Multi-judge validation + gold standard calibration |
| Real project history scenarios too specific to Pennyfarthing | Not generalizable | Focus on universal tensions (install, package, refactor) |
| Human grading bottleneck | Gold standards take time | Prioritize top 5 scenarios, grade in batches |
| Difficulty profiles require baseline data that doesn't exist yet | Can't populate calibration fields | Ship stubs first, populate after initial runs (Growth phase) |
