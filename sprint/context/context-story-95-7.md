# Story Context: 95-7 - Bell Mode Observation Injection

## Summary

Extend the PostToolUse hook to check the tandem observation file for new content and inject it as a bell message into the primary agent's context. The primary agent receives observations formatted as `[Tandem] {persona_name}: {observation_summary}` and surfaces them in its own voice. No bell mode schema changes required. Must complete within the existing hook time budget.

## Planning References

- **PRD:** FR15-FR17 (bell mode injection, format, attribution), NFR2 (hook time budget), NFR12 (no bell schema changes). See `sprint/planning/tandem-mode-prd.md`
- **UX Design Spec:** "Bell Mode Integration" section in `sprint/planning/tandem-mode-ux-design.md`
- **Epics Breakdown:** Story 2.7 in `sprint/planning/tandem-mode-epics.md` under "Epic 2"

## Current State

### Bell mode hook (existing)

**File:** `pennyfarthing/pennyfarthing-dist/scripts/hooks/bell-mode-hook.sh` (107 lines)

Current flow:
1. **Lines 24-36:** Find project root (walk up to `.pennyfarthing/`)
2. **Lines 38-51:** Check if bell mode enabled in `config.local.yaml`
3. **Lines 53-62:** Check bell queue file (`.pennyfarthing/bell-queue.json`) for messages
4. **Lines 64-70:** Extract first message text
5. **Lines 80-87:** Output `hookSpecificOutput` JSON:
   ```json
   {
     "hookSpecificOutput": {
       "hookEventName": "PostToolUse",
       "additionalContext": "User feedback: {message_text}"
     }
   }
   ```
6. **Lines 91-104:** Background: dequeue message, notify Cyclist via `/api/bell-consumed`

### Python implementation (existing)

**File:** `pennyfarthing/pennyfarthing_scripts/bellmode_hook.py` (155 lines)
- Same logic as bash implementation
- Must receive the same tandem extension

### Bell mode guide (reference)

**File:** `pennyfarthing/pennyfarthing-dist/guides/bell-mode.md`
- Documents the bell queue format, PostToolUse protocol, config structure
- `additionalContext` is the injection mechanism — already established

### Observation file (from 95-3)

**Location:** `.session/{story-id}-tandem-{agent}.md`
- Append-only markdown with `---`-separated entries
- Each entry has timestamp, trigger type, trigger detail, observation text

## Target State

After implementation:

1. PostToolUse hook checks tandem observation file for new content after the bell queue check
2. Tracks last-read position via mtime sidecar (`.session/.tandem-mtime-{agent}`)
3. If new content since last check, extracts the latest observation entry
4. Formats as `additionalContext`: `[Tandem] {persona_name}: {observation_summary}`
5. Injects via existing `hookSpecificOutput` mechanism
6. Primary agent receives the observation and surfaces it in its own voice
7. No bell mode schema changes — uses existing `additionalContext` format
8. Completes within existing hook time budget

## Key Files

### Files to Modify

| File | Path | Purpose |
|------|------|---------|
| `bell-mode-hook.sh` | `pennyfarthing/pennyfarthing-dist/scripts/hooks/bell-mode-hook.sh` | Add tandem observation file check after bell queue check |
| `bellmode_hook.py` | `pennyfarthing/pennyfarthing_scripts/bellmode_hook.py` | Same extension in Python |

### Files to Read (Context / Reference)

| File | Path | Why |
|------|------|-----|
| `bell-mode.md` | `pennyfarthing/pennyfarthing-dist/guides/bell-mode.md` | Bell mode protocol, `additionalContext` format |
| Observation file | `.session/*-tandem-*.md` | File format to parse for new entries |

## Technical Approach

### Hook Extension (bash)

After the existing bell queue check (after line 70), add tandem observation check:

```bash
# --- Tandem observation injection ---
TANDEM_FILES=$(ls .session/*-tandem-*.md 2>/dev/null | grep -v '.tandem-mtime')
if [ -n "$TANDEM_FILES" ]; then
  for TANDEM_FILE in $TANDEM_FILES; do
    AGENT_NAME=$(echo "$TANDEM_FILE" | sed 's/.*-tandem-\(.*\)\.md/\1/')
    MTIME_FILE=".session/.tandem-mtime-${AGENT_NAME}"

    # Check if file has been modified since last read
    if [ -f "$MTIME_FILE" ]; then
      LAST_MTIME=$(cat "$MTIME_FILE")
      CURRENT_MTIME=$(stat -f %m "$TANDEM_FILE" 2>/dev/null || stat -c %Y "$TANDEM_FILE")
      if [ "$CURRENT_MTIME" = "$LAST_MTIME" ]; then
        continue  # No new content
      fi
    fi

    # Extract latest observation entry (last block between --- separators)
    LATEST_OBS=$(awk '/^---$/{block=""; next} {block=block"\n"$0} END{print block}' "$TANDEM_FILE" | tail -20)

    if [ -n "$LATEST_OBS" ]; then
      # Get persona name from file header
      PERSONA=$(grep "^\*\*Observer:\*\*" "$TANDEM_FILE" | sed 's/.*(\(.*\))/\1/')

      # Format for injection
      TANDEM_MSG="[Tandem] ${PERSONA}: ${LATEST_OBS}"

      # Update mtime tracker
      stat -f %m "$TANDEM_FILE" > "$MTIME_FILE" 2>/dev/null || stat -c %Y "$TANDEM_FILE" > "$MTIME_FILE"
    fi
  done
fi
```

### Output Integration

The hook currently outputs bell queue messages OR nothing. With tandem, the output can include both:

```json
{
  "hookSpecificOutput": {
    "hookEventName": "PostToolUse",
    "additionalContext": "[Tandem] Will Bailey: The event handler pattern here differs from the notification module. Consider extracting a shared EventDispatcher."
  }
}
```

If both a bell message and a tandem observation exist, concatenate:
```
"additionalContext": "User feedback: {bell_msg}\n\n[Tandem] {persona}: {observation}"
```

### Mtime Tracking

- Sidecar file: `.session/.tandem-mtime-{agent}`
- Contains the file's modification timestamp (epoch seconds)
- Checked on each hook invocation
- If tandem file mtime > stored mtime → new content exists
- Updated after successful read

### Primary Agent Attribution

The primary agent receives `[Tandem] Will Bailey: ...` in its `additionalContext`. It should surface this naturally:

> "Will Bailey notes that the event handler pattern here differs from the notification module — we might want to extract a shared EventDispatcher."

The attribution format (`[Tandem] {persona}:`) tells the primary agent who the observation is from. The primary surfaces it in its own voice with attribution.

## Acceptance Criteria

- PostToolUse hook checks tandem observation file for new content
- New observations injected as `additionalContext` with `[Tandem] {persona}: {summary}` format
- Mtime tracking prevents re-injecting already-read observations
- Works with all observation scopes (file-watch, tool-watch, context-watch)
- Completes within existing hook time budget
- No bell mode schema changes
- Bell queue messages and tandem observations can coexist in the same hook output
- Both bash and Python hook implementations updated

## Dependencies

### Depends On

- **95-3** (Observation file format) — must know the file format to parse entries

### Depended On By

- No stories directly depend on this — it completes the tandem observation loop

## Risks / Open Questions

1. **Hook time budget:** Adding file stat + read + parse to every PostToolUse invocation. The mtime check is fast (single stat call). Reading the latest entry requires parsing from the end of the file. For large observation files, `tail` + `awk` should be fast enough. Benchmark to confirm.

2. **Multiple tandem files:** If multiple backseat agents are active (combined scopes), there could be multiple observation files. The hook should check all matching files. For MVP, assume one tandem file per phase.

3. **Bell vs tandem priority:** If both a bell message and a tandem observation exist, which takes priority in the `additionalContext`? Recommendation: bell messages first (user feedback is higher priority than agent observations), then tandem. Concatenate with newline separator.

4. **Observation freshness:** The mtime check only detects if the file changed, not how many new entries exist. If the backseat writes 3 observations between hook invocations, only the latest is injected. For MVP this is acceptable — the backseat accumulates context, so the latest observation is the most informed.

5. **Cross-platform stat:** The `stat` command has different flags on macOS (`-f %m`) vs Linux (`-c %Y`). The hook must handle both. The Python implementation avoids this with `os.path.getmtime()`.
