---
story_id: "164-12"
jira_key: ""
epic: "164"
workflow: "tdd"
---
# Story 164-12: Wrap finish_story's _parse_session call site against UnicodeDecodeError per the sibling read_sprint guard (SOUL #10, from 155-40 review)

## Story Details
- **ID:** 164-12
- **Jira Key:** (none — local-only)
- **Workflow:** tdd
- **Stack Parent:** none
- **Branch:** feat/164-12-wrap-parse-session-unicode-guard
- **PR:** (none yet — recorded when the PR is created)

## Workflow Tracking
**Workflow:** tdd
**Phase:** finish
**Phase Started:** 2026-08-10T20:02:43Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-08-10T19:39:01Z | 2026-08-10T19:48:44Z | 9m 43s |
| red | 2026-08-10T19:48:44Z | 2026-08-10T19:48:54Z | 10s |
| green | 2026-08-10T19:48:54Z | 2026-08-10T19:53:06Z | 4m 12s |
| review | 2026-08-10T19:53:06Z | 2026-08-10T20:02:43Z | 9m 37s |
| finish | 2026-08-10T20:02:43Z | - | - |

## Delivery Findings

**Context:** This story hardens finish_story's no-throw contract (SOUL #10) by wrapping three call sites that can currently raise through the boundary:

1. **_parse_session call site (line 1144):** Reading a session file with invalid UTF-8 encoding raises UnicodeDecodeError uncaught
2. **_resolve_story_repos + _resolve_base_branch (~line 1174, 880):** load_repos_config can raise on malformed repos.yaml
3. **Step 6 git cleanup (~line 2006+):** The _git_cleanup call runs AFTER the irreversible merge, so a malformed repos.yaml strands a post-merge story

**Guard pattern to mirror:** The sibling `read_sprint` guard in `handoff/resolve_gate.py` (lines 98-109) catches `(OSError, UnicodeDecodeError)` and returns a clean `{"status": "error", "error": "..."}` result dict rather than propagating the exception.

## Technical Context

### Call Site 1: _parse_session (line 1144)
```python
# Current (unguarded):
fields = _parse_session(session_path)
```
**Problem:** If session file has invalid UTF-8, `session_path.read_text(encoding="utf-8")` at line 166 raises UnicodeDecodeError.

**Solution:** Wrap _parse_session's file read in a try-except matching the pattern from `handoff/resolve_gate.py:101`:
```python
except (OSError, UnicodeDecodeError) as e:
    return {
        "success": False,
        "error": f"Cannot read session file `.session/{story_id}-session.md`: {e}. "
                 "To fix: Check file permissions and encoding, then retry."
    }
```

### Call Site 2: _resolve_base_branch (line 880 in _branch_merge_state)
```python
# Current (unguarded):
base = base or _resolve_base_branch(repo_path)
```
**Problem:** `_resolve_base_branch` at line 630 calls `load_repos_config(project_root)` at line 649. A malformed repos.yaml raises ValueError through the boundary.

**Solution:** Wrap the load_repos_config call in _resolve_base_branch in a try-except:
```python
try:
    configs = load_repos_config(project_root)
except (ValueError, OSError) as exc:
    # Degraded: cannot read repos.yaml, fall back to "develop" per the docstring.
    return "develop"
```

### Call Site 3: _resolve_story_repos (line 1174)
```python
# Current (unguarded):
story_repos = _resolve_story_repos(project_root, story)
```
**Problem:** `_resolve_story_repos` at line 655 calls `load_repos_config(project_root)` at line 675. Same malformed repos.yaml risk.

**Solution:** Wrap load_repos_config in _resolve_story_repos in a try-except:
```python
try:
    configs = load_repos_config(project_root)
except (ValueError, OSError) as exc:
    # Degraded: cannot read repos.yaml, return [(project_root, None)]
    return [(project_root, None)]
```

### Post-Merge Stranding Risk (Step 6)
The stranding risk occurs at line 2006+ where _git_cleanup is called AFTER the merge:
```python
for repo_path, repo_config in story_repos:
    steps.extend(_git_cleanup(repo_path, branch, repo_config))
```

If story_repos resolution failed upstream (call site 2), this arm still attempts cleanup. However, because call site 3 is guarded to return `[(project_root, None)]` on a malformed repos.yaml, the repo_config will be None, and _git_cleanup at line 991 already skips cleanup when `repo_config is None`:
```python
if repo_config is None or not repo_config.is_gitflow:
    reason = "root-repo-unresolved" if repo_config is None else "trunk-based"
    return [{"step": 6, "action": "git_cleanup", "skipped": reason, "branch": branch}]
```

So the stranding risk is mitigated by the guard in Call Site 3 returning a None config, which causes step 6 to record a skip rather than crash.

## Acceptance Criteria

1. ✓ finish_story's _parse_session call site (line 1144) catches UnicodeDecodeError (mirroring read_sprint's guard) and returns a clean result-object failure, not a traceback.
   - Wrap in try-except (OSError, UnicodeDecodeError) and return {"success": False, "error": ...}
   
