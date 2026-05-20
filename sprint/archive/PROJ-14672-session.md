# Story 95-7: Bell mode observation injection

**Jira:** PROJ-14672
**Epic:** epic-95 (Workflow Configuration & Observation Protocol)
**Points:** 3
**Workflow:** tdd
**Phase:** finish
**Branch:** feature/95-7-bell-mode-observation-injection
**Repos:** pennyfarthing

## Acceptance Criteria

1. PostToolUse hook checks tandem observation file mtime for new content
2. Injects observations as bell messages: `[Tandem] {persona_name}: {observation_summary}`
3. Primary agent surfaces observations in own voice, attributing to backseat persona
4. No bell mode schema changes required
5. Injection completes within existing hook time budget (NFR2)
6. Both bash and Python hook implementations updated

## Technical Context

### What This Story Does

Bell mode observation injection is the final step of the tandem observation loop. Once a backseat agent has written observations to `.session/{story-id}-tandem-{agent}.md`, the bell mode hook reads and injects them back into the primary agent's context.

The flow is:
1. Backseat agent writes observations to `.session/{story-id}-tandem-{agent}.md` (append-only)
2. Bell mode PostToolUse hook detects new observations via mtime check
3. Hook extracts latest observation entry and formats as `[Tandem] {persona_name}: {observation_summary}`
4. Hook injects via existing `hookSpecificOutput.additionalContext` mechanism
5. Primary agent receives and surfaces the observation in its own voice

### Key Implementation Details

**Files to Modify:**
- `pennyfarthing-dist/scripts/hooks/bell-mode-hook.sh` (line 107) -- add tandem file check after bell queue check
- `pennyfarthing_scripts/bellmode_hook.py` (line 155) -- same tandem observation check in Python

**Hook Integration:**
- Existing PostToolUse hook already checks `.pennyfarthing/bell-queue.json`
- Tandem extends this: after bell queue check, check for tandem observation files matching `.session/*-tandem-*.md`
- Track last-read position in a sidecar file (`.session/.tandem-mtime-{agent}`)
- If file modified since last check, extract latest observation entry
- Format as `additionalContext`: `[Tandem] {persona_name}: {observation_summary}`
- Inject via same `hookSpecificOutput` mechanism (no schema changes needed)

**Hook Output Format (Unchanged):**
```json
{
  "hookSpecificOutput": {
    "hookEventName": "PostToolUse",
    "additionalContext": "[Tandem] Will Bailey: The event handler pattern here differs from the notification module."
  }
}
```

### Observation File Format (Reference)

The backseat agent creates files at `.session/{story-id}-tandem-{agent}.md` with this format:

```markdown
# Tandem Observations: {story-id}
**Observer:** {agent} ({persona})
**Phase:** {phase}
**Started:** {ISO timestamp}

---

## [{HH:MM}] Observation
**Trigger:** {trigger_type}: {trigger_detail}
{observation text}

---
```

Key properties:
- Append-only (new entries appended, never modified)
- Entry-atomic (each entry is complete markdown; crash mid-write leaves prior entries valid)
- Valid markdown throughout lifecycle (NFR11)

### Constraints

- **Hook time budget (NFR2):** Tandem injection must complete within existing PostToolUse hook time budget
- **No schema changes (NFR12):** Bell mode config/schema remains unchanged; tandem reuses existing `additionalContext` format
- **Non-blocking (NFR1):** Hook must never delay tool execution for primary agent
- **Backward compatible (NFR15):** Workflows without tandem still work unchanged

### Dependencies

**Story 95-7 depends on:**
- Story 95-3: Observation file format and writer (backseat must be able to write observations)
- Implicit: Stories 95-4, 95-5, 95-6 (file-watch, tool-watch, context-watch scopes) provide the observations to inject

**Story 95-7 enables:**
- The complete tandem observation loop end-to-end
- Epics 96 (Cyclist Tandem UI) and 97 (CLI Tandem & Shipping Workflow) which depend on tandem working

## Story Context

### Bell Mode Architecture

From `pennyfarthing-dist/guides/bell-mode.md`:
- Bell mode queues messages from external sources into the primary agent's context via PostToolUse hook
- Hook receives `.pennyfarthing/bell-queue.json` with message list
- Each message formatted as `additionalContext` and injected into next tool use
- Existing hook implementations: bash (`bell-mode-hook.sh`) and Python (`bellmode_hook.py`)

### Tandem System Overview (from Epic 95)

The tandem system allows workflow authors to add `tandem:` blocks to their workflow YAML, and BikeLane spawns/terminates backseat agents with observation scopes.

The complete tandem loop:
1. **95-1:** YAML schema and BikeLane validation
2. **95-2:** Backseat agent spawn and lifecycle
3. **95-3:** Observation file format and writer
4. **95-4:** File-watch observation scope
5. **95-5:** Tool-watch observation scope
6. **95-6:** Context-watch observation scope
7. **95-7:** Bell mode observation injection (THIS STORY)

### Component Map

```
Backseat Agent (long-lived background subagent)
  |  writes observations to: .session/{story-id}-tandem-{agent}.md
  v
Bell Mode Hook (PostToolUse trigger)
  |  detects new observations via mtime check
  |  extracts latest observation entry
  |  formats: [Tandem] {persona_name}: {observation_summary}
  v
Primary Agent
  |  receives injected observation → surfaces in own voice
```

### Related Files to Reference

