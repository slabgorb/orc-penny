---
story_id: "155-7"
jira_key: ""
epic: ""
workflow: "tdd"
---
# Story 155-7: Harden get_archive_path: path-traversal containment + sprint_id sanitization + encoding= on archive append (155-3 review deferral)

## Story Details
- **ID:** 155-7
- **Jira Key:** (not tracked in Jira)
- **Workflow:** tdd
- **Stack Parent:** none

## Workflow Tracking
**Workflow:** tdd
**Phase:** finish
**Phase Started:** 2026-07-14T12:24:37Z
**Round-Trip Count:** 1

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-07-13T15:18:47+00:00 | 2026-07-13T15:20:59Z | 2m 12s |
| red | 2026-07-13T15:20:59Z | 2026-07-13T16:29:31Z | 1h 8m |
| green | 2026-07-13T16:29:31Z | 2026-07-14T11:57:00Z | 19h 27m |
| review | 2026-07-14T11:57:00Z | 2026-07-14T12:07:29Z | 10m 29s |
| red | 2026-07-14T12:07:29Z | 2026-07-14T12:15:09Z | 7m 40s |
| green | 2026-07-14T12:15:09Z | 2026-07-14T12:18:50Z | 3m 41s |
| review | 2026-07-14T12:18:50Z | 2026-07-14T12:24:37Z | 5m 47s |
| finish | 2026-07-14T12:24:37Z | - | - |

## Technical Approach

**Context:** This story addresses a deferred finding from PR pennyfarthing#119 (155-3 code review). The `archive_epic.get_archive_path()` function needs hardening against path-traversal attacks (CWE-22). While severity is LOW (local self-authored config, no upstream trust boundary), the fix should be centralized in `get_archive_path()` so both story- and epic-archive callers benefit.

**Implementation Plan:**

1. **Path Canonicalization & Containment (archive_epic.py)**
   - Call `archive_path.resolve()` to canonicalize the path (resolve symlinks, `..` segments)
   - Assert the resolved path is contained under `sprint/archive/` directory
   - Raise `ValueError` if the path escapes the archive directory
   - This centralizes the guard at the function boundary

2. **Sprint ID Sanitization**
   - Restrict `sprint_id` parameter to word/dot/dash characters: `[a-zA-Z0-9._-]+`
   - Use a regex check or allow-list validation early in the function
   - Raise `ValueError` if sprint_id contains invalid characters

3. **Encoding Fix (archive.py)**
   - Locate the `open()` call that appends to the archive file
   - Add `encoding='utf-8'` parameter to ensure consistent text encoding
   - This prevents encoding mismatches across platforms

4. **Test Coverage**
   - RED phase: Write failing tests for:
     - Path-traversal attempt detection (e.g., `../../../etc/passwd`)
     - Sprint ID validation (e.g., `../evil`, `sprint;rm -rf`)
     - Encoding correctness (UTF-8 special characters)
   - GREEN phase: Implement the checks and verify tests pass

## Acceptance Criteria

- [ ] `archive_epic.get_archive_path()` calls `archive_path.resolve()` and validates the resolved path is under `sprint/archive/`
- [ ] Path-traversal attempts (containing `..` or absolute paths escaping the archive directory) raise `ValueError` with a clear message
- [ ] `sprint_id` parameter validation restricts input to `[a-zA-Z0-9._-]+` characters, rejecting invalid characters with `ValueError`
- [ ] `archive.py` open() call appends with `encoding='utf-8'` explicitly set
- [ ] Unit tests cover all three hardening layers: path containment, sprint_id sanitization, and encoding
- [ ] Both story-archive and epic-archive paths succeed with valid inputs
- [ ] Code passes linting and all existing tests remain green

## Delivery Findings

### TEA (test design)
- **Improvement** (non-blocking): `archive_epic.get_archive_path` returns an
  actually-escaping path for deep-traversal sprint names (e.g. token
  `../../../tmp/pwned`) — confirmed by the failing `never_returns_escaping_path`
  guard. Shallower tokens (`../evil`) stay within the archive dir after
  resolution, so the containment layer only bites on deep escapes; the
  sprint_id allow-list (`[A-Za-z0-9._-]`) is the primary guard and rejects all
  of them. Affects `pf/sprint/archive_epic.py:56` (build the path, `.resolve()`,
  assert containment before returning). *Found by TEA during test design.*
- **Note** (non-blocking): `archive.py` already reads the sprint file with a
  bare `open(sprint_file)` (line 59) and `yaml.safe_load` — safe_load is correct,
  but the read `open()` also lacks `encoding=`. Story scope is the *append*
  open() (AC4); flagging the sibling read so Dev can fix both in one pass if
  cheap. Affects `pf/sprint/archive.py:59`. *Found by TEA during test design.*

### Dev (implementation)
- **Improvement** (non-blocking): the encoding= sweep stopped at story scope —
  `archive_epic.py` still has bare text I/O on archive files: `ensure_archive_file`'s
  `archive_path.write_text(template)`, `_load_archive_file`'s `open(archive_path)`,
  `_write_archive_file`'s `archive_path.write_text(result)`, and the raw index
  re-read `open(sprint_path)` in `archive_epic`. Same CWE-838 class as AC4.
  Affects `pf/sprint/archive_epic.py` (add `encoding="utf-8"` to each).
  *Found by Dev during implementation.*

