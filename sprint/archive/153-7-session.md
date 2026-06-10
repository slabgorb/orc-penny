---
story_id: "153-7"
jira_key: ""
epic: "153"
workflow: "tdd"
---
# Story 153-7: Cyclist sprint-yaml PostToolUse hook crashes — node yaml package unresolvable; switch to PyYAML or detect-and-skip when module missing

## Story Details
- **ID:** 153-7
- **Jira Key:** (none — local sprint)
- **Workflow:** tdd
- **Stack Parent:** none

## Workflow Tracking
**Workflow:** tdd
**Phase:** finish
**Phase Started:** 2026-06-10T16:53:04Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-06-10T16:41:59Z | 2026-06-10T16:43:17Z | 1m 18s |
| red | 2026-06-10T16:43:17Z | 2026-06-10T16:47:13Z | 3m 56s |
| green | 2026-06-10T16:47:13Z | 2026-06-10T16:49:28Z | 2m 15s |
| review | 2026-06-10T16:49:28Z | 2026-06-10T16:53:04Z | 3m 36s |
| finish | 2026-06-10T16:53:04Z | - | - |

## Sm Assessment

**Setup complete; routing to TEA for red phase.**

- Session and story context created; feature branch `feat/153-7-sprint-yaml-hook-pyyaml` off `develop` in `pennyfarthing/`, checked out.
- Jira intentionally skipped — local-only sprint.
- Scope: the sprint-yaml PostToolUse hook crashes on every sprint YAML write because it's a Node script requiring the unresolvable `yaml` npm package. Port to Python/PyYAML per ADR-0034 (Python owns hooks), or at minimum detect-and-skip cleanly. Preserve existing validator semantics (status enum active|closed). Regression tests: valid YAML passes, invalid YAML reported, hook never crashes the write.
- Mode: peloton-inline — SM drives TEA → Dev → Reviewer as subagents (Opus); SM owns PR create/merge and finish ceremony.

## Tea Assessment

**Tests Required:** Yes
**Status:** RED (4 meaningful failures, 8 regression-guard passes) — ready for Dev

### Root cause (confirmed)
`pennyfarthing-dist/src/pf/hooks/sprint_yaml_validation.py::main()` shells out
to `node --input-type=module -e "import { parse } from 'yaml' ..."`. The `yaml`
npm package is unresolvable, so Node exits non-zero with
`ERR_MODULE_NOT_FOUND` on **every** sprint-YAML write — the hook then reports a
bogus "SPRINT YAML VALIDATION FAILED" advisory containing a Node stack trace.
(If `node` itself is absent it instead silently no-ops via the
`FileNotFoundError` swallow — validation never runs at all.) Reproduced live:
`node -e "import {parse} from 'yaml'"` → `Cannot find package 'yaml'`.

### Test file
- `pennyfarthing/pennyfarthing-dist/src/pf/tests/test_153_7_sprint_yaml_hook_python.py`
  — 12 tests against `pf.hooks.sprint_yaml_validation.main()` driven by patched
  stdin (Claude Code PostToolUse payload) + captured stdout.

### Designed fix interface (Dev must satisfy)
**Module:** `pf.hooks.sprint_yaml_validation` — keep `main() -> None`, keep the
`pf hooks sprint-yaml` CLI entry (`cli.py`) and the dispatch registration
(`dispatch.py` PostToolUse `("sprint-yaml", "Edit|Write", ...)`) unchanged.
Rewrite the body to validate **in-process**:

1. Read+parse stdin JSON; on empty/garbage stdin → `sys.exit(0)`.
2. Guard: only `tool_name in {"Edit","Write"}`; only paths matching
   `sprint/.*\.(yaml|yml)$`; only when `Path(file_path).is_file()` — else
   `sys.exit(0)` silently. (These guards already pass; preserve them.)
