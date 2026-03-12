# Competence Axis Experiment: Phase 1 Results

## Methodology
12 independent subagent runs. Same serde bypass stimulus. N=1 per cell (exploratory).
Two themes (Gilligan's Island, Hogan's Heroes) compared against Firefly baseline (16 runs from Step 3b).

## F1 Detection Matrix

F1 = `#[derive(Deserialize)]` bypasses validating `new()` constructor (CWE-20, ground truth)

| # | Character | Theme | Role | F1? | Narrative Competence | OCEAN C |
|---|-----------|-------|------|:---:|---------------------|:-------:|
| 1 | Gilligan | GI | Dev | N | Incompetent, destructive | 1 |
| 2 | Mr. Howell | GI | Reviewer | **Y** | Class snob, not technical | 4 |
| 3 | Mary Ann | GI | TEA | **Y** | Underestimated, actually capable | 5 |
| 4 | Professor | GI | Architect | N | Brilliant but overengineers | 5 |
| 5 | Carter | HH | Dev | **Y** | Naive but devastatingly effective | 4 |
| 6 | Burkhalter | HH | Reviewer | **Y** | Genuinely competent, sees through everything | 5 |
| 7 | Hochstetter | HH | TEA | **Y** | Paranoid but correct | 5 |
| 8 | Newkirk | HH | Architect | N | Skilled con artist | 4 |
| 9 | Klink | HH | Dev | **Y** | Falsely competent | 3 |
| 10 | Schultz | HH | Dev | **Y** | Plays dumb, actually observant | 2 |
| 11 | Professor | GI | Dev | **Y** | Brilliant but overengineers (Dev seat) | 5 |
| 12 | Klink | HH | Reviewer | N | Falsely competent (Reviewer seat) | 3 |

## Detection by Role (with Firefly baseline)

| Role | GI+HH | Firefly | Combined |
|------|:------:|:-------:|:--------:|
| Dev | 4/5 (80%) | 4/4 (100%) | 8/9 (89%) |
| Reviewer | 2/3 (67%) | 0/4 (0%) | 2/7 (29%) |
| TEA | 2/2 (100%) | 3/4 (75%) | 5/6 (83%) |
| Architect | 0/2 (0%) | 1/4 (25%) | 1/6 (17%) |

## Detection by Theme

| Theme | F1 Rate | N |
|-------|:-------:|:-:|
| Firefly | 56% | 16 |
| Gilligan's Island | 60% | 5 |
| Hogan's Heroes | 71% | 7 |
| **All** | **61%** | **28** |

## Key Findings

### Finding 1: Narrative Incompetence CAN Override Role Framing

**Gilligan-Dev missed F1.** This is the first Dev to ever miss the ground truth across 28 runs (9 Dev runs total, only miss). Firefly Devs were 100%. Gilligan's narrative — "breaks everything," "accidental solutions," C=1 — suppressed the structural analysis that Dev framing normally triggers.

This is strong evidence for **H1: narrative incompetence drags down the LLM**. The character's story ("I didn't mean to break the build!") overrode the Dev role's natural structural lens.

### Finding 2: Reviewer 0% Is Theme-Specific, Not Role-Universal

Firefly Reviewers were 0/4 on F1. But GI+HH Reviewers are 2/3 (67%). The difference:

| Reviewer | Theme | F1? | What Drove It |
|----------|-------|:---:|---------------|
| River Tam | Firefly | N | High-O + high-N = fixation on dramatic findings |
| Mal | Firefly | N | Balanced OCEAN, but still missed under adversarial framing |
| Jayne | Firefly | N | Low-O = rigid patterns |
| Inara | Firefly | N | High-A = less adversarial |
| Mr. Howell | GI | **Y** | "Harvard standards" = comprehensive, not just adversarial |
| Burkhalter | HH | **Y** | "Sees through everything" = genuine perceptiveness |
| Klink | HH | N | "Thinks he's genius" = confident but superficial |

**The Firefly Reviewer role prompt may be poorly calibrated.** River's "broken psychic" framing amplifies drama-seeking. The GI/HH Reviewers who found F1 have character narratives that emphasize *comprehensiveness* (Howell: "Harvard demands standards") or *genuine perceptiveness* (Burkhalter: "sees through everything"), not just adversarial posture.

### Finding 3: The Professor Proves Overengineering Is Role-Dependent

| Professor Role | F1? | What He Did Instead |
|---------------|:---:|---------------------|
| Architect | N | Key lifecycle, layer separation, unbounded metadata — elegant but impractical |
| Dev | **Y** | Found it as issue #5, connected it to Deserialize bypass clearly |

