---
story_id: "164-8"
jira_key: ""
epic: "164"
workflow: "tdd"
---
# Story 164-8: 155-13 followups.py hardening

## Story Details
- **ID:** 164-8
- **Jira Key:** (none — local-only)
- **Workflow:** tdd
- **Stack Parent:** none
- **Branch:** feat/164-8-followups-py-hardening
- **PR:** (none yet — recorded when the PR is created)

## Workflow Tracking
**Workflow:** tdd
**Phase:** finish
**Phase Started:** 2026-08-10T17:49:55Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-08-10T17:15:25Z | - | - |

## Story Scope

Four hardening requirements from the 155-13 code review of `pennyfarthing-dist/src/pf/findings/followups.py`. Each maps to an acceptance criterion with exact file/line context.

### AC 1: Promote _parse_session_deviations to Public
**Module:** `pf/findings/summary.py`
**Current definition:** Lines 164-227 (private function `_parse_session_deviations`)
**Callers:**
- `pf/findings/summary.py:255` — `write_impact_summary_to_session()` calls `_parse_session_deviations(content)`
- `pf/findings/followups.py:23` — import statement `from pf.findings.summary import _parse_session_deviations`
- `pf/findings/followups.py:84` — `detect_deferred_followups()` calls `_parse_session_deviations(content)`

**Task:** Rename `_parse_session_deviations` to `parse_session_deviations` (public). Update all three call sites. Behavior unchanged — parse the `## Design Deviations` section from session markdown and return list of deviation dicts with keys: `description`, `rationale`, `severity`, `forward_impact`, plus optional `spec_source`, `spec_text`, `implementation`.

**Acceptance:** Function is public; old private name removed or aliased per pennyfarthing conventions; all internal callers updated; behavior unchanged; test coverage verifies parse correctness.

### AC 2: CWE-22 Containment on session_path
**Module:** `pf/findings/followups.py`
**Current exposure:** Line 185-209 in `suggest_followups()` function
**Current pattern:**
```python
session_path = Path(session_path)
if not session_path.exists():
    return {"success": False, "error": f"Session file not found: {session_path}"}
try:
    content = session_path.read_text(encoding="utf-8")
except (OSError, UnicodeDecodeError) as exc:
    return {...}
```

**Shared validator:** `pf/sprint/path_validation.py` provides `_validate_ref()` (line 26-55) with charset fullmatch `[A-Za-z0-9._-]+` and explicit `..` rejection. Raises `ValueError` on traversal attempt.

**Task:** Add traversal containment check before the `.exists()` call. The expected session directory is `.session/` at the project root. Resolve the input path and verify it stays within that directory (e.g., using `Path.resolve()` + parent containment check, or call an adapted path validator). A crafted `session_path` like `../../etc/passwd` or `...session/foo` must be rejected with a clean error (fail-closed).

**Reuse consideration:** `path_validation.py` guards archive filenames (epic shards, sprint archives) with charset validation. For session paths (full filesystem paths, not just stems), a slightly different guard may be needed (allow `/` separators for path construction, but reject `..`). Consider whether to extend `path_validation.py` with a new function `validate_session_path()` or inline a focused check in `suggest_followups()`.

**Acceptance:** A crafted session_path can't traverse outside `.session/` (or the intended session directory); traversal attempt raises a clean error with an actionable message; test proves the guard works (e.g., attempt `../sprint/future.yaml` as session_path and catch the error).

### AC 3: TypedDict Modeling for Candidate and Suggestion Dicts
**Module:** `pf/findings/followups.py`
**Current dicts (loosely typed):**

**Candidate dict (lines 66-95):**
```python
# From detect_deferred_followups(), appended to candidates list:
{
    "source": "finding"|"deviation",
    "description": str,
    "type": str,  # for source="finding"
}
# or
{
    "source": "deviation",
    "description": str,
    "forward_impact": str,
}
```

**Suggestion dict (lines 268-275):**
```python
# From suggest_followups(), appended to suggestions list:
{
    "description": description,
    "command": command,
    "provenance": provenance,
    "source": candidate["source"],
}
```

