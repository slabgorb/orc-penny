# Harnessing the Kraken

> What does not kill me makes me stronger. — Nietzsche

## The Kraken

We call it the Kraken because it has a lot of arms and they all grab at something different.

The Kraken is [@Zious11](https://github.com/Zious11)'s external PR review process on the [axiathon](https://github.com/drbothen/axiathon) project. A CODEOWNER alongside @drbothen and @arcaven, Zious11 runs a thorough, automated review tool that consistently surfaces 10–15+ findings per pull request — findings that are difficult, specific, and genuinely important.

The reviews are notorious. Not because they're unfair, but because they're *right*. Every finding represents something our entire internal pipeline missed: the TEA's test design, the Dev's implementation, the Reviewer's adversarial analysis — all three agents failed to catch what the Kraken found.

That makes the Kraken invaluable.

### Notable Kraken Reviews

| PR | Story | Findings | Scenario |
|----|-------|----------|----------|
| #52 | 8.1 REST API Foundation (DPGD-117) | 10 findings, 52 weight | `dpgd-117` |
| #48 | 6.1 CLI Framework (DPGD-116) | 7 findings, 36 weight | `dpgd-116` |
| #50 | 5.1 | 13 findings | Future scenario |
| #55 | 5.2 | 9 findings | Future scenario |
| #58 | 8.3 | 15 findings | Future scenario |
| #59 | 5.3 | — | Future scenario |

## Two Problems, One Solution

We had two separate challenges that converged into a single methodology.

### Problem 1: Surviving the Kraken

Every Kraken review was a fire drill. A dozen findings, many at Important or Critical severity, covering security (CWE-209, CWE-113), test quality (vacuous assertions, zero-assertion tests), dependency hygiene, error handling, and configuration security. We'd fix the findings, introduce regressions in the fixes, get re-reviewed, find more issues — a painful cycle.

We needed the pipeline to stop making the same classes of mistakes.

### Problem 2: Evaluating the Agentic System

Separately, we were building Pennyfarthing — an agent orchestration framework with themed personas, BikeLane workflows, and a full TEA → Dev → Reviewer pipeline. We wanted to evaluate everything: Do personas matter? Do agent prompts matter? Does the epic and story context matter? What's actually working?

The fundamental obstacle was **Claude judging Claude**. We call it the "god lifting rocks" problem — the same model that writes the code is scoring the code. Any evaluation we devised was internally consistent but potentially circular. We had no external ground truth.

### The Convergence

The Kraken findings *are* the external ground truth.

Each Kraken review tells us exactly what the pipeline missed on real production code. Not synthetic benchmarks, not contrived scenarios — actual findings from actual code that actual agents wrote. The ground truth comes from outside the system, breaking the circularity.

This insight unlocked two parallel uses.

## Use 1: Auto-Tuning the Review Checklist

The simplest application: every Kraken finding becomes a new check in the pipeline.

The **review-correlation gate** (`pennyfarthing-dist/gates/review-correlation.md`) formalizes this feedback loop. When the Dev addresses external review feedback, the gate enforces:

1. **Classify every finding** — Does it map to an existing checklist check (process failure: we had the check but missed it) or is it a new class of bug (knowledge gap: the checklist didn't cover it)?
2. **Update the checklist** — New findings become new checks in the language-specific review checklist, tagged with provenance: `[EXT] *Origin: PR#48 EXT-Zious11 (vacuously true assertion)*`
3. **Prioritize external findings highest** — They represent pipeline blind spots. Internal findings mean someone caught it. External findings mean *nobody* caught it.

Source priority:
1. External reviewer / maintainer (pipeline blind spot — highest signal)
2. CI / automated tooling (reproducible, automatable)
3. Internal reviewer (caught in-process, still valuable)

This creates a **self-improving checklist**. Every encounter with the Kraken makes the pipeline more resistant to that class of finding. The Reviewer agent's mandatory checklist (`pennyfarthing-dist/agents/reviewer.md`) grows specifically in the directions where the pipeline has proven blind.

## Use 2: Objective Benchmark Criteria

The deeper application: using Kraken findings as ground truth for systematic benchmarking.

### The Pipeline Replay Methodology

For a reviewed story (ideally 3 points — the sweet spot for complexity), we:

1. **Check out the starting hash** — the exact commit where that story began, before any work was done
2. **Create a git worktree** — an isolated copy, no cross-contamination between runs
3. **Run the full TDD pipeline** — TEA writes tests → Dev implements → Reviewer reviews, exactly as it would run in production
4. **Score against the known findings** — Did the pipeline catch what the Kraken caught?

The agents don't have access to Pennyfarthing's quality hooks (pre-commit checks, schema validation, etc.). This is intentional — we're testing the agents' raw judgment, not the safety net. The Pennyfarthing commands still work (they operate within the repo normally), but the automated "did you check everything?" gates are absent. This makes the benchmark more demanding and more revealing than production.

### The Proxy: Multi-Judge Scoring

Running the actual Kraken on every benchmark iteration is impractical. Instead, we built a **multi-judge majority-vote system** that acts as a Kraken proxy:

- **3 independent LLM judges** evaluate each pipeline run against the ground truth findings
- **Majority vote** (2/3 agreement) determines whether each finding was caught
- **v2 rubric** uses partial-match rules: same vulnerability class, adjacent location, general-encompasses-specific, opposite-conclusion all count
- **Per-finding scoring** with severity weights: Critical (8), Important (5), Medium (3)

This lets us run hundreds of benchmark iterations and evaluate them consistently without re-running the external tool.

### What We Measure

The benchmark framework (`pf benchmark replay`) supports:

- **Theme comparison** — Run the same scenario with different persona themes and compare detection profiles
- **Phase attribution** — Which pipeline stage (TEA, Dev, Reviewer) catches which findings?
- **Consistency** — How much does performance vary across repeated runs of the same configuration?
- **Detection heatmaps** — Which findings are universally caught vs. which are reliably missed?

## What the Data Shows

### DPGD-116: 25 Themes, 85+ Runs

The DPGD-116 scenario (Story 6.1 CLI Framework, 7 findings, 36 weight) has been run across 25 persona themes with multiple runs each — the most comprehensive dataset.

### Role Determines Who; Persona Determines How Well

**Cascade attribution** — analyzing which pipeline phase catches each finding — shows that detection is **role-driven**. The Reviewer catches config security issues. TEA catches injection risks. Dev catches implementation bugs. This pattern holds across all themes. No finding switches to a different phase because of persona.

But the scatter plot of **Mean Weighted Score vs Consistency** tells the rest of the story:

- **Control baseline** (no persona): ~50% accuracy, ~85 consistency
- **Top performers**: Princess Bride (~70%, ~95), House MD (~65%, ~93), Dune (~65%, ~95), Sherlock Holmes (~58%, ~95)
- **Strong middle band**: Breaking Bad, MASH, Monty Python, Stephen King, Matrix, Battlestar Galactica — all clustering at 55–60% accuracy, above control
- **Below control**: Only a handful — X-Files (~42%), Firefly (~45%), Star Trek TOS (~40% but very consistent at ~98)

The conclusion: **role determines who catches a finding, but persona affects whether they catch it and how reliably.** Persona is not noise — it shapes both accuracy (mean weighted score) and precision (consistency across runs). The pipeline performs measurably better with most persona themes than with the neutral control baseline.

### Detection Profiles Differ

Different themes don't just score differently — they catch *different things*:

| Finding | Catch Rate | Notes |
|---------|-----------|-------|
| C1: Error swallowing (wt: 8) | 4/19 themes | Hardest finding — stochastic, only firefly, gilligans-island, mash, star-trek-tng |
| I1: CWE-209 info leak (wt: 5) | 19/19 | Universal — every theme catches it |
| I2: Header injection (wt: 5) | 19/19 | Universal — TEA-dominated |
| I3: Dependency hygiene (wt: 3) | 10/19 | Reviewer-only when caught |
| I4: Config token ignored (wt: 5) | 19/19 | Universal — reviewer-dominated |
| I5: Vacuous assertion (wt: 5) | 9/19 | Reviewer catches it, never TEA (despite being TEA's ideal) |
| I6: Zero-assertion test (wt: 5) | 7/19 | Hardest test-quality finding |

The "easy" findings (I1, I2, I4) are caught universally regardless of persona. The differentiators are the hard findings (C1, I5, I6) where persona-driven differences in analytical depth and skepticism create real detection gaps.

### Noteworthy Theme Behaviors

- **Princess Bride**: The statistical standout — the only theme to reach significance vs control (t=2.65, mean 66.9% vs 49.5%). Both accurate and consistent.
- **Star Trek TOS**: Low accuracy (~40%) but the most consistent theme (~98). It reliably catches the same subset every time.
- **Stephen King**: Highest single-run score observed (75.7%, catching 6/7 findings in one run) but high variance — swings from 27% to 76%.

## The Rubric Journey

Getting the evaluation right was its own odyssey.

### v1: The Contaminated Rubric

The original rubric allocated 25/100 points to "persona scoring" — how well the agent embodied its character. This **contaminated all results**. Persona agents scored well on the persona dimension (circular by definition), which masked penalties on detection and quality. Control agents were penalized for not having a persona to embody. The comparison was meaningless.

### v2: Detection-Focused

The v2 rubric strips persona scoring entirely:
- **Detection: 75 points** (recall × 50 + precision × 15 + novel findings × 10)
- **Quality: 25 points** (analysis depth, fix specificity, actionability)

This means the only way to score well is to *find things* and *explain them clearly*. Persona helps only if it makes you a better finder.

### The Re-Judging Campaign

All control baselines were run on the v1 rubric, persona runs on v2 — making cross-comparison invalid. A systematic re-judging campaign with the v2 rubric brought everything onto the same scale. The v1→v2 shift was uniformly +10.7 percentage points on DPGD-116 (the partial-match rules are more generous) but mixed on DPGD-117.

## The Feedback Loop

The Kraken methodology creates a virtuous cycle:

```
Kraken Review → Ground Truth Findings
                    ↓                  ↓
            Review Checklist    Benchmark Scenario
            (auto-tuning)       (objective evaluation)
                    ↓                  ↓
            Better Pipeline     Better Understanding
                    ↓                  ↓
            Fewer Findings  ←  Targeted Improvements
```

Each Kraken encounter makes the system stronger in two ways: the checklist gets smarter (fewer repeat mistakes), and the benchmark library grows (better evaluation coverage). The Kraken doesn't get easier — the stories keep coming, the code keeps getting reviewed — but the pipeline gets harder to surprise.

## Methodology Details

### Scenario Structure

A benchmark scenario (`benchmarks/scenarios/*.yaml`) captures:
- **Base commit**: The exact git hash where the story began
- **Story context**: Epic and story documents the agents receive
- **Ground truth findings**: Each finding with ID, title, severity, weight, category, ideal phase, description, affected files, and fix commit
- **Review rounds**: Findings organized by review round (initial review, re-review after fixes)

### Production Fidelity

The benchmark prompts are **production-faithful** — agents receive the same system prompt they'd get in a real session, extracted from `pf agent start <role>`. This includes the full agent definition, role instructions, adversarial mindset, review checklist, and severity levels. The only variable between control and persona runs is the persona block (~11 lines). This proper isolation means results transfer to production behavior.

### Runner Infrastructure

- `pf benchmark replay run` — Execute a full pipeline run against a scenario
- `pf benchmark replay score` — Score an existing run against ground truth
- `pf benchmark replay judge` — Multi-judge evaluation (3 judges, majority vote)
- `pf benchmark replay compare` — Cross-theme comparison with detection heatmaps
- Visualization: Interactive HTML dashboard at `internal/results/benchmark-dashboard.html`

Runs execute via `claude -p` in standalone terminal sessions (not nested inside Claude Code). The project maintains two Claude Max Pro accounts for parallel execution.

## What's Next

The current dataset proves persona affects pipeline performance on a single scenario. The open questions:

1. **Context variance** — All DPGD-116 runs used identical epic/story context. Does varying the *quality* of upstream context (PM and Architect output) change detection outcomes? (Stories 47-3 through 47-7)
2. **Cross-scenario stability** — Do the same themes that excel on DPGD-116 excel on DPGD-117? Or is theme effectiveness scenario-dependent?
3. **Pipeline interaction effects** — The full pipeline (TEA → Dev → Reviewer) may have interaction effects that single-agent benchmarks miss. Research suggests multi-persona collaboration is where personas truly shine.
4. **More scenarios** — PRs #50 (13 findings), #55 (9 findings), #58 (15 findings) are rich candidates for new scenarios.

The Kraken keeps reviewing. The benchmarks keep running. The pipeline keeps improving.

---

*"What does not kill me makes me stronger" is aspirational for most systems. For this one, it's the literal methodology.*