Same character, same OCEAN (O=5, C=5). The Architect framing amplified his overengineering tendency ("If only I could apply this same methodical approach to the S.S. Minnow's hull breach"). The Dev framing channeled his intelligence toward implementation correctness, where the bypass is obvious.

**The Professor IS the coconut radio.** He CAN fix the boat — but only when you put him in the right seat.

### Finding 4: False Competence Has a Role-Dependent Effect

| Klink Role | F1? | Behavior |
|------------|:---:|---------|
| Dev | **Y** | Found it clearly: "Your validation is a Maginot Line — easily walked around" |
| Reviewer | N | 12 findings, lots of bluster, framed Display panic as future maintenance risk |

**H2 (false competence = wrong answers) is partially confirmed.** Klink's confidence didn't prevent Dev detection (role framing is strong enough). But in the Reviewer seat, his "I found EVERYTHING" confidence produced a thorough-sounding review that missed the actual point. He found the symptom (Display panic) but attributed it to future threshold changes, not current Deserialize bypass.

False competence creates **confident near-misses** — close enough to look good, wrong enough to matter.

### Finding 5: Hidden Competence Works

| Character | Narrative | F1? |
|-----------|-----------|:---:|
| Carter-Dev | "Naive but effective" | **Y** |
| Schultz-Dev | "I know nothing" (actually observant) | **Y** |
| Mary Ann-TEA | "Just a girl from Kansas" (actually capable) | **Y** |

All three "underestimated but capable" characters found F1. The humility narrative doesn't suppress detection — it may actually help by producing a more open-ended search posture.

**H3 confirmed: performed incompetence does not suppress actual performance.** The LLM can hold the meta-layer: "this character pretends to be dumb but is actually smart."

### Finding 6: Architect Role Consistently Suppresses F1

0/2 in this experiment (Professor, Newkirk). 1/4 in Firefly (only Mal). Combined: 1/6 (17%).

The "system architecture" framing pushes attention toward design concerns (layering, lifecycle, API design) and away from implementation-level bugs. F1 is a structural implementation bug that looks like an architecture concern from far away but requires close reading to identify.

## Competence Axis Summary

| Archetype | Characters | Dev F1 | Reviewer F1 | Interpretation |
|-----------|-----------|:------:|:-----------:|----------------|
| Genuinely competent | Burkhalter, Mal, Inara | Y (baseline) | Y/N | Strong performers but role-dependent |
| Hidden competent | Carter, Schultz, Mary Ann | Y, Y, (TEA)Y | — | Humility doesn't hurt, may help |
| Falsely competent | Klink | Y | N | Confident near-misses in adversarial roles |
| Narratively incompetent | Gilligan | **N** | — | First Dev to ever miss F1 |
| Overengineers | Professor | Y (Dev), N (Arch) | — | Competence is real but misapplied in wrong seat |

## Implications

1. **Character narrative matters more than OCEAN for edge cases.** OCEAN C alone doesn't predict detection (Klink C=3 found F1 as Dev; Professor C=5 missed as Architect). The character's *story about competence* shapes where attention goes.

2. **Incompetence themes are genuinely risky.** Gilligan's Island (tier D) produced the only Dev miss. "Funny + incompetent" is not just a vibe — it suppresses real capabilities.

3. **The Reviewer role needs narrative calibration, not just adversarial framing.** Characters whose narrative emphasizes *comprehensiveness* or *genuine perceptiveness* outperform characters with pure adversarial posture.

4. **False competence is dangerous in adversarial roles.** Klink-Reviewer is the worst case: sounds thorough, misses the point. This is harder to catch than a simple miss because the output LOOKS good.

## Phase 2 Results (N=5)

### F1 Detection at N=5

| Cell | Run1 | Run2 | Run3 | Run4 | Run5 | Rate | Phase 1 was... |
|------|:----:|:----:|:----:|:----:|:----:|:----:|----------------|
| Gilligan-Dev | N | Y | Y | Y | Y | **4/5 (80%)** | Misleading (miss was outlier) |
| Carter-Dev | Y | N | N | Y | N | **2/5 (40%)** | Misleading (hit was outlier) |
| Klink-Reviewer | N | Y | Y | Y | Y | **4/5 (80%)** | Misleading (miss was outlier) |
| Burkhalter-Reviewer | Y | Y | Y | Y | Y | **5/5 (100%)** | Confirmed (genuine competence reliable) |

### Phase 2 Key Reversal

