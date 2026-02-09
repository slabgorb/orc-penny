# Story Context: 97-1 - CLI Statusline Tandem Indicator

## Summary

Modify the CLI statusline script to detect an active tandem phase and display the backseat agent's character name alongside the primary agent. Format: `[DEV] Toby Ziegler + Will Bailey`. The suffix drops when the phase ends or backseat crashes. No statusline protocol changes. No indicator when no tandem configuration exists.

## Planning References

- **PRD:** FR22-FR23 (CLI statusline indicator), NFR14 (no protocol changes). See `sprint/planning/tandem-mode-prd.md`
- **UX Design Spec:** "Journey 3: CLI User with Tandem", "Feedback Patterns" table (CLI column) in `sprint/planning/tandem-mode-ux-design.md`
- **Epics Breakdown:** Story 4.1 in `sprint/planning/tandem-mode-epics.md` under "Epic 4: CLI Tandem & Shipping Workflow"

## Current State

### Statusline script (existing)

**File:** `pennyfarthing/pennyfarthing-dist/scripts/misc/statusline.sh` (258 lines)

Overall structure:
1. **Lines 1-11:** Read stdin JSON, validate with jq
2. **Lines 14-27:** Extract fields (cwd, model)
3. **Lines 29-43:** Git branch detection and dirty status
4. **Lines 45-54:** Context percentage calculation
5. **Lines 56-71:** `get_agent_abbrev()` — maps agent names to 3-char codes (PM, SM, DEV, etc.)
6. **Lines 73-91:** Agent name lookup from `.session/agents/{session-id}` files
7. **Lines 93-135:** Character name resolution from theme YAML
8. **Lines 137-155:** ANSI color constants
9. **Lines 156-171:** `get_agent_color()` — maps agent roles to ANSI codes
10. **Lines 173-202:** Progress bar rendering (10-segment, color-coded)
11. **Lines 204-209:** Branch color (yellow if dirty, green if clean)
12. **Lines 211-246:** Fixed-width formatting and segment assembly
13. **Lines 248-257:** Final output: `[ROLE] Theme | repo | branch | model [progress] pct%`

Agent section rendering (lines 218-234):
- Role displayed as 3-char abbreviation in reverse video with agent-specific ANSI color
- Character name appended in dim text
- Segment ~20 chars width

Agent name lookup flow:
1. `agent-session.sh start "tea"` writes agent name to `.session/agents/{session-id}`
2. Statusline reads session ID from stdin JSON
3. Looks up `.session/agents/{session-id}` for agent name
4. Falls back to most recently modified agent file
5. Character name resolved from theme YAML (lines 93-135)

### Agent color map (existing)

| Agent | Color | ANSI Code |
|-------|-------|-----------|
| pm | Purple | `\033[35m` |
| sm | Blue | `\033[34m` |
| dev | Green | `\033[32m` |
| tea | Teal | `\033[36m` |
| reviewer | Red | `\033[31m` |
| architect | Orange | `\033[33m` |
| devops | Cyan | `\033[96m` |
| ux | Pink | `\033[95m` |
| tech-writer | White | `\033[37m` |
| orchestrator | Magenta | `\033[95m` |

### Theme YAML character resolution (lines 93-135)

- Reads config to find active theme (`.pennyfarthing/config.local.yaml`)
- Looks up agent character from theme file (`.pennyfarthing/personas/themes/{theme}.yaml`)
- Smart name extraction: removes titles, parentheticals, takes last name
- Fallback to theme name if no character found

### No tandem detection

- Statusline has no awareness of tandem phases
- No tandem observation file check
- No backseat agent display

## Target State

After implementation:

1. Statusline detects active tandem phase by checking `.session/*-tandem-*.md` files
2. Extracts backseat agent name from observation file header
3. Resolves backseat character name from theme YAML (same pipeline as primary)
4. Displays: `[DEV] Toby Ziegler + Will Bailey`
5. Backseat character name uses backseat agent's ANSI color
6. Suffix drops when observation file stops updating (stale >60s) or doesn't exist
7. No statusline protocol changes — same stdin JSON format

## Key Files

### Files to Modify

| File | Path | Purpose |
|------|------|---------|
| `statusline.sh` | `pennyfarthing/pennyfarthing-dist/scripts/misc/statusline.sh` | Add tandem detection after agent name lookup (~line 91); render `+ {backseat}` suffix in agent section |

### Files to Read (Context / Reference)

| File | Path | Why |
|------|------|-----|
| `statusline.sh` | Lines 73-135 | Existing agent name lookup and character resolution pattern |
| Observation file | `.session/*-tandem-*.md` | Header format with `**Observer:** {agent} ({persona})` |
| `agent-session.sh` | `pennyfarthing/pennyfarthing-dist/scripts/core/agent-session.sh` | Session agent tracking (reference only, no changes) |

## Technical Approach

