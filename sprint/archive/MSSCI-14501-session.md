# Story 86-6: Tandem metrics and token tracking

**Status:** in-progress
**Jira:** MSSCI-14501
**Branch:** feature/MSSCI-14501-tandem-metrics-token-tracking
**Repos:** pennyfarthing
**Workflow:** tdd
**Phase:** finish
**Assigned:** keith.avery@1898andco.io
**Sprint:** 2606

---

## Story Context

**Title:** Tandem metrics and token tracking

**Points:** 2

**Priority:** P1

**Description:** Track consultation token usage, frequency, and outcomes for overhead analysis.

### Acceptance Criteria

- [ ] Consultation tokens logged separately from leader session tokens
- [ ] Metrics captured: count, total tokens, avg response time, outcome distribution
- [ ] Metrics written to dialogue file summary section
- [ ] Session summary includes tandem overhead percentage
- [ ] Target: consultation overhead < 25% of baseline story token cost

---

## Epic Context

### Epic 86: Agent Collaboration — Tandem to Teams

This epic builds a graduated agent collaboration system for Pennyfarthing, starting with Tandem consultation (ADR-0012) as the foundation and layering Claude Code's native Agent Teams as an optional upgrade for interactive users.

**Three tiers of agent collaboration:**
- **Tier 1: Subagents** (existing) — Fire-and-forget, Haiku, <1K tokens, no communication, `-p` compatible
- **Tier 2: Tandem** (Phase 1, this story) — Structured Q&A, Sonnet, capped budget, request/response, `-p` compatible
- **Tier 3: Native Teams** (Phase 2) — Parallel sessions, full context windows, free-form messaging, interactive only

**Phase 1 delivers:** Tandem consultation (stories 86-1 through 86-6) — works in `-p` mode, no new dependencies.

Story 86-6 focuses on instrumenting Tandem consultations to understand their cost and effectiveness. This provides:
1. Token usage tracking per consultation exchange
2. Metrics aggregation for dialogue summary sections
3. Overhead percentage calculation vs baseline story cost
4. Foundation for cost-based triggers and workflow tuning

**Related stories:**
- 86-3: Dialogue file management (creates the `.session/{story-id}-dialogue.md` structure)
- 86-16: Port dialogue manager to Python (ports metrics logic to `pennyfarthing_scripts/consultation/dialogue_manager.py`)

---

## Technical Approach

### Key Considerations

1. **Token Counting:** The Tandem consultation protocol (86-2) spawns a Haiku subagent and captures structured responses. Metrics must track:
   - Input tokens (consultation request sent to partner)
   - Output tokens (partner response received)
   - Total per exchange
   - Cumulative across dialogue

2. **Dialogue File Integration:** Metrics live in the `.session/{story-id}-dialogue.md` summary section (created by 86-3). The summary format likely includes:
   ```
   ## Summary
   - Total exchanges: N
   - Total tokens: M
   - Avg response time: X ms
   - Outcome distribution: applied (%), deferred (%), rejected (%)
   - Overhead: Y% of baseline
   ```

3. **Baseline Measurement:** "Consultation overhead < 25% of baseline story token cost" implies:
   - Baseline = non-tandem session token cost
   - Measurement per story or globally?
   - Likely captured in session summary section created at story completion

4. **Implementation Points:**
   - Update dialogue manager (86-3) to log token counts on each exchange
   - Calculate summary metrics at dialogue refresh/close
   - Ensure metrics are human-readable and audit-friendly
   - May tie into `pf sprint story show` command for oversight

### Key Files to Modify

- `pennyfarthing_scripts/consultation/dialogue_manager.py` — core metrics logic (after porting from 86-3)
- `.session/{story-id}-dialogue.md` — summary section format
- Possibly `packages/core/src/consultation/dialogue-manager.ts` (before porting to Python in 86-16)

### Dependencies

- **Blocks:** 86-16 (porting logic to Python relies on stable metrics interface)
- **Blocked by:** 86-3 (dialogue file structure must be finalized first)

---

## TEA Assessment

**Tests Required:** Yes
**Reason:** Core metrics module — all 5 ACs require new computation logic

**Test Files:**
- `packages/core/src/consultation/tandem-metrics.test.ts` — 37 tests across all ACs

**Tests Written:** 37 tests covering 5 ACs
**Status:** RED (all failing with `Error('not implemented')` — ready for Dev)

**AC → Test Mapping:**
| AC | Tests | Description |
|----|-------|-------------|
| AC1 | 5 | Per-exchange input/output token tracking, exclusion of untracked exchanges |
| AC2 | 7 | Aggregate metrics: avg response time, outcome distribution, multi-exchange totals |
| AC3 | 9 | Summary formatting as markdown bullets, round-trip parse, null handling |
| AC4 | 7 | Overhead percentage calculation, rounding, edge cases (zero baseline, large values) |
| AC5 | 7 | Budget threshold validation: default 25%, custom thresholds, null/zero cases |
| Compliance | 2 | Result format validation (field presence, type checks) |

**Implementation Stubs:**
- `aggregateMetrics(exchanges)` — aggregate token/timing/outcome data
- `calculateOverheadPercent(tandemTokens, baselineTokens)` — overhead calculation
- `isWithinBudget(overheadPercent, threshold?)` — threshold check (default 25%)
- `formatMetricsSummary(metrics)` — markdown bullet array for dialogue summary
- `parseMetricsFromSummary(content)` — parse metrics from existing summary

**Handoff:** To Jack Torrance (Dev) for implementation

---

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `packages/core/src/consultation/tandem-metrics.ts` - Implemented all 5 stub functions (aggregateMetrics, calculateOverheadPercent, isWithinBudget, formatMetricsSummary, parseMetricsFromSummary)

**Tests:** 37/37 passing (GREEN)
**PR:** #933 — feat(86-6): implement tandem metrics and token tracking
**Branch:** feature/MSSCI-14501-tandem-metrics-token-tracking (pushed)

**Handoff:** To Reviewer for code review

---

## Reviewer Assessment

**Verdict:** APPROVED
**Data flow traced:** `MetricsExchange[]` → `aggregateMetrics()` → `TandemMetricsSummary` → `formatMetricsSummary()` → `string[]` → `parseMetricsFromSummary()` → round-trip verified (safe: pure functions, no I/O, no injection vectors)
**Pattern observed:** Framework-compliant pure module at `tandem-metrics.ts:75-206` — `.js` imports, exported types, no thrown exceptions, result objects
**Error handling:** Zero baseline → null at `tandem-metrics.ts:122`, empty exchanges → zeroed summary at `tandem-metrics.ts:104`, null overhead → pass-through at `tandem-metrics.ts:138`
**Observations:**
- `[VERIFIED]` 37/37 tests pass, no forbidden patterns, no TypeScript errors in changed file
- `[VERIFIED]` Round-trip format/parse integrity confirmed
- `[MEDIUM]` `aggregateMetrics` returns `overheadPercent: null` by design — caller composes with `calculateOverheadPercent`
- `[LOW]` `outcomeDistribution` typed as `Record<string, number>` — acceptable, tests validate shape

**Handoff:** To SM for finish-story