### Reviewer (code review)
- **Gap** (non-blocking): epic-shard paths are a parallel unguarded CWE-22 surface —
  `_get_epic_ref` returns the raw id/jira string with no charset check (only an
  `epic-` prefix strip), and it feeds `archive_dir / f"epic-{epic_ref}.yaml"` at
  `migrate_completed_archive`, `load_archive`, `archive_epic`, and the yaml_io
  shard write/delete sites with no resolve()/containment. Same class 155-7 fixed,
  sibling call sites. Affects `pf/sprint/yaml_io.py` (`_get_epic_ref`) and
  `pf/sprint/archive_epic.py` (needs its own story). *Found by Reviewer during code review.*
- **Gap** (non-blocking): a third `sprint-{id}-completed.yaml` construction site
  bypasses the central guard — `pf sprint new` builds it directly from the CLI
  `sprint_yyww` arg (`pf/sprint/cli.py` ~2207) with no validation. Weaker threat
  model (interactive arg, not YAML), but it breaks the "one place" claim; fold
  into the epic-shard follow-up. Affects `pf/sprint/cli.py`. *Found by Reviewer during code review.*
- **Gap** (non-blocking): whitespace-only sprint `name` (truthy, `.split()` → `[]`)
  raises `IndexError` at `archive_epic.py:47`, upstream of the new sanitization —
  a malformed-input shape that bypasses the guard entirely and escapes even a
  `ValueError` wrap. Pre-existing, proven on develop baseline. Affects
  `pf/sprint/archive_epic.py:47` (guard the empty-token case → ValueError).
  *Found by Reviewer during code review.*

### TEA (test design — rework round 2)
- No new upstream findings during rework; Reviewer's three Gaps stand as the follow-up backlog.

### Dev (implementation — rework round 2)
- No new upstream findings during rework.

### Reviewer (code review — round 2)
- **Improvement** (non-blocking): stale `try/except ValueError: pass` in
  `test_archive_epic_unsafe_sprint_id_leaves_no_stray_shard` — the except branch
  is dead now that `archive_epic()` returns a result dict; collapse to a plain
  call on the next touch of the file. Cosmetic only (the assert executes
  unconditionally). Affects `pf/tests/test_155_7_archive_path_hardening.py:341`.
  *Found by Reviewer during code review.*
- **Question** (non-blocking): dry-run with an unsafe sprint name still returns
  `success: True` ("Would archive...") because the dry-run return precedes the
  hoisted guard in `archive_epic()`. Harmless (no mutation) but preview fidelity
  could be improved by hoisting above the dry-run branch; fold into the
  archive-hardening follow-up if desired. Affects `pf/sprint/archive_epic.py`.
  *Found by Reviewer during code review.*

## Design Deviations

### TEA (test design)
- **Encoding tested by open()-kwarg spy, not byte round-trip**
  - Spec source: context-story-155-7.md, AC4 ("archive.py open() call appends with encoding='utf-8' explicitly set")
  - Spec text: "pass encoding=utf-8 to the append open()"
  - Implementation: `test_archive_append_open_passes_utf8_encoding` spies on `builtins.open` and asserts the append call passes `encoding="utf-8"`, rather than only round-tripping non-ASCII bytes
  - Rationale: CWE-838 is platform-dependent — on the macOS/Linux CI default (utf-8) a byte round-trip passes even on unfixed code (vacuous RED). The kwarg spy fails deterministically on every platform. A round-trip companion test is retained as a content-integrity guard.
  - Severity: minor
  - Forward impact: Dev must pass `encoding="utf-8"` as an explicit kwarg on the append `open()`; wrapping in a helper that hardcodes utf-8 also satisfies the spy as long as the kwarg reaches `open`.
  - → ✓ ACCEPTED by Reviewer: platform-independent RED is the right call; spy target (`builtins.open`) verified correct — `open` is looked up dynamically, no patch-where-defined trap.
- **Containment asserted positively for valid inputs, not via a valid-charset escape**
  - Spec source: context-story-155-7.md, AC1 ("validates the resolved path is under sprint/archive/")
  - Spec text: "add archive_path.resolve() plus a containment assertion under sprint/archive/"
  - Implementation: Negative traversal cases are driven through the sprint_id allow-list (they all contain out-of-charset chars); the containment layer is pinned positively (valid ids resolve under the archive dir, both sides `.resolve()`d) plus one deep-escape case that current code fails.
  - Rationale: With sprint_id restricted to `[A-Za-z0-9._-]` no separator survives, so no valid-charset value can traverse — the two layers necessarily overlap. Testing the observable contract (bad input → ValueError; good input → contained path) avoids coupling to which layer fires.
  - Severity: minor
  - Forward impact: none — Dev may implement either order (sanitize-then-resolve or resolve-then-contain); both satisfy the suite.
  - → ✓ ACCEPTED by Reviewer: agrees with author reasoning — the layers necessarily overlap. Side effect confirmed by test-analyzer: post-fix, all 10 `never_returns_escaping_path` cases take the `except ValueError` early-return, so the containment assert is currently unreachable (inert regression latch). Logged as [LOW] finding for TEA to tighten (e.g. charset-valid `a..b` case), not a flag on the deviation itself.