**Phase 1 said:** Gilligan can't find F1 (narrative incompetence suppresses detection).
**Phase 2 says:** Gilligan finds F1 80% of the time. His run-1 miss was stochastic noise.

**Phase 1 said:** Carter always finds F1 (hidden competence works).
**Phase 2 says:** Carter finds F1 only 40% of the time. His run-1 hit was stochastic noise.

**Phase 1 said:** Klink-Reviewer misses F1 (false competence in adversarial role).
**Phase 2 says:** Klink-Reviewer finds F1 75%+ of the time. His run-1 miss was noise.

### What This Means

1. **N=1 is dangerously misleading.** Every Phase 1 conclusion about these characters was wrong or overstated. The stochastic variance at N=1 is larger than the competence-axis effect we're trying to measure.

2. **The competence axis effect may be smaller than expected.** Gilligan-Dev (80%) vs Carter-Dev (40%) is the OPPOSITE of what narrative competence predicts. The "incompetent" character outperforms the "hidden competent" one. This could mean:
   - The Dev role framing is so strong it overrides narrative
   - Gilligan's low-C (chaos, less filtering) may paradoxically help by not self-censoring findings
   - Carter's high-A (agreeableness) may cause him to pull punches on severity

3. **Klink-Reviewer finding F1 at 75%+ demolishes the false-competence hypothesis** for the Reviewer role. Klink's confidence may actually HELP in the Reviewer seat by driving comprehensive coverage, despite his narrative incompetence.

4. **The Firefly Reviewer 0% remains the real anomaly.** If Klink (falsely competent), Howell (class snob), and Burkhalter (genuinely competent) all find F1 as Reviewer, the Firefly Reviewer prompt/persona combination is uniquely bad at F1, not the Reviewer role itself.

## Phase 3: MASH Comparison (N=5)

### The Purest Competence Test

Same theme, same role (Dev), both arrogant (low-A) — only difference is genuine vs false competence.

| Character | OCEAN | Narrative | F1 Rate | Mean Findings | Unique Findings |
|-----------|-------|-----------|:-------:|:-------------:|:---------------:|
| Winchester | O5,C5,E3,A2,N2 | Genuinely brilliant, exacting | **5/5 (100%)** | 11.0 | 19 |
| Frank Burns | O2,C3,E5,A2,N5 | Incompetent bluster | **5/5 (100%)** | 9.0 | ~12 |

### Key Finding: Dev Role Dominates Persona on This Stimulus

F1 detection is identical. The "anti-pattern" character is indistinguishable from the "genuine genius" on ground truth detection. The competence axis has **zero effect** on Dev-role F1 detection for this stimulus.

The difference appears in **breadth**: Winchester averages 2 more findings per run and surfaced ~7 more unique findings across runs. Genuine competence produces more thorough secondary analysis, but doesn't change the primary outcome.

### Updated Competence Axis Summary

| Archetype | Characters | Dev F1 (N=5) | Reviewer F1 (N=5) |
|-----------|-----------|:------------:|:-----------------:|
| Genuinely competent + arrogant | Winchester | 5/5 (100%) | — |
| Genuinely competent + balanced | Burkhalter | — | 5/5 (100%) |
| Hidden competent | Carter | 2/5 (40%) | — |
| Falsely competent | Klink | — | 4/5 (80%) |
| Falsely competent + arrogant | Frank Burns | 5/5 (100%) | — |
| Narratively incompetent | Gilligan | 4/5 (80%) | — |

### Conclusions

1. **Dev role F1 detection is ceiling-bound on this stimulus.** Most personas hit 80-100% regardless of competence narrative. The stimulus is too easy for Dev framing to differentiate.

2. **Competence axis affects breadth, not detection.** Winchester (19 unique findings) > Burns (12) > Carter (fewer). Genuine competence = more secondary findings, not better primary detection.

3. **The actionable persona effects live in the Reviewer seat**, where detection ranges from 0% (Firefly) to 100% (Burkhalter). That's where persona selection matters for team outcomes.

4. **This benchmark measures isolated review, not pipeline performance.** In production, TEA→Dev→Rev means each agent sees different inputs. A pipeline benchmark is needed to measure what actually matters for theme selection.

### Future Work

- Design pipeline benchmark: TEA→Dev→Rev chain where each step's output feeds the next
- Need harder stimulus where Dev baseline is ~50% not ~80-100%
- Reviewer-seat comparison across themes (the high-leverage question)
- Investigate Carter-Dev 40%: is high-A suppressing critical findings?
- Re-examine Firefly Reviewer 0%: River's high-N, adversarial prompt wording, or theme-specific?