- **Bell mode guide:** `pennyfarthing-dist/guides/bell-mode.md` -- PostToolUse hook protocol, config structure
- **Epic context:** `sprint/context/context-epic-95.md` -- complete technical architecture
- **PRD:** `sprint/planning/tandem-mode-prd.md` -- feature requirements (FR1-FR17), NFRs
- **Session state patterns:** `packages/core/src/workflow/session-state.ts` -- existing state tracking patterns
- **Background task tracking:** `pennyfarthing-dist/scripts/lib/background-tasks.sh` -- existing background task infrastructure

## TEA Assessment

**Tests Required:** Yes
**Reason:** 3-point TDD feature with 6 ACs requiring Python function implementation and bash hook updates

**Test Files:**
- `tests/python/test_bellmode_tandem_injection.py` - 30 tests covering all 6 ACs

**Tests Written:** 30 tests covering 6 ACs
**Status:** RED (17 failing on assertions, 13 passing infrastructure/negative cases)

**Test Classes:**
| Class | AC | Tests | Status |
|-------|-----|-------|--------|
| `TestMtimeTracking` | AC1 | 7 | 5 RED, 2 GREEN |
| `TestMessageFormatting` | AC2 | 8 | 6 RED, 2 GREEN |
| `TestOutputFormat` | AC3 | 2 | 1 RED, 1 GREEN |
| `TestNoSchemaChanges` | AC4 | 2 | 2 GREEN |
| `TestHookTimeBudget` | AC5 | 3 | 1 RED, 2 GREEN |
| `TestDualImplementation` | AC6 | 4 | 3 RED, 1 GREEN |
| `TestEdgeCases` | — | 4 | 2 RED, 2 GREEN |

**Stubs Created in `bellmode_hook.py`:**
- `read_tandem_observations(project_root)` → find `.session/*-tandem-*.md` files
- `get_latest_observation(file_content)` → parse latest `## [HH:MM] Observation` block + extract persona
- `format_tandem_message(persona, text)` → `[Tandem] {persona}: {text}`
- `get_tandem_mtime(project_root, agent)` → read `.session/.tandem-mtime-{agent}`
- `save_tandem_mtime(project_root, agent, mtime)` → write mtime sidecar
- `check_tandem_files(project_root)` → orchestrate: find files, check mtime, extract, format

**Implementation Notes for Dev:**
1. **Python (bellmode_hook.py):** Implement the 6 stub functions. Wire `check_tandem_files()` into `main()` after the bell queue check. If tandem observations found AND no bell queue messages, use tandem as additionalContext instead.
2. **Bash (bell-mode-hook.sh):** Add tandem file detection after line 107 (bell queue check). Use `stat -f %m` (macOS) or `stat -c %Y` (Linux) for mtime. Store sidecar at `.session/.tandem-mtime-{agent}`.
3. **Observation parsing:** Each entry starts with `## [HH:MM] Observation`. Extract persona from `**Observer:** {agent} ({persona})` header. Return last entry's text (between final `---` markers).
4. **Priority:** Bell queue messages take precedence over tandem observations (only one additionalContext per hook invocation).

**Handoff:** To Dev (The White Rabbit) for implementation

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing_scripts/bellmode_hook.py` - 6 tandem functions + main() wiring
- `pennyfarthing-dist/scripts/hooks/bell-mode-hook.sh` - tandem section with mtime tracking

**Tests:** 30/30 passing (GREEN)
**PR:** #805 - feat(95-7): bell mode tandem observation injection
**Branch:** feature/95-7-bell-mode-observation-injection (pushed)

**Handoff:** To Reviewer for code review

## Reviewer Assessment

**Verdict:** APPROVED

**Preflight:**
- Tests: 30/30 passing (0.05s)
- Forbidden patterns: None
- Import hygiene: Clean
- Bash syntax: Valid (`shellcheck` clean)

**Observations:**

| # | Severity | File | Finding |
|---|----------|------|---------|
| 1 | VERIFIED | `bellmode_hook.py` | Data flow: mtime check → parse → format → inject — correct |
| 2 | VERIFIED | `bellmode_hook.py:291-302` | Bell queue precedence enforced via early `sys.exit(0)` |
| 3 | LOW | `bellmode_hook.py:112` | Stale "Stubs for tandem observation injection. Dev will implement." comment |
| 4 | VERIFIED | `bellmode_hook.py:246-248` | Error handling: `try/except OSError` around stat and read |
| 5 | VERIFIED | `bellmode_hook.py:195` | Mtime float equality roundtrip: `str(mtime)` → `float(text)` preserves precision |
| 6 | VERIFIED | `bellmode_hook.py:145-165` | Regex parsing handles multi-entry, single-entry, empty, and no-trigger cases |
| 7 | MEDIUM | `bell-mode-hook.sh:120` | Bash word-splitting on `$TANDEM_FILES` if filenames contain spaces — practically impossible given naming convention `*-tandem-*.md` |
| 8 | VERIFIED | `bell-mode-hook.sh:179-186` | JSON output matches pre-existing bell queue pattern exactly |
| 9 | LOW | `bell-mode-hook.sh:62` | `BELL_QUEUE_HANDLED=false` variable set but never read (leftover from restructuring) |
| 10 | VERIFIED | `bellmode_hook.py:230,286` | Double `is_bell_mode_enabled` call (in `check_tandem_files` and `main`) — acceptable, fast stat check |

**Summary:** Clean implementation. All 6 ACs met. Bell queue precedence correct. Mtime tracking robust. Dual implementations (Python + bash) follow identical logic. No Critical or High issues. Two cosmetic LOWs and one theoretical MEDIUM that cannot trigger in practice.

**PR:** #805 merged
**Handoff:** To SM for story completion