### TEA (test design — rework round 2)
- **Stray-shard test constrains fix shape beyond the Reviewer's minimal recommendation**
  - Spec source: Reviewer Assessment [HIGH] fix-required ("wrap in try/except at the two result-object boundaries")
  - Spec text: "Wrap in `try/except ValueError → {\"success\": False, ...}` at the two result-object boundaries (mirroring archive.py:65-68)"
  - Implementation: `test_archive_epic_unsafe_sprint_id_leaves_no_stray_shard` additionally requires that a failed archive leaves no `archive/epic-{ref}.yaml` behind — a wrap alone at step 3 passes the contract test but fails this one; Dev must validate before the step-1 mutation.
  - Rationale: the Reviewer's own Devil's Advocate identified half-done-state stranding as the severity amplifier (the epic-155 truthfulness class); a wrap that still strands a shard fixes the traceback but not the harm. 155-12 set the validate-before-mutate precedent for finish.
  - Severity: minor
  - Forward impact: Dev must hoist archive-path resolution above step 1 in `archive_epic()` — a 2-line reorder plus the wrap, not just the wrap.
- **Whitespace-only-name IndexError deliberately NOT tested this round**
  - Spec source: Reviewer Delivery Finding (Gap, non-blocking) — "pre-existing, proven on develop baseline ... needs the empty-token guard"
  - Spec text: "guard the empty-token case → ValueError"
  - Implementation: no test for `{"name": "   "}` in the rework suite.
  - Rationale: Reviewer filed it as a non-blocking Delivery Finding (follow-up story), not a rework fix-required; pulling a pre-existing develop bug into a round-2 rework widens scope against SOUL #13/#14 and the Dev sidecar's baseline-prove-preexisting-failures discipline.
  - Severity: minor
  - Forward impact: follow-up story should add the test alongside the guard; until then a whitespace-only name still crashes with IndexError even after Dev's wraps (ValueError-only except).

### Dev (implementation — rework round 2)
- No deviations from spec — implemented TEA's designed interface verbatim (hoist-then-wrap in `archive_epic()`, wrap in `_add_story_to_completed`, `Raises:` docstring, resolved-path in containment message).
- → ✓ ACCEPTED by Reviewer (round 2): verified verbatim against the delta diff; no undocumented deviations spotted.

### Reviewer (audit — round 2 stamps on TEA rework deviations)
- TEA "Stray-shard test constrains fix shape beyond the Reviewer's minimal recommendation" → ✓ ACCEPTED by Reviewer: correct tightening — my own Devil's Advocate identified the stranding as the severity amplifier; a wrap that leaves the shard fixes the traceback, not the harm. The test forced the right fix.
- TEA "Whitespace-only-name IndexError deliberately NOT tested this round" → ✓ ACCEPTED by Reviewer: agrees — it's my own non-blocking Gap finding, pre-existing on develop, and pulling it into a rework round would be scope creep against SOUL #13/#14. Follow-up story owns it.

### Dev (implementation)
- **`..` rejected beyond the charset allow-list**
  - Spec source: context-story-155-7.md, AC3
  - Spec text: "restricts input to [a-zA-Z0-9._-]+ characters, rejecting invalid characters with ValueError"
  - Implementation: charset fullmatch PLUS an explicit `".." in sprint_id` rejection — a bare/embedded parent ref is charset-valid, so charset-only would build `sprint-..-completed.yaml` instead of raising
  - Rationale: TEA's `rejects_unsafe_sprint_id[..]` case requires ValueError for the bare parent ref; the tests are the binding spec. Side effect: charset-valid ids containing consecutive dots (e.g. `v1..2`) are also rejected.
  - Severity: minor
  - Forward impact: none — no real sprint id shape uses consecutive dots.
  - → ✓ ACCEPTED by Reviewer: required by AC2 ("attempts containing `..` ... raise ValueError") and the `[..]` test case. Security notes the check is not load-bearing (the `sprint-` prefix/`-completed.yaml` suffix structurally prevents a bare `..` component) — it is spec-required defence-in-depth, and reachable (`..`, `a..b`).
- **Sibling read open() also given encoding=**
  - Spec source: context-story-155-7.md, AC4
  - Spec text: "archive.py open() call appends with encoding='utf-8' explicitly set"
  - Implementation: also added `encoding="utf-8"` to the sprint-file read open() in `archive_story` (archive.py:59), beyond the append open() AC4 names
  - Rationale: TEA's Delivery Finding explicitly invited fixing the sibling read in the same pass; same CWE-838 class, one-kwarg change, covered by the existing round-trip guard.
  - Severity: minor
  - Forward impact: none.
  - → ✓ ACCEPTED by Reviewer: TEA's Delivery Finding explicitly invited it; one-kwarg change, same CWE class, covered by the round-trip guard.

## SM Assessment

**Routing:** 155-7 is a 2-pt security-hardening story tagged `workflow: tdd` (phased). Although 2-pointers can skip TEA under the default routing table, the explicit `tdd` tag governs — this is exactly the kind of well-bounded, testable hardening (path containment, input sanitization, encoding) where RED-first tests pin the contract cheaply. Routing through TEA → Dev → Reviewer.

**Scope is tight and self-contained:**
- `archive_epic.get_archive_path()` — add `.resolve()` + containment assertion under `sprint/archive/`, sanitize `sprint_id` to `[a-zA-Z0-9._-]+`.
- `archive.py` append `open()` — add `encoding='utf-8'`.
- Centralize the guard so both story- and epic-archive callers inherit it.

**Framework repo:** All work lands in `pennyfarthing/` on branch `feat/155-7` off `develop` (gitflow). No orchestrator code changes.

**For TEA (Murdock):** Write failing tests for (1) path-traversal rejection (`../../../etc/passwd`, absolute escapes), (2) sprint_id validation (`../evil`, `sprint;rm -rf`), (3) UTF-8 append round-trip. Verify both story- and epic-archive callers still succeed on valid inputs. Severity is LOW — no need to invent a trust boundary that isn't there; the value is a clean, centralized guard that fails loud.

