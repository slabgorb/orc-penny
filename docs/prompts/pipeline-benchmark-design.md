# Pipeline Benchmark Design: TEA→Dev→Rev Chain

## Problem

The isolated review benchmark (serde bypass) measures "can this persona find bugs alone?" but the production pipeline is TEA→Dev→Rev where each agent's output feeds the next. Persona effects compound differently in chains vs isolation.

Key insight: a TEA who writes a test catching the serde bypass makes Dev's job trivial. A TEA who misses it puts all pressure on Reviewer. **The handoff quality matters more than individual capability.**

## Design

### Three-Stage Stateful Benchmark

```
Stage 1: TEA receives stimulus code + neutral prompt
         → Outputs: test file(s)

Stage 2: Dev receives stimulus code + TEA's test file(s)
         → Outputs: modified code (fixes)

Stage 3: Reviewer receives stimulus code + Dev's diff
         → Outputs: review with findings
```

Each stage's output is the literal input to the next stage. No editing, no summarization.

### Scoring

#### Per-Stage Scores (BARS, 1-10)
- **TEA:** Did the tests target the ground truth? Coverage breadth? Test quality?
- **Dev:** Did the fixes address the ground truth? Did they break anything? Code quality?
- **Reviewer:** Did the review catch what Dev missed? False positives? Actionable feedback?

#### Pipeline Score (the one that matters)
- **Ground truth resolved?** Binary — is the serde bypass fixed in the final output?
- **Handoff quality:** Did each stage leave the next stage with clear, actionable input?
- **Residual findings:** What's still broken after all three stages complete?
- **Coverage union:** Total distinct issues addressed across the chain

### Stimulus Requirements

The serde bypass stimulus is too easy for Dev (80-100% detection in isolation). For the pipeline benchmark we need:

1. **Current stimulus (medium):** Serde bypass. Baseline data exists. Good for validating the pipeline framework itself.
2. **Hard stimulus (new):** Something where isolated Dev detection is ~40-50%. This is where pipeline composition should shine — TEA + Dev + Rev together catch what none catch alone.

### Hard Stimulus Candidates

The ground truth should be something that:
- Requires multi-step reasoning (not a single derive macro)
- Benefits from different perspectives (TEA sees it from test angle, Dev from implementation, Rev from design)
- Has plausible red herrings that absorb attention

Ideas:
- **Lifetime/ownership bug** that only manifests under specific async usage patterns
- **Logic error in state machine** where one transition is silently wrong
- **TOCTOU race** in a file-based config loader
- **Integer overflow** in a pagination calculation that only triggers at boundary values

### Experimental Matrix

For each stimulus, test theme teams:

| Team | TEA | Dev | Reviewer |
|------|-----|-----|----------|
| Firefly | Jayne | Mal | River |
| MASH | Radar | Winchester | Potter |
| Hogan's Heroes | Hochstetter | Carter | Burkhalter |
| Gilligan's Island | Mary Ann | Professor | Mr. Howell |

Score each team's pipeline on the same stimulus. The question becomes: **which theme's team composition produces the best pipeline outcomes?**

### Control Conditions

1. **No-persona baseline:** Same three-stage pipeline with generic "TEA/Dev/Reviewer" prompts, no character. Measures the role-framing effect in isolation.
2. **Shuffled teams:** Mix personas across themes (e.g., Radar-TEA + Mal-Dev + Potter-Rev) to test whether within-theme cohesion matters.
3. **Solo reviewer:** Single agent reviews the code (current benchmark). Comparison shows pipeline value-add.

### Implementation

Each pipeline run requires 3 sequential agent calls (output of N feeds N+1). For N=5 per team, that's 15 agent calls per team, 60 for 4 themes, plus controls.

```yaml
pipeline_run:
  id: "firefly-serde-001"
  stimulus: "serde-bypass"
  theme: "firefly"

  stages:
    - role: tea
      character: Jayne Cobb
      input: [stimulus_code]
      output: test_files

    - role: dev
      character: Malcolm Reynolds
      input: [stimulus_code, stage_1.test_files]
      output: code_diff

    - role: reviewer
      character: River Tam
      input: [stimulus_code, stage_2.code_diff]
      output: review_findings

  scoring:
    ground_truth_resolved: bool
    per_stage: [tea_score, dev_score, reviewer_score]
    pipeline_score: float
    residual_findings: [list]
```

### Design Decisions (Locked In)

| # | Question | Decision | Rationale |
|---|----------|----------|-----------|
| 1 | Dev sees TEA tests as failing (RED→GREEN) or spec? | **Failing tests** | Matches TDD workflow; Dev must make them pass |
| 2 | Reviewer sees original + diff, or just final? | **Original + Dev's modified code** | Matches real PR review; can spot regressions |
| 3 | TEA catches bug but Dev introduces new one? | **Net score with deductions** | Regressions count against pipeline score |
| 4 | N=5 sufficient or need N=10? | **Start N=5**, escalate if variance high | Balances cost vs statistical power |
| 5 | Same persona in different pipeline positions? | **Deferred** | Theme-team composition first |

### Experimental Design: Hold Two, Vary One

Instead of only testing fixed theme teams, we isolate persona effects per seat
by holding the other two seats at **control baseline** (OCEAN 3/3/3/3/3, no persona).

**TEA Seat** (T0-T4): Control Dev + Control Rev, vary TEA persona
**Dev Seat** (D1-D4): Control TEA + Control Rev, vary Dev persona
**Rev Seat** (R1-R4): Control TEA + Control Dev, vary Rev persona
**Full Teams** (FF/MA/HH/GI): All three seats from same theme

| Config | TEA | Dev | Rev |
|--------|-----|-----|-----|
| T0 | Control | Control | Control |
| T1 | Jayne (Firefly) | Control | Control |
| T2 | Radar (MASH) | Control | Control |
| T3 | Hochstetter (HH) | Control | Control |
| T4 | Mary Ann (GI) | Control | Control |
| D1 | Control | Mal (Firefly) | Control |
| D2 | Control | Winchester (MASH) | Control |
| D3 | Control | Carter (HH) | Control |
| D4 | Control | Gilligan (GI) | Control |
| R1 | Control | Control | River (Firefly) |
| R2 | Control | Control | Potter (MASH) |
| R3 | Control | Control | Burkhalter (HH) |
| R4 | Control | Control | Howell (GI) |
| FF | Jayne | Mal | River |
| MA | Radar | Winchester | Potter |
| HH | Hochstetter | Carter | Burkhalter |
| GI | Mary Ann | Gilligan | Howell |

**17 configs x N=5 x 3 stages = 255 subagent calls**

Control theme (`pennyfarthing-dist/personas/themes/control.yaml`) uses OCEAN 3/3/3/3/3
with no style, no expertise, no catchphrases — the proper experimental baseline.

### Execution

Pipeline runs use the Agent tool (not nested CLI) for each stage.
Each stage's literal output is injected into the next stage's prompt.
Results saved to `internal/results/peloton/{config_id}/runs/run_{n}/`.

Scenario YAML: `benchmarks/test-cases/peloton/peloton-001-serde-bypass.yaml`
Runner scripts: `scripts/peloton-runner.sh`, `scripts/peloton-batch.sh`
