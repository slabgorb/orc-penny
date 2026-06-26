---
story_id: "159-1"
jira_key: ""
epic: "159"
workflow: "tdd"
---
# Story 159-1: theme_characters: accept dict-shaped agent_data, not just character name (gh #34)

## Story Details
- **ID:** 159-1
- **Jira Key:** (none — local sprint only)
- **Type:** bug
- **Points:** 2
- **Workflow:** tdd
- **Stack Parent:** none
- **Repository:** pennyfarthing

## Technical Context

### Problem
The `theme_characters:` field in `.pennyfarthing/config.local.yaml` currently accepts only a string (character name) per role. Setting e.g. `gm: Count Rugen` sets `persona.character` but leaves all other persona fields empty (style, role, trait, quote, helper, motto, quirk, catchphrases), because `load_persona()` reads those from `theme_data["agents"][role]`, which does not exist for custom roles. The only workarounds today are hand-editing framework theme YAML (clobbered by `pf init`) or accepting a lean persona. This was discovered in a real oq-1 migration where a `gm:` block in `princess-bride.yaml` was reverted by `pf init`.

### Proposed Solution
Extend `theme_characters` to accept EITHER a string (current behavior, backwards-compatible) OR a dict matching the `agents.<role>:` shape. The change occurs in `pennyfarthing-dist/src/pf/prime/persona.py` in the `load_persona()` function:

```python
override = theme_characters.get(agent_name)
if isinstance(override, dict):
    agent_data = {**(agent_data or {}), **override}
    character_override = override.get("character")
elif isinstance(override, str):
    character_override = override
```

### Acceptance Criteria
1. `theme_characters.<role>` accepts a string → behaves exactly as today (character name only), backwards-compatible.
2. `theme_characters.<role>` accepts a dict → merges into agent_data so style/role/trait/quote/helper/catchphrases etc. populate the persona.
3. A dict override with a `character` key sets persona.character; a string override still sets persona.character.
4. No regression for roles defined in the theme's own `agents.<role>:` block; dict overrides merge on top of (override-wins) existing agent_data.
5. Tests cover: string override, dict override (full + partial), dict override on a role with no theme agent_data, and the original string-only path.

### Implementation Notes
- Location: `pennyfarthing-dist/src/pf/prime/persona.py`
- Function: `load_persona()`
- Backwards-compatible: string-only behavior unchanged
- Dict merging: override-wins semantics (custom dict on top of theme agent_data)

## Workflow Tracking
**Workflow:** tdd
**Phases:** setup → red → green → review → finish (phased)
**Phase:** finish
**Phase Started:** 2026-06-24T06:15:00Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-06-23T22:14:00.581427+00:00 | 2026-06-23T22:17:56Z | 3m 55s |
| red | 2026-06-23T22:17:56Z | 2026-06-23T22:49:24Z | 31m 28s |
| green | 2026-06-23T22:49:24Z | 2026-06-24T00:00:03Z | 1h 10m |
| review | 2026-06-24T00:00:03Z | 2026-06-24T06:15:00Z | 6h 14m |
| finish | 2026-06-24T06:15:00Z | - | - |

## Sm Assessment

**Routing:** `tdd` (phased) — full ceremony: setup → **red (TEA)** → green (Dev) → review (Reviewer) → finish. Although 2 pts would normally skip TEA under the points-fallback, the story carries an explicit `workflow: tdd` tag, so it routes through TEA for the red phase. Next agent: **TEA**.

**Scope is well-bounded:** single-function change in `pennyfarthing-dist/src/pf/prime/persona.py` (`load_persona()`), backwards-compatible. The behavioral contract is the union type for `theme_characters.<role>`: `str` (legacy) | `dict` (rich override, override-wins merge onto theme `agents.<role>` data).

**TEA focus — the red phase must lock these in failing tests (per AC 5):**
1. String override → character set, legacy behavior unchanged (regression guard).
2. Dict override (full) → style/role/trait/quote/helper/catchphrases all populate.
3. Dict override (partial) → only provided keys override; rest fall back to theme data.
4. Dict override on a role with **no** theme `agents.<role>` block → persona built purely from the dict.
5. Dict override containing `character` → sets `persona.character`.

**Watch-outs for TEA/Dev:**
- Merge semantics are override-wins: `{**(agent_data or {}), **override}`. Confirm whether nested fields like `helper` (a dict) should deep-merge or replace — the issue example shows `helper` as a full dict, so shallow replace is the likely intent; flag in Delivery Findings if ambiguous.
- Don't break the `theme_data["agents"][role]` path for roles that already have a block and no override.
- Repo `pennyfarthing/` targets **develop**, not main. PRs and diffs base on `develop`.

