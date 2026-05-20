# Story 141-26: Wire output_style config to prime activation

**Jira:** PROJ-16208
**Epic:** 141 — PROJ-16127
**Type:** chore
**Points:** 2
**Repos:** pennyfarthing
**Workflow:** trivial
**Phase:** finish
**Branch:** chore/wire-output-style-prime

## Context

The `output_style` config value in `.pennyfarthing/config.local.yaml` (terse/verbose/teaching) is not read by `pf prime` during agent activation. Style files exist at `pennyfarthing-dist/output-styles/` but are never loaded or injected. The guide claims they are loaded during prime — this needs to be made true.

## SM Assessment

Session created, Jira PROJ-16208 claimed. 2pt chore — routing to Mal (Dev) via trivial workflow, skipping TEA. Key files: `pennyfarthing-dist/src/pf/prime/cli.py` (loader), `pennyfarthing-dist/output-styles/` (style files), `.pennyfarthing/config.local.yaml` (config source).

## Acceptance Criteria

- [x] `pf prime` reads `output_style` from config.local.yaml
- [x] Loads corresponding output-styles/{style}.md file content
- [x] Includes style content in prime output (both text and JSON modes)
- [x] Missing or invalid style gracefully falls back (no error)
- [x] Existing tests pass, new test covers style loading

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/src/pf/prime/loader.py` — added `load_output_style()` function
- `pennyfarthing-dist/src/pf/prime/cli.py` — wired output style into text output path (Priority 2.6, between SOUL.md and persona)
- `pennyfarthing-dist/src/pf/prime/tiers.py` — wired output style into JSON/tiered output path (FULL tier)
- `pennyfarthing-dist/src/pf/tests/test_prime.py` — 3 tests: configured style loads, no config returns None, invalid style returns None
- `pennyfarthing-dist/data/spinner-tips.yaml` — fixed /pf-tea tip, added 19 new tips, removed unwired output_style tip
- `pennyfarthing-dist/guides/relay-mode.md` — removed stale deprecation notice

**Tests:** 52/52 passing (GREEN)
**Branch:** chore/wire-output-style-prime (pushed)

**Handoff:** To River for code review

## Reviewer Assessment

**Verdict:** APPROVED
**Data flow traced:** config.local.yaml → `load_pennyfarthing_config()` → `config.get("output_style")` → path construction → `read_text()` → prime output (safe: user-owned config, .md suffix, constrained directory)
**Pattern observed:** Follows exact `load_soul()`/`load_behavior_guide()` pattern — .pennyfarthing/ first, dist_root fallback at `loader.py:89-99`
**Error handling:** All failure modes (no config, non-string, missing file) return None gracefully at `loader.py:85-101`
**Low:** JSON path discards style_name, text path includes it in header — minor inconsistency at `tiers.py:202`

**Handoff:** To Zoe for finish-story

## Delivery Findings

- No upstream findings during implementation.

### Reviewer (code review)

- No upstream findings during code review.