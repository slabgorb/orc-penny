# Story Context: 95-6 - Context-Watch Observation Scope

## Summary

Implement periodic conversation summary delivery for the backseat agent running with `scope: context-watch`. The backseat receives summaries of the primary agent's conversation at configurable turn intervals, enabling high-level awareness of the primary's reasoning and decisions. Summary generation must not block the primary agent, and combined token overhead stays under 25% per phase.

## Planning References

- **PRD:** FR13-FR14 (context-watch scope, summary intervals), NFR1 (non-blocking), NFR5 (configurable intervals), NFR7 (25% token overhead limit). See `sprint/planning/tandem-mode-prd.md`
- **UX Design Spec:** "Three Observation Scopes" table in `sprint/planning/tandem-mode-ux-design.md`
- **Epics Breakdown:** Story 2.6 in `sprint/planning/tandem-mode-epics.md` under "Epic 2"

## Current State

### No context-watch infrastructure exists

- No mechanism to summarize or forward primary agent conversation to a background agent
- Claude Code's conversation context is internal to the primary agent process
- No existing summary generation pipeline

### OTEL spans (reference)

- Claude Code emits OTEL spans that include conversation metadata
- Cyclist's WheelHub intercepts these spans
- Could be a source of conversation state, but spans don't contain full conversation text

### PostToolUse hook (reference)

**File:** `pennyfarthing/pennyfarthing-dist/scripts/hooks/bell-mode-hook.sh` (107 lines)
- Fires after every tool call — could count turns and trigger summary generation at intervals
- Already has `hookSpecificOutput` injection mechanism

## Target State

After implementation:

1. Backseat with `scope: context-watch` receives periodic conversation summaries
2. Summaries generated at configurable turn intervals (e.g., every 5 tool calls)
3. Summary captures: what the primary is working on, key decisions made, current approach
4. Summary generation is non-blocking to primary agent
5. Combined token overhead (summary generation + delivery) stays under 25% per phase

## Key Files

### Files to Modify

| File | Path | Purpose |
|------|------|---------|
| `bell-mode-hook.sh` | `pennyfarthing/pennyfarthing-dist/scripts/hooks/bell-mode-hook.sh` | Track turn count, trigger summary generation at intervals |
| `bellmode_hook.py` | `pennyfarthing/pennyfarthing_scripts/bellmode_hook.py` | Same in Python |

### Files to Read (Context / Reference)

| File | Path | Why |
|------|------|-----|
| Observation writer | (from 95-3) | API for writing observation entries |
| `bell-mode-hook.sh` | `pennyfarthing/pennyfarthing-dist/scripts/hooks/bell-mode-hook.sh` | Hook structure and output format |

## Technical Approach

### Summary Generation Strategy

Context-watch is the most challenging scope because the primary agent's full conversation isn't directly accessible to external processes. Options:

**Option A: Session file parsing (recommended for MVP)**
1. The primary agent's session file (`.session/{story-id}-session.md`) accumulates context
2. Periodically read the session file and extract recent additions
3. Generate a summary from the delta since last read
4. Simple, no new infrastructure needed

**Option B: Tool call accumulation**
1. Combine with tool-watch — accumulate tool call summaries over N turns
2. Every N turns, write a "context summary" observation that synthesizes recent tool activity
3. Doesn't capture reasoning, only actions

**Option C: Hook-injected context snapshots**
1. The PostToolUse hook counts turns (via a counter file)
2. Every N turns, it requests the primary agent to emit a brief summary
3. Summary written to a shared file the backseat reads
4. Requires primary agent cooperation — adds to its workload

### Recommended: Option A + B Hybrid

1. Track turn count via a counter file (`.session/.tandem-turn-count`)
2. Every N turns (configurable, default 5):
   - Read session file for recent updates
   - Combine with accumulated tool call data (if tool-watch also active)
   - Backseat synthesizes a context observation
3. The backseat's natural LLM reasoning handles the summarization

### Turn Counter

```bash
# In PostToolUse hook:
COUNTER_FILE=".session/.tandem-turn-counter"
COUNT=$(cat "$COUNTER_FILE" 2>/dev/null || echo 0)
COUNT=$((COUNT + 1))
echo "$COUNT" > "$COUNTER_FILE"

if [ $((COUNT % INTERVAL)) -eq 0 ]; then
  # Signal backseat to generate context summary
  touch ".session/.tandem-context-trigger"
fi
```

### Backseat Context Summary

The backseat detects the trigger file and:
1. Reads the session file for recent content
2. Reviews its accumulated observations
3. Writes a higher-level context observation

### Observation Entry Example

```markdown
---

## [10:45] Observation
**Trigger:** context-watch: summary at turn 15
The developer is midway through migrating NotificationService from vanilla event listeners to React hooks. They've completed the useNotification hook (turns 1-8) and are now working on the NotificationPanel component integration (turns 9-15). The approach follows the same pattern used in the Settings panel migration last sprint. Two test failures remain in the notification test suite — both related to mock timing.

---
```

### Token Budget

NFR7 requires combined scope overhead under 25% per phase. For context-watch:
- Summary generation: ~200-500 tokens per summary
- At every 5 turns over a 50-turn phase: ~10 summaries = 2,000-5,000 tokens
- Well within 25% of a typical phase token budget

## Acceptance Criteria

- Backseat receives periodic conversation summaries at configurable turn intervals
- Default interval: every 5 tool calls
- Summaries capture primary agent's current focus, decisions, and approach
- Summary generation does not block primary agent's conversation flow
- Combined token overhead stays under 25% per phase
- Context accumulates — later summaries reference earlier ones

## Dependencies

### Depends On

- **95-3** (Observation file format) — writes using the observation file format

### Depended On By

- **95-7** (Bell mode injection) — reads context-watch observations for injection

## Risks / Open Questions

1. **Summary quality:** The backseat agent (Haiku) generates summaries from session file content and tool call data. Haiku's summarization quality may be lower than Sonnet/Opus. For MVP, accept this — the summaries are advisory, not authoritative.

2. **Session file access:** If the session file is being actively written by the SM subagent or the primary agent, concurrent reads by the backseat could get partial content. Markdown format mitigates this — partial reads still produce valid content up to the read point.

3. **Configurable interval:** Where does the interval config live? Options:
   - In the workflow YAML tandem block: `tandem: { partner: tea, scope: context-watch, interval: 5 }`
   - In `config.local.yaml` as a global default
   - Hard-coded default (5) with override via environment variable
   For MVP, hard-code the default. Make it configurable in a follow-up.

4. **Token overhead measurement:** NFR7 requires staying under 25%. How do we measure this? Options:
   - Estimate based on summary size × count
   - Track via OTEL spans
   For MVP, estimate is sufficient. The default interval of 5 naturally limits overhead.
