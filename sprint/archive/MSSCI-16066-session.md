# Standalone: Remove is_gui gating from relay mode handoff

**Jira:** MSSCI-16066
**Points:** 2
**Priority:** P2
**Workflow:** standalone
**Status:** done
**Repos:** pennyfarthing
**Branch:** feat/MSSCI-16066-remove-isgui-relay
**PR:** 1238
**Started:** 2026-03-03
**Completed:** 2026-03-03

---

## Description

Remove legacy BikeRack GUI gating from handoff marker generation. Relay mode
now works in all environments (CLI, TUI, GUI). When relay is on, marker outputs
`relay: true` + `invoke` field for the agent to auto-invoke the next agent via
Skill tool. When relay is off, outputs fallback text for manual invocation.

Removes dead code: PF:HANDOFF, PF:CONTEXT_CLEAR, PF:QUESTION HTML comment
markers, tirepump branching, and inline_handoff action blocks.

## Files Changed

| File | Change |
|------|--------|
| `pennyfarthing-dist/src/pf/handoff/marker.py` | Removed is_gui gating, simplified to relay/no-relay paths |
| `pennyfarthing-dist/guides/agent-behavior.md` | Updated exit protocol for relay invoke via Skill tool |
| `pennyfarthing-dist/guides/handoff-cli.md` | Updated marker docs and exit protocol diagram |
