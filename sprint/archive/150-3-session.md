---
story_id: "150-3"
jira_key: null
epic: null
workflow: "tdd"
---

# Story 150-3: Theme character extension — config.local.yaml overrides for custom roles

## Story Details

- **ID:** 150-3
- **Title:** Theme character extension — config.local.yaml overrides for custom roles
- **Points:** 5
- **Workflow:** tdd
- **Epic:** 150 (Custom Agent Creation System)
- **Jira Key:** None (framework story, local tracking only)
- **Stack Parent:** none
- **Repository:** pennyfarthing (gitflow, branch: feat/150-3-theme-character-extension)

## Description

Wire theme_characters map from config.local.yaml into load_persona(). Consumer sets `theme_characters.my-agent: "Character Name"` and the persona loader picks it up for custom agent roles without requiring a theme file fork.

### Acceptance Criteria

1. load_persona() checks config.local.yaml theme_characters BEFORE theme YAML
2. Custom roles not in the theme YAML still resolve if they're in config.local.yaml
3. config.local.yaml overrides take precedence over theme YAML entries for both built-in and custom roles
4. Tests verify override behavior for both built-in roles (e.g., sm → Grand Admiral Thrawn) and custom roles (e.g., gm → "Character Name")

### Use Case

oq-1 repo currently has `theme_characters:` in config.local.yaml for overriding BUILT-IN roles (e.g., `sm: Grand Admiral Thrawn`), but custom roles like `gm` require editing every theme YAML file directly. This story makes config.local.yaml overrides work for custom roles too.

### Dependencies

- 150-1 (agents-local/) — COMPLETE
- 150-2 (pf agent create) — COMPLETE

## Workflow Tracking

**Workflow:** tdd
**Phase:** finish
**Phase Started:** 2026-04-03T11:42:33Z

### Phase History

| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-04-03 | 2026-04-03T11:34:11Z | 11h 34m |
| red | 2026-04-03T11:34:11Z | 2026-04-03T11:36:49Z | 2m 38s |
| green | 2026-04-03T11:36:49Z | 2026-04-03T11:38:38Z | 1m 49s |
| spec-check | 2026-04-03T11:38:38Z | 2026-04-03T11:39:23Z | 45s |
| verify | 2026-04-03T11:39:23Z | 2026-04-03T11:40:11Z | 48s |
| review | 2026-04-03T11:40:11Z | 2026-04-03T11:42:21Z | 2m 10s |
| spec-reconcile | 2026-04-03T11:42:21Z | 2026-04-03T11:42:33Z | 12s |
| finish | 2026-04-03T11:42:33Z | - | - |

## Delivery Findings

### TEA (test design)
- No upstream findings during test design.

### Dev (implementation)
- No upstream findings during implementation.

### Architect (spec-check)
- No upstream findings during spec-check.

### TEA (test verification)
- No upstream findings during test verification.

### Reviewer (code review)
- No upstream findings during code review.

## Design Deviations

### TEA (test design)
- No deviations from spec.

### Dev (implementation)
- No deviations from spec.

### Reviewer (audit)
- No undocumented deviations found.

### Architect (reconcile)
- No additional deviations found. TEA and Dev entries verified — both accurately report no spec deviations.

## Sm Assessment

**Story 150-3** is ready for the RED phase. Theme character extension — enables `config.local.yaml` `theme_characters` map to work for custom roles (like `gm`) not just built-in role overrides.

**Driving use case:** The GM agent in oq-1 currently requires editing every theme YAML to add a `gm:` character entry. This story makes it work via `config.local.yaml` alone: `theme_characters.gm: "The Bendu"`.

**Key areas for testing:**
- `load_persona()` checks `config.local.yaml` `theme_characters` BEFORE theme YAML
- Custom roles not in theme YAML resolve if they're in `config.local.yaml`
- Built-in role overrides still work (backward compatibility)
- Missing character in both sources returns None gracefully