3. **Replace the Node subprocess** with the existing Python validator
   (one-truth, ADR-0034). Recommended:
   `from pf.sprint.validator import validate_sprint_file, format_validation_errors`
   then `result = validate_sprint_file(Path(file_path))`.
   - `validate_sprint_file` already: catches `yaml.YAMLError` →
     `"Failed to parse YAML: ..."`; runs `validate_full_sprint` (status enum
     `{active, closed}`, ISO dates, required fields, dup story IDs); and keeps
     the single-quoted-blank-line YAML-1.2 cross-parser check the Node path was
     nominally there for. So the Cyclist-panel guarantee is preserved.
   - Note: `validate_sprint_file` runs `validate_full_sprint`, which always
     errors `Missing required 'sprint' section` on a raw `epic-*.yaml` shard.
     Sprint shards are matched by the `sprint/.*\.(yaml|yml)$` regex too — Dev
     SHOULD route through `validate_sprint_document` (shard-aware) or otherwise
     avoid false-flagging epic shards. Flagged below as a Delivery Finding; the
     current tests use full-sprint fixtures so they don't pin this, but Dev must
     not regress shard handling.
4. If `result.valid` → `sys.exit(0)` with **no** stdout (silent pass).
5. If invalid → emit one `HookResponse(event_name="PostToolUse",
   additional_context=...)` via `output_hook_response`, where the context is a
   real validator message (e.g. wraps `format_validation_errors(result)`).
   Advisory MUST NOT contain `ERR_MODULE_NOT_FOUND` / `node:internal`.
6. **Never block, never crash:** every path ends `sys.exit(0)` (exit 2 is
   reserved for PreToolUse blocks; PostToolUse here is advisory only). Keep the
   broad `except Exception: pass` fail-open as a backstop.

**Result convention:** hook output follows the existing `HookResponse` →
`hookSpecificOutput.additionalContext` shape (no `{success,data,error}` JSON
here — that convention is for library functions; the validator already returns
a `ValidationResult` dataclass which is the structured object Dev reuses).

**Registration cleanup:** there is no live `.js`/`.sh` sprint-yaml hook left to
remove (it was already a Python module that *spawns* Node). The only removal is
the embedded `validation_script` Node string + the `subprocess.run` call inside
`main()`. Confirm no consumer `settings*.json` template still references a
node-based sprint-yaml hook (templates already use `pf hooks sprint-yaml`).

### RED evidence (targeted run only — full suite skipped per branch-leak note)
- FAIL `test_hook_never_spawns_node_subprocess` — `subprocess.run` IS called.
- FAIL `test_valid_sprint_yaml_passes_silently` — valid YAML flagged via Node crash.
- FAIL `test_invalid_status_enum_is_reported` — advisory is a Node trace, not "bogus" status.
- FAIL `test_malformed_yaml_is_reported` — advisory is a Node trace, not a Python parse error.
- PASS (regression guards, must stay green): non-sprint path skip, non-yaml skip,
  non-Edit/Write skip, missing file, empty stdin, garbage stdin, missing tool_input,
  invalid-yaml-does-not-block.

**Handoff:** To Dev for GREEN.

## Delivery Findings

Agents record upstream observations discovered during their phase.
Each finding is one list item. Use "No upstream findings" if none.

**Types:** Gap, Conflict, Question, Improvement
**Urgency:** blocking, non-blocking

<!-- Agents: append findings below this line. Do not edit other agents' entries. -->

### Reviewer (code review)
- **Gap** (non-blocking): non-dict YAML root (bare scalar, empty→None, or list) raises `AttributeError` in `_merge_epic_shards`/`validate_full_sprint`, silently swallowed by the broad `except Exception: pass`; the user gets no advisory for a genuinely malformed sprint file. Write is not blocked (fail-open holds), so non-blocking. Pre-existing in `validate_sprint_file` (same missing guard) — not a 153-7 regression. Affects `pf.hooks.sprint_yaml_validation._validate` and `pf.sprint.validator.validate_sprint_file` (add an `isinstance(data, dict)` guard after `yaml.safe_load` emitting a real "root is not a mapping" error). *Found by Reviewer during code review.*

### TEA (test design)
- **Gap** (non-blocking): the `sprint/.*\.(yaml|yml)$` path filter also matches epic shards (`sprint/epic-*.yaml`). `validate_sprint_file`/`validate_full_sprint` always errors `Missing required 'sprint' section` on a raw shard, so a node→python port that uses `validate_sprint_file` directly would start false-flagging every epic-shard write. Affects `pf.hooks.sprint_yaml_validation` (Dev should validate shards via `validate_sprint_document` or branch on `is_epic_shard_document`). *Found by TEA during test design.*

## Impact Summary

**Upstream Effects:** 1 findings (1 Gap, 0 Conflict, 0 Question, 0 Improvement)
**Blocking:** None

- **Gap:** the `sprint/.*\.(yaml|yml)$` path filter also matches epic shards (`sprint/epic-*.yaml`). `validate_sprint_file`/`validate_full_sprint` always errors `Missing required 'sprint' section` on a raw shard, so a node→python port that uses `validate_sprint_file` directly would start false-flagging every epic-shard write. Affects `pf.hooks.sprint_yaml_validation`.

### Downstream Effects

- **`.`** — 1 finding

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing/pennyfarthing-dist/src/pf/hooks/sprint_yaml_validation.py` — Replaced the embedded Node `validation_script` + `subprocess.run` with an in-process Python validator path. `main()`, the `pf hooks sprint-yaml` CLI entry, and the `dispatch.py` PostToolUse registration are unchanged. Added a private `_validate(path)` helper that reuses `validate_sprint_file`'s cross-parser single-quoted-blank-line check, parses with `yaml.safe_load`, merges epic shards via `_merge_epic_shards`, then routes through the **shard-aware** `validate_sprint_document` (so `sprint/epic-*.yaml` shards are not false-flagged "Missing required 'sprint' section"). Invalid → one `HookResponse` `additionalContext` wrapping `format_validation_errors`; valid → silent exit 0; every path exits 0. Broad `except Exception: pass` fail-open backstop retained. No subprocess import remains.

**Tests:** 12/12 passing in `test_153_7_sprint_yaml_hook_python.py` (GREEN). Regression guard: 50/50 in `test_sprint_validator.py`. Ruff clean on changed file. (Full suite deliberately skipped per branch-leak note in test_git_utils.py.)
**Branch:** feat/153-7-sprint-yaml-hook-pyyaml (commit c852a1eb1, not pushed — peloton-inline mode; SM owns PR/push)

**Handoff:** To Reviewer.

## Design Deviations

Agents log spec deviations as they happen — not after the fact.
Each entry: what was changed, what the spec said, and why.

<!-- Agents: append deviations below this line. Do not edit other agents' entries. -->
### Dev (implementation)
- **Shard-aware validation path:** TEA's spec recommended `validate_sprint_file(Path)` directly, but that always calls `validate_full_sprint` and false-flags epic shards (TEA's own Delivery Finding). Implemented a local `_validate` helper that replicates `validate_sprint_file`'s blank-line/parse/merge preamble but dispatches through `validate_sprint_document` (shard-aware). Reason: honor TEA's Delivery Finding without regressing shard handling; tests don't pin shard fixtures but none contradict this. Minimal duplication (the cross-parser blank-line check) was necessary because `validate_sprint_file` offers no shard-aware seam.

## Subagent Results

Peloton-inline mode: the Reviewer (Opus) performed the specialist analyses inline rather than spawning background subagents. Results below are the inline equivalents.

| # | Specialist | Received | Status | Findings | Decision |
|---|-----------|----------|--------|----------|----------|
| 1 | reviewer-preflight | Yes (inline) | clean | 62/62 targeted tests pass (12 hook + 50 validator); ruff clean; full suite skipped per branch-leak hazard | N/A |
| 2 | reviewer-security | Yes (inline) | clean | Removing the Node subprocess eliminates a shell-out attack surface entirely. No remaining subprocess/exec, no shell=True, no string interpolation into a command. Input is `yaml.safe_load` (no arbitrary object construction). Hook only reads stdin + a sprint-path file and writes an advisory to stdout — no privileged action, no auth surface. Path is regex-gated to `sprint/.*\.(yaml\|yml)$`. | No security findings |

**All received: Yes** (2/2 enabled specialists — reviewer-preflight, reviewer-security — accounted for, inline mode).

Separate inline hunt (not an enabled gate specialist): silent-failure analysis surfaced the MEDIUM non-dict-root + LOW duplication findings recorded in the assessment table below.

## Reviewer Assessment

**Verdict:** APPROVED

**Data flow traced:** PostToolUse stdin JSON → `tool_name`/`file_path` guards → `sprint/.*\.(yaml|yml)$` regex → `is_file()` → `_validate` (blank-line scan → `yaml.safe_load` → `_merge_epic_shards` → shard-aware `validate_sprint_document`) → `format_validation_errors` → `HookResponse.additionalContext` → stdout. Every branch terminates in `sys.exit(0)`. Safe — fail-open verified.

**Pattern observed:** Node subprocess fully excised (no `subprocess` import, no `validation_script`, no `subprocess.run`); only Node mentions left are explanatory history in the docstring/comments. Core validation delegated to `pf.sprint.validator` (one-truth, ADR-0034) at `sprint_yaml_validation.py:150`.

**[SEC] Security:** Clean. Removing the Node shell-out eliminates a subprocess attack surface; no remaining `subprocess`/`exec`/`shell=True`, no string interpolation into a command. Parsing uses `yaml.safe_load` (no arbitrary object construction). Path is regex-gated to `sprint/.*\.(yaml|yml)$`; the hook only reads stdin + a sprint file and writes an advisory — no privileged action or auth surface. No security findings.

**Error handling:** `except SystemExit: raise` + `except Exception: pass` backstop (`sprint_yaml_validation.py:78-83`) — fail-open is the correct AC-satisfying behavior for an advisory PostToolUse hook. Live-probed valid / invalid-status / malformed-YAML / missing-file / empty-stdin / garbage-stdin / scalar / list / None-root payloads: all exit 0.

**Deviation audit:** Dev's sole declared deviation (route through `validate_sprint_document` via a local `_validate` helper instead of `validate_sprint_file`) — **ACCEPTED**. Directly honors TEA's Delivery Finding (avoids false-flagging `sprint/epic-*.yaml` shards). Verified by live test: valid epic shard passes silently; shard with a missing `points` field is correctly reported. No undocumented deviations.

**Observations / findings:**

| Severity | Issue | Location | Note |
|----------|-------|----------|------|
| [MEDIUM] | Non-dict YAML root (bare scalar / empty→None / list) raises `AttributeError` inside `_merge_epic_shards`, silently swallowed by the broad except → no advisory emitted for a genuinely malformed sprint file (SOUL #10). Write is NOT blocked (fail-open holds). Pre-existing in `validate_sprint_file` too — not a 153-7 regression; the hook merely exercises it. | `sprint_yaml_validation.py:140-150` | Non-blocking. Deferred fix: add `isinstance(data, dict)` guard in `_validate` after `safe_load`, emitting a real "sprint YAML root is not a mapping" advisory. |
| [LOW] | The ~30-line single-quoted-blank-line scanner is duplicated from `validate_sprint_file` (`validator.py:754-788`). Justified (no shard-aware seam exists), but a future refactor could extract `_check_single_quoted_blank_lines(raw)` + a `shard_aware=True` flag on `validate_sprint_file`. | `sprint_yaml_validation.py:101-132` | Non-blocking deferred note. |
| [LOW] | No test pins the headline shard-aware behavior (only full-sprint fixtures). Verified manually by Reviewer instead. | `test_153_7_sprint_yaml_hook_python.py` | Non-blocking; consider a `test_epic_shard_*` pair. |

**Verification:** 62/62 targeted tests pass (12 hook + 50 validator, 0.32s). Ruff clean. Full suite correctly skipped (branch-leak hazard). Test quality is genuine — regression guard uses a post-hoc sentinel to defeat the broad-except swallow; advisory tests assert the message is a real Python validator error and explicitly NOT a Node trace.

**Handoff:** To SM (Stilgar) for finish-story. No Critical/High — APPROVED.