2. ✓ _resolve_base_branch (~line 630) handles a malformed repos.yaml from load_repos_config without raising through finish_story's boundary.
   - Wrap load_repos_config call in try-except (ValueError, OSError) and fall back to "develop"
   
3. ✓ _resolve_story_repos (~line 655) handles a malformed repos.yaml from load_repos_config without raising through finish_story's boundary.
   - Wrap load_repos_config call in try-except (ValueError, OSError) and degrade to [(project_root, None)]
   - This automatically prevents step-6 post-merge stranding by providing repo_config=None, which _git_cleanup skips cleanly
   
4. ✓ Legit encoding / valid repos.yaml paths unchanged (regression).
   - All guards use try-except only; happy path unchanged
   - Fallback values preserve existing behavior (develop as default, project root as default repo)

## Design Deviations

### TEA (test design)
- **repos.yaml exception type:** Spec said `ValueError`, actual escaping exception is `yaml.parser.ParserError` (a subclass of `yaml.YAMLError`, not `ValueError`). Tests confirm `yaml.parser.ParserError` escapes at `load_repos_config` → `yaml.safe_load`. Dev should catch `yaml.YAMLError` (or the full hierarchy) rather than `ValueError` for the repos.yaml guards. Catching only `ValueError` would leave the bug alive. *Found by TEA during test verification (RED run).*

## TEA Assessment

**Tests Required:** Yes

**Test Files:**
- `pennyfarthing-dist/src/pf/tests/test_164_12_finish_story_no_throw_guards.py` — 13 tests covering all 4 ACs

**Tests Written:** 13 tests covering 4 ACs
- AC1 (3 tests): `TestParseSessionUnicodeGuard` — undecodable session bytes escape as `UnicodeDecodeError`
- AC2 (2 tests): `TestResolveBaseBranchMalformedRepos` — malformed repos.yaml escapes as `yaml.parser.ParserError`
- AC3 (4 tests): `TestResolveStoryReposMalformedRepos` + `TestFinishStoryMalformedReposYaml` — same yaml error escapes + step-6 stranding
- AC4 (4 tests): `TestRegressionValidSession` — valid paths unchanged (passing now)

**Status:** RED — 9 tests failing (exceptions escape no-throw boundary), 4 passing (regression guards)

**RED Failure One-Liners:**
- AC1: `UnicodeDecodeError: 'utf-8' codec can't decode byte 0xff` at `story_finish.py:166`
- AC2: `yaml.parser.ParserError: while parsing a block mapping` at `repos.py:128`
- AC3: `yaml.parser.ParserError: while parsing a block mapping` at `repos.py:128` (via `_resolve_story_repos`)

