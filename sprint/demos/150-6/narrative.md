# Narrative

## Problem Statement
**Problem:** The agent review pipeline accepted vague, unchecked justifications for rule deviations, had no safeguard against quietly deleting or weakening tests, and enforced a fixed list of reviewers that became wrong the moment an operator changed the configuration.

**Why it matters:** When any team — human or AI — can say "I reviewed this" without citing a real source, the audit trail is fiction. Defects slip to production, reviewers lose confidence in the output, and compliance paperwork becomes a checkbox exercise rather than a real control.

---

## What Changed
Think of the agent review workflow like a law firm's signature chain. Every deviation from the agreed playbook has to cite a real document — not "general vibes."

Three specific holes were closed:

**1. Vague citations were silently accepted.**
Before, an agent could write `Spec source: general architecture` and the quality gate would wave it through. Now every deviation must point to a real document — a specific file name, an acceptance-criteria number, or a named section. "I read the spec" no longer passes; you have to say *which page*.

**2. Test coverage could be quietly erased.**
A developer could delete a snapshot test file, add a "skip this test" marker, or swap a strict assertion for a meaningless one — and no gate would notice. A new quality regression guard now scans every change for these patterns and stops the handoff before weakened coverage can reach review.

**3. The required-reviewer list was hardcoded.**
The workflow had nine specialist reviewer agents baked in. When an operator disabled two of them in settings, the gate still demanded results from all nine and blocked the handoff with a misleading error listing agents that weren't even running. The gate now reads live configuration: if an agent is disabled, its slot is pre-filled as "Skipped" and the workflow proceeds cleanly.

---

## Why This Approach
**Pattern matching, not another AI layer.**
Each of these checks uses deterministic rules — the same logic a search-and-replace would use. This keeps gates fast (milliseconds), predictable (same input, same result every time), and auditable (a gate either fires or it doesn't, with no ambiguity).

**Graduated authority, not binary pass/fail.**
The hierarchy (session notes > story context > epic context > architecture docs) issues a *warning* when a lower-authority source is cited, rather than an outright block. The issue surfaces for human review without grinding the whole workflow to a halt over edge cases.

**Configuration-aware enforcement.**
Hardcoding a list of required reviewers means the enforcement logic falls out of sync every time an operator changes settings. By reading live configuration at gate-evaluation time, enforcement and configuration stay in lockstep automatically — zero manual maintenance.

---

## Before/After
| Scenario | Before | After |
|---|---|---|
| **Blank spec source** | `Spec source:` (empty) — gate passes silently | Gate fails: `"Entry 'Changed field name' has empty Spec source — must cite a specific document or section"` |
| **Vague spec source** | `Spec source: general architecture` — gate passes | Gate fails: `"vague Spec source 'general architecture' — must reference a file path, AC, or section"` |
| **Valid spec source** | `Spec source: context-story-150-6.md, AC-3` — passes | Still passes — no change for well-formed citations |
| **Snapshot test deleted** | `tests/snapshots/api.snap` deleted — gate has no awareness | Gate fails: `"Snapshot file deleted: tests/snapshots/api.snap"` |
| **Test marked `.skip()`** | `it.skip('auth test')` added — gate has no awareness | Gate fails: `".skip() added in src/auth.test.ts"` |
| **Strict assertion replaced** | `assert_json_snapshot!` removed, replaced with `assert!(true)` — gate is silent | Gate fails: `"Snapshot assertion removed in src/api_test.rs"` |
| **Subagent disabled in config** | Gate still demands all 9, blocks handoff with misleading error | Gate reads settings, pre-fills disabled agents as `Skipped / disabled`, workflow proceeds |
| **Gate error message** | `"missing specialist subagent tags: [EDGE], [SILENT], [TEST], [DOC], [TYPE], [SEC], [SIMPLE]"` (7 hardcoded, always) | `"missing specialist subagent tags: [EDGE], [TEST]"` (only the 2 that are actually enabled) |
