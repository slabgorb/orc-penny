# Workflow Session: scenario-discovery

**Workflow:** scenario-discovery
**Type:** stepped
**Agent:** orchestrator
**Started:** 2026-03-06T23:09:10Z

## Workflow State
- **Workflow Name:** scenario-discovery
- **Type:** stepped
- **Mode:** create
- **Started:** 2026-03-06T23:09:10Z
- **Last Updated:** 2026-03-07T11:11:25Z
- **Current Step:** 8
- **Steps Completed:** [1, 2, 3, 4, 5, 6, 7]
- **Status:** completed
- **Notes:** Peloton pipeline harness built and validated with N=1 proof-of-concept

## Progress
- Total Steps: 7
- Completion: 100%

---

## Handoff Context

### What Was Done

**Steps 1-3 completed. Step 4 (Observe) in progress — data collected, analysis pending codification.**

#### Step 1: Source
- Source type: `lang-review`
- Reference: `rust-review-checklist.md` check #8 (from orc-ax-2 `.pennyfarthing/gates/`)
- Ground truth: `#[derive(Deserialize)]` bypasses validating `new()` constructor. Fix: `#[serde(try_from)]`. CWE-20.
- Family: `detection`
- Origin PRs: PR#53 I10/I12, PR#50 I10

#### Step 2: Prepare
- ~85-line Rust stimulus with `ApiKey` (validated constructor + derive Deserialize), `RateLimitConfig` (red herring: pub fields, no invariants), `WebhookPayload` (deserializes ApiKey from external input), and 2 tests
- Red herrings: (1) `unwrap()` in test helper, (2) `RateLimitConfig` pub fields
- Neutral prompt: "Review this Rust code. What issues do you see? Prioritize them."
- Selected agents: dev, reviewer, tea, architect

#### Step 3: Party Mode (original run)
- Ran party mode with Firefly crew (Mal/dev, River/reviewer, Jayne/tea, Inara/architect)
- River found serde bypass first, all 4 converged on it as critical
- Novel findings: case sensitivity misclassification, untestable invariant framing
- **Methodological concern raised:** party mode prompts lean agents toward specific approaches, sequential visibility creates anchoring effects, observations not independent

#### Step 3b: Factorial Redesign (the key experiment)
- User proposed 4x4 agent-persona matrix to decompose role effect vs persona effect
- Ran 16 independent subagent calls: 4 personas (Mal, River, Jayne, Inara) x 4 roles (Dev, Reviewer, TEA, Architect)
- Same stimulus, minimal prompt, no social influence between runs

### Key Findings

#### Detection Matrix (did the run find the ground truth serde bypass?)

| | Mal | River | Jayne | Inara |
|---|:---:|:---:|:---:|:---:|
| Dev | Y | Y | Y | Y |
| Reviewer | N | N | N | N |
| TEA | Y | N | Y | Y |
| Architect | Y | N | N | N |

**By role:** Dev 100%, TEA 75%, Architect 25%, Reviewer 0%
**By persona:** Mal 75%, Jayne 50%, Inara 50%, River 25%

#### The Reviewer Paradox
- Reviewer role (adversarial: "find problems, assume it's broken") has 0% detection on ground truth
- All 4 Reviewer runs converged on same #1: Serialize/Debug leaks secret keys
- Adversarial framing creates tunnel vision toward high-drama findings, suppresses subtle structural ones
- **User insight:** This is correct behavior in context — Dev fixes structural bugs, Reviewer catches what Dev leaves behind. They work in tension. The pipeline is the unit, not the individual.

#### Team Composition Analysis
- Computed coverage unions for all 12 non-self Dev+Reviewer pairings
- 15 distinct findings cataloged across all 16 runs
- Best teams: Any Dev + Mal-as-Reviewer = 13/15 (87%)
- Worst teams: Any Dev + River-as-Reviewer = 10-11/15 (67-73%)
- Reviewer seat has MORE leverage than Dev seat (3-4 finding swing vs 1-3)
- Mal's balanced personality resists role-framing tunnel vision; River's intensity amplifies it
- Full analysis: `docs/prompts/team-composition-analysis.md`

### What Remains

#### Step 4 Status: BARS analysis done, competence axis experiment in progress
- BARS analysis complete: `docs/prompts/serde-bypass-bars-analysis.md`
- Competence axis Phase 1 (N=1, 12 runs): `docs/prompts/competence-axis-results.md`
- Competence axis Phase 2 (N=5, 16 of 32 runs complete): Results overturning Phase 1 conclusions
- Pending: 4 Burkhalter-Reviewer runs, 1 Klink-Reviewer run still completing in background
- Stimulus code saved: `docs/prompts/serde-bypass-stimulus.rs`

#### Key Phase 2 Finding: N=1 is dangerously misleading
- Gilligan-Dev: 4/5 (80%) — Phase 1 said 0% (was noise)
- Carter-Dev: 2/5 (40%) — Phase 1 said 100% (was noise)
- Klink-Reviewer: 3/4+ (75%+) — Phase 1 said 0% (was noise)
- Competence axis effect may be smaller than OCEAN/role effects

#### MASH Comparison (Winchester vs Frank Burns) — COMPLETE
- Winchester-Dev N=5: **5/5 (100%)** F1, mean 11.0 findings, 19 unique
- Frank Burns-Dev N=5: **5/5 (100%)** F1, mean 9.0 findings, ~12 unique
- **Result:** Dev role dominates persona. Competence axis = zero effect on F1 detection.
- Competence affects breadth (Winchester 19 vs Burns 12 unique findings) but not ground truth.