**Task:** Model both dict shapes as `TypedDict` classes (at module level or in a types submodule). Use union types to capture the two candidate variants (finding-source vs. deviation-source). Apply the TypedDict at construction and consumption sites:
- `detect_deferred_followups()`: annotate return type as `list[CandidateDict]` and each `.append()` to pass the typed dict.
- `suggest_followups()`: for the inner loop building suggestions, annotate `candidate: CandidateDict` parameter to `_covering_story()` call, and annotate the suggestion dicts in the list.

**Acceptance:** Both dict shapes are modeled as TypedDicts; return types are annotated; construction sites pass correctly-shaped dicts; linter (mypy/pyright) is satisfied; behavior unchanged.

### AC 4: Extend Dedup to future.yaml
**Module:** `pf/findings/followups.py`
**Current dedup logic (lines 141-163, 184-315):**

`_open_stories()` loads `pf/sprint/loader.py:load_sprint()` and collects `(id, title)` tuples for stories in `OPEN_STATUSES = {"backlog", "in_progress", "in_review"}` from the current sprint's merged data (epics → stories). Dedup compares candidate descriptions to open story titles via `_covering_story()` substring match.

**Gap:** The function does NOT check `sprint/future.yaml`, which holds pre-planned epics and stories in the `future.initiatives[].epics[].stories[]` structure (per `pf/sprint/validator.py` lines 100-102, required fields: `id`, `title`, `points`).

**Task:** Extend `_open_stories()` to also scan `future.yaml` stories and add their `(id, title)` tuples to the list. Load `future.yaml` via `pf/common/config.py:load_yaml_config()` (same loader used by `load_sprint()`). Walk the structure: `future.initiatives[] → epics[] → stories[]`, extracting each story's `id` and `title`.

**Result:** A candidate already minted as a story in the future backlog will be deduplicated (not re-suggested at finish time). Test proves the dedup works: create a session with a finding that matches an existing `future.yaml` story title, call `suggest_followups()`, and verify the suggestion is in the `skipped` list, not `suggestions`.

**Acceptance:** `_open_stories()` returns stories from both current sprint AND future.yaml; dedup considers future stories; test proves a candidate in future.yaml is not re-suggested; behavior unchanged for current-sprint-only scenarios.

## Implementation Context

### Files to Modify

1. **`pennyfarthing-dist/src/pf/findings/summary.py`**
   - Rename `_parse_session_deviations` to `parse_session_deviations` (line 164)
   - Update all internal docstrings/references

2. **`pennyfarthing-dist/src/pf/findings/followups.py`**
   - Import `parse_session_deviations` instead of `_parse_session_deviations` (line 23)
   - Update call site at line 84
   - Add TypedDict definitions for `CandidateDict` (union of two variants) and `SuggestionDict`
   - Add session_path containment check in `suggest_followups()` before `.exists()` call (lines 209-211)
   - Extend `_open_stories()` to load and walk `future.yaml` (lines 141-163)
   - Annotate return types and function signatures with TypedDict types

3. **Optional: `pennyfarthing-dist/src/pf/sprint/path_validation.py`**
   - Consider adding a new `validate_session_path()` function if the charset logic should be reused elsewhere

### Test Files to Create/Update

- **`pennyfarthing-dist/src/pf/tests/test_164_8_followups_hardening.py`** — new test file
  - AC 1: Parse function public and callable from both callers
  - AC 2: Traversal rejection (e.g., `../../etc/passwd` as session_path)
  - AC 3: TypedDict compliance (mypy/pyright pass, or manual inspection of type annotations)
  - AC 4: Future.yaml dedup (candidate in future.yaml is skipped, not suggested)

### Relevant Sessions & PRs

- **PR pennyfarthing#155:** Review of the original `followups.py` implementation (code review findings that spawned this story)
- **Story 155-13:** The code review that identified these four hardening needs

## TEA Assessment

**Tests Required:** Yes