Handing off to TEA for RED phase.

## TEA Assessment

**Tests Required:** Yes
**Reason:** Security-hardening story with concrete, testable invariants (path containment, input sanitization, encoding).

**Test Files:**
- `pennyfarthing-dist/src/pf/tests/test_155_7_archive_path_hardening.py` — 8 test functions, 28 parametrized cases

**Tests Written:** 28 cases covering 4 ACs (AC1 containment, AC3 sanitization, AC4 encoding, AC6 valid-input preservation for both callers)
**Status:** RED (14 failing as designed — ready for Dev)

**RED verification (testing-runner):** 14 FAILED / 14 PASSED in the new file; all 7 sibling tests (`test_get_archive_path.py`, `test_155_3_archive_story_number_fallback.py`) remain GREEN; no collection errors.

Failing (the contract Dev must satisfy):
- `test_get_archive_path_rejects_unsafe_sprint_id[*]` — 10 cases, unsafe tokens must raise `ValueError`
- `test_get_archive_path_never_returns_escaping_path[../../../tmp/pwned]` — deep traversal currently escapes the archive dir
- `test_get_archive_path_rejects_traversal_via_name_prefix` — `"TO Sprint ../../etc/pwn"` last token
- `test_archive_story_rejects_unsafe_sprint_id` — central fix must reach the story-archive caller
- `test_archive_append_open_passes_utf8_encoding` — append `open()` must pass `encoding="utf-8"`

Passing (preservation guards — must stay green):
- `test_get_archive_path_accepts_valid_sprint_id[*]` — 4 valid ids still resolve, contained
- `test_archive_append_roundtrips_non_ascii` — non-ASCII title round-trips
- `never_returns_escaping_path[*]` — 9 non-deep cases already contained

### Rule Coverage

| Rule (lang-review python.md) | Test(s) | Status |
|------|---------|--------|
| #5 path handling — missing `Path.resolve()` before security check (CWE-59) | `never_returns_escaping_path`, `accepts_valid_sprint_id` (positive containment) | failing/passing |
| #5 path handling — `open()` without `encoding=` (CWE-838) | `archive_append_open_passes_utf8_encoding` | failing |
| #11 input validation — file paths resolved & checked vs allowed dir (CWE-22) | `rejects_unsafe_sprint_id[*]`, `rejects_traversal_via_name_prefix`, `archive_story_rejects_unsafe_sprint_id` | failing |
| #6 test quality — no vacuous assertions | self-check (below) | passing |

