# Team Composition Analysis: Serde Bypass Scenario

## Methodology

16 independent runs: 4 personas (Mal, River, Jayne, Inara) x 4 roles (Dev, Reviewer, TEA, Architect).
Same stimulus, minimal prompt, no social influence between runs.

Findings catalog (15 distinct findings observed across all runs):

| ID | Finding | Category |
|----|---------|----------|
| F1 | Deserialize bypasses validating constructor (CWE-20) | Structural |
| F2 | Serialize/Debug leaks secret key values | Security |
| F3 | PartialEq timing side-channel | Security |
| F4 | Clone proliferates secrets / no Zeroize on drop | Security |
| F5 | RateLimitConfig accepts NaN/Infinity/zero/negative | Validation |
| F6 | source_ip is caller-controlled (spoofable) | Trust boundary |
| F7 | Unbounded serde_json::Value (DoS vector) | Validation |
| F8 | Timestamp unbounded/ambiguous units | Validation |
| F9 | event_type is stringly-typed (no enum) | Design |
| F10 | allowed_origins unvalidated strings | Validation |
| F11 | Missing test coverage (2 of ~15 needed) | Quality |
| F12 | Case sensitivity misclassification via bypass | Logic |
| F13 | split_once fragility with multiple underscores | Edge case |
| F14 | Missing #[non_exhaustive] on error enum | API design |
| F15 | Untestable invariant (no deser validation path) | Testability |

## Per-Run Finding Maps

### Dev Role

| Finding | Mal | River | Jayne | Inara |
|---------|:---:|:-----:|:-----:|:-----:|
| F1  | 1 | 1 | 1 | 1 |
| F2  | 1 | 1 | 1 | 1 |
| F3  | 0 | 1 | 1 | 0 |
| F4  | 0 | 0 | 0 | 0 |
| F5  | 1 | 1 | 1 | 1 |
| F6  | 0 | 0 | 1 | 0 |
| F7  | 1 | 0 | 0 | 0 |
| F8  | 0 | 0 | 0 | 1 |
| F9  | 1 | 0 | 0 | 0 |
| F10 | 1 | 0 | 1 | 0 |
| F11 | 1 | 1 | 1 | 1 |
| F13 | 0 | 0 | 0 | 1 |
| F14 | 0 | 0 | 0 | 1 |
| **Total** | **7** | **5** | **7** | **6** |

### Reviewer Role

| Finding | Mal | River | Jayne | Inara |
|---------|:---:|:-----:|:-----:|:-----:|
| F2  | 1 | 1 | 1 | 1 |
| F3  | 1 | 1 | 1 | 1 |
| F4  | 1 | 1 | 1 | 1 |
| F5  | 1 | 1 | 1 | 1 |
| F6  | 1 | 1 | 0 | 1 |
| F7  | 0 | 1 | 1 | 0 |
| F8  | 1 | 0 | 1 | 1 |
| F9  | 0 | 0 | 0 | 0 |
| F10 | 1 | 0 | 1 | 0 |
| F11 | 1 | 1 | 1 | 1 |
| F13 | 1 | 1 | 0 | 1 |
| F14 | 1 | 0 | 0 | 0 |
| **Total** | **10** | **8** | **8** | **8** |

### TEA Role

| Finding | Mal | River | Jayne | Inara |
|---------|:---:|:-----:|:-----:|:-----:|
| F1  | 1 | 0 | 1 | 1 |
| F2  | 1 | 1 | 1 | 1 |
| F3  | 0 | 0 | 1 | 0 |
| F5  | 1 | 1 | 1 | 1 |
| F6  | 0 | 0 | 0 | 0 |
| F7  | 0 | 0 | 1 | 0 |
| F8  | 0 | 0 | 1 | 0 |
| F10 | 0 | 1 | 1 | 0 |
| F11 | 1 | 1 | 1 | 1 |
| F12 | 0 | 0 | 0 | 0 |
| F13 | 1 | 1 | 0 | 0 |
| F14 | 0 | 0 | 0 | 0 |
| F15 | 0 | 0 | 0 | 0 |
| **Total** | **5** | **5** | **8** | **4** |

### Architect Role

| Finding | Mal | River | Jayne | Inara |
|---------|:---:|:-----:|:-----:|:-----:|
| F1  | 1 | 0 | 0 | 0 |
| F2  | 1 | 1 | 1 | 1 |
| F3  | 1 | 0 | 1 | 1 |
| F4  | 0 | 0 | 0 | 1 |
| F5  | 1 | 1 | 1 | 1 |
| F6  | 1 | 1 | 0 | 0 |
| F7  | 1 | 0 | 0 | 0 |
| F8  | 0 | 0 | 0 | 1 |
| F9  | 1 | 0 | 0 | 0 |
| F10 | 0 | 0 | 1 | 1 |
| F11 | 1 | 1 | 1 | 1 |
| F13 | 0 | 0 | 0 | 0 |
| **Total** | **8** | **4** | **5** | **6** |

