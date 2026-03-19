# Narrative

## Problem Statement
**Problem:** The agent review pipeline could pass quality gates even when agents were citing vague or low-authority sources for spec deviations, silently weakening test coverage, or ignoring the hierarchy of which documents should take precedence over others. **Why it matters:** When agents skip or misrepresent their sources, reviewers lose confidence in the output, defects slip through to production, and the audit trail that proves "we checked this" becomes unreliable.

---

## What Changed
Think of the agent workflow like a law firm with a clear chain of authority: a client's signed contract outweighs a generic industry handbook. Before this fix, agents could file a "deviation report" and cite the equivalent of "general vibes" as their justification — the system accepted it without complaint.

Three concrete problems were fixed:

1. **Vague citations were allowed.** An agent could write `Spec source: general architecture` and the gate would wave it through. Now, every deviation must cite a real document — a file name, an acceptance criterion number, or a section reference. Saying "I read the spec" is no longer enough; you have to say *which page*.

2. **Test coverage could be silently erased.** A developer could delete a snapshot test file, add `.skip()` to a test, or replace a strict snapshot assertion with a weaker one — and no gate would catch it. A new quality regression guard now scans every code change for these patterns and blocks the handoff.

3. **Reviewer subagents were hardwired.** The reviewer always had to wait for all nine specialist subagents, even if some were turned off in configuration. Gate error messages still listed all nine and blocked on all nine. Now the gate reads live configuration and only requires the agents that are actually enabled — disabled agents are pre-filled as "Skipped" so the workflow can proceed cleanly.

---

## Why This Approach
**Pattern matching over AI judgment.** Each of these checks uses deterministic regular-expression rules rather than asking another AI to decide. This keeps the gates fast, predictable, and auditable — a gate either fires or it doesn't, with no ambiguity about why.

**Graduated authority, not binary pass/fail.** The hierarchy (`session → story-context → epic-context → architecture`) issues a warning rather than a hard block when a low-authority source is cited. This lets the workflow surface the issue for human review without grinding everything to a halt over edge cases.

**Configuration-aware enforcement.** Hardcoding a list of required subagents meant the enforcement logic was always out of sync when operators toggled subagents off. By reading live settings at gate-evaluation time, enforcement and configuration stay in lockstep automatically.

---

## Before/After
| Scenario | Before | After |
|---|---|---|
| **Empty spec source** | `Spec source:` (blank line) — gate passes silently | Gate fails: `"Entry 'Changed field name' has empty Spec source — must cite a specific document or section"` |
| **Vague spec source** | `Spec source: general architecture` — gate passes | Gate fails: `"vague Spec source 'general architecture' — must reference a file path, AC, or section"` |
| **Valid spec source** | `Spec source: context-story-150-6.md, AC-3` — passes | Continues to pass — no change to valid citations |
| **Snapshot test deleted** | `tests/snapshots/api.snap` deleted — gate has no awareness | Gate fails: `"Snapshot file deleted: tests/snapshots/api.snap"` |
| **Test skipped** | `it.skip('auth test')` added — gate has no awareness | Gate fails: `".skip() added in src/auth.test.ts"` |
| **Snapshot assertion replaced** | `assert_json_snapshot!` removed, replaced with `assert!(true)` — gate silent | Gate fails: `"Snapshot assertion removed in src/api_test.rs"` |
| **Subagent disabled in settings** | Gate still demands all 9 subagents, blocks handoff with misleading error | Gate reads settings, only requires enabled subagents, pre-fills disabled ones as `Skipped / disabled` |
| **Gate error message** | `"missing specialist subagent tags: [EDGE], [SILENT], [TEST], [DOC], [TYPE], [SEC], [SIMPLE]"` (always 7 hardcoded) | `"missing specialist subagent tags: [EDGE], [TEST]"` (only the tags for enabled subagents) |