**Jira:** none — local sprint only. No claim/move performed (correct for this repo).

## TEA Assessment

**Tests Required:** Yes
**Reason:** Behavioral change to persona construction in `load_persona()` — a new union type (`str | dict`) for `theme_characters.<role>`.

**Test Files:**
- `pennyfarthing-dist/src/pf/tests/test_159_1_theme_characters_dict.py` — 10 tests for the `theme_characters` str|dict contract.

**Tests Written:** 10 tests covering all 5 ACs (string-only legacy path; dict full; dict partial w/ theme fallback; dict on a custom role with no theme block; dict `character` key + character fallback).
**Status:** RED — 6 failing (feature absent), 4 backwards-compat guards passing.

### Rule Coverage

| Rule | Test(s) | Status |
|------|---------|--------|
| #2 no shared-mutable-state | `test_load_persona_does_not_mutate_theme_agent_data` | failing (RED) — also guards against an in-place `dict.update` fix |
| #6 test quality | self-check (no vacuous asserts, specific value checks, no skips) | pass |

**Rules checked:** 2 of 13 lang-review rules apply to this pure-merge change. The other 11 (silent exceptions, type annotations, logging, path handling, resource leaks, unsafe deserialization, async, import hygiene, input validation, dependency hygiene, fix-regressions) are Dev-implementation concerns with no surface in test design for a dict-merge.
**Self-check:** 0 vacuous tests found.

**RED verification:** `testing-runner` RUN_ID `159-1-tea-red` → 10 collected, 4 passed, 6 failed (also independently confirmed via targeted pytest). Valid RED. Branch `feat/159-1-theme-characters-dict-agent-data` intact (subagent scoped to the single file; no full-suite branch leak).

**Watch-outs passed to Dev (Reverend Mother):**
- Make `persona.character` a plain string in the dict path (`override.get("character")`), never the dict itself.
- Merge override onto theme `agent_data` (override-wins) WITHOUT mutating the theme dict — use `{**(agent_data or {}), **override}`, not `agent_data.update(...)` (the mutation guard enforces this).
- See the three Delivery Findings above (get_crew_manifest parity, nested-dict merge, empty-dict).