### Tandem Detection (add after line 91)

```bash
# --- Tandem detection ---
TANDEM_CHAR=""
TANDEM_FILE=$(ls -t "$PROJECT_ROOT/.session/"*-tandem-*.md 2>/dev/null | head -1)
if [ -n "$TANDEM_FILE" ]; then
  # Check freshness — only show if file updated within last 60s
  TANDEM_MTIME=$(stat -f %m "$TANDEM_FILE" 2>/dev/null || stat -c %Y "$TANDEM_FILE" 2>/dev/null)
  NOW=$(date +%s)
  if [ $((NOW - TANDEM_MTIME)) -lt 60 ]; then
    # Extract observer agent from file header
    TANDEM_AGENT=$(grep '^\*\*Observer:\*\*' "$TANDEM_FILE" | sed 's/\*\*Observer:\*\* \([^ ]*\).*/\1/')
    if [ -n "$TANDEM_AGENT" ]; then
      # Resolve character name using same theme lookup
      TANDEM_CHAR=$(resolve_character_name "$TANDEM_AGENT")
      TANDEM_COLOR=$(get_agent_color "$TANDEM_AGENT")
    fi
  fi
fi
```

### Display Format (modify lines 218-234)

Current:
```
[DEV] Toby Ziegler
```

With tandem:
```
[DEV] Toby Ziegler + Will Bailey
```

The `+ {backseat}` suffix uses the backseat agent's color. Implementation:

```bash
AGENT_DISPLAY="${AGENT_COLOR}${REVERSE} ${AGENT_ABBREV} ${RESET} ${DIM}${AGENT_CHAR}${RESET}"
if [ -n "$TANDEM_CHAR" ]; then
  AGENT_DISPLAY="${AGENT_DISPLAY} ${DIM}+${RESET} ${TANDEM_COLOR}${TANDEM_CHAR}${RESET}"
fi
```

### Width Considerations

The agent section is ~20 chars without tandem. With tandem, it grows to ~35-40 chars. Options:
- Allow the section to grow (simplest, acceptable for most terminal widths)
- Truncate character names to first name only (e.g., "Toby + Will")
- Use agent abbreviation for backseat (e.g., "Toby Ziegler + ARC")

Recommendation: allow growth for now. Most terminals are 80+ chars wide, and the total statusline stays under 80 chars even with tandem.

### Cross-Platform stat

The `stat` command differs between macOS and Linux:
- macOS: `stat -f %m` (modification time in epoch seconds)
- Linux: `stat -c %Y` (modification time in epoch seconds)

The script should try macOS format first, fallback to Linux:
```bash
TANDEM_MTIME=$(stat -f %m "$TANDEM_FILE" 2>/dev/null || stat -c %Y "$TANDEM_FILE" 2>/dev/null)
```

### Character Name Resolution

The existing character resolution logic (lines 93-135) should be extracted into a function that can be called for both primary and backseat agents. Currently it's inline code. Refactor to:

```bash
resolve_character_name() {
  local agent="$1"
  # ... existing lookup logic from lines 93-135 ...
}
```

Then call for both:
```bash
AGENT_CHAR=$(resolve_character_name "$AGENT_NAME")
TANDEM_CHAR=$(resolve_character_name "$TANDEM_AGENT")
```

## Acceptance Criteria

- Statusline shows `[ROLE] Character + Backseat Character` when tandem phase is active
- Backseat character name uses the backseat agent's ANSI color
- Indicator drops when observation file is stale (>60s since last update)
- Indicator drops when no observation file exists
- No statusline protocol changes — same stdin JSON format
- No indicator when no tandem configuration exists on the current workflow
- Character name resolution uses same theme YAML pipeline as primary agent
- Works on both macOS and Linux (cross-platform `stat`)

## Dependencies

### Depends On

- **95-2** (Backseat agent spawn) — creates the observation file that statusline detects

### Depended On By

- Nothing. This is CLI polish.

## Risks / Open Questions

1. **Freshness threshold:** 60 seconds may be too aggressive or too lenient. If the backseat writes observations every 5 seconds, 60s gives a 55s buffer. If it writes every 30 seconds, 60s gives only 30s buffer. Consider making the threshold configurable or using 120s for safety.

2. **Multiple tandem files:** If multiple tandem phases have run in the same session, there could be multiple `*-tandem-*.md` files. Taking the most recently modified (`ls -t | head -1`) is correct — it represents the current or most recent backseat.

3. **Width overflow:** If both character names are long (e.g., "President Bartlet + Ainsley Hayes"), the agent section could exceed 40 chars. Consider truncation at a fixed width. For MVP, allow growth — it's a statusline, not a fixed-width UI element.

4. **Character name extraction:** The `resolve_character_name` refactoring is not strictly necessary — the same logic could be duplicated for tandem. But extracting a function is cleaner and prevents drift. The developer should decide based on the existing code structure.