**Branch:** `feat/150-3-theme-character-extension` in pennyfarthing repo (targets `develop`)

**Handoff to:** TEA (RED phase) — write failing tests for persona loader extension

## Tea Assessment

**Tests Required:** Yes
**Reason:** Persona loader change affects all agent activation — must verify override priority and backward compatibility

**Test Files:**
- `pennyfarthing-dist/src/pf/tests/test_theme_character_extension.py` — 12 tests

**Tests Written:** 12 tests covering 3 ACs
**Status:** RED (6 failing, 6 passing — ready for Dev)

### Rule Coverage

| Rule | Test(s) | Status |
|------|---------|--------|
| #6 test quality | Self-check: all 12 tests have meaningful assertions | passing |

**Self-check:** 0 vacuous tests found

**Implementation guidance for Dev:**
1. In `persona.py:load_persona()` — after getting theme, read `config.local.yaml` `theme_characters` map
2. If `theme_characters[agent_name]` exists, use that character name instead of the theme YAML lookup
3. For custom roles not in theme YAML: create a minimal Persona with just the character name from config
4. In `get_crew_manifest()` — merge `theme_characters` entries (both overrides and custom roles) into the crew list

**Handoff:** To Dev (White Rabbit) for GREEN phase

## Dev Assessment

**Status:** GREEN — all 12 tests passing
**Regression check:** 100/100 existing tests still passing

**Changes made:**
1. `pennyfarthing-dist/src/pf/prime/persona.py:load_persona()` — Added `config.local.yaml` `theme_characters` lookup before theme YAML. Custom roles create minimal Persona from config character name alone.
2. `pennyfarthing-dist/src/pf/prime/persona.py:get_crew_manifest()` — Merges `theme_characters` overrides and custom roles into crew list. Config overrides win for character name.

**Diff size:** +35/-13 lines in 1 file.

**AC coverage:**
- AC 1 (wire theme_characters): `load_pennyfarthing_config()` reads `theme_characters` map, checked before theme YAML ✓
- AC 2 (consumer sets character): `theme_characters.gm: "The Bendu"` resolves in `load_persona("gm")` ✓
- AC 3 (no theme fork): Custom roles not in theme YAML work via config alone ✓

**Handoff:** To TEA for verify phase

## Architect Assessment (spec-check)

**Spec Alignment:** Aligned
**Mismatches Found:** None

| AC | Spec | Code | Status |
|----|------|------|--------|
| 1 | Wire theme_characters into load_persona() | Lines 112-114 read config, check theme_characters | Aligned |
| 2 | Consumer sets character, persona loader picks it up | Line 132: config override wins over theme YAML | Aligned |
| 3 | Custom roles resolve without theme fork | Lines 124-125: custom role + config override returns Persona | Aligned |

**Decision:** Proceed to verify phase

## Tea Assessment (verify)

**Phase:** finish
**Status:** GREEN confirmed

### Simplify Report

**Teammates:** Manual review (diff too small for fan-out)
**Files Analyzed:** 2

**Applied:** 0 fixes — code is clean
**Overall:** simplify: clean

**Quality Checks:** 112/112 tests passing
**Handoff:** To Queen of Hearts (Reviewer) for code review

## Subagent Results

| # | Specialist | Received | Status | Findings | Decision |
|---|-----------|----------|--------|----------|----------|
| 1 | reviewer-preflight | Yes | clean | none | N/A — 64/64 tests, 0 smells |
| 2 | reviewer-edge-hunter | Yes | Skipped | disabled | Disabled via settings |
| 3 | reviewer-silent-failure-hunter | Yes | Skipped | disabled | Disabled via settings |
| 4 | reviewer-test-analyzer | Yes | Skipped | disabled | Disabled via settings |
| 5 | reviewer-comment-analyzer | Yes | Skipped | disabled | Disabled via settings |
| 6 | reviewer-type-design | Yes | Skipped | disabled | Disabled via settings |
| 7 | reviewer-security | Yes | findings | 1 | dismissed 1 |
| 8 | reviewer-simplifier | Yes | Skipped | disabled | Disabled via settings |
| 9 | reviewer-rule-checker | Yes | Skipped | disabled | Disabled via settings |