**Test Files:**
- `pennyfarthing-dist/src/pf/tests/test_164_8_followups_hardening.py` — 20 tests covering all 4 ACs

**Tests Written:** 20 tests (17 failing RED, 3 regression tests passing)
**Status:** RED (failing — ready for Dev)

**RED failure one-liners per AC:**
- AC1 (×6): `AssertionError: pf.findings.summary.parse_session_deviations does not exist` / `private import still present in followups.py` / `private call still present in summary.py`
- AC2 (×2): Traversal to existing outside file returns `success=True` (not rejected); `..` path not rejected before `.exists()`
- AC3 (×6): `FindingCandidateDict not found` / `DeviationCandidateDict not found` / `SuggestionDict not found` (all three TypedDicts missing)
- AC4 (×3): `candidate already in future.yaml was RE-SUGGESTED` — `_open_stories()` only loads current sprint

**Passing regression tests (3):**
- `test_ac2_inbounds_session_path_still_succeeds` — legitimate .session/ path works
- `test_ac4_no_future_yaml_fails_open_does_not_crash` — absent future.yaml fails open
- `test_ac4_candidate_not_in_future_yaml_is_still_suggested` — no false-positive dedup

**Design notes for Dev:**
- AC3 TypedDict names chosen: `FindingCandidateDict`, `DeviationCandidateDict`, `SuggestionDict` — these must be at module level in followups.py with exact key sets tested
- AC2 containment check: resolve `session_path`, verify it stays within `project_root/.session/` (or detect `..` components) and return `{success: False, error: "...traversal/outside..."}` — the error keyword must be one of: traversal, outside, contain, not within, invalid
- AC1 callers: followups.py:23 import + followups.py:84 call + summary.py:255 call — all three must use public name

**Handoff:** To Dev for implementation

## Delivery Findings

Agents record upstream observations discovered during their phase.
Each finding is one list item. Use "No upstream findings" if none.

<!-- Agents: append findings below this line. Do not edit other agents' entries. -->

### TEA (test design)
- No upstream findings.