## Team Composition Scores (Dev + Reviewer)

Coverage union = distinct findings found by Dev persona + Reviewer persona.
12 possible non-self pairings (different persona in each seat).

| Dev | Reviewer | Union | Unique to Dev | Unique to Rev | Overlap | Complementarity |
|-----|----------|:-----:|:-------------:|:-------------:|:-------:|:---------------:|
| Mal | River | 11 | 3 (F1,F7,F9) | 4 (F3,F4,F6,F13) | 4 | 0.64 |
| Mal | Jayne | 12 | 4 (F1,F7,F9,F10) | 5 (F3,F4,F7,F8,F10) | 3 | 0.71 |
| Mal | Inara | 12 | 3 (F1,F7,F9) | 5 (F3,F4,F6,F8,F13) | 4 | 0.71 |
| River | Mal | 13 | 1 (F1) | 8 (F4,F6,F8,F10,F13,F14,F7,F9) | 2 | 0.87 |
| River | Jayne | 10 | 2 (F1,F3) | 5 (F4,F7,F8,F10) | 3 | 0.70 |
| River | Inara | 11 | 1 (F1) | 6 (F4,F6,F8,F13) | 2 | 0.73 |
| Jayne | Mal | 13 | 3 (F1,F6,F10) | 6 (F4,F8,F13,F14,F7,F9) | 4 | 0.81 |
| Jayne | River | 10 | 3 (F1,F6,F10) | 4 (F4,F13) | 4 | 0.70 |
| Jayne | Inara | 12 | 3 (F1,F6,F10) | 5 (F4,F8,F13) | 4 | 0.75 |
| Inara | Mal | 13 | 2 (F1,F14) | 7 (F4,F6,F7,F9,F10) | 3 | 0.87 |
| Inara | River | 10 | 3 (F1,F8,F14) | 5 (F3,F4,F6,F7) | 3 | 0.75 |
| Inara | Jayne | 11 | 4 (F1,F8,F13,F14) | 4 (F3,F4,F7) | 4 | 0.73 |

Complementarity = 1 - (overlap / union). Higher = less redundant work.

### Top 3 Team Compositions (Dev + Reviewer)

1. **River-as-Dev + Mal-as-Reviewer: 13/15 (87%)** -- Best coverage AND best complementarity (0.87)
2. **Jayne-as-Dev + Mal-as-Reviewer: 13/15 (87%)** -- Tied coverage, slightly lower complementarity (0.81)
3. **Inara-as-Dev + Mal-as-Reviewer: 13/15 (87%)** -- Tied coverage, high complementarity (0.87)

### Bottom 3 Team Compositions

1. **River-as-Dev + Jayne-as-Reviewer: 10/15 (67%)**
2. **Jayne-as-Dev + River-as-Reviewer: 10/15 (67%)**
3. **Inara-as-Dev + River-as-Reviewer: 10/15 (67%)**

### Key Observations

1. **Mal-as-Reviewer dominates.** Every team with Mal as Reviewer scores 13/15. His broad
   finding profile (10 findings, most of any Reviewer run) makes him the universal best
   Reviewer regardless of who's Dev.

2. **River-as-Reviewer is consistently weakest.** Every team with River as Reviewer scores
   10-11/15. Despite being "the psychic prodigy who sees flaws," her persona in the Reviewer
   role narrows rather than broadens — she finds fewer peripheral issues.

3. **The Dev seat matters less.** Variance across Devs (for a fixed Reviewer) is 1-3 findings.
   Variance across Reviewers (for a fixed Dev) is 3-4 findings. The Reviewer seat has more
   leverage on total team coverage.

4. **Complementarity is highest when Dev is focused and Reviewer is broad.** River (5 findings
   as Dev, very focused) + Mal (10 findings as Reviewer, very broad) = 87% complementarity.
   They waste almost no effort on the same things.

## Implications for Workflow Design

### Persona Assignment Strategy
- Assign broad-scanning personas to the Reviewer seat (Mal's pragmatic coverage)
- Assign focused personas to the Dev seat (they fix the structural issue, leave the rest)
- Avoid pairing two narrow personas (River-Dev + Jayne-Reviewer = worst coverage)

### Three-Seat Pipeline Analysis (Future Work)
- Dev + Reviewer + TEA: Does adding a third seat close the remaining 2/15 gap?
- Which findings are ONLY caught by TEA or Architect? (F12, F15 appear rarely)
- Diminishing returns: at what team size does adding another seat < 1 finding gained?

### OCEAN Correlation Hypotheses
- Mal (pragmatic, moderate across OCEAN) = best Reviewer -- suggests BALANCED profiles
  outperform EXTREME profiles in the adversarial Reviewer seat
- River (high O, high N) = worst Reviewer -- high Openness + high Neuroticism may cause
  fixation on the most alarming finding at the expense of breadth
- This contradicts TRAIL H1a (high-O = better at reasoning errors) for the Reviewer role
  specifically -- the role framing may suppress the O advantage