**All received:** Yes (2 enabled returned, 7 disabled pre-filled)
**Total findings:** 0 confirmed, 1 dismissed

### Security Finding Triage

1. **[SEC] XML attribute injection via character name (line 324)** — Dismissed (LOW). Pre-existing pattern — ALL persona fields (style, role, quote, trait) are interpolated unescaped into pseudo-XML tags in `format_persona_output` and `format_persona_compressed`. Not introduced by this PR. Attack requires local filesystem write to gitignored `config.local.yaml`. These tags are consumed by Claude's context window, not parsed by an XML parser.

## Reviewer Assessment

**Verdict:** APPROVED

### Observations

1. [VERIFIED] Config override priority — `persona.py:114` reads `theme_characters[agent_name]`, line 132 uses `character_override or agent_data.get(...)`. Config wins. Evidence: persona.py lines 112-132. Complies with AC 1.

2. [VERIFIED] Custom role resolution — Lines 124-125: if no `agent_data` AND no `character_override`, returns None. If config has it, proceeds to build Persona with `agent_data = agent_data or {}` (empty dict fallback). Evidence: persona.py lines 121-128. Complies with AC 2, 3.

3. [VERIFIED] Crew manifest includes custom roles — `get_crew_manifest()` lines 172-175 append custom roles from `theme_characters` to `all_roles`. Lines 178-184 let config overrides win. Evidence: persona.py lines 167-184. Complies with AC 2.

4. [VERIFIED] Backward compatibility — `config.get("theme_characters", {}) or {}` handles None/missing gracefully. If no theme_characters, both functions fall through to original theme YAML behavior. Evidence: line 113.

5. [VERIFIED] Safe YAML loading — `load_pennyfarthing_config` uses `yaml.safe_load` via `load_yaml_config`. No unsafe deserialization. Evidence: config.py:137.

### Rule Compliance

| Rule | Applicable Code | Status |
|------|----------------|--------|
| #3 Type annotations | All functions have annotations | Compliant |
| #8 Safe YAML | `load_pennyfarthing_config` → `yaml.safe_load` | Compliant |
| SOUL #10 Return results | Persona returns `(None, None)` on not-found | Compliant |

[EDGE] No findings (disabled). [SILENT] No findings (disabled). [TEST] No findings (disabled). [DOC] No findings (disabled). [TYPE] No findings (disabled). [SEC] 1 finding dismissed (pre-existing unescaped XML interpolation). [SIMPLE] No findings (disabled). [RULE] No findings (disabled).

### Devil's Advocate

What if `theme_characters` contains a non-string value? E.g., `theme_characters: {gm: 42}` or `theme_characters: {gm: [a, b]}`. The code does `character_override = theme_characters.get(agent_name)` and then `character=character_override or agent_data.get("character", "Unknown")`. If `character_override` is 42, it's truthy, so `Persona(character=42)` — the dataclass would accept it (character is typed `str` but Python doesn't enforce at runtime). This would produce `Character: 42` in the output — ugly but harmless, not a crash. The config is developer-authored, not user input. Not blocking.

What if `load_pennyfarthing_config` returns None? It returns `{}` on not-found (per implementation). `{}.get("theme_characters", {})` → `{}`. Safe.

Nothing blocking uncovered.

**Data flow traced:** config.local.yaml → yaml.safe_load → dict → theme_characters[agent_name] → string → Persona.character → markdown output. Safe.
**Pattern observed:** Config-override-then-fallback at persona.py:112-132, same pattern as agents-local/ loader priority.
**Error handling:** Graceful None returns on all missing-data paths.
**Handoff:** To Mad Hatter (SM) for finish-story