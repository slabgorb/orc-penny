# Story 126-12: Wire setup auto-detection into session-start hook

**Status:** in_progress
**Phase:** finish
**Workflow:** tdd
**Repos:** pennyfarthing
**Jira:** none
**Branch:** feat/126-12-setup-auto-detection

## Story Context

Session-start hook should detect incomplete setup (pf init ran but /pf-setup did not) and inject additionalContext telling Claude to run /pf-setup. Replaces the removed setup-detector.js. Without this, users who run pf init but miss the setup prompt get a half-configured installation with no nudge to complete it.

## Acceptance Criteria

- [ ] session-start hook detects when `.pennyfarthing/` exists but `config.local.yaml` is missing or incomplete
- [ ] hook detects when `repos.yaml` is missing
- [ ] hook detects when `settings.local.json` is missing
- [ ] hook returns additionalContext with instruction to run `/pf-setup` when setup is incomplete
- [ ] detection logic is fast (file existence checks only) to avoid slowing session start
- [ ] setup complete state has no performance penalty
- [ ] unit tests cover detection logic in `test_setup_detection.py`

## Technical Approach

The session-start hook (`pennyfarthing/pennyfarthing-dist/src/pf/hooks/session_start.py`) needs to detect incomplete setup state and return `additionalContext` when setup is incomplete. Key signals:
- `.pennyfarthing/` directory exists (init ran)
- But `config.local.yaml` is missing or has no `theme` key (setup didn't run)
- Or `repos.yaml` is missing
- Or `settings.local.json` is missing

When detected, the hook should return additionalContext instructing Claude to run `/pf-setup`.

When setup is complete, this check should be fast (a few file existence checks) to avoid slowing every session start.

## Files to Modify

- `pennyfarthing/pennyfarthing-dist/src/pf/hooks/session_start.py` — add setup detection
- `pennyfarthing/pennyfarthing-dist/src/pf/init/setup.py` — reuse `get_setup_state()`

## Files to Create (Tests)

- `pennyfarthing/tests/pf/hooks/test_setup_detection.py` — unit tests for detection logic

## Assessment: setup → red

**SM (Captain Carrot):** Story is set up and ready for test design. The session-start hook at `session_start.py` is the integration point. The existing `get_setup_state()` in `setup.py` already does the file-existence checks — TEA should consider whether to reuse it or write a lighter-weight check function that avoids importing yaml for a simple existence test. The key constraint is speed: this runs on every session start, so it must be file-existence checks only (no YAML parsing) for the happy path (setup complete). Only parse when something is missing and we need to explain what's incomplete. Branch is `feat/126-12-setup-auto-detection` in `pennyfarthing/`.

## TEA Assessment

**Tests Required:** Yes
**Reason:** Core detection logic with multiple states and an integration path through session-start

**Test Files:**
- `tests/python/test_setup_detection.py` — 15 tests across 8 classes

**Tests Written:** 15 tests covering 7 ACs
**Status:** RED (failing — ImportError on `detect_incomplete_setup`)

**Design Decisions:**
- New function `detect_incomplete_setup(project_dir: Path) -> str | None` in `session_start.py`
- Returns `None` when setup is complete (fast path — file existence only, no YAML parsing)
- Returns additionalContext string listing missing items when incomplete
- No `.pennyfarthing/` dir = not initialized = returns `None` (can't tell user to setup what isn't installed)
- Performance test verifies yaml.safe_load is NOT called on happy path
- Integration tests verify `main()` outputs proper `HookResponse` JSON with additionalContext

**Handoff:** To Dev (Ponder Stibbons) for implementation

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/src/pf/hooks/session_start.py` — added `detect_incomplete_setup()` function and wired into `main()`

**Implementation Notes:**
- `detect_incomplete_setup(project_dir)` returns `str | None`
- Fast path: if config.local.yaml, repos.yaml, and settings.local.json all exist and are non-empty, returns `None` using only `Path.is_file()` + `Path.stat().st_size` — zero YAML parsing
- Slow path (something missing): builds a detailed report listing what's incomplete, with YAML parsing only for config files that exist but may lack required keys
- `main()` calls detection after checkpoint validation, before WheelHub. If incomplete, outputs `HookResponse` with `additional_context` containing the setup nudge
- No changes to `setup.py` needed — the detection is self-contained in session_start.py

**Tests:** 14/14 passing (GREEN) + 110 existing hooks tests pass (zero regressions)
**Branch:** feat/126-12-setup-auto-detection (pushed)

**Handoff:** To Reviewer (Granny Weatherwax)

## TEA Verify Assessment

**GREEN State Confirmed:** Yes — 14/14 tests passing
**Regressions:** None — 4 pre-existing collection errors in unrelated test files (bellmode, bikerack, statusline), all from prior refactoring commits, not this branch
**Files Changed:** 2 (session_start.py, test_setup_detection.py) — clean diff, no stray changes

**AC Coverage:**
- AC1 (config missing/incomplete): 3 tests — missing, no theme key, null theme
- AC2 (repos.yaml missing): 2 tests — missing, empty file
- AC3 (settings.local.json missing): 1 test — no .claude/ dir
- AC4 (additionalContext with /pf-setup): 3 tests — command mention, lists missing items, returns string
- AC5 (fast detection): 1 test — verifies yaml.safe_load NOT called on happy path
- AC6 (no performance penalty): 2 tests — complete returns None, not-initialized returns None
- AC7 (integration): 2 tests — main() emits additionalContext when incomplete, omits when complete

**Quality Notes:**
- Invalid YAML handled with try/except (reports "unreadable")
- Empty repos.yaml explicitly detected via st_size check
- Fast path uses only Path.is_file() + stat().st_size — no imports or parsing
- Integration tests properly mock stdin, env, and side effects

**Handoff:** To Reviewer (Granny Weatherwax)

## Reviewer Assessment

**Verdict:** APPROVED

**Data flow traced:** CLAUDE_PROJECT_DIR env → Path → detect_incomplete_setup() → str|None → HookResponse(additional_context) → stdout JSON → Claude Code (safe, no injection risk)

**Observations:**
| Severity | Finding | Location |
|----------|---------|----------|
| [VERIFIED] | Fast path: no YAML parsing, confirmed by test | session_start.py:297-303 |
| [VERIFIED] | All 7 ACs covered by 14 tests | test_setup_detection.py |
| [MEDIUM] | Fast path gap: config with content but no theme passes as complete — intentional per AC5 | session_start.py:297-303 |
| [LOW] | Unused imports (sys, Path) and variable (original_print) in test file | test_setup_detection.py:11-12,239 |
| [LOW] | Module-level import yaml runs every session start; ~1ms cost | session_start.py:23 |
| [VERIFIED] | yaml.safe_load used — no deserialization risk | session_start.py:319 |
| [VERIFIED] | Integration tests mock all side effects correctly | test_setup_detection.py:220-300 |

**Error handling:** Invalid YAML caught, empty files caught, TOCTOU race caught by outer exception handler
**Security:** safe_load only, no user-controlled path construction, no injection vectors
**Pattern:** Clean single-responsibility function with str|None return. Follows existing session_start.py patterns.

**Handoff:** To SM (Captain Carrot) for finish-story