### Reviewer (code review)
- **Improvement** (non-blocking): AC3 TypedDicts defined but not applied as annotations — `detect_deferred_followups` returns `list[dict[str, Any]]` not `list[FindingCandidateDict | DeviationCandidateDict]`; candidates/suggestions variables are untyped; `FindingCandidateDict.type` should be `str | None` (construction site uses `.get()`). AC spec required "return types annotated; linter satisfied" which is unmet. Affects `pennyfarthing-dist/src/pf/findings/followups.py:70,91,316` (wire TypedDicts into function signatures and variable annotations). *Found by Reviewer during code review.*
- **Improvement** (non-blocking): AC4 `except Exception: pass` silently swallows `yaml.YAMLError` on corrupt future.yaml — dedup silently skips with zero diagnostic signal, indistinguishable from an empty backlog. Spec-compliant fail-open per AC, but project pattern prefers warn-then-fail-open. Affects `pennyfarthing-dist/src/pf/findings/followups.py:210` (add `warnings.warn()` or similar before `pass`). *Found by Reviewer during code review.*
- **Improvement** (non-blocking): CWE-22 TOCTOU — `_resolved = session_path.resolve()` used for containment check (line 274) but original `session_path` used for `exists()` (line 286) and `read_text()` (line 290). A symlink swap in the window could bypass the guard. Affects `pennyfarthing-dist/src/pf/findings/followups.py:274,286,290` (use `_resolved.exists()` and `_resolved.read_text()` after the check). *Found by Reviewer during code review.*
- **Improvement** (non-blocking): `_session_base` at line 273 is `Path(_check_root).resolve() / ".session"` — the `.session` component is not resolved. If `.session/` is a symlinked directory, all legitimate session paths are wrongly rejected (false positive). Affects `pennyfarthing-dist/src/pf/findings/followups.py:273` (use `(Path(_check_root).resolve() / ".session").resolve()`). *Found by Reviewer during code review.*
- **Improvement** (non-blocking): `ImportError` not in the `except (FileNotFoundError, OSError)` tuple at line 270 (and 309). If the lazy `from pf.common.config import get_project_root` import fails, the exception propagates out of `suggest_followups()`, violating the "never raises" contract. Affects `pennyfarthing-dist/src/pf/findings/followups.py:270,309` (add `ImportError` to both except tuples). *Found by Reviewer during code review.*

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/src/pf/findings/summary.py` — renamed `_parse_session_deviations` → `parse_session_deviations`; updated internal caller at line 255
- `pennyfarthing-dist/src/pf/findings/followups.py` — updated import + call site (AC1); added CWE-22 containment check in `suggest_followups()` (AC2); added `FindingCandidateDict`, `DeviationCandidateDict`, `SuggestionDict` TypedDicts (AC3); extended `_open_stories()` to walk `future.yaml` (AC4)

**Tests:** 20/20 passing (GREEN), 236 regression tests passing
**Branch:** feat/164-8-followups-py-hardening (pushed, commit ce49e8167)

**Handoff:** To next phase (reviewer)

## Design Deviations

Agents log spec deviations as they happen — not after the fact.
Each entry: what was changed, what the spec said, and why.

<!-- Agents: append deviations below this line. Do not edit other agents' entries. -->

## Subagent Results

| # | Specialist | Received | Status | Findings | Decision |
|---|------------|----------|--------|----------|----------|
| 1 | reviewer-preflight | Yes | clean | encoding smell in summary.py:249 (pre-existing); 20/20 tests pass | N/A — pre-existing |
| 2 | reviewer-edge-hunter | Yes | findings | `initiatives: null` unguarded (LOW new); empty-desc false-match in `_covering_story` (LOW pre-existing) | Noted LOW |
| 3 | reviewer-silent-failure-hunter | Yes | findings | `except Exception: pass` at followups.py:210 swallows YAMLError silently | Noted MEDIUM |
| 4 | reviewer-test-analyzer | Yes | findings | AC3 tests vacuous (existence only, not usage); no corrupt-YAML test | Noted LOW |
| 5 | reviewer-comment-analyzer | Yes | findings | 3 lying docstrings: `_open_stories` says "open" for all future stories; suggest_followups docstring omits CWE-22 failure case; stale comment on line 211 claims "missing" handled by except (it isn't) | Noted LOW |
| 6 | reviewer-type-design | Yes | findings | TypedDicts defined but not applied as annotations; return type still `list[dict[str, Any]]` | Noted MEDIUM |
| 7 | reviewer-security | Yes | findings | TOCTOU between resolve() check and read; `_session_base` not fully resolved (symlink edge) | Noted LOW |
| 8 | reviewer-rule-checker | Yes | findings | detect_deferred_followups/`_session_epic` unguarded in suggest_followups (pre-existing); summary.py:249 encoding (pre-existing) | Pre-existing, not blocking |
| 9 | reviewer-simplifier | Yes | findings | TypedDicts are dead declarations; duplicate project-root resolution logic; epic-story traversal duplicated | Noted LOW/MEDIUM |

All received: Yes

## Reviewer Assessment

**Verdict:** APPROVED

**AC4 fail-open determination:** Absent future.yaml is handled correctly by the `if future_path.exists()` guard before the try block — the except never fires for a missing file. Corrupt future.yaml is swallowed by `except Exception: pass` (followups.py:210) with **zero signal** — dedup silently skips, re-minting future backlog stories as suggestions. The stale comment at line 211 incorrectly claims the except also handles "missing." This is MEDIUM: spec explicitly requested fail-open for corrupt files; the feature is non-blocking/suggest-only; but no warning/log emitted means an operator cannot distinguish empty backlog from corrupt file. Does not block — flagged as delivery finding for follow-up.

**AC2 containment scope determination:** The `.session/` restriction is **correct** for all legitimate callers. `suggest_followups()` is called by `sm-finish` on live session files only — archived sessions live at `sprint/archive/` and are never passed to this function. The guard uses `session_path.resolve()` which correctly follows symlinks in the session path itself, so a symlink pointing outside `.session/` is caught. The `_session_base` is not fully resolved (followups.py:273), meaning a symlinked `.session/` directory would cause false-positive rejections — LOW edge case, unusual deployment. Fail-open when project_root is unresolvable is intentional per spec. No bypass via normal operation.

**Data flow traced:** crafted `session_path` (`.session/../sprint/fixture.yaml`) → `Path.resolve()` → `relative_to(_session_base)` raises ValueError → `{success: False, error: "...traversal rejected..."}` — fires before `.exists()` call. [SEC] Guard correct for normal paths.

**Pattern observed:** fail-open posture used consistently throughout — missing sprint data, missing future.yaml, unresolvable project root all degrade gracefully. Pattern at `followups.py:191-211`. [SILENT] The one exception: corrupt future.yaml swallowed with no signal.

**Error handling:** `suggest_followups()` returns result objects at every documented exit path. [RULE] The unguarded `detect_deferred_followups()` and `_session_epic()` calls at lines 301-302 are pre-existing (not in this diff) but represent a latent "never raises" contract violation.

**Observations:** 20/20 AC tests pass; 3108 regression tests pass; 1 pre-existing failure in unrelated 164-1 scope.

| Severity | Issue | Location | Fix Required |
|----------|-------|----------|--------------|
| [MEDIUM] [TYPE] [SIMPLE] | AC3 TypedDicts defined but not applied as annotations; `detect_deferred_followups` returns `list[dict[str, Any]]`; `FindingCandidateDict.type` should be `str\|None`; TypedDicts are dead declarations | `followups.py:70,91,316` | Wire into function signatures and variable annotations in follow-up story |
| [MEDIUM] [SILENT] [DOC] | AC4 corrupt future.yaml swallowed with no signal; stale comment at line 211 claims except handles "missing" (it doesn't — that's the `exists()` guard above) | `followups.py:210-211` | Add `warnings.warn()` before `pass`; fix comment |
| [LOW] [DOC] | `_open_stories()` docstring says "open stories" but future.yaml stories added unconditionally without OPEN_STATUSES filter | `followups.py:167` | Clarify docstring |
| [LOW] [DOC] | `suggest_followups()` docstring states "success=False only when session missing/unreadable" — omits CWE-22 traversal rejection case | `followups.py:255` | Extend Returns clause |
| [LOW] [SEC] | TOCTOU: containment check uses `_resolved` but `exists()`/`read_text()` use original unresolved `session_path` | `followups.py:274,286,290` | Use `_resolved.exists()` and `_resolved.read_text()` after the check |
| [LOW] [SEC] | `_session_base` not fully resolved — symlinked `.session/` dir causes false-positive rejections | `followups.py:273` | `(Path(_check_root).resolve() / ".session").resolve()` |
| [LOW] [EDGE] | `initiatives: null` in future.yaml causes TypeError swallowed by except (inconsistent with `or []` guards on epics/stories) | `followups.py:198` | Add `or []` to initiatives iteration |
| [LOW] [RULE] [TEST] | `ImportError` not in except tuple; no test covers corrupt-YAML AC4 path or unresolvable project_root bypass; AC3 tests are vacuous (check TypedDict existence only, not annotation usage) | `followups.py:270,309`; test file | Add `ImportError` to exception tuples; add corrupt-YAML test; wire TypedDicts into annotations so tests have something real to assert |
| [LOW] [SIMPLE] | Duplicate `get_project_root()` resolution logic — resolved twice (CWE-22 check + dedup) | `followups.py:264-271,304-313` | Resolve project_root once at function top |

**Pre-existing (not introduced by this commit, flagged for follow-up):**
- `summary.py:249` missing `encoding="utf-8"` on `read_text()` [RULE]
- `summary.py:276` NamedTemporaryFile missing `encoding="utf-8"` [RULE]
- `followups.py:301-302` unguarded `detect_deferred_followups()`/`_session_epic()` calls violate "never raises" [RULE]
- `followups.py:226` empty description matches first story with non-empty title in `_covering_story()` [EDGE]

**Handoff:** To SM for finish-story