#### Step 4 Key Insight: Peloton Testing (Pipeline Benchmark)
- Current benchmark measures "find bugs in isolation" — useful for persona characterization
- But the real pipeline is TEA→Dev→Rev where each agent's output is the next agent's input
- A TEA who writes a serde bypass test makes the Dev's job trivial
- A TEA who misses it puts all pressure on Reviewer
- **Need a pipeline benchmark** for Step 5: three-stage, stateful, score the chain not the individual

#### Steps 5-7
- Step 5 (Codify): Write TWO scenario types:
  1. Isolated review scenario (current serde bypass, with BARS and dual scoring)
  2. Pipeline scenario (TEA→Dev→Rev chain, scoring the handoff quality)
- Step 6 (Validate): Run both scenario types through judge
- Step 7 (Verify Persona): MBTI-in-Thoughts persistence check

#### Open Questions (updated)
1. Why does Carter-Dev underperform at 40%? High-A (agreeableness) suppressing critical findings?
2. Why is Firefly Reviewer 0% when GI/HH Reviewers find F1 at 67-100%? River's high-N? Prompt wording?
3. Is the competence axis effect real but small, or drowned in stochastic noise?
4. Does scenario difficulty interact with competence axis? Need harder scenarios to see divergence
5. Pipeline benchmark design: how to score three-stage chains where each step depends on prior output?

### Files Created/Modified
- `.session/scenario-discovery-workflow-session.md` (this file)
- `docs/prompts/team-composition-analysis.md` — full 4x4 matrix with coverage unions and team scores

### Peloton Pipeline: Proof-of-Concept Complete

#### Harness Built
- `scripts/peloton-runner.sh` — single pipeline runner (can't use nested CLI, use Agent tool instead)
- `scripts/peloton-batch.sh` — batch orchestrator (17 configs × N=5)
- `pennyfarthing/benchmarks/test-cases/peloton/peloton-001-serde-bypass.yaml` — scenario YAML
- `docs/prompts/pipeline-benchmark-design.md` — updated with locked-in design decisions

#### N=1 Results: T0 (All Control) and T1 (Jayne TEA + Control Dev/Rev)

| | T0 (All Control) | T1 (Jayne TEA) |
|---|---|---|
| TEA found F1? | Yes | Yes |
| TEA test framing | `deserialize_bypasses_validation` — documents bug | `serde_bypass_creates_invalid_key` + `#[should_panic]` — documents bug + consequences |
| Dev fixed F1? | **NO** — preserved bypass, added panic-safe Display | **NO** — preserved bypass AND the panic |
| Rev caught it? | **YES** — "net-negative, reject PR" | **YES** — "made code strictly worse, reject" |
| Ground truth resolved? | **No** | **No** |

#### Critical Pipeline Finding: TEA Framing Trap
Both TEAs wrote tests that assert the bypass WORKS (`.unwrap()` on invalid deserialization).
The Dev dutifully made all tests pass — including the broken ones.
The Reviewer caught it both times but by then the pipeline has enshrined the bug.

**The TEA's test framing determines whether the Dev fixes or preserves the bug.**
This is the key Peloton insight — individual competence doesn't matter if the handoff framing is wrong.

#### Experimental Design: Hold Two, Vary One
- 13 isolated configs (T0-T4, D1-D4, R1-R4) + 4 full theme teams = 17 configs
- N=5 per config = 85 pipelines = 255 subagent calls
- Control theme (OCEAN 3/3/3/3/3) as experimental baseline
- Results dir: `internal/results/peloton/{config_id}/runs/run_{n}/`

#### Execution Mechanics
- Cannot use nested `claude` CLI — must use Agent tool for each stage
- Each pipeline = 3 sequential Agent calls (TEA → Dev → Rev)
- TEA output injected literally into Dev prompt, Dev output into Rev prompt
- ~25K tokens per pipeline run

#### Open Question for Next Session
Should TEA tests assert CORRECT behavior (forcing Dev to fix) or CURRENT behavior (documenting bugs)?
This may need a TEA prompt variant experiment before running the full matrix.

### How to Resume
```bash
pf workflow resume scenario-discovery
```
Continue with Peloton batch runs:

1. **Immediate:** Launch T2-T4 TEA seat variations (Radar, Hochstetter, Mary Ann) at N=1 in parallel
   - Key question: do any personas write tests that DEMAND the fix vs document the bug?
   - Use Agent tool (not nested CLI) for each stage, 3 stages per pipeline
   - Each TEA uses Control Dev + Control Rev (isolate TEA persona effect)
2. **Then:** Run N=5 for all 17 configs systematically
   - 17 configs × N=5 = 85 pipelines = 255 agent calls
   - ~25K tokens per pipeline, ~60s each
   - Runs within a config can be parallelized (independent)
   - Results go to `internal/results/peloton/{config_id}/runs/run_{n}/`
3. **Execution pattern per pipeline:**
   - Agent TEA (background) → wait → save tea.json → read TEA result
   - Agent Dev (background, inject TEA output) → wait → save dev.json → read Dev result
   - Agent Rev (background, inject Dev output) → wait → save rev.json
   - Save pipeline.json summary
4. **Prompt templates** are in the session — read T0/T1 prompts as reference
   - Control persona: "You are a {role}. Respond professionally and directly."
   - Themed persona: "You are {character}. **Style:** ... **Expertise:** ... **Catchphrases:** ..."
   - TEA prompt: "write comprehensive test suite, focus on correctness/edge cases/security"
   - Dev prompt: "fix source code so all tests pass, do NOT modify tests, show complete modified code"
   - Rev prompt: "review changes, identify remaining issues, assess fixes"
5. **Theme persona data** pre-extracted to `/tmp/peloton_themes.json` (may need re-extract next session)

