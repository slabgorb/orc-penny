---
story_id: "155-3"
jira_key: ""
epic: "155"
workflow: "tdd"
---
# Story 155-3: Archive looks for sprint-unknown-*.yaml not sprint-{number}-*.yaml (gh #28)

## Story Details
- **ID:** 155-3
- **Jira Key:** (kanban-local, no Jira key)
- **Workflow:** tdd
- **Type:** bug
- **Points:** 2
- **Priority:** p2
- **Stack Parent:** none

## Branch Strategy
- **Repo:** pennyfarthing (gitflow)
- **Base Branch:** develop
- **Feature Branch:** fix/155-3-archive-sprint-glob

## Workflow Tracking
**Workflow:** tdd
**Phase:** finish
**Phase Started:** 2026-06-24T11:25:24Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-06-24T10:45:46Z | 2026-06-24T10:45:46Z | - |
| red | 2026-06-24T10:45:46Z | 2026-06-24T11:11:22Z | 25m 36s |
| green | 2026-06-24T11:11:22Z | 2026-06-24T11:16:42Z | 5m 20s |
| review | 2026-06-24T11:16:42Z | 2026-06-24T11:25:24Z | 8m 42s |
| finish | 2026-06-24T11:25:24Z | - | - |

## Problem Statement

The archive/finish routine in `pf sprint story finish` computes the wrong sprint number when archiving completed stories. The code globs for `sprint-unknown-*.yaml` instead of `sprint-{resolved_number}-*.yaml`, which means:

1. Completed stories are archived to the wrong file (if it exists at all)
2. The sprint number is being resolved incorrectly — likely to the literal string "unknown"
3. This breaks sprint continuity and makes it impossible to find archived stories

**Root cause:** A code path in the finish/archive logic is not resolving the sprint number correctly before constructing the archive glob pattern.

## Acceptance Criteria

- [ ] The sprint number is resolved correctly from sprint state (not a literal "unknown" string)
- [ ] Archive routine globs for `sprint-{number}-*.yaml` (with actual resolved sprint number)
- [ ] A regression test captures the wrong-glob bug and verifies the fix
- [ ] The fix correctly handles edge cases: sprint ID recovery, fallback sprint selection

## Story Context

The story context has been created in `/Users/slabgorb/Projects/orc-penny/sprint/context/context-story-155-3.md` and validated.

## Sm Assessment

Story scoped and routed for RED phase. This is a 2pt `type: bug` in the `pennyfarthing/` framework repo (gitflow → branch `fix/155-3-archive-sprint-glob` off `develop`). Explicit `workflow: tdd` tag governs (overrides the points-based skip-TEA default), so it follows the full phased flow: setup → **red (TEA)** → green (Dev) → review (Reviewer) → finish (SM).

**Handoff to TEA (Thufir Hawat):** GitHub issue #28 — the archive/finish code path globs for `sprint-unknown-*.yaml` instead of `sprint-{number}-*.yaml`; the sprint number is resolving to the literal "unknown". RED phase deliverable: a failing regression test that reproduces the wrong-glob (asserts the archive routine targets the resolved sprint number, not "unknown"), per the ACs in this session. No Jira claim — kanban-local sprint.

## TEA Assessment

**Phase:** finish
**Tests Required:** Yes
**Reason:** 2pt regression with explicit `workflow: tdd`; gh #28 needs a failing test that reproduces the wrong filename resolution.

**Test File:**
- `pennyfarthing-dist/src/pf/tests/test_155_3_archive_story_number_fallback.py` (new) — 4 tests

**Tests Written:** 4 tests — 3 ACs + the literal gh #28 symptom
**Status:** RED confirmed via scoped run (`cd pennyfarthing-dist && uv run pytest <file> -q`): **3 failed, 1 passed, 0 errored**. The passing one is an intentional green preservation guard (see Design Deviations). Failures are assertion-based (right reason), not import/collection.

**Root cause (for Dev):** `archive.py::archive_story` (the `pf sprint archive STORY_ID PR` path) carries its own inline resolver:
```python
sprint_name = sprint_data.get("sprint", {}).get("jira_sprint_name", "")
match = re.search(r"(\d{4})", sprint_name)
sprint_num = match.group(1) if match else "unknown"
```
It reads **only** `jira_sprint_name`, requires a 4-digit regex match, and silently defaults to `"unknown"` — never consulting `sprint.number`. The correct resolver already exists at `archive_epic.py::get_archive_path` (story 151-1): prefer `name`/`jira_sprint_name`, fall back to `number`, fail loud if neither. This is a **SOUL #2 (One Truth, One Place)** duplication — see Delivery Findings for the consolidation direction.

| Test | AC | HEAD |
|------|----|------|
| `test_falls_back_to_number_when_name_absent` | AC1 number fallback (dry-run resolution) | RED |
| `test_appends_to_number_resolved_archive_file` | AC1 end-to-end (reproduces `Archive file not found: …/sprint-unknown-completed.yaml`) | RED |
| `test_uses_name_token_when_present` | AC2 name-priority preservation guard | GREEN (intentional) |
| `test_fails_loud_when_name_and_number_missing` | AC3 no silent `"unknown"` target | RED |

### Rule Coverage

| Rule (lang-review/python.md) | Test | Status |
|------|------|--------|
| §1 spirit — fail loud, no silent default masking misconfiguration | `test_fails_loud_when_name_and_number_missing` | failing |

**Rules checked:** the silent-fallback/fail-loud rule is the one applicable to a path resolver. No untrusted-input, deserialization, resource-leak, or mutable-default surface is introduced by this change, so those checklist items are N/A.
**Self-check:** 0 vacuous tests — every test asserts a concrete filename, an actual file append, or a failure invariant; no `assert True`, no discarded results, no always-`None` checks.

**Handoff:** To Dev (Reverend Mother Gaius Helen Mohiam) for GREEN.

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/src/pf/sprint/archive.py` — replaced the inline `jira_sprint_name` regex resolver with a wrapped call to `archive_epic.get_archive_path(project_root=root)`; removed the now-dead function-local `import re` (3 edits, +9/-6).

**Approach:** Delegation, not re-implementation. `archive_story` now resolves the archive filename through the same shared resolver as the epic-archive path (story 151-1): prefer `name`/`jira_sprint_name`, fall back to `sprint.number`, fail loud if neither. `get_archive_path` *raises* `ValueError`; wrapped in `try/except` to return `{success: False, error: str(e)}`, preserving `archive_story`'s result-object contract (SOUL #10). Net effect: the duplicate resolver is gone (SOUL #2), and the `"unknown"` silent default is removed.

**Tests:** 4/4 passing (GREEN) — `test_155_3_archive_story_number_fallback.py` (scoped `uv run pytest`).
**Regressions:** 18 sibling archive tests pass (`test_get_archive_path`, `test_archive_epic`, `test_archived_stories_filter`); 58 package-structure tests pass; `ruff check` clean. Caller `cli.py::archive_story` (line ~297) needs no change — signature and result-dict contract preserved.
**Branch:** `fix/155-3-archive-sprint-glob` (pushed) — commit `b334af782`. No PR (SM creates it at finish).

**Handoff:** To Reviewer (Leto II) for code review.

## Subagent Results

| # | Specialist | Received | Status | Findings | Decision |
|---|-----------|----------|--------|----------|----------|
| 1 | reviewer-preflight | Yes | clean | none (22 tests pass: 4 new + 18 sibling; ruff clean; 0 smells) | N/A |
| 2 | reviewer-edge-hunter | Skipped | disabled | N/A | Disabled via settings — domain covered by reviewer |
| 3 | reviewer-silent-failure-hunter | Skipped | disabled | N/A | Disabled via settings — domain covered by reviewer |
| 4 | reviewer-test-analyzer | Skipped | disabled | N/A | Disabled via settings — domain covered by reviewer |
| 5 | reviewer-comment-analyzer | Skipped | disabled | N/A | Disabled via settings — domain covered by reviewer |
| 6 | reviewer-type-design | Skipped | disabled | N/A | Disabled via settings — domain covered by reviewer |
| 7 | reviewer-security | Yes | findings | 3 (2 medium, 1 low) | confirmed 3, downgraded all to LOW (rationale below), deferred to follow-up; dismissed 0 |
| 8 | reviewer-simplifier | Skipped | disabled | N/A | Disabled via settings — domain covered by reviewer |
| 9 | reviewer-rule-checker | Skipped | disabled | N/A | Disabled via settings — domain covered by reviewer |

**All received:** Yes (2 enabled subagents returned; 7 disabled via `workflow.reviewer_subagents` and pre-filled)
**Total findings:** 0 blocking confirmed; 3 confirmed-but-downgraded-to-LOW (security, all pre-existing / out-of-diff), deferred to a follow-up; 0 dismissed.

## Reviewer Assessment

**Verdict:** APPROVED

**Summary:** The fix replaces `archive_story`'s buggy inline regex resolver (read only `jira_sprint_name`, require `\d{4}`, silently default to `"unknown"`) with delegation to the shared `archive_epic.get_archive_path` (story 151-1): prefer `name`/`jira_sprint_name`, fall back to `sprint.number`, fail loud if neither. The `ValueError` is wrapped to a result dict (SOUL #10). This removes a duplicate resolver (SOUL #2) and the silent `"unknown"` default. Tests green, ruff clean, no regressions. Findings are all pre-existing/out-of-diff and LOW; none reintroduce the gh #28 wrong-path bug or cross a trust boundary.

**Data flow traced:** `pf sprint archive 37-15 477 --apply` → `cli.py:297` → `archive_story()` → `get_story_by_id` → status gate → read `current-sprint.yaml` (raw, `yaml.safe_load`) → `get_archive_path(project_root=root)` resolves `sprint-{id}-completed.yaml` → `if not archive_file.exists(): return error` (loud) → append entry → `--apply` removes story via `write_sprint`. The fix corrects only the filename-resolution step; the `--apply`/append paths are untouched (safe because `sprint_data` is still the raw `current-sprint.yaml` read and `write_sprint` is unchanged — 18 sibling tests confirm).

**Observations (12):**
- `[SEC]` CWE-22 path traversal in `get_archive_path` via `str(name).split()[-1]` / `str(number)` interpolated into a `Path` with no `resolve()`/containment — `archive_epic.py:46,54`. **Confirmed (rule #5/#11), downgraded LOW:** the resolver is pre-existing (151-1), **not in this diff**; sprint YAML is local self-authored config (no trust boundary → CWE-22 doesn't truly apply); and `archive.py:88` (`if not archive_file.exists(): return error`) makes a typo'd/`/`-bearing name fail loud, not silently corrupt. Deferred to a central-hardening follow-up.
- `[RULE]` `open(archive_file, "a")` lacks `encoding=` — `archive.py:104`. Rule #5. **Confirmed, LOW, pre-existing** (line untouched by diff); bundle into the same follow-up. Append content is ASCII story IDs (+ titles that could be non-ASCII), default UTF-8 on macOS/Linux.
- `[SILENT]` The change **removes** a silent failure (the `"unknown"` default) and substitutes an explicit error return — a net improvement. `except ValueError` is the **complete** raisable set of `get_archive_path` (its only explicit `raise`; `load_sprint` swallows `FileNotFoundError`/`ValueError` internally), so no exception class escapes the narrow catch — `archive.py:65-68`. No swallowed errors introduced.
- `[EDGE]` Boundary cases: `number: 0` → guard treats it as present (`0 is not None and != ""`) → `sprint-0` (valid); both-absent → `ValueError` → error dict; trailing-space names handled by `str.split()`. Covered by the 4 tests.
- `[TEST]` 4 tests, all with meaningful assertions (concrete filenames, real file appends, failure invariants) — no vacuous `assert True`/discarded results. Fix-agnostic via `PROJECT_ROOT` env + mini-project (robust to inline-vs-delegation). The green preservation guard and the raise-or-result fail-loud test are both logged Design Deviations — legitimate, not false-greens.
- `[TYPE]` No new types; `archive_story` signature and `{success, error?}` return contract unchanged; `cli.py` caller needs no change.
- `[DOC]` New comments are accurate and cite `story 151-1` + `gh #28`; the stale `# Get sprint name for archive file` comment was correctly replaced. No misleading docs.
- `[SIMPLE]` Delegation **reduces** complexity: removes the duplicate resolver and the dead function-local `import re`. Net simplification aligned with SOUL #2.
- `[VERIFIED]` Resolution parity — no archive orphaning: real sprint `name: "TO Sprint 2618"`, `number: 2618` (`sprint/current-sprint.yaml`). Old regex on `jira_sprint_name` → `2618`; new `split()[-1]` → `2618`. Existing `sprint-2618-completed.yaml` (and historical 2606/2608/2610) match both resolvers. Complies with the gh #28 expected behavior.
- `[VERIFIED]` Source-of-truth consistency — `get_archive_path`→`load_sprint` resolves to the same `current-sprint.yaml` that `archive_story` reads raw, because there is no `sprint/sprints.yaml` registry and no `sprint.active` preference in `.pennyfarthing/config.local.yaml`. Evidence: both absent (checked). The latent mismatch only surfaces under a future multi-sprint registry — pre-existing architecture, not a regression here.
- `[VERIFIED]` `--apply` path safe — `git diff` shows lines 70+ (`epic_id` loop, append, `write_sprint`) untouched; `test_archived_stories_filter` + `test_archive_epic` (18 tests) pass.
- `[VERIFIED]` No circular import — `archive_epic` imports `loader`/`yaml_io`, never `archive`; the new `from pf.sprint.archive_epic import get_archive_path` introduces no cycle (preflight import + 58 structural tests pass).

### Rule Compliance (python.md, applicable checks)

| # | Rule | Verdict |
|---|------|---------|
| 1 | Silent exception swallowing | COMPLIANT — `except ValueError` specific, returns visible result (`archive.py:65-68`) |
| 5 | Path handling (`resolve()`/encoding) | VIOLATION (LOW) — no containment check (`archive_epic.py:46,54`); `open()` no `encoding=` (`archive.py:104`). Both pre-existing, deferred. |
| 6 | Test quality | COMPLIANT — concrete assertions, no vacuous/skip |
| 8 | Unsafe deserialization | COMPLIANT — `yaml.safe_load` (`archive.py:60`) |
| 10 | Import hygiene | COMPLIANT — explicit import, no cycle |
| 11 | Input validation at boundaries | VIOLATION (LOW) — sprint-id not sanitized before path join; local config, deferred |
| 13 | Fix-introduced regressions | COMPLIANT — silent default replaced with fail-loud; narrow catch is complete; no new bug class |
| 2,3,4,7,9,12 | mutable defaults / type annotations / logging / resource leaks / async / deps | N/A or COMPLIANT (no such surface; `with open(...)` context manager retained) |

### Devil's Advocate

Suppose this code is broken. The most credible attack on the change is the resolution-semantics swap: the old code could ONLY ever emit `sprint-<4digits>-completed.yaml` or the inert `sprint-unknown-completed.yaml`; the new code emits `sprint-<arbitrary-token>-completed.yaml`. A malicious or careless operator who writes `jira_sprint_name: "TO Sprint ../../etc/cron.d/x"` into sprint YAML now steers the archive path outside `sprint/archive/`. Is that a data-corruption vector? Trace it: `split()[-1]` of that value is `x`, not a traversal — the traversal only materializes if the *last* token itself contains separators (e.g. `number: "../../bad"`). Even then, `archive.py:88` refuses to proceed unless the resolved file already exists, so the realistic outcome is a loud "Archive file not found", not a silent overwrite. To actually append to a sensitive file the attacker must name one that already exists and is writable — and they already have full local FS access to edit the YAML in the first place. No privilege boundary is crossed: this is a single-user local CLI operating on the user's own repo. A confused user could mis-resolve the archive due to a typo'd sprint name — but that is a usability wart caught loudly, not corruption. What about a stressed filesystem? `open(..., "a")` without `encoding=` could raise `UnicodeEncodeError` on an exotic locale with a non-ASCII story title — but that surfaces as a loud traceback, and the pre-fix code had the identical line. What if `current-sprint.yaml` is malformed? `yaml.safe_load` at line 60 would crash *before* `get_archive_path` runs — unchanged from before. What if `load_sprint` picks a different sprint than the raw read? Only under a multi-sprint registry, which is absent. None of these reintroduce gh #28 (the silent wrong-path bug) — the fix's core invariant (resolve to the real sprint number, never `"unknown"`) holds in every branch. The devil finds only pre-existing, loud, local, out-of-scope hardening gaps — captured as a non-blocking follow-up.

**Verdict rationale:** No Critical/High. The three security findings are pre-existing (not in this diff), rule-matching-but-LOW (local config, no trust boundary, downstream fail-loud guard), and best fixed centrally in `get_archive_path` so both archive callers benefit. The core fix is correct, minimal, tested, and regression-free.

**Handoff:** To SM (Stilgar) for finish-story.

## Delivery Findings

No upstream findings at setup.

<!-- Agents: append findings below this line. Do not edit other agents' entries. -->

### TEA (test design)
- **Improvement** (non-blocking): `archive_story` duplicates archive-path resolution that already exists, correctly, at `archive_epic.py::get_archive_path` (name→number→fail-loud, story 151-1). Affects `pennyfarthing-dist/src/pf/sprint/archive.py` (delete the inline `jira_sprint_name` regex resolver at ~lines 62-65 and delegate to `get_archive_path`; `archive_story` has no `project_root` param, so a bare `get_archive_path()` call resolves the root the same way via `get_project_root`). *Found by TEA during test design.*
- **Gap** (non-blocking): `archive_story` returns result dicts everywhere (SOUL #10) but `get_archive_path` *raises* `ValueError` when neither name nor number is set. Affects `pennyfarthing-dist/src/pf/sprint/archive.py` (wrap the resolver call and return `{success: False, error: str(e)}` to preserve the result-object contract; the RED fail-loud test accepts either form). *Found by TEA during test design.*

### Dev (implementation)
- No upstream findings during implementation. Both of TEA's findings (consolidate onto `get_archive_path`; wrap the raise per SOUL #10) were resolved directly in this change.

### Reviewer (code review)
- **Improvement** (non-blocking): `get_archive_path` builds `sprint-{id}-completed.yaml` from raw sprint-YAML metadata (`str(name).split()[-1]` / `str(number)`) with no containment check; `archive_story` opens the result for append without `encoding=`. Affects `pennyfarthing-dist/src/pf/sprint/archive_epic.py` (lines ~46/54: add `archive_path.resolve()` + assert it stays under `sprint/archive/`, and `re.fullmatch(r"[\w.-]+", sprint_id)`) and `pennyfarthing-dist/src/pf/sprint/archive.py` (line ~104: `open(archive_file, "a", encoding="utf-8")`). Pre-existing (resolver shipped in 151-1; this PR only widened `archive_story`'s exposure from a `\d{4}` regex to the shared resolver). LOW severity — local self-authored config, no trust boundary, and the downstream `archive_file.exists()` guard fails loud. Best fixed **centrally** in `get_archive_path` so both story- and epic-archive callers benefit. Recommend a follow-up story in epic 155 (Finish/merge/archive truthfulness). *Found by Reviewer during code review.*

## Design Deviations

None at setup.

<!-- Agents: append deviations below this line. Do not edit other agents' entries. -->

### TEA (test design)
- **Name-priority test is intentionally green on HEAD**
  - Spec source: context-story-155-3.md (AC) + gh #28
  - Spec text: "Archive resolves to sprint-2-completed.yaml (using sprint.number when sprint.name is absent)"
  - Implementation: `test_uses_name_token_when_present` asserts a present `jira_sprint_name` still wins over a differing `number`; this already holds on HEAD (the buggy regex extracts `2618` from "TO Sprint 2618"), so it is green, not red.
  - Rationale: preservation/regression guard — fails only if the fix over-applies and resolves to `number` unconditionally. Paired with 3 genuinely-red AC tests.
  - Severity: minor
  - Forward impact: none
- **Fail-loud outcome left to Dev (raise vs result-object)**
  - Spec source: SOUL.md #10 (Return Results, Don't Throw) vs `archive_epic.get_archive_path` behavior
  - Spec text: "Functions return {success, data?, error?} so every failure is visible"
  - Implementation: `test_fails_loud_when_name_and_number_missing` accepts EITHER a raised `ValueError` OR a `{success: False}` result rather than pinning one.
  - Rationale: `get_archive_path` raises; `archive_story`'s contract returns result dicts. Both satisfy "no silent unknown"; over-pinning would dictate Dev's internal handling. Recommended (non-binding): wrap and return a result object per SOUL #10 (also logged as a Delivery Finding).
  - Severity: minor
  - Forward impact: none

### Dev (implementation)
- No deviations from spec. Implemented TEA's recommended consolidation onto `get_archive_path`; the fail-loud outcome was returned as a result object (`{success: False, error}`) per SOUL #10, which TEA's test explicitly permits — a choice within latitude, not a deviation.

### Reviewer (audit)
- **TEA — Name-priority test intentionally green** → ✓ ACCEPTED by Reviewer: a preservation guard against an over-broad fix; verified green-on-HEAD reasoning is sound (regex extracts `2618` from "TO Sprint 2618"), and it correctly fails if the fix resolves to `number` unconditionally.
- **TEA — Fail-loud outcome left to Dev (raise vs result)** → ✓ ACCEPTED by Reviewer: not over-pinning Dev's internal handling was the right call; Dev chose the result-object form per SOUL #10, which the test permits.
- **Dev — No deviations (result-object for fail-loud)** → ✓ ACCEPTED by Reviewer: the result-object choice aligns with SOUL #10 and `archive_story`'s established contract; confirmed `except ValueError` is the complete raisable set of `get_archive_path`.
- **UNDOCUMENTED (spotted by Reviewer):** Resolution-semantics widening — the old resolver constrained the sprint token to `\d{4}` (regex) and emitted `"unknown"` on no-match; the new shared resolver uses `str(name).split()[-1]`/`str(number)` with no character constraint. Spec said "fall back to sprint.number" (gh #28); the code does that AND widens accepted tokens for malformed names ("Sprint Foo" → `Foo` rather than `"unknown"`). Not logged by TEA/Dev. **Severity: LOW** — consequence is the path-hardening gap captured as a Reviewer Delivery Finding; for the real "TO Sprint NNNN" sprint format the resolved id is identical, so no behavioral change in practice. Accepted as in-scope of the SOUL #2 consolidation, with central hardening deferred to a follow-up.