**Rules checked:** 3 of 3 applicable lang-review rules (#5, #11, #6) have test coverage. (#1–#4, #7–#10, #12–#13 not applicable to this diff.)
**Self-check:** Reviewed all 8 test functions — every test has a meaningful assertion. The one platform-vacuous risk (encoding round-trip on utf-8-default OS) is mitigated by the deterministic open()-kwarg spy; the round-trip is retained only as a content-integrity guard. 0 vacuous tests shipped.

**Handoff:** To Dev (B.A.) for GREEN implementation — centralize the guard in `get_archive_path`, add `encoding="utf-8"` to the append `open()` in `archive.py`.

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/src/pf/sprint/archive_epic.py` - `get_archive_path`: sprint_id allow-list (`[A-Za-z0-9._-]+` fullmatch + explicit `..` rejection, ValueError with the offending id named) and resolved-path containment assert directly under `sprint/archive/` (defence-in-depth). Central fix — both epic-archive and story-archive callers inherit it; `archive_story` already wraps ValueError into `{success: False}` (155-3), so no caller changes.
- `pennyfarthing-dist/src/pf/sprint/archive.py` - `encoding="utf-8"` on the archive append `open()` (AC4) and on the sprint-file read `open()` (TEA's sibling finding, same pass).

**Tests:** 40/40 passing (GREEN) — 28/28 story file + `test_get_archive_path.py`, `test_155_3_archive_story_number_fallback.py`, `test_archive_epic.py` regression batch (testing-runner RUN_ID 155-7-dev-green); `ruff check` clean on both changed files. Scoped runs only — full suite carries known unrelated failures.
**Branch:** feat/155-7 (pushed, commit 540c07709)

**Handoff:** To Reviewer for code review

## Subagent Results

| # | Specialist | Received | Status | Findings | Decision |
|---|-----------|----------|--------|----------|----------|
| 1 | reviewer-preflight | Yes (summary relay only; Reviewer re-ran checks directly) | findings | 1 | confirmed 1 (ruff UP012, test file:274) |
| 2 | reviewer-edge-hunter | Skipped | disabled | N/A | Disabled via settings |
| 3 | reviewer-silent-failure-hunter | Skipped | disabled | N/A | Disabled via settings |
| 4 | reviewer-test-analyzer | Yes | findings | 5 | confirmed 3 (wrong-key leak assert M; inert escape guard L; missing `a..b` branch case L), deferred 2 (whitespace-IndexError → Delivery Finding; `"."` case nice-to-have) |
| 5 | reviewer-comment-analyzer | Skipped | disabled | N/A | Disabled via settings |
| 6 | reviewer-type-design | Yes | findings | 5 | confirmed 3 (unwrapped ValueError H; containment msg shows unresolved path L; missing Raises: docstring L), deferred 2 (`pf sprint new` site → Delivery Finding; whitespace-IndexError dup → Delivery Finding) |
| 7 | reviewer-security | Yes | findings | 2 | confirmed 0 blocking; deferred 1 (epic-shard CWE-22 gap → Delivery Finding); dismissed 1 (`..` check "dead code" — reachable for `..`/`a..b` and required by AC2/test contract; not load-bearing ≠ dead) |
| 8 | reviewer-simplifier | Skipped | disabled | N/A | Disabled via settings |
| 9 | reviewer-rule-checker | Yes | findings | 1 | confirmed 1 (rule #13 / SOUL #10 unwrapped-caller violation — corroborates type-design H). Its rule #6 "compliant" verdict overridden by test-analyzer's empirical proof (see Challenged note) |

**All received:** Yes (5 enabled returned, 4 disabled skipped)
**Total findings:** 8 confirmed, 1 dismissed (with rationale), 4 deferred (3 folded into Delivery Findings, 1 nice-to-have)

## Reviewer Assessment

**Verdict:** REJECTED

| Severity | Issue | Location | Fix Required |
|----------|-------|----------|--------------|
| [HIGH] [RULE][TYPE] | New `ValueError` raises are unwrapped in 2 of 3 call chains — `archive_epic()` (via `ensure_archive_file`, archive_epic.py:91→548) and `_add_story_to_completed` (story_finish.py:103, whose docstring promises the SOUL #10 result contract). A sprint name with ordinary punctuation (`"Sprint (Q3)"`, non-ASCII) now crashes `pf sprint epic archive` and `pf sprint story finish` with a traceback — and story-finish step 4b runs AFTER the merge step, so the crash strands finish half-done. Pre-existing exposure, but this diff's charset check widens the trigger from "name and number both unset" (rare) to "any punctuated name" (common). | archive_epic.py:548, story_finish.py:103 | Wrap in `try/except ValueError → {"success": False, "error": ...}` at the two result-object boundaries (mirroring archive.py:65-68). Needs RED tests for both callers. |
| [MEDIUM] [TEST] | Leak assertion checks the wrong dict key — failure path sets only `error` (archive.py:68), so `result.get("message")` is always `""` and the `"/tmp/pwned" not in` assert is vacuous (lang-review #6). Fixing it to check `error` fails today: the ValueError echoes the offending sprint_id verbatim. | test_155_7_archive_path_hardening.py:208 | Assert on `result["error"]`; decide echo policy (echoing the user's own YAML token is acceptable — asserting no RESOLVED out-of-tree path appears is the meaningful check). |
| [LOW] [TEST] | `never_returns_escaping_path` containment assert is unreachable post-fix (all 10 tokens raise → early return); only bare `..` exercises the second OR-branch. | test file, `never_returns_escaping_path` | Add a charset-valid `a..b` case to `rejects_unsafe_sprint_id`, keep the escape guard as a documented regression latch. |
| [LOW] [RULE] | ruff UP012 — `.encode("utf-8")` redundant arg; AC7 requires lint-pass. | test file:274 | `ruff check --fix`. |
| [LOW] [DOC][TYPE] | `get_archive_path` docstring lacks a `Raises:` section despite three distinct ValueError conditions — the exact omission that produced the HIGH (callers don't know to catch). `_write_archive_file` in the same file models the convention. | archive_epic.py:24-33 | Add `Raises: ValueError` with the three conditions. |
| [LOW] [TYPE] | Containment error echoes the unresolved (safe, already-validated) path; the diagnostic that matters is where it actually resolves. | archive_epic.py:74-76 | Include `archive_path.resolve()` in the message. |

### Rule Compliance

Per lang-review python.md, all 13 checks enumerated against every changed function (rule-checker, verified by Reviewer):
- **#1 silent exceptions, #2 mutable defaults, #4 logging, #8 deserialization, #9 async, #10 imports, #12 dependencies:** compliant/N-A — no new except blocks, no new defaults, no logging imports, `yaml.safe_load` untouched, no async, `import re` clean, no dep changes.
- **#3 annotations:** compliant — `get_archive_path` signature fully annotated; untyped `monkeypatch` in tests is conventional and exempt.
- **#5 path handling:** compliant — both `open()` calls carry `encoding="utf-8"` inside `with` blocks (#7); `.resolve()` called on both sides before the security comparison; parent-equality is deliberately stricter than `is_relative_to` (flat-filename invariant).
- **#6 test quality:** **VIOLATION — Challenged:** rule-checker judged compliant, but test-analyzer empirically proved the wrong-key leak assert is vacuous and the escape-guard assert unreachable; line-level evidence wins ([MEDIUM]/[LOW] above).
- **#11 input validation:** compliant — allow-list before path construction, correct boundary placement, no ReDoS.
- **#13 fix-introduced regressions:** **VIOLATION** — "adding validation but only on one code path": the validation's new failure mode is handled by `archive_story` only; `archive_epic()`/`_add_story_to_completed` crash ([HIGH] above).
- **SOUL #2:** compliant — guard lives once in `get_archive_path` (the two OTHER construction sites pre-date this story; deferred as Delivery Findings). **SOUL #10:** violation ([HIGH]). **SOUL #13/#14:** compliant — diff tightly scoped, deviations logged.

### Observations (traced + verified)

1. [VERIFIED] Sanitization is sound against bypass — evidence: archive_epic.py:61-66; [SEC] walked NUL bytes, unicode, `/`+`\`, Windows reserved names, long ids: all rejected by the fullmatch or structurally neutralized by the `sprint-…-completed.yaml` template. Complies with #5/#11 (CWE-22).
2. [VERIFIED] Containment check resolves both sides before comparing (archive_epic.py:73) — symlinked archive dirs resolve consistently; `resolve(strict=False)` on a non-existent target is lexical on both sides. Complies with #5 (CWE-59). TOCTOU dismissed: same-user local CLI, no trust boundary crossed.
3. [VERIFIED] Data flow traced: YAML `name`/`number` → `split()[-1]` → charset gate (raises before any path exists) → template filename → resolved-parent equality → unresolved Path returned (caller contract preserved — sibling tests assert `path.name`). Safe because no separator survives the charset and the template pins prefix/suffix.
4. [VERIFIED] Both `open()` fixes are inside existing `with` blocks (archive.py:59,104) — CWE-838 closed for this file; [SILENT] no new swallowed exceptions introduced (no new except blocks in the diff).
5. [EDGE] Boundary review done directly (specialist disabled): `"."` passes and is benign (`sprint-.-completed.yaml`, contained); empty name falls to `number` branch; whitespace-only name hits the pre-existing IndexError (Delivery Finding); list/dict-typed `number` now fails loud at the charset gate (previously built a garbage filename) — an improvement.
6. [SIMPLE] No over-engineering (specialist disabled): the two-layer guard is AC-mandated, not gold-plating; no dead code — the `..` branch is reachable and spec-required.
7. [DOC] Comments accurate ([DOC] specialist disabled, checked directly); the one doc defect is the missing `Raises:` section ([LOW] above).

### Devil's Advocate

Assume this diff ships and the fix is broken. The most damaging path: a team names their sprint "Sprint (Q3 hardening)" in current-sprint.yaml — a perfectly reasonable, non-malicious name. `split()[-1]` yields `hardening)`, the charset gate raises, and `pf sprint story finish` crashes with a traceback at step 4b — after the PR was already merged in step 2. Finish is now stranded half-done: PR merged, story not archived, session not cleaned — precisely the truthfulness failure this whole epic (155) exists to eliminate. Before this diff, that sprint name silently built an ugly-but-working filename; the hardening converts a cosmetic wart into a mid-flow crash on two CLI paths that don't wrap it. The guard is correct; the deployment of the guard is incomplete. That is the HIGH, and it is why this is a REJECT rather than an approve-with-notes. Second angle: the tests lie about coverage. The 10-case escape-guard parametrization reads as strong containment verification but executes zero containment asserts post-fix, and the leak assertion checks a key the failure path never populates — two tests that would keep passing if the containment logic were deleted outright (the charset gate alone satisfies every currently-executing assertion). A future refactor could loosen containment with the suite still green. Third angle: the story's title promises hardening "centrally," but two sibling construction sites (`epic-{ref}.yaml` shards, `pf sprint new`) remain unguarded — a reviewer of the follow-up 155-3 deferral could reasonably believe the CWE-22 class is closed when it is only closed for one filename family. All three angles produced findings above; nothing further uncovered.

**Handoff:** Back to TEA (Murdock) for red rework — the [HIGH] needs RED tests (punctuated sprint name through `archive_epic()` and `_add_story_to_completed`) plus the two test-defect fixes, then Dev wraps the two boundaries.

## TEA Assessment (rework round 2)

**Tests Required:** Yes
**Reason:** Reviewer REJECTED round 1 — [HIGH] unwrapped ValueError call chains need RED coverage; two test defects in my round-1 file needed fixing.

**Test Files:**
- `pennyfarthing-dist/src/pf/tests/test_155_7_archive_path_hardening.py` — now 11 test functions, 34 parametrized cases (commit 3ee979ba8)

**Round-2 changes:**
1. **NEW RED — `test_archive_epic_returns_result_on_unsafe_sprint_id`:** `archive_epic("37")` with sprint name `"Sprint (Q3)"` must return `{"success": False, "error": "Invalid sprint id ..."}`, not raise (SOUL #10). Fails today: uncaught ValueError from `ensure_archive_file` at archive_epic.py:548.
2. **NEW RED — `test_archive_epic_unsafe_sprint_id_leaves_no_stray_shard`:** a failed epic-archive must not leave `archive/epic-37.yaml` behind. Fails today: the shard is written (step 1) before the guard fires (step 3). Forces Dev to validate the archive path BEFORE the first filesystem mutation (155-12 precedent) — a plain try/except at step 3 alone will NOT green this.
3. **NEW RED — `test_add_story_to_completed_returns_result_on_unsafe_sprint_id`:** `_add_story_to_completed` must keep its docstring's result-dict promise. Fails today: uncaught ValueError at story_finish.py:103.
4. **FIXED (Reviewer [MEDIUM]) — vacuous leak assert:** `test_archive_story_rejects_unsafe_sprint_id` now asserts on `result["error"]` (contains "Invalid sprint id") and that no "Would archive" message was built; removed the `except ValueError: return` escape hatch — archive_story's wrap IS the contract. Passes today (preservation guard).
5. **FIXED (Reviewer [LOW]/AC7) — ruff UP012:** `.encode("utf-8")` → `.encode()` at the round-trip assert. Ruff clean.
6. **ADDED (Reviewer [LOW]) — `"a..b"` token** in TRAVERSAL_TOKENS: charset-valid, isolates the `..` OR-branch of the guard. Passes today (branch already implemented); the escape-guard test stays as a documented regression latch per Reviewer's deviation stamp.

**Status:** RED (3 failing as designed — ready for Dev)

**RED verification (testing-runner, RUN_ID 155-7-tea-red-r2):** 3 FAILED / 59 PASSED across the story file + `test_get_archive_path.py`, `test_155_3_archive_story_number_fallback.py`, `test_archive_epic.py`, `test_story_finish_no_jira.py`. Each failure verified to fail for its designed reason (uncaught ValueError ×2, stray-shard assert ×1), not fixture errors. Ruff clean.

### Rule Coverage (round 2 delta)

| Rule (lang-review python.md) | Test(s) | Status |
|------|---------|--------|
| #13 fix-introduced regressions / SOUL #10 — validation added on one code path only | `archive_epic_returns_result_on_unsafe_sprint_id`, `add_story_to_completed_returns_result_on_unsafe_sprint_id` | failing |
| #1 silent-exception discipline (fail loud, no half-done state) | `archive_epic_unsafe_sprint_id_leaves_no_stray_shard` | failing |
| #6 test quality — vacuous assertion fixed in my own round-1 file | reworked `archive_story_rejects_unsafe_sprint_id` self-check | passing |

**Self-check:** re-reviewed all 11 test functions post-rework — the two round-1 defects (wrong-key assert, dead escape hatch) are gone; every assert executes on the path it claims to pin. 0 vacuous tests.

**Notes for Dev (B.A.):**
- The no-stray-shard test constrains the FIX SHAPE: hoist archive-path resolution (`ensure_archive_file` or a `get_archive_path` probe) ABOVE step 1 in `archive_epic()`, then wrap. Wrapping in place at step 3 leaves the stray shard and stays RED.
- `_add_story_to_completed`: wrap the `ensure_archive_file(project_root)` call in `try/except ValueError → {"success": False, "error": str(exc)}` — mirror archive.py:65-68. The step-4b caller already handles a False result gracefully (non-fatal, recorded).
- Reviewer [LOW]s to fold in while you're there: `Raises:` section on `get_archive_path`'s docstring; containment error message should echo `archive_path.resolve()` (the diagnostic that matters), not the unresolved path.

**Handoff:** To Dev (B.A.) for GREEN — wrap the two result-object boundaries, reorder validation before mutation in `archive_epic()`.

## Dev Assessment (rework round 2)

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/src/pf/sprint/archive_epic.py` — (1) `archive_epic()`: hoisted `ensure_archive_file(root)` above step 1 (after the dry-run return), wrapped in `try/except ValueError → {"success": False, "error"}` — the guard now fires before any filesystem mutation, so no stray shard; step 3 reuses the hoisted `archive_path`. (2) `get_archive_path` docstring: added the `Raises:` section documenting all three ValueError conditions and the caller-must-wrap contract. (3) Containment error message now includes `archive_path.resolve()` (the actual escape target).
- `pennyfarthing-dist/src/pf/sprint/story_finish.py` — `_add_story_to_completed`: wrapped `ensure_archive_file(project_root)` in `try/except ValueError → {"success": False, "error"}`, honoring its documented result-dict promise; the step-4b caller already records a False result non-fatally.

**Design Deviations:** none — implemented TEA's designed interface verbatim (see `### Dev (implementation — rework round 2)` finding entry).
**Tests:** 86/86 passing (GREEN) — 33/33 story file (all 3 round-2 RED tests now pass) + full finish-flow regression batch (`test_get_archive_path`, `test_155_3`, `test_archive_epic`, `test_story_finish_no_jira`, `test_155_1`, `test_155_4`, `test_155_8`); `ruff check` clean on all three changed source files plus the test file (testing-runner RUN_ID 155-7-dev-green-r2).
**Branch:** feat/155-7 (pushed, commit 17ce6b3f7)

**Handoff:** To Reviewer (Colonel Decker) for round-2 review

## Subagent Results

**(Round 2 — delta review of commits 3ee979ba8 + 17ce6b3f7)**

| # | Specialist | Received | Status | Findings | Decision |
|---|-----------|----------|--------|----------|----------|
| 1 | reviewer-preflight | Yes (run directly by Reviewer — round-1 relay was lossy) | clean | none | N/A — 62/62 scoped tests pass, ruff clean on all 4 changed files, tree clean, no debug code |
| 2 | reviewer-edge-hunter | Skipped | disabled | N/A | Disabled via settings |
| 3 | reviewer-silent-failure-hunter | Skipped | disabled | N/A | Disabled via settings |
| 4 | reviewer-test-analyzer | Yes | findings | 1 | All 3 round-1 findings verified FIXED (high confidence, empirically traced); confirmed 1 cosmetic LOW (stale `except ValueError: pass` in stray-shard test — dead branch post-fix; the assert executes unconditionally, so not vacuous) → deferred as non-blocking polish |
| 5 | reviewer-comment-analyzer | Skipped | disabled | N/A | Disabled via settings |
| 6 | reviewer-type-design | Yes | clean | 0 (1 observation) | All 3 round-1 findings verified FIXED; no unbound `archive_path` on any branch; no success-path behavior change; observation on earlier template-file creation under a mid-flow OSError judged idempotent/harmless — concurred, not a finding |
| 7 | reviewer-security | No — spawn failed twice (tmux fork error) | error | N/A | Domain assessed directly by Reviewer: new except blocks are narrow (ValueError only) and return result dicts — not swallows; resolved-path echo within accepted local-CLI trust model; hoist opens no new TOCTOU/partial-state window; round-2 tests drive the real guard unmocked |
| 8 | reviewer-simplifier | Skipped | disabled | N/A | Disabled via settings |
| 9 | reviewer-rule-checker | No — spawn failed twice (tmux fork error) | error | N/A | Domain assessed directly by Reviewer: all 13 lang-review checks pass on the delta; rule #13 closed by exhaustive caller grep — the only production call sites are archive.py:66 (wrapped r1), archive_epic.py:534 (wrapped r2), story_finish.py:106 (wrapped r2), archive_epic.py:99 (internal, raise-style by design, documented in Raises:); CLI consumes result dicts only |

**All received:** Yes (2 specialists returned, 2 errored with domains covered directly by Reviewer, 4 disabled, preflight run directly)
**Total findings:** 1 confirmed (cosmetic LOW, deferred), 0 dismissed, all 6 round-1 findings verified FIXED

## Reviewer Assessment

**(Rework round 2)**

**Verdict:** APPROVED

**Round-1 findings — all verified fixed:**
1. [HIGH] [RULE][TYPE] unwrapped ValueError → FIXED: hoist-then-wrap in `archive_epic()` (archive_epic.py:530-537, before the step-1 shard mutation, after the dry-run return), wrap in `_add_story_to_completed` (story_finish.py:104-108). Proven by the three round-2 tests going RED→GREEN and by exhaustive caller enumeration (no chain remains that crashes).
2. [MEDIUM] [TEST] vacuous leak assert → FIXED: now asserts `"Invalid sprint id" in result["error"]`; escape hatch removed.
3. [LOW] [TEST] inert escape guard → FIXED: `a..b` token added — verified it genuinely isolates the `..` OR-branch (charset-valid, containment would NOT catch an embedded `..` in a flat filename; only the explicit check can raise).
4. [LOW] [RULE] ruff UP012 → FIXED (`ruff check` clean, AC7 satisfied).
5. [LOW] [DOC][TYPE] missing `Raises:` → FIXED (archive_epic.py:34-39, names all three conditions and the caller-wrap obligation).
6. [LOW] [TYPE] containment message → FIXED (echoes the resolved target).

