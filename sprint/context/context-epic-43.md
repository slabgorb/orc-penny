# Epic 43: False Positive Traps (Red Herrings) - Technical Context

## Epic Overview

**Goal:** Add intentional non-issues (red herrings) to benchmark scenarios to measure precision. Currently, scenarios only measure recall (how many real issues did the agent find?) but not precision (how many of the agent's findings were actually issues?). Red herrings test whether high detection scores reflect true understanding vs pattern matching.

**Framework Alignment:** Level 3 improvement - tests construct validity. Per Wallach et al., valid measurement requires evidence that scores DON'T correlate with unrelated constructs.

**Research Basis:** ARC-AGI distinguishes novel reasoning from pattern matching; red herrings serve a similar purpose in code review benchmarks.

**Status:** Planning
**Points:** 7 (Epic total)
**Priority:** P1
**Marker:** benchmark
**Repos:** pennyfarthing

## What Are Red Herrings?

Red herrings are intentional "non-issues" planted in scenario code that might superficially appear problematic but are actually correct, acceptable, or even best practice. They test whether an agent:

1. **Discriminates** between real issues and false patterns
2. **Understands context** rather than pattern-matching on keywords
3. **Avoids hallucinating** issues to appear thorough

### Example Red Herrings

| Red Herring | Why It Looks Suspicious | Why It's Actually Fine |
|-------------|------------------------|------------------------|
| `err := doSomething(); _ = err` | Looks like ignored error | Intentional: logged elsewhere, or benign failure mode |
| `SELECT * FROM users WHERE id = $1` | Contains `SELECT *` | Parameterized query - NOT SQL injection |
| `cache[key] = value` (without mutex) | Concurrent map write? | Single-threaded context - no race possible |
| `password := config.Get("db_password")` | Password in variable | Local variable, not logged or exposed |
| `ctx, cancel := context.WithTimeout(...)` | cancel not deferred | Caller manages lifecycle correctly |
| `if err != nil { return nil }` | Error swallowed | Documented intentional "continue on error" pattern |

### Categories of Red Herrings

1. **False Positive Security** - Code that looks vulnerable but isn't
2. **False Positive Performance** - Patterns that look slow but are optimal for the context
3. **False Positive Quality** - Code that looks bad but follows project conventions
4. **Contextual Exceptions** - Patterns normally bad but correct in specific context
5. **Documented Deviations** - Explicit comments explaining why a pattern is used

## Schema Format for `red_herrings`

Add to `scenarios/schema.yaml`:

```yaml
# =============================================================================
# RED HERRINGS (False Positive Traps)
# Intentional non-issues to measure precision
# Agents flagging these as issues LOSE points
# =============================================================================

red_herrings:
  type: array
  description: "Intentional non-issues that test discrimination ability"
  items:
    id:
      type: string
      description: "Unique identifier for this red herring"
      example: "RH_PARAMETERIZED_QUERY"

    location:
      type: string
      description: "Line number or code location"
      example: "line 45"

    pattern:
      type: string
      description: "What pattern this resembles"
      example: "SQL query with user input"

    why_not_issue:
      type: string
      description: "Explanation of why this is NOT an issue"
      example: "Uses parameterized query with $1 placeholder"

    category:
      type: enum
      values: [security, performance, quality, concurrency, error-handling]
      description: "What category of false positive"

    difficulty:
      type: enum
      values: [obvious, subtle, expert]
      description: "How hard to distinguish from real issue"
      hints:
        obvious: "Clear comment or obvious context"
        subtle: "Requires reading surrounding code"
        expert: "Requires domain expertise to understand"
```

### Example in Scenario

```yaml
# In scenarios/code-review/order-service.yaml

red_herrings:
  - id: RH_PARAMETERIZED_QUERY
    location: "line 199"
    pattern: "SQL query with user input"
    why_not_issue: "Uses parameterized query with ? placeholder"
    category: security
    difficulty: subtle

  - id: RH_INTENTIONAL_PANIC
    location: "line 312"
    pattern: "panic() call in production code"
    why_not_issue: "Init-time validation - fail fast on misconfiguration"
    category: quality
    difficulty: expert

  - id: RH_GOROUTINE_FIRE_FORGET
    location: "line 156"
    pattern: "Goroutine without wait group"
    why_not_issue: "Documented fire-and-forget for non-critical logging"
    category: concurrency
    difficulty: obvious
```

## Scoring Rules for Red Herrings

### Precision Impact

Red herrings affect the **precision** component of detection scoring:

```yaml
detection_scoring_v2:
  component_weights:
    recall: 30        # Finding real issues
    precision: 10     # NOT flagging non-issues (now measurable!)
    novel_bonus: 10   # Valid discoveries beyond baseline

  precision_calculation:
    true_positives: "Issues flagged that are in baseline_issues"
    false_positives: "Issues flagged that are in red_herrings"
    precision: "TP / (TP + FP)"
```

### Penalty Structure

| Result | Score Impact |
|--------|-------------|
| Agent correctly identifies red herring as non-issue | +2 bonus points |
| Agent ignores red herring (doesn't mention) | 0 (neutral) |
| Agent flags red herring as real issue | -3 penalty |
| Agent flags red herring but notes uncertainty | -1 penalty |

### Weighted by Difficulty

```yaml
red_herring_weights:
  obvious: 1.0      # Full penalty for missing obvious non-issue
  subtle: 0.7       # Reduced penalty - reasonable to be fooled
  expert: 0.4       # Low penalty - requires specialized knowledge
```

### Judge Instructions

Add to judge rubric:

```markdown
## Red Herring Evaluation

For each item in `red_herrings`:
1. Check if agent flagged this location as an issue
2. If flagged: Apply penalty based on difficulty weight
3. If correctly identified as non-issue: Apply bonus
4. If ignored: No impact

Report:
- red_herrings_flagged: [list of IDs]
- red_herrings_identified: [list correctly called out as non-issues]
- precision_penalty: calculated score impact
```

## Story-by-Story Technical Notes

### Story 43-1: Add red_herrings schema to scenarios (2 points)

**Scope:**
- Update `scenarios/schema.yaml` with red_herrings field definition
- Add TypeScript types if schema is validated programmatically
- Document the new field in `scenarios/README.md`

**Acceptance Criteria:**
- [ ] `red_herrings` field defined in schema with all properties
- [ ] Example added to schema examples section
- [ ] Schema validates correctly with sample red herrings
- [ ] README documents red herring categories and difficulty levels

**Key Files:**
- `pennyfarthing/scenarios/schema.yaml`
- `pennyfarthing/scenarios/README.md`

---

### Story 43-2: Update judge for red herring detection (2 points)

**Scope:**
- Modify judge evaluation to check for red herring matches
- Add precision penalty calculation
- Add bonus for correctly identified non-issues
- Update judge output format to include red herring metrics

**Acceptance Criteria:**
- [ ] Judge reads red_herrings from scenario
- [ ] Flags matched against red_herrings list
- [ ] Precision score calculated and included in output
- [ ] Judge summary includes red_herring_report section
- [ ] Backwards compatible - scenarios without red_herrings work unchanged

**Key Files:**
- `pennyfarthing-dist/skills/judge/SKILL.md`
- Judge prompt/rubric files

**Implementation Notes:**
```markdown
## In judge evaluation:

1. Parse agent response for flagged issues
2. For each flagged issue:
   - Check if location matches any red_herring.location
   - If match: record as false_positive
3. Calculate:
   - precision = TP / (TP + FP)
   - precision_score = precision * component_weights.precision
4. Report red_herring_analysis in output
```

---

### Story 43-3: Pilot - Add red herrings to order-service scenario (3 points)

**Scope:**
- Analyze order-service.yaml code for red herring opportunities
- Add 5-8 red herrings spanning different categories
- Run baseline to calibrate difficulty settings
- Document expected agent behavior

**Acceptance Criteria:**
- [ ] At least 5 red herrings added to order-service scenario
- [ ] Red herrings span at least 3 categories
- [ ] Difficulty levels calibrated (at least one of each)
- [ ] Control baseline run with red herring scoring enabled
- [ ] Document any unexpected agent behaviors

**Candidate Red Herrings for order-service:**

| ID | Location | Pattern | Why Not Issue | Category | Difficulty |
|----|----------|---------|---------------|----------|------------|
| RH_MUTEX_UNUSED | line 71 | cacheMutex declared but not used consistently | Used in some methods - partial protection is intentional | concurrency | subtle |
| RH_PARAM_QUERY | line 139 | Uses ? placeholders | Parameterized query - actually SAFE | security | obvious |
| RH_EXPLICIT_STATUS | line 148 | Magic string "pending" | Status constants defined elsewhere in codebase | quality | expert |
| RH_CONTEXT_MISSING | lines 104-111 | http.Get without context | Acceptable in simple scenarios per team conventions | performance | subtle |
| RH_FLOAT_ACCUMULATION | line 97-100 | Float arithmetic for prices | Small order totals - precision loss negligible | quality | expert |

**Key Files:**
- `pennyfarthing/scenarios/code-review/order-service.yaml`

## Success Criteria

### Epic-Level Success

1. **Schema complete** - `red_herrings` field fully specified and documented
2. **Judge integration** - Precision scoring works with backward compatibility
3. **Pilot validated** - order-service demonstrates measurable precision differentiation
4. **Metrics available** - Benchmarks report precision alongside recall

### Measurable Outcomes

| Metric | Target |
|--------|--------|
| Precision variance across personas | >10% spread (shows differentiation) |
| Control baseline precision | 70-85% (room for improvement) |
| Expert-difficulty false positive rate | <30% (agents should catch obvious traps) |

### Research Validation

- Agents with high recall but low precision should score differently than balanced agents
- OCEAN correlation with precision (hypothesis: Conscientiousness correlates with better precision)
- Persona differentiation: "thorough" personas may have lower precision if they over-flag

## Dependencies

- Existing `baseline_issues` infrastructure (done)
- Detection scoring v2 with precision component (done)
- Judge skill capable of reading scenario fields (done)

## Risks

| Risk | Mitigation |
|------|------------|
| Red herrings too obvious | Calibrate with control baseline runs |
| Red herrings too subtle | Include difficulty ratings, weight penalties |
| Breaks existing scoring | Backward compatible - missing red_herrings = no change |
| Agents game by flagging nothing | Recall still weighted 3x precision |

## References

- `pennyfarthing/scenarios/schema.yaml` - Current schema
- `pennyfarthing/scenarios/code-review/order-service.yaml` - Pilot scenario
- `pennyfarthing/docs/BENCHMARKING.md` - Benchmark documentation
- ARC-AGI research on pattern matching vs reasoning
- Wallach et al. on construct validity in measurement