**Handoff:** To Dev for GREEN.

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/src/pf/prime/persona.py` — `load_persona()` accepts `theme_characters.<role>` as a str (legacy) or dict (override-wins merge onto theme agent_data, no mutation); `get_crew_manifest()` mirrors the str|dict handling.
- `pennyfarthing-dist/src/pf/tests/test_159_1_theme_characters_dict.py` — +2 crew-manifest tests (Dev-added); 12 total.

**Tests:** 12/12 passing (GREEN) — `testing-runner` RUN_ID `159-1-dev-green`. Existing persona tests regression-free (test_prime / test_json_output / test_config_consolidation = 124 passed). ruff clean on both changed files.
**Branch:** feat/159-1-theme-characters-dict-agent-data (pushed)

**TEA findings — resolution:**
- #1 `get_crew_manifest` parity → FIXED + 2 tests added.
- #2 nested-dict merge → implemented **shallow-replace**: an override's nested dict (e.g. `helper`) replaces the theme's wholesale via `{**agent_data, **override}`, matching the issue's complete-`helper` example.
- #3 empty-dict override → implemented as a **no-op**: an empty dict merges nothing and yields no character, so on a role with no theme block `load_persona` returns `(None, None)`. Chosen behavior, documented here.

**Handoff:** To Reviewer for code review.

## Delivery Findings


Agents record upstream observations discovered during their phase.
Each finding is one list item. Use "No upstream findings" if none.

**Types:** Gap, Conflict, Question, Improvement
**Urgency:** blocking, non-blocking

<!-- Agents: append findings below this line. Do not edit other agents' entries. -->

### TEA (test design)
- **Improvement** (non-blocking): `get_crew_manifest()` consumes the same `theme_characters` map and assigns `CrewMember(character=theme_characters[role])` directly — once dict overrides exist it will render the whole dict as a character name. Affects `pennyfarthing-dist/src/pf/prime/persona.py` (`get_crew_manifest()` must extract `.get("character")` from dict-shaped entries, mirroring the `load_persona` fix). Recommend Dev address in-story for consistency. *Found by TEA during test design.*
- **Question** (non-blocking): Nested-dict merge semantics are unspecified — when both the theme block and a dict override supply `helper` (or any nested dict), the tests assume shallow replace (`{**agent_data, **override}`, override wins wholesale), matching the issue example which provides a complete `helper` block. Affects `pennyfarthing-dist/src/pf/prime/persona.py` (`load_persona()` merge). Dev should confirm shallow-replace is intended; deep-merge would need explicit handling + a test. *Found by TEA during test design.*
- **Question** (non-blocking): Empty-dict override (`theme_characters: {role: {}}`) behavior is undefined and untested — an empty dict is falsy, so the current `if not agent_data and not character_override` guard would treat it as "not found" and return `(None, None)`. Affects `pennyfarthing-dist/src/pf/prime/persona.py` (`load_persona()` found-guard). Dev to decide whether an empty dict registers the role and document the choice. *Found by TEA during test design.*

### Dev (implementation)
- **Improvement** (non-blocking): `pf theme set` rebuilds `theme_characters` as a flat string map and writes it wholesale, clobbering any user dict-shaped overrides in `config.local.yaml` on theme switch. Affects `pennyfarthing-dist/src/pf/theme/cli.py` (~line 305 — preserve/merge existing dict-shaped entries rather than replacing). Follow-up candidate; not required for this story (`load_persona`/`get_crew_manifest` now consume dicts correctly). *Found by Dev during implementation.*

### Reviewer (code review)
- **Improvement** (non-blocking): Field-type robustness — a dict override with `helper` set to a non-dict (e.g. a string) raises `AttributeError`, and `catchphrases` set to a non-list raises `TypeError` via `random.choice()`. Affects `pennyfarthing-dist/src/pf/prime/persona.py` (lines 146, 150-151 — guard non-dict `helper` / non-list `catchphrases` as absent). Pre-existing field-consumption pattern widened to `config.local.yaml` by dict overrides; corroborated by reviewer-security (reliability, not security). *Found by Reviewer during code review.*
- **Improvement** (non-blocking): `get_crew_manifest` partial-override gap — a dict override WITHOUT a `character` key on a role that HAS a theme block drops that role from the crew manifest (`character=None` → `if character:` false), whereas `load_persona` falls back to the theme character. A plausible partial override (tweak style, keep theme character) yields an inconsistent crew reference. Affects `pennyfarthing-dist/src/pf/prime/persona.py` (lines 191-195 — fall back to theme character when override lacks one). *Found by Reviewer during code review.*
- **Improvement** (non-blocking): Test isolation — `_quote_cache` (`persona.py:25`) is a module global never reset between tests, creating latent order-dependence for catchphrase-based tests sharing an `(agent, theme)` key (currently benign). Affects the test suite (add a fixture clearing `pf.prime.persona._quote_cache`). *Found by Reviewer during code review.*
- **Improvement** (non-blocking): Document the `str | dict` shape of `theme_characters.<role>` in the config guide/schema (currently only an inline comment + gh #34). Affects `pennyfarthing-dist/guides/` config docs. *Found by Reviewer during code review.*

## Design Deviations

Agents log spec deviations as they happen — not after the fact.
Each entry: what was changed, what the spec said, and why.

<!-- Agents: append deviations below this line. Do not edit other agents' entries. -->

### TEA (test design)
- No deviations from spec. All five AC-enumerated cases (string-only, dict full, dict partial, dict on a role with no theme block, character-key + fallback) have dedicated tests; an additional mutation guard (python rule #2) is additive coverage, not a spec change.


### Dev (implementation)
- **Extended dict handling to get_crew_manifest beyond TEA's RED set**
  - Spec source: story 159-1 title; TEA Delivery Finding #1
  - Spec text: "theme_characters: accept dict-shaped agent_data, not just character name"
  - Implementation: Updated `get_crew_manifest()` to extract `.get("character")` from dict overrides; added 2 Dev-authored tests (TestCrewManifestDictOverride), since TEA's RED set covered only `load_persona`
  - Rationale: `get_crew_manifest` reads the same `theme_characters` map; leaving it unhandled would render a dict as a character name in the crew manifest — a defect introduced by this very feature (SOUL #14, prove-the-work)
  - Severity: minor
  - Forward impact: none — additive; both new tests pass, no existing test changed


### Reviewer (audit)
- Dev (implementation) — **Extended dict handling to get_crew_manifest beyond TEA's RED set** → ✓ ACCEPTED by Reviewer: sound and in-scope. The feature is "accept dict-shaped agent_data"; `get_crew_manifest` reads the same `theme_characters` map, so leaving it unhandled would render a dict as a character name (SOUL #14). Additive, with 2 Dev-authored tests; no existing test changed. (Residual edge — partial override without `character` drops the role — logged as a non-blocking Delivery Finding, not a reason to reverse the deviation.)
- TEA (test design) — "No deviations from spec" → ✓ Confirmed: AC coverage is complete; nothing to audit.
- No undocumented spec deviations found.


## Subagent Results

| # | Specialist | Received | Status | Findings | Decision |
|---|-----------|----------|--------|----------|----------|
| 1 | reviewer-preflight | Yes | clean | none (GREEN 12/12, ruff pass, 0 smells) | N/A |
| 2 | reviewer-edge-hunter | No | Skipped | disabled | Disabled via settings — assessed manually |
| 3 | reviewer-silent-failure-hunter | No | Skipped | disabled | Disabled via settings — assessed manually |
| 4 | reviewer-test-analyzer | No | Skipped | disabled | Disabled via settings — assessed manually |
| 5 | reviewer-comment-analyzer | No | Skipped | disabled | Disabled via settings — assessed manually |
| 6 | reviewer-type-design | No | Skipped | disabled | Disabled via settings — assessed manually |
| 7 | reviewer-security | Yes | clean | none (0 violations; noted 2 reliability edges) | confirmed 0, dismissed 0, deferred 2 (→ Delivery Findings) |
| 8 | reviewer-simplifier | No | Skipped | disabled | Disabled via settings — assessed manually |
| 9 | reviewer-rule-checker | No | Skipped | disabled | Disabled via settings — assessed manually (see Rule Compliance) |

**All received:** Yes (2 enabled returned clean; 7 disabled via `workflow.reviewer_subagents`, assessed manually)
**Total findings:** 0 confirmed blocking, 0 dismissed, 4 deferred (non-blocking Delivery Findings)

## Rule Compliance

Python lang-review checklist (`.pennyfarthing/gates/lang-review/python.md`), enumerated against the diff (rule_checker disabled — manual):

| # | Rule | Verdict | Note |
|---|------|---------|------|
| 1 | Silent exception swallowing | PASS | No except added; `if character:` drop is intentional contract, not a swallow |
| 2 | Mutable default arguments | PASS | Merge uses `{**a, **b}` (new dict); no mutable defaults; aligns with rule spirit |
| 3 | Type annotations at boundaries | PASS | Signatures unchanged/annotated; new local `character_override: str \| None` added |
| 4 | Logging coverage/correctness | PASS | No logging in module; graceful `(None, None)` returns |
| 5 | Path handling | PASS | No path string-concat; existing Path helpers |
| 6 | Test quality | PASS (LOW note) | Meaningful asserts, correct patch targets, no skips; `_quote_cache` not reset (latent isolation smell) |
| 7 | Resource leaks | PASS | None |
| 8 | Unsafe deserialization | PASS | `yaml.safe_load` throughout (reviewer-security confirmed) |
| 9 | Async pitfalls | N/A | Sync code |
| 10 | Import hygiene | PASS | Explicit imports; no star/cycles |
| 11 | Input validation at boundaries | PASS (LOW note) | `isinstance` type-dispatch added; nested field types (helper/catchphrases) unguarded — local config, not network boundary |
| 12 | Dependency hygiene | N/A | No dependency changes |
| 13 | Fix-introduced regressions | PASS | Re-scanned; the field-type robustness gap is pre-existing-pattern, widened — logged as Delivery Finding |

## Devil's Advocate

Assume this code is broken. Where does it fail? The new dict path trusts that every value in a dict override is well-typed, but `config.local.yaml` is hand-edited — the most likely author of a dict override is a human who just read gh #34 and is improvising. The issue example shows `helper:` as a full `{name, style}` dict, but a hurried user could just as easily write `helper: "The Machine"` (a bare string feels natural for a name). That input flows unchecked into `helper.get("name")` (persona.py:150) and throws `AttributeError` at agent-activation time — a confusing, stack-trace-y failure for what is really a config typo. The same trap waits in `catchphrases:` — write a single string instead of a list and `random.choice()` will either silently pick a character of the string or, for `None`, raise `TypeError`. Neither is a security hole (the file is local and the consumer is the LLM whose prompt the author already controls), but both are real reliability papercuts that the happy-path tests never exercise.

A confused user would also misunderstand the empty-dict and partial-override semantics. `theme_characters: {gm: {}}` does nothing on a role with no theme block (returns `(None, None)`) — a user might reasonably expect it to register a lean `gm`. And the partial override `{dev: {style: "..."}}` — meant to tweak only style while keeping the theme's `dev` character — works in `load_persona` (character falls back) but silently drops `dev` from `get_crew_manifest` (character resolves to `None`), so other agents lose the `dev` character in handoff references. That asymmetry between the two functions is the kind of inconsistency a reviewer must surface: the same config produces a persona but no crew entry.

What about a stressed filesystem or malformed YAML? `load_theme` swallows all exceptions and returns `None` (pre-existing), so a corrupt theme file degrades to `{"agents": {}}` and overrides still apply — acceptable. None of these failure modes rise to Critical/High: the documented dict shape works, is tested, doesn't mutate shared state, and introduces no injection vector. The edges are LOW-severity robustness/UX gaps on malformed local input, captured as non-blocking Delivery Findings.

## Reviewer Assessment

**Verdict:** APPROVED

**Summary:** A tight, well-documented 2-point change. `load_persona()` and `get_crew_manifest()` now accept `theme_characters.<role>` as `str | dict` with override-wins, no-mutation merge semantics. Backwards-compat preserved (4 guards), no-mutation enforced by a dedicated test, security clean. All findings are LOW / non-blocking robustness, test-hygiene, and UX papercuts on *malformed local* config; the documented happy path works and is well covered (12/12 GREEN).

**Data flow traced:** `config.local.yaml` → `load_pennyfarthing_config` → `theme_characters[role]` (`str|dict`) → merged `agent_data` (`{**theme, **override}`) → `Persona` fields via named `.get()` → `format_persona_output` (plain text into the LLM prompt). No file paths derived from override values; `yaml.safe_load` throughout. Safe.

**Observations:**
- [VERIFIED] No-mutation merge — `{**(agent_data or {}), **override}` builds a new dict, never `agent_data.update()` (persona.py:129); enforced by `TestNoInputMutation`. Complies with python rule #2.
- [VERIFIED] Backwards-compat — str path unchanged (persona.py:131-132); 4 compat guards pass; legacy character-only behavior intact.
- [VERIFIED] get_crew_manifest str|dict parity — extracts `.get("character")` from dicts (persona.py:189-195); confirmed by preflight.
- [VERIFIED][SEC] No unsafe deserialization — `yaml.safe_load` (persona.py:88, config loader); reviewer-security clean, 0 findings.
- [LOW][EDGE] Non-dict `helper` in a dict override → `AttributeError` (persona.py:150-151). Pre-existing pattern, widened to config; corroborated by [SEC]. Non-blocking → Delivery Finding.
- [LOW][EDGE] Non-list `catchphrases` in a dict override → `random.choice()` `TypeError` (persona.py:146). Same class; corroborated by [SEC]. Non-blocking → Delivery Finding.
- [LOW][EDGE] get_crew_manifest drops a themed role when a dict override omits `character`, instead of falling back to the theme character (persona.py:191-195) — asymmetric with load_persona. Non-blocking → Delivery Finding.
- [LOW][TEST] `_quote_cache` module global not reset between tests (persona.py:25) — latent order-dependence (currently benign). test_analyzer disabled; assessed manually → Delivery Finding.
- [DOC] Inline comments accurately document the str|dict contract (persona.py:111-113, 127-128, 187-188); no stale/misleading comments. comment_analyzer disabled; assessed manually. Suggest documenting the shape in the config guide → Delivery Finding.
- [TYPE] `character_override: str | None` (persona.py:125) is a net improvement over the prior untyped assignment. type_design disabled; assessed manually — acceptable.
- [SILENT] No swallowed errors introduced; the `if character:` drop is an intentional contract, not an error swallow. silent_failure_hunter disabled; assessed manually.
- [SIMPLE] Minimal change mirroring existing patterns; no over-engineering. simplifier disabled; assessed manually.
- [RULE] python lang-review 13-check pass (see Rule Compliance); LOW notes on #6 and #11. rule_checker disabled; enumerated manually.

**Deviation audit:** Dev's get_crew_manifest scope extension → ACCEPTED (see Design Deviations → Reviewer audit).

**Handoff:** To SM for finish-story.