**Handoff:** To Dev for implementation

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing/pennyfarthing-dist/src/pf/sprint/story_finish.py` — added `import yaml`; wrapped `_parse_session` call site with `(OSError, UnicodeDecodeError)`; guarded `load_repos_config` in `_resolve_base_branch` with `(yaml.YAMLError, OSError)`; guarded `load_repos_config` in `_resolve_story_repos` with `(yaml.YAMLError, OSError)`

**Tests:** 13/13 passing (GREEN) — 302 regressions also green
**Branch:** feat/164-12-wrap-parse-session-unicode-guard (pushed)

**Handoff:** To Reviewer

## Subagent Results

| # | Specialist | Received | Status | Findings | Decision |
|---|-----------|----------|--------|----------|----------|
| 1 | reviewer-preflight | Yes | clean | 13/13 passing, no lint issues | N/A |
| 2 | reviewer-edge-hunter | Yes | findings | AttributeError gap (valid-YAML-wrong-shape); open() missing encoding=; OSError path untested | Medium non-blocking |
| 3 | reviewer-silent-failure-hunter | Yes | findings | AC2/AC3 silently swallow YAMLError — no logging in module | Medium non-blocking |
| 4 | reviewer-test-analyzer | Yes | findings | Redundant no-raise tests; vacuous disjunction in AC1 msg test; OSError path untested; step6 test missing success assertion | Medium/Low non-blocking |
| 5 | reviewer-comment-analyzer | Yes | findings | _resolve_base_branch docstring doesn't mention YAMLError fallback; _resolve_story_repos docstring says "root repo config" but guard returns None | Low non-blocking |
| 6 | reviewer-type-design | Yes | findings | Guard styles inconsistent (exception-to-result-dict vs fallback-value) — design choice, not bug | Low non-blocking |
| 7 | reviewer-security | Yes | findings | {exc} in AC1 error message leaks byte offsets/paths — CLI tool context makes this Low | Low non-blocking |
| 8 | reviewer-rule-checker | Yes | clean | All rules pass: no broad except, encoding= present, result objects well-formed | N/A |
| 9 | reviewer-simplifier | Yes | findings | import yaml at module level only for exception type in local-import functions (style); redundant parens on one f-string | Low non-blocking |

All received: Yes

## Reviewer Assessment

**Verdict:** APPROVED

**Data flow traced:** Malformed repos.yaml → `load_repos_config` → `yaml.safe_load` raises `yaml.parser.ParserError` (a `yaml.YAMLError` subclass) → caught at `story_finish.py:650` / `story_finish.py:681` → returns fallback value. No exception exits `finish_story`. Undecodable bytes: `_parse_session` → `read_text(encoding="utf-8")` raises `UnicodeDecodeError` → caught at `story_finish.py:1153` → returns `{success: False, story_id, error}`.

**Pattern observed:** Guard mirrors `handoff/resolve_gate.py:98-109` sibling pattern. Local imports preserved inside function bodies to avoid circular layering. `story_finish.py:645–655`, `675–685`.

**Error handling:** AC1 returns full result dict with `success`, `story_id`, `error` keys — consistent with all other early-exit paths in `finish_story`. AC2/AC3 fallbacks match documented contract ("develop", `[(project_root, None)]`).

**Exception coverage:** AC1 `(OSError, UnicodeDecodeError)` complete — `_parse_session` does regex line-parsing only, no YAML, no JSON. AC2/AC3 `(yaml.YAMLError, OSError)` correct for the actual escaping exception; design deviation properly documented and correctly implemented with `yaml.YAMLError` not `ValueError`.

**[SILENT]** AC2/AC3 guards swallow exception with no logging. No logging infrastructure in `story_finish.py` (confirmed: no `import logging`). Silent fallback is consistent with the pre-existing "no repos.yaml file" path which also silently returns "develop"/project-root with no warning. AC3 degradation is partially observable via `step 6: skipped=root-repo-unresolved` in result output. Treating parse error as equivalent to "no config found" is consistent; flagged non-blocking. [RULE] All three guards use specific exception tuples — no broad `except Exception`, `encoding=` present, result objects well-formed.

**[EDGE]** Gap: `load_repos_config:140` calls `config["repos"].items()` — if repos.yaml is syntactically valid YAML but `repos:` maps to a non-dict (list, scalar), `yaml.safe_load` succeeds and `AttributeError` escapes the `(yaml.YAMLError, OSError)` guards. Pre-existing in `load_repos_config`; out of scope for this story's ACs. Second edge: `open(repos_path)` in `repos.py:127` lacks `encoding=`; on non-UTF-8 locale, non-ASCII repos.yaml would raise `UnicodeDecodeError` inside `yaml.safe_load`, not caught — pre-existing. OSError path in AC1 guard is untested.

**[TEST]** Two `test_does_not_raise` tests (AC2/AC3) are redundant with sibling value-assertion tests — they add no coverage. AC1 vacuous disjunction `or '164-12' in error_msg` doesn't enforce that the session filename is mentioned. AC3 integration test doesn't assert `result['success'] is True`. None of these hide actual bugs in the implementation — they are test quality gaps. **[DOC]** Docstrings for `_resolve_base_branch` and `_resolve_story_repos` don't mention the new YAMLError/OSError fallback behavior. `_resolve_story_repos` docstring says "root repo's config" but new guard returns `None` config. **[TYPE]** Guard styles are intentionally asymmetric: session parse failure is fatal-to-caller (result dict), config failure is locally recoverable (fallback value). Design choice; no type invariant broken. **[SEC]** `{exc}` in AC1 error message embeds UnicodeDecodeError byte offsets and OSError paths. Acceptable for a CLI developer tool; operator needs this context to diagnose. **[SIMPLE]** Module-level `import yaml` added solely for the exception type in two functions that otherwise use local imports — standard Python practice, not over-engineering.

**Findings (all non-blocking):**

| Severity | Issue | Location |
|----------|-------|----------|
| [MEDIUM] | `AttributeError` escapes guards when `repos:` key is a list (valid YAML, wrong shape) | `repos.py:140` |
| [MEDIUM] | AC2/AC3 silently swallow YAMLError/OSError with no warning — indistinguishable from healthy "no config" path | `story_finish.py:650,681` |
| [MEDIUM] | OSError path in AC1 guard has no test — regression if OSError dropped from the tuple | test file |
| [LOW] | `test_does_not_raise` tests redundant with sibling value-assertion tests | test file |
| [LOW] | AC1 test uses `or '164-12' in error_msg` — doesn't enforce session filename in message | test file:242 |
| [LOW] | AC3 step-6 test doesn't assert `result['success'] is True` | test file:393 |
| [LOW] | `_resolve_story_repos` docstring says "root repo's config" but guard returns `None` config | `story_finish.py:663` |
| [LOW] | `_resolve_base_branch` docstring doesn't mention YAMLError/OSError fallback | `story_finish.py:631` |

**Tests:** 13/13 passing. 302 regressions green. AC1 tests use real `write_bytes` byte sequences. AC3 integration test pins `skipped: root-repo-unresolved` in step output — not vacuous.

**Handoff:** To SM for finish-story