**Data flow traced:** malformed sprint `name` ("Sprint (Q3)") → `split()[-1]` = `(Q3)` → charset guard raises ValueError → caught at all three result-object boundaries → `{"success": False, "error": "Invalid sprint id ..."}` → CLI prints `Failed: ...` (safe because the raise happens before any path construction or filesystem mutation — the stray-shard test pins this ordering).
**Pattern observed:** validate-before-first-mutation (archive_epic.py:530-532), the 155-12 precedent correctly generalized to epic archival.
**Error handling:** narrow `except ValueError` at exactly the documented raise-style boundary, result dicts conform to SOUL #10; [SILENT] no swallowed errors introduced; [EDGE] no unbound-variable branch (all early returns precede the hoist); [SEC] trust model unchanged, guard unmocked in tests; [SIMPLE] one cosmetic nit (stale `except ValueError: pass` in the stray-shard test, dead post-fix — non-blocking polish for a future touch); [DOC] Raises: section closes the contract-documentation gap that caused the round-1 HIGH.

### Rule Compliance (round 2 delta)

- **#1 silent exceptions:** compliant — both new excepts return the error, never swallow. **#5/#7/#11:** unchanged from round 1 (compliant). **#6 test quality:** compliant — round-1 defects fixed; the trivially-true secondary `"Would archive"` assert is defense-in-depth alongside a real primary assert, not a sole vacuous check. **#13 fix-regressions:** compliant — the fix re-scanned against #1-#12; caller enumeration closed. **#3/#10:** compliant (no signature changes; imports used, ruff clean). **#2/#4/#8/#9/#12:** N/A on this delta.
- **SOUL #2:** guard still lives once in `get_archive_path`. **SOUL #10:** now honored on every chain. **SOUL #13/#14:** rework tightly scoped to the six findings, deviations logged and stamped.

### Devil's Advocate

Assume the rework is broken. Angle 1: the wrap hides a deeper failure — could `except ValueError` now mask a legitimate crash? No: the only ValueErrors raisable inside `ensure_archive_file` are the three documented guard conditions (traced `get_archive_path` line by line; `load_sprint`/`write_text` raise OSError/yaml errors, which still propagate loudly). Angle 2: the hoist changes success-path semantics — the archive template is now created before the shard moves, so an unrelated mid-flow OSError leaves an empty template file that didn't exist before. Traced: idempotent (next run reuses it), and the pre-existing mid-flow OSError exposure (unwrapped `shutil.move`) is unchanged by this diff — filed nothing because the delta neither introduced nor widened it. Angle 3: the tests could be green for the wrong reason — could `archive_epic("37")` short-circuit before the guard (epic not found, incomplete)? No: the fixture's epic is `status: done` with a done story, and the RED run proved the pre-fix path reached the raise (uncaught ValueError at archive_epic.py:62 in the RED log) and left the stray shard, so GREEN is attributable to the fix, not to an earlier return. Angle 4: dry-run with a bad sprint name still returns `success: True` "Would archive..." because dry-run returns before the hoist — defensible (dry-run makes no mutation and round 1 deliberately left it unpinned) but worth naming so nobody mistakes it for covered behavior; a follow-up could hoist above dry-run for stricter preview fidelity. None of these angles produced a blocking finding.

**Handoff:** To SM (Faceman) for finish-story — PR creation and merge are SM's. Round-trip complete: REJECT → red rework → green → APPROVED in one cycle.