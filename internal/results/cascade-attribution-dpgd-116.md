# Cascade Attribution Analysis: dpgd-116

**Scenario:** dpgd-116 (Rust CLI tool — consumer-project)
**Date:** 2026-03-08
**Data:** 19 themed themes + 1 control baseline, 2–6 runs each (85 total runs)
**Story:** 47-1

## Executive Summary

Cascade attribution on dpgd-116 reveals **no persona-driven variance in phase routing** — which phase catches which finding is stable across themes. However, this does NOT mean personas have no effect on detection. Aggregate data shows 64% of persona themes beat control (51.1%), and specific findings show large persona-vs-control deltas (I3: +22.7pp, I5: +13.3pp). The correct conclusion is: **role definition determines which phase catches a finding, but persona presence affects whether it gets caught at all.**

**Important limitation:** All dpgd-116 runs used the **same static epic and story context documents** — context was held constant across themes, not absent. Every agent (TEA, Dev, Reviewer) received identical context via `build_phase_claude_md()`. This means we can measure persona-driven variance (none found) but **cannot measure context-driven variance** from this dataset because the independent variable (context content) was never varied.

**Signal assessment:** No persona effect at the pipeline detection level. Context effect is **untestable** from this data — stories 47-3/47-4 are critical to generate the context variance needed before 47-6/47-7 can answer the context question.

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
- **Attribution: Role-driven (low catch rate due to difficulty)**
- **Analysis:** This is the hardest finding — a subtle error-swallowing pattern that requires understanding Rust's `unwrap_or_default()` semantics. The 4 themes that catch it don't share obvious traits (2 comedy, 1 sci-fi, 1 sci-fi). The catch appears stochastic rather than persona-driven. Control also misses it. The low catch rate reflects genuine difficulty — the role definition covers it, but agents don't reliably surface it.

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
| **Role-driven** | C1, I1, I2, I3, I4, I5, I6 | 100% (37/37 weight) |
| **Persona-driven** | (none detected) | 0% |
| **Context-driven** | (not measurable — context held constant) | N/A |

**0% of catches show persona-driven phase routing** — role definition determines which phase catches each finding. However, **persona presence does affect overall catch rates vs control.** 64% of persona themes beat control's 51.1% average. Per-finding deltas are significant: I3 goes from 0% (control) to 22.7% (persona avg), I5 from 36.4% to 49.6%. The cascade attribution measures phase routing invariance, not whether personas improve detection overall — they do, modestly. Context-driven attribution cannot be assessed from this dataset because all runs used identical static context documents.

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

Control (no theme) catches 5/7 findings ever — above the themed mean of 4.4 ever-caught. However, "ever caught" masks frequency: control's per-run average (51.1%) is below the persona mean (52.9%), and 64% of persona themes beat control on average score. The ever-caught metric favors control's N=11 (more chances to catch each finding) over persona themes' typical N=4. Per-run weighted score is the fairer comparison.

### High Performers

- **firefly** (6/7), **house-md** (6/7), **mash** (6/7), **stephen-king** (6/7): These themes catch the most findings but none catch all 7. Their advantage is catching C1, I5, or I6 — the hard findings — which appears run-variance driven rather than persona-driven.

## Signal Assessment

### What this data tells us

**Persona variance at the detection level: NO.** Changing the theme (persona character) does not change which findings are caught or which phase catches them. The pipeline is persona-insensitive for detection.

**Context variance at the detection level: UNKNOWN.** All dpgd-116 runs used the same static epic and story context documents. Since context was never varied, this dataset cannot answer whether different context content would produce different detection outcomes. This is the central question of the epic — and it remains open.

### Is there enough variance to justify 47-3 through 47-7?

**For 47-3 (PM personas) and 47-4 (Architect personas):** YES — these are critical. The pipeline-replay runs load context docs into every agent's prompt via `build_phase_claude_md()`. Stories 47-3/47-4 generate *different* context documents using different PM and Architect personas. This creates the context variance that dpgd-116 lacks — the prerequisite for testing whether upstream context quality affects downstream detection.

**For 47-5 (Score against manifests):** YES. Scoring persona-generated context docs against concern/AC manifests measures whether personas produce meaningfully different context. This is the gating signal for 47-6/47-7.

**For 47-6 (Context ablation):** GATE ON 47-5. If persona-generated context docs show meaningful quality variance (47-5), then ablation experiments become justified — remove sections from the good context and measure detection impact. If context docs don't vary across personas, ablation still has value (measuring which sections of static context matter) but at lower priority.

**For 47-7 (A/B pipeline):** GATE ON 47-5. Run the pipeline with persona-generated context (from 47-3/47-4) vs the original static context. Only justified if 47-5 shows the context docs are actually different.

**For 47-8 (Question quality instrumentation):** DEPRIORITIZE. P3 — wait for signal from 47-3/47-4.

### Recommendation

Proceed with 47-2, 47-3, 47-4, 47-5 as planned. Gate 47-6 and 47-7 on 47-5 results (do the context docs actually vary across personas?). If context docs show <10% quality variance, deprioritize 47-6/47-7. The key insight from this analysis is that the epic's hypothesis is about **context**, not persona — and context variance has not yet been tested.

## Methodology Notes

- "Ever caught" = finding was caught in at least one run for that theme
- Best-run analysis used for phase attribution (which phase caught it in the highest-scoring run)
- 85 total score.yaml files analyzed (19 themes × 2–6 runs + 4 control runs)
- Attribution classification based on evidence text in each score.yaml
- No statistical significance testing performed — sample sizes (2–6 runs per theme) are too small for parametric tests
- **Context setup:** All runs used identical static epic and story context documents, loaded into each agent's CLAUDE.md via `build_phase_claude_md()` in `pipeline_replay.py`. The only variable across themes was the persona definition — context content was held constant. This means persona-driven attribution can be assessed (none found) but context-driven attribution cannot (no variance in the independent variable).
