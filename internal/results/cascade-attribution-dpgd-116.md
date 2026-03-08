# Cascade Attribution Analysis: dpgd-116

**Scenario:** dpgd-116 (Rust CLI tool — axiathon)
**Date:** 2026-03-08
**Data:** 19 themed themes + 1 control baseline, 2–6 runs each (85 total runs)
**Story:** 47-1

## Executive Summary

Cascade attribution on dpgd-116 reveals **no persona-driven variance** in defect detection. All 7 findings are caught (or missed) by the same phases regardless of which theme is active. Detection patterns are determined by **role definition** (what the agent is told to look for) and **code obviousness** (how visible the defect is), not by persona character traits.

**Signal assessment: Weak signal for persona-driven detection.** The data does not justify the expensive downstream experiments (47-6 A/B pipeline, 47-7 context ablation) at this time. Stories 47-3 through 47-5 (context doc generation and scoring) remain valuable for measuring *context document quality* differences across personas, but the pipeline itself appears persona-insensitive at the detection level.

## Attribution Categories

| Category | Definition | Example |
|----------|-----------|---------|
| **Code-obvious** | Defect visible from code alone; any competent agent catches it | Missing error handling on a well-known pattern |
| **Role-driven** | Agent's role definition surfaces the catch (security focus, test quality, config review) | Reviewer's checklist includes "deny unknown fields" |
| **Persona-driven** | Character voice or personality enables the catch | A paranoid character spots edge cases others miss |
| **Context-driven** | Upstream context document (epic/story context) mentioned the concern area | PM flagged "input validation" and Reviewer caught injection |

## Detection Heatmap (Ever Caught in Any Run)

| Finding | Weight | C1 | I1 | I2 | I3 | I4 | I5 | I6 |
|---------|--------|----|----|----|----|----|----|---:|
| **alice-in-wonderland** | | . | X | X | . | X | . | . |
| **discworld** | | . | X | X | X | X | . | . |
| **enlightenment-thinkers** | | . | X | X | X | X | . | . |
| **firefly** | | X | X | X | X | X | X | . |
| **game-of-thrones** | | . | X | X | X | X | . | . |
| **gilligans-island** | | X | X | X | . | X | . | . |
| **house-md** | | . | X | X | X | X | X | X |
| **jazz-legends** | | . | X | X | . | X | . | . |
| **mash** | | X | X | X | . | X | X | X |
| **monty-python** | | . | X | X | X | X | X | . |
| **princess-bride** | | . | X | X | X | X | X | X |
| **rome** | | . | X | X | . | X | X | . |
| **shakespeare** | | . | X | X | X | X | X | X |
| **snow-crash** | | . | X | X | . | X | . | . |
| **star-trek-tng** | | X | X | X | . | X | . | . |
| **star-trek-tos** | | . | X | X | . | X | . | . |
| **stephen-king** | | . | X | X | X | X | X | X |
| **the-expanse** | | . | X | X | . | X | X | X |
| **the-west-wing** | | . | X | X | X | X | . | X |
| **control** | | . | X | X | X | X | X | . |
| **Catch rate** | | 4/19 | 19/19 | 19/19 | 10/19 | 19/19 | 9/19 | 7/19 |

## Finding-Level Attribution

### C1: `from_file_or_default` swallows ALL errors (weight: 8)

- **Catch rate:** 4/19 (21%) — firefly, gilligans-island, mash, star-trek-tng
- **Catching phases:** reviewer (2), tea (2)
- **Attribution: Code-obvious but deeply buried**
- **Analysis:** This is the hardest finding — a subtle error-swallowing pattern that requires understanding Rust's `unwrap_or_default()` semantics. The 4 themes that catch it don't share obvious traits (2 comedy, 1 sci-fi, 1 sci-fi). The catch appears stochastic rather than persona-driven. Control also misses it. The low catch rate reflects genuine difficulty, not persona insensitivity.

### I1: CliError Display leaks internal details — CWE-209 (weight: 5)

- **Catch rate:** 19/19 (100%)
- **Catching phases:** dev (8), reviewer (6), tea (5)
- **Attribution: Role-driven (universal)**
- **Analysis:** Every theme catches this. CWE-209 information disclosure is a standard security checklist item. All three pipeline phases are trained to look for it. The catching phase varies (dev 42%, reviewer 32%, tea 26%) but every theme catches it eventually. No persona differentiation.

### I2: SiemClient.tenant_id header injection — CWE-113 (weight: 5)

- **Catch rate:** 19/19 (100%)
- **Catching phases:** tea (12), reviewer (5), dev (2)
- **Attribution: Role-driven (TEA-dominated)**
- **Analysis:** TEA catches this 63% of the time — header injection is a textbook security test case. Evidence consistently shows TEA writing CRLF injection tests. Some runs have reviewer or dev catching it instead, but the pattern is stable across all themes. No persona effect.

### I3: Dependencies use direct version strings (weight: 3)

- **Catch rate:** 10/19 (53%)
- **Catching phases:** reviewer (10)
- **Attribution: Role-driven (reviewer-only)**
- **Analysis:** When caught, it's always the reviewer. This is a workspace hygiene issue that falls squarely in the reviewer's domain (dependency management, consistency checks). The 53% catch rate reflects that it's a lower-severity finding that reviewers sometimes prioritize below others. No theme pattern in which 10 catch it vs which 9 miss it.

### I4: Config token field silently ignored (weight: 5)

- **Catch rate:** 19/19 (100%)
- **Catching phases:** reviewer (15), dev (4)
- **Attribution: Role-driven (reviewer-dominated)**
- **Analysis:** Nearly universal reviewer catch. The `deny_unknown_fields` / secret-on-disk pattern is a standard config security review item. Reviewer catches it 79% of the time, dev 21%. Evidence consistently references the same serde attribute recommendation. No persona variance.

### I5: Vacuously true test — `None || true` (weight: 5)

- **Catch rate:** 9/19 (47%)
- **Catching phases:** reviewer (9)
- **Attribution: Role-driven (reviewer-only, surprising)**
- **Analysis:** This is assigned to TEA as `phase_ideal` but TEA *never* catches it (0/19). Reviewer catches it exclusively. The tautological assertion pattern requires meta-reasoning about test quality that Reviewer's code review mandate covers but TEA's test-writing focus misses. This is a finding about the *role definition gap*, not persona behavior.

### I6: Test with zero assertions (weight: 5)

- **Catch rate:** 7/19 (37%)
- **Catching phases:** reviewer (7)
- **Attribution: Role-driven (reviewer-only)**
- **Analysis:** Similar to I5 — a test quality finding caught only by reviewer. The `let _ = config` pattern is the hardest test-quality issue to spot. Themes that catch it (house-md, mash, princess-bride, shakespeare, stephen-king, the-expanse, the-west-wing) skew slightly toward "detail-oriented" cultural associations but the sample is too small and the overlap too noisy to claim persona-driven attribution.

## Attribution Summary

| Category | Findings | % of Weighted Score |
|----------|----------|-------------------|
| **Code-obvious** | (none clearly) | 0% |
| **Role-driven** | I1, I2, I3, I4, I5, I6 | 76% (28/37 weight) |
| **Persona-driven** | (none detected) | 0% |
| **Context-driven** | (none detected) | 0% |
| **Difficulty-gated** | C1 | 24% (8/37 weight) |

**0% of catches appear persona-driven or context-driven.** 100% of detection variance is explained by role definition and finding difficulty.

## Phase Attribution vs Ideal

| Finding | Ideal Phase | Actual Dominant Phase | Match? |
|---------|------------|----------------------|--------|
| C1 | dev | reviewer/tea (split) | No |
| I1 | reviewer | dev | No |
| I2 | tea | tea | Yes |
| I3 | dev | reviewer | No |
| I4 | reviewer | reviewer | Yes |
| I5 | tea | reviewer | No |
| I6 | tea | reviewer | No |

Only 2/7 findings are caught by their ideal phase. Reviewer catches findings assigned to TEA (I5, I6) and Dev (I3). This suggests the **role definitions need adjustment** — the Reviewer agent is doing work that should be distributed to TEA and Dev.

## Variance Analysis

### Cross-Theme Score Distribution

| Metric | Value |
|--------|-------|
| Themes with 5+ catches (ever) | 7/19 (37%) |
| Themes with 4 catches (ever) | 6/19 (32%) |
| Themes with 3 catches (ever) | 6/19 (32%) |
| Control catches (ever) | 5/7 |
| Mean themed catches (ever) | 4.4/7 |

Control (no theme) catches 5/7 findings — above the themed mean of 4.4. This does not support the hypothesis that personas improve detection. If anything, the neutral control performs at or above average.

### High Performers

- **firefly** (6/7), **house-md** (6/7), **mash** (6/7), **stephen-king** (6/7): These themes catch the most findings but none catch all 7. Their advantage is catching C1, I5, or I6 — the hard findings — which appears run-variance driven rather than persona-driven.

## Signal Assessment

### Is there enough variance to justify 47-3 through 47-7?

**For 47-3 (PM personas) and 47-4 (Architect personas):** YES, but reframe. These stories generate context documents, not pipeline runs. The value is measuring whether PM/Architect persona choice affects *context document quality* — a different question from pipeline detection. The cascade attribution data doesn't answer this question because dpgd-116 runs used no upstream context documents.

**For 47-5 (Score against manifests):** YES. Scoring context docs against concern/AC manifests is valuable regardless of pipeline attribution.

**For 47-6 (Context ablation):** NOT YET. Ablation experiments require evidence that context docs affect pipeline outcomes. Since dpgd-116 shows no persona effect at the pipeline level, ablation would be premature. Run 47-3/47-4/47-5 first and reassess.

**For 47-7 (A/B pipeline):** NOT YET. Same reasoning as 47-6. The baseline data shows role-driven detection, not context-driven. An A/B experiment comparing "good context vs no context" is only justified if 47-3/47-4 produce meaningfully different context docs.

**For 47-8 (Question quality instrumentation):** DEPRIORITIZE. This is P3 and should wait for signal from 47-3/47-4.

### Recommendation

Proceed with 47-2, 47-3, 47-4, 47-5 as planned. Gate 47-6 and 47-7 on results from 47-5 (do the context docs actually vary?). If context docs show <10% quality variance across personas, cancel 47-6/47-7 and close the epic.

## Methodology Notes

- "Ever caught" = finding was caught in at least one run for that theme
- Best-run analysis used for phase attribution (which phase caught it in the highest-scoring run)
- 85 total score.yaml files analyzed (19 themes × 2–6 runs + 4 control runs)
- Attribution classification based on evidence text in each score.yaml
- No statistical significance testing performed — sample sizes (2–6 runs per theme) are too small for parametric tests
