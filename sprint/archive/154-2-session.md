---
story_id: "154-2"
jira_key: ""
epic: ""
workflow: "tdd"
---
# Story 154-2: portrait_cdn hardening: path-traversal in clean()/ensure_portraits, manifest SSRF + KeyError guards, py3.11 filter, test isolation (Reviewer C1-C8)

## Story Details
- **ID:** 154-2
- **Jira Key:** (none — kanban-only)
- **Workflow:** tdd
- **Stack Parent:** none
- **Branch Strategy:** gitflow (feat/154-2-portrait-cdn-hardening)

## Workflow Tracking
**Workflow:** tdd
**Phase:** finish
**Phase Started:** 2026-06-03T20:12:36Z
**Round-Trip Count:** 1

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-06-03 19:01:49+00:00 | 2026-06-03T19:05:38Z | 3m 49s |
| red | 2026-06-03T19:05:38Z | 2026-06-03T19:14:32Z | 8m 54s |
| green | 2026-06-03T19:14:32Z | 2026-06-03T19:19:01Z | 4m 29s |
| spec-check | 2026-06-03T19:19:01Z | 2026-06-03T19:20:36Z | 1m 35s |
| verify | 2026-06-03T19:20:36Z | 2026-06-03T19:24:45Z | 4m 9s |
| review | 2026-06-03T19:24:45Z | 2026-06-03T19:38:22Z | 13m 37s |
| red | 2026-06-03T19:38:22Z | 2026-06-03T19:42:37Z | 4m 15s |
| green | 2026-06-03T19:42:37Z | 2026-06-03T19:45:33Z | 2m 56s |
| spec-check | 2026-06-03T19:45:33Z | 2026-06-03T19:46:12Z | 39s |
| verify | 2026-06-03T19:46:12Z | 2026-06-03T19:50:57Z | 4m 45s |
| review | 2026-06-03T19:50:57Z | 2026-06-03T20:11:29Z | 20m 32s |
| spec-reconcile | 2026-06-03T20:11:29Z | 2026-06-03T20:12:36Z | 1m 7s |
| finish | 2026-06-03T20:12:36Z | - | - |

## SM Assessment

**Setup complete — routing to TEA (RED phase).**

- **Origin:** Hardening follow-up to 154-1 (portrait_cdn R2 module), which merged to develop today (PR #72) and is now the *primary* portrait source for installed users after PR #73 removed bundled portraits from the wheel. These are real production security/quality defects, not theoretical.
- **Spec source:** Reviewer-confirmed findings C1–C8 from `sprint/archive/154-1-session.md` (lines ~215–245). All eight are transcribed into `sprint/context/context-story-154-2.md` with file:line, severity, recommended fix, and a per-finding acceptance criterion.
- **Severity mix:** C1, C2, C3, C6 = Major; C4, C5, C7, C8 = Minor. C1–C5 are implementation; C6–C8 are test-quality fixes; C5 also touches `pyproject.toml` (Python floor 3.11.4).
- **Workflow:** tdd (phased, 5 pts) → TEA writes a failing test per finding, Dev makes them pass, Reviewer verifies. Preserve the "never raises" contract — guarded failures return `{success: False}`, they do not throw.
- **Jira:** none — kanban-only project, no transition needed.
- **Branch:** `feat/154-2-portrait-cdn-hardening` off `develop` (pennyfarthing is gitflow).

**Next:** Igor (TEA) for RED — eight failing tests against the C1–C8 acceptance criteria.

## TEA Assessment

**Tests Required:** Yes
**Status:** RED (failing — ready for Dev)

**Test Files:**
- `pennyfarthing-dist/src/pf/tests/test_154_2_portrait_cdn_hardening.py` (new) — 10 failing tests for the implementation/packaging findings C1–C5 + C8(impl).
- `pennyfarthing-dist/src/pf/tests/test_154_1_portrait_cdn.py` (edited) — C7 made non-vacuous; C8 under-assertion fixed (test half).
- `pennyfarthing-dist/src/pf/tests/test_154_1_portrait_cdn_wiring.py` (edited) — C6 live-CDN leak made hermetic.

**Tests Written:** 10 new failing + 3 strengthened existing, covering all 8 findings (C1–C8).
**RED verified:** scoped run (`uv run pytest <3 files> -q`) → `10 failed, 39 passed`. All 10 failures are assertion/`pytest.fail`/intended-raise — none are collection or import errors. Did NOT run the full suite (it leaks a `feature/test` checkout via test_git_utils.py).

### Finding → Test → RED reason

| Finding | Test | Fails now because |
|---------|------|-------------------|
| C1 clean() traversal | `test_clean_rejects_path_traversal_*`, `test_clean_rejects_absolute_path_theme` | `clean("../victim")` rmtrees the out-of-cache victim |
| C2 theme-name traversal | `test_ensure_portraits_rejects_{traversal,slash,empty}_theme_name` | not rejected up front → `urlopen` is called (manifest fetched) before any validation |
| C3 unguarded keys | `test_..._missing_base_url_*`, `test_..._missing_pack_sha256_*` | bare `manifest['base_url']` / `entry['pack_sha256']` raise `KeyError` |
| C4 SSRF | `test_..._pack_url_ignores_poisoned_manifest_base_url` | pack URL is built from `manifest['base_url']` (honors `file://`), not `CDN_BASE_URL` |
| C5 py3.11 filter | `test_requires_python_floor_excludes_broken_filter_versions` | `requires-python = ">=3.11"` admits 3.11.0–3.11.3 where `filter="data"` raises `TypeError` |
| C8 partial-extract cleanup | `test_..._cleans_theme_dir_on_extraction_failure` | `TarError` mid-extract leaves a populated, sentinel-less theme dir |

### Rule Coverage (`gates/lang-review/python.md`)

| Rule | Test(s) | Status |
|------|---------|--------|
| #5 path handling (CWE-22/59) | C1 + C2 traversal tests | failing |
| #11 input validation at boundaries (CWE-22/918) | C2 (theme name), C4 (SSRF base_url) | failing |
| #1 silent exceptions (KeyError/TypeError escape) | C3 (base_url, pack_sha256), C5 | failing |
| #7 resource leaks (tmp + orphaned dir) | C3 (pack_sha256 tmp leak), C7, C8 | failing / fixed |
| #6 test quality (vacuous / network in test) | C6 (hermetic), C7 (non-vacuous) | fixed (passing) |

**Rules checked:** 5 of 13 lang-review rules apply to this diff; all have test coverage.
**Self-check:** Caught and fixed one false-negative of my own — the C2 traversal tests initially passed against vulnerable code (incidental OSError from a missing tmp-parent dir), so I rewrote them to assert up-front rejection (no network call). No vacuous assertions remain.

**Handoff:** To Dev (Ponder Stibbons) for GREEN.

## Dev Assessment

**Implementation:** Complete
**Status:** GREEN (all tests passing)

**Files changed:**
- `pennyfarthing-dist/src/pf/package/portrait_cdn.py` — `_is_safe_theme()` validator; up-front theme validation in `ensure_portraits` + `clean`; guarded `base_url`/`pack_sha256`; pack URL from `CDN_BASE_URL`; `rmtree` on extraction failure.
- `pennyfarthing-dist/pyproject.toml` — `requires-python` floor `>=3.11` → `>=3.11.4`.
- `pennyfarthing-dist/src/pf/tests/test_154_2_portrait_cdn_hardening.py` — removed an unused import (F401 lint-gate fix on TEA's test file).

**Verification:** scoped run → `76 passed` (10 hardening + 66 existing portrait/wiring/protocol/peloton tests); `ruff check` clean on all four changed `.py` files. Did NOT run the full suite (test_git_utils.py leaks a `feature/test` checkout).

### AC Accountability

| AC | Status | How |
|----|--------|-----|
| C1 clean() traversal | DONE | `_is_safe_theme` guard before `rmtree`; rejects `../`, absolute, separators |
| C2 ensure_portraits traversal | DONE | `_is_safe_theme` guard at function top, before `fetch_manifest` (no network on reject) |
| C3 unguarded keys | DONE | `entry.get("pack_sha256")` + `"base_url" not in manifest` guard → `{success: False}`, no download, no `.tmp` |
| C4 SSRF | DONE | pack URL built from `CDN_BASE_URL`; manifest `base_url` value never used for fetch |
| C5 py3.11 filter | DONE | `requires-python = ">=3.11.4"` (floor route — agrees with TEA's encoded contract) |
| C6 wiring hermetic | DONE | (TEA) verified passing — resolver test no longer hits live CDN |
| C7 vacuous tmp assertion | DONE | (TEA) verified passing — tmp pre-seeded, unlink exercised |
| C8 partial-extract cleanup | DONE | `shutil.rmtree(theme_dir, ignore_errors=True)` on `TarError` |

**Resolves TEA's C5 Question:** I took the floor-bump route, matching the encoded test contract — catching `TypeError` would preserve the silent-skip failure mode, which is the worse option.

**Handoff:** To Architect (Leonard) for spec-check.

## Architect Assessment (spec-check)

**Spec Alignment:** Aligned
**Mismatches Found:** None

Read the full implementation diff (`portrait_cdn.py`, `pyproject.toml`) against all eight C1–C8 acceptance criteria in `context-story-154-2.md`. Every finding's code matches its spec:

- **C1/C2 (path traversal):** `_is_safe_theme` rejects empty, `/`, `\`, `..`; applied before any path build or network call in both `ensure_portraits` and `clean`. Absolute paths are caught via the `/` check. Matches "reject up front."
- **C3 (unguarded keys):** `entry.get("pack_sha256")` + `"base_url" not in manifest` guard returns `{success: False}` *before* download — stronger than the spec (no `.tmp` can ever be created on the malformed-manifest path), still within the "never raises" contract.
- **C4 (SSRF):** pack URL built from the hardcoded `CDN_BASE_URL`; the manifest `base_url` value is never used for the fetch. Matches the "build from hardcoded CDN" option.
- **C5 (py3.11 filter):** `requires-python = ">=3.11.4"` — the floor route. Endorsed: catching `TypeError` would keep the silent-skip failure mode alive, so removing the broken range is the correct architectural call. Resolves TEA's open Question.
- **C8 (partial extraction):** `shutil.rmtree(theme_dir, ignore_errors=True)` on `TarError` before returning. Matches "clean theme_dir on extraction failure."

**Reuse note:** `_is_safe_theme` is a new 3-line module-local helper. No existing theme-name validator exists to reuse; a local guard is the right scope — no new infrastructure warranted.

**On the C3+C4 reconciliation (Dev deviation):** requiring `base_url` present while ignoring its value is mild coupling to a now-unused manifest field, but it is exactly what AC C3's test encodes ("missing base_url → success False"). Code correctly matches spec. Severity Trivial — **Resolution A (spec/test stands)**, no action. Forward note already captured in Dev's deviation entry.

**Decision:** Proceed to review (TEA verify).

## TEA Assessment (verify)

**Phase:** finish
**Status:** GREEN confirmed

### Simplify Report

**Teammates:** reuse, quality, efficiency
**Files Analyzed:** 4 (portrait_cdn.py + 3 test files; pyproject.toml excluded as config)

| Teammate | Status | Findings |
|----------|--------|----------|
| simplify-reuse | 6 findings | Test-harness duplication: 154-2 re-defines `_png_bytes`/`_make_pack`/`_manifest`/`_FakeResp`/`FakeCDN` and the `cache`/`personas` fixtures already in test_154_1_portrait_cdn.py |
| simplify-quality | clean | — |
| simplify-efficiency | clean | — |

**Applied:** 0
**Flagged for follow-up:** 6 (all reuse — see finding below)
**Reverted:** 0

**Triage rationale (not applied):** Every reuse finding's fix is the same move — extract the shared portrait test harness into a `conftest.py`/shared module so both files import it. That requires editing the **already-merged** 154-1 test file (deleting ~90 lines, adding imports) and unifying two intentionally-different `FakeCDN` variants. Doing it here would (a) restructure a working, merged file inside a focused security PR, (b) obscure the C1–C8 security diff under test-harness churn (SOUL #14), and (c) only half-solve it — the duplication is a pre-existing 154-1 pattern that deserves its own deliberate consolidation. Deferred as a tracked follow-up, not corner-cut.

**Quality Checks:** scoped portrait suite green (76 passed), ruff clean (verified in GREEN; no code changed in verify).
**Overall:** simplify: clean (impl + quality + efficiency); reuse dedup deferred to follow-up.

**Handoff:** To Reviewer (Granny Weatherwax).

### Subagent Results (round 0 — superseded; reject, see round 2 below)

| # | Specialist | Received | Status | Findings | Decision |
|---|-----------|----------|--------|----------|----------|
| 1 | reviewer-preflight | yes | success | GREEN (49 scoped pass, ruff clean, 0 smells, no branch leak) | Confirmed |
| 2 | reviewer-edge-hunter | yes | findings | 9 (`.`→cache-wipe, null byte, themes-not-dict, TypeError-escape, clean() rmtree, URL chars, rmtree ignore_errors, C8 disjunction) | Several CONFIRMED |
| 3 | reviewer-silent-failure-hunter | yes | findings | 1 (rmtree ignore_errors hides cleanup failure) | Confirmed (downgraded) |
| 4 | reviewer-test-analyzer | yes | findings | 4 (C3 tmp vacuous, C8 disjunction, C6 all([]) vacuous, C4 no result assert) | Several CONFIRMED |
| 5 | reviewer-security | yes | findings | 3 (CWE-59 symlink containment, resolve_portrait unguarded, base_url over-reject) | CWE-59 CONFIRMED |
| - | comment_analyzer / type_design / simplifier / rule_checker | — | Skipped | disabled | Disabled via settings |

### Reviewer Assessment (round 0 — superseded by the approval below)

**Verdict: REJECTED (changes requested)** — testable findings → back to TEA (red) for new RED tests + assertion fixes, then Dev (green). Scope confirmed by user: blocking B1–B3 + recommended R1–R3.

The implementation closes the documented C1–C8 string-traversal/SSRF/py-floor vectors correctly, and security confirmed the SSRF and py3.11 fixes are fully closed. But multiple independent hunters found a real, reachable defect **in the exact function being hardened**, plus test assertions that give false confidence. This is a security-hardening story; an incomplete guard with a vacuous safety net cannot ship.

### Blocking

- **B1 — `_is_safe_theme` accepts `"."` → destructive.** (`portrait_cdn.py:~57`, edge-hunter, high) `_is_safe_theme(".")` is `True` (non-empty, no `/`/`\`/`..`). Then `clean(".")` → `shutil.rmtree(cache / ".")` = **`rmtree(cache)`**, wiping the entire portrait cache and returning `{success: True}`. `ensure_portraits(".")` sets `theme_dir == cache` and extracts the tarball into the cache root. Reachable from the CLI (`pf portraits clean .`). This is the same destructive class the story exists to close.
- **B2 — `_is_safe_theme` accepts a null byte → never-raises violation.** (`portrait_cdn.py:~57`, edge-hunter, high) `"disc\x00world"` passes the guard; the resulting `Path` raises `ValueError` on the first syscall (`mkdir`/`open`), which no handler catches — breaking the module's documented "never raises" contract.
- **B3 — C3 `leaks_no_tmp` test is vacuous.** (`test_154_2_...py:~272`, test-analyzer, high) Dev's guard fires *before* download, so the `.tmp` is never created and `glob("*.tmp") == []` is trivially true on every code path — it can never catch a regression. The test named for tmp-leak protection proves nothing about it.

**Root fix for B1+B2 (and edge-hunter's `#`/`?`/whitespace/unicode notes):** replace the character *blocklist* with an *allowlist* — e.g. `re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._-]*", theme)`. First-char-alphanumeric rejects `.`/`..`/leading-dot; the class rejects separators, null bytes, URL-special chars, and whitespace in one rule. All existing theme slugs (`discworld`, `monty-python`, `hogans-heroes`, …) match. TEA should add RED tests for `clean(".")`, `ensure_portraits(".")`, and a null-byte theme.

### Strongly recommended (bundle into the rework — cheap, correct, in-scope for a security PR)

- **R1 — CWE-59 symlink containment** (`portrait_cdn.py:~149,~283`, security, medium; **project rule #5**). `_is_safe_theme` is necessary but not sufficient: a pre-planted symlink at `cache/<valid-name>` lets `extractall(path=theme_dir)` write through it. Add a `Path.resolve()` containment check after building `theme_dir`/`d`: `if not resolved.is_relative_to(cache.resolve()): return {success: False}`. Rule #5 ("missing `Path.resolve()` before security checks") matches — I downgrade severity (needs prior local-write access) but do not dismiss it.
- **R2 — C8 test `or` loophole** (`test_154_2_...py:~362`, edge-hunter + test-analyzer). `assert not theme_dir.exists() or not any(rglob("*.png"))` passes for a buggy impl that leaves an empty skeleton. Tighten to `assert not theme_dir.exists()`.
- **R3 — C6 `all([])` vacuous** (`test_154_1_..._wiring.py:~117`, test-analyzer). Add `assert calls` so the hermetic check proves the resolver actually attempted (and was intercepted from) the CDN.

### Non-blocking (note / Dev's discretion)

- **N1 — `manifest["themes"]` not coerced to dict** (edge-hunter): `manifest.get("themes", {})` returns `None`/list verbatim → `theme not in themes` can raise. Cheap: `manifest.get("themes") or {}`. Within C3's malformed-manifest spirit.
- **N2 — C5 already-installed 3.11.0–3.11.3** (edge-hunter): the floor gates *installs*, not existing venvs, where `filter="data"` `TypeError` still escapes. Spec allowed floor-only, so non-blocking, but adding `except TypeError` next to `except tarfile.TarError` makes the guarantee unconditional for ~free.
- **N3 — `clean()` `rmtree(d)` unguarded** (edge-hunter): pre-existing never-raises gap; since we're already editing `clean`, wrapping in `try/except OSError` is consistent.
- **N4 — `rmtree(theme_dir, ignore_errors=True)` hides cleanup failure** (silent-failure): append the cleanup error to the returned message instead of swallowing.
- **N5 — `base_url` presence guard over-rejects a schema-evolved manifest** (security, low): contradicts AC C3's test ("missing base_url → success False"), which is the governing spec. **Keep as-is** — already logged as a Dev deviation. Flagging only so spec-reconcile is aware.
- **N6 — C4 test lacks `result["success"] is True`** and **resolve_portrait() unguarded** (not in prod path): minor robustness; Dev's discretion.

### Rule Compliance (`gates/lang-review/python.md`)

| Rule | Verdict |
|------|---------|
| #1 silent exceptions | B2 (null-byte escape), N4 (rmtree swallow), N2 (TypeError escape) — **fail** |
| #5 path handling (resolve before security check) | R1 symlink containment missing — **fail** |
| #6 test quality | B3 (vacuous), R2 (disjunction), R3 (all([])) — **fail** |
| #7 resource leaks | N4 (cleanup-fail observability) — partial |
| #11 input validation at boundaries | B1 (`.` accepted), partial allowlist — **fail** |

**Decision:** Return to Dev for B1–B3 + R1–R3; TEA to add RED tests for `.`/null-byte rejection and tighten the vacuous/loophole assertions. The SSRF (C4) and py-floor (C5) fixes are sound and need no rework.

## TEA Assessment (rework — round 1 RED)

**Status:** RED (rework tests failing — ready for Dev)

**New failing tests** (`test_154_2_portrait_cdn_hardening.py`), 5 RED against the current blocklist impl:
- `test_clean_bare_dot_does_not_wipe_cache` (B1) — `clean(".")` currently rmtrees the whole cache.
- `test_ensure_portraits_rejects_bare_dot` (B1) — `.` currently treated as the cache root.
- `test_ensure_portraits_rejects_null_byte_theme` (B2) — null byte currently raises uncaught `ValueError`.
- `test_ensure_portraits_rejects_url_special_theme` — `#`/`?` currently flow into the pack URL.
- `test_ensure_portraits_rejects_symlinked_theme_dir_escaping_cache` (R1, CWE-59) — extraction currently escapes via a pre-planted symlink.

**Test-quality fixes** (now non-vacuous, passing):
- B3 — dropped the vacuous tmp-glob from the missing-`pack_sha256` test; now asserts no pack download.
- R2 — C8 cleanup test asserts `not theme_dir.exists()` unconditionally (was an `or` loophole).
- R3 — wiring hermetic test asserts `calls` non-empty before the `all(...)` check (was `all([])`-vacuous).

**RED verified:** `test_154_2 + wiring` → `5 failed, 18 passed`; `test_154_1` → 32 passed; ruff clean. Scoped runs only.
**Note:** `test_clean_rejects_null_byte_theme` passes already (current `clean` returns "not cached" via `is_dir()` swallowing the null byte) — kept as a guard so the allowlist fix is locked in.

**Fix direction for Dev:** replace the `_is_safe_theme` character blocklist with an allowlist (`re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._-]*", theme)`) — closes B1/B2/url-special at once — and add a `Path.resolve()` containment check in `ensure_portraits` + `clean` for R1. SSRF/py-floor untouched.

**Handoff:** To Dev (Ponder Stibbons) for GREEN (round 1 rework).

## Dev Assessment (rework — round 1 GREEN)

**Status:** GREEN — all rework tests pass.

**Files changed:** `pennyfarthing-dist/src/pf/package/portrait_cdn.py` only.
- **B1/B2 (+ URL-special):** replaced the `_is_safe_theme` character *blocklist* with an *allowlist* — `_SAFE_THEME_RE = re.compile(r"[A-Za-z0-9][A-Za-z0-9._-]*")`, matched via `fullmatch`. One rule rejects bare `.`, `..`, separators, null bytes, whitespace, and `#`/`?` URL-special chars. Added `import re`.
- **R1 (CWE-59):** new `_within_cache(path, cache)` helper (`path.resolve().is_relative_to(cache.resolve())`, returns `False` on resolve error — never raises). Called in `ensure_portraits` (before the sentinel check) and `clean` (before `is_dir`/`rmtree`), so a pre-planted symlink at `cache/<theme>` that escapes the cache is refused.

**Reviewer findings addressed:** B1 ✓ B2 ✓ R1 ✓ (impl). B3/R2/R3 were TEA test fixes (done in rework RED). N1–N6 deferred per user scope decision (blocking + recommended only).

**Verification:** scoped suite → `82 passed` (6 new rework tests now green, incl. the 5 previously-RED), ruff clean on `portrait_cdn.py`. The 5 RED rework tests (`clean(".")`, `ensure_portraits(".")`, null-byte, url-special, symlink-escape) now pass; SSRF/py-floor from round 0 untouched.

**Handoff:** To Architect (Leonard) for spec-check.

## Architect Assessment (spec-check — rework round 1)

**Spec Alignment:** Aligned
**Mismatches Found:** None

Reviewed the rework diff against the Reviewer findings and the C1/C2 ACs:
- **B1/B2 — allowlist `_SAFE_THEME_RE`:** correctly broader than C1/C2's enumerated blocklist; rejects `.`/null/whitespace/`#`/`?` in addition to separators/traversal/empty. Dev logged the broadening as a deviation (minor, no legitimate input lost). Closes the `clean(".")` cache-wipe and the null-byte never-raises break.
- **R1 — `_within_cache` containment:** `resolve().is_relative_to(cache.resolve())` applied in both `ensure_portraits` (before sentinel) and `clean` (before rmtree), returning `False` on resolve error (preserves never-raises). Satisfies project rule #5 / CWE-59. Legitimate non-symlinked dirs always pass.
- C4/C5 (round 0) untouched and still sound.

The two new deviations are well-formed and accurate. No new mismatches.

**Decision:** Proceed to review (TEA verify).

## TEA Assessment (verify — rework round 1)

**Phase:** finish
**Status:** GREEN confirmed

### Simplify Report

**Teammates:** reuse, quality, efficiency · **Files Analyzed:** 4 (rework delta)

| Teammate | Status | Findings |
|----------|--------|----------|
| simplify-reuse | 1 high (applied) | Guard pair `_is_safe_theme`+`_within_cache` duplicated in `ensure_portraits`/`clean` → extracted `_resolve_theme_dir`. (Test-harness dup = already-tracked follow-up, not re-reported.) |
| simplify-quality | 1 high (applied) | Dead `import urllib.error` in test_154_2 → removed. |
| simplify-efficiency | clean | New guards are intentional defense-in-depth, no over-engineering. |

**Applied:** 2 high-confidence fixes (extract `_resolve_theme_dir`; drop dead import).
**Flagged for follow-up:** test-harness dedup (carried over from round-0 verify; tracked).
**Reverted:** 0.

**Verification (regression):** scoped suite → `82 passed`; ruff clean on `portrait_cdn.py` + test_154_2. No behavior change from the simplify edits.
**Overall:** simplify: applied 2 fixes.

**Handoff:** To Reviewer (Granny Weatherwax) for re-review of the rework.

## Reviewer Assessment (re-review — round 1 rework)

**Verdict: APPROVED** — B1/B2/B3/R1/R2/R3 confirmed closed in round 1; the round-2 findings B4/B5/R4 were fixed directly (user instructed "fix this yourself"), verified, and committed (`ec557e450`). All security findings (CWE-22/59/918, py-floor) are now closed.

**Round-2 follow-up resolution (fixed in-place, not re-looped):**
- **B4 (TOCTOU CWE-59) `[EDGE]` `[SEC]`:** flagged by both edge-hunter and security (security confirmed empirically that a symlink planted in the 10-30s download window let `extractall` escape the cache). Fixed: post-`mkdir` containment/`is_symlink` re-check in `ensure_portraits`; `clean` refuses symlinked dirs and wraps `rmtree` in `try/except OSError`. New test `test_ensure_portraits_rejects_symlink_planted_during_download` (plants the symlink mid-download via a `_verify_sha256` hook) — passes only with the post-mkdir guard.
- **B5 (vacuous test) `[TEST]`:** test-analyzer found `test_clean_rejects_null_byte_theme` passed via the "not cached" branch without proving the guard. Fixed: now asserts `"Invalid theme name" in result["error"]`.
- **R4 (CWE-22 slug) `[SEC]`:** security flagged `resolve_portrait` interpolating an untrusted manifest slug. Fixed: validates the slug with `_is_safe_theme` + `_within_cache`-checks the candidate. New test `test_resolve_portrait_rejects_traversal_slug`.
- **Silent-failure `[SILENT]`:** no new swallowed errors introduced by the rework; the pre-existing `clean()` `rmtree` never-raises gap (N3) is now closed by the B4 `try/except OSError`. The pre-existing resolver `except Exception: pass` (one level out of this diff) remains an out-of-scope note.
- **Preflight `[EDGE]`-adjacent:** GREEN, 82→84 pass, ruff clean, no branch leak.

**Final verification:** scoped suite `84 passed` (incl. 2 new round-2 tests); ruff clean on `portrait_cdn.py` + test_154_2. No regression to the legitimate download/extract/resolve paths.

---
_Original round-2 finding detail retained below for the audit trail._

**Verdict (pre-fix): would have been REJECT for B4/B5; fixed directly per user request.**

## Subagent Results

**Cycle: 1** · **All received: Yes** (5 enabled subagents)

| # | Specialist | Received | Status | Findings | Decision |
|---|-----------|----------|--------|----------|----------|
| 1 | reviewer-preflight | Yes | success | GREEN — 82 pass, ruff clean, 0 smells, no branch leak | Confirmed |
| 2 | reviewer-edge-hunter | Yes | findings | B1/B2/R1 CLOSED (allowlist ASCII-literal, no unicode/newline bypass; refactor behavior-preserving). New: TOCTOU symlink-swap (med); clean() rmtree-on-symlink (med); TarError-rmtree symlink (low) | B4 fixed; rest noted |
| 3 | reviewer-silent-failure-hunter | Yes | findings | No new swallowed errors. Pre-existing: resolver bare-except (med); clean() rmtree unguarded (N3) | Pre-existing; N3 now closed by B4 fix |
| 4 | reviewer-test-analyzer | Yes | findings | B3/R2/R3 genuinely fixed; new tests sound EXCEPT `test_clean_rejects_null_byte_theme` vacuous (high); missing_pack_sha256 manifest-fetch assertion gap (med) | B5 fixed |
| 5 | reviewer-security | Yes | findings | B1/B2 (CWE-22), R1 pre-planted symlink (CWE-59), C4 (SSRF), C5 (floor) FULLY CLOSED. New: TOCTOU (CWE-59, med, empirically confirmed); resolve_portrait slug injection (CWE-22, med, latent) | B4 + R4 fixed |

_Disabled via `workflow.reviewer_subagents` (not blocking): comment_analyzer, type_design, simplifier, rule_checker._

### Round-1 findings: all resolved
B1 ✓ B2 ✓ B3 ✓ R1 ✓ (pre-planted) R2 ✓ R3 ✓. C4/C5 untouched and still closed.

### NEW findings (round 2)

- **B4 — TOCTOU symlink-swap escapes the cache (CWE-59, medium; edge + security, security confirmed empirically).** `_within_cache(theme_dir, cache)` runs at `_resolve_theme_dir` time, *before* `theme_dir` exists — so `resolve()` has no symlink to follow and containment passes. `theme_dir.mkdir()` + `tar.extractall()` happen 10–30s later (after manifest fetch + pack download). A writer to the cache dir can plant `cache/<valid-theme> → /outside` in that window; `mkdir(exist_ok=True)` accepts the symlink and `extractall` writes through it. This is the *plant-during-download* half of R1 that the round-1 containment check did not cover. **Fix (cheap):** re-check `_within_cache(theme_dir, cache)` (or `theme_dir.is_symlink()`) immediately after `mkdir`, before extract; same guard before `clean`'s `rmtree`. TEA adds a plant-after-mkdir test.
- **B5 — `test_clean_rejects_null_byte_theme` is vacuous (high, test).** `success is False` is satisfied by the pre-existing "not cached" branch (`Path.is_dir()` returns False on a null-byte path) even without the guard. **Fix:** assert `"Invalid theme name" in result["error"]` to prove the guard fired.
- **R4 — `resolve_portrait()` slug injection (CWE-22, medium, latent).** `slug` from the local manifest (CDN persona data) is interpolated into `cache/theme/size/{slug}.png` with no validation; a poisoned manifest slug `../../...` escapes. No live caller today (production uses `portrait_resolver.resolve_portrait_path`), but it's public API. **Fix:** allowlist/containment-guard the slug. (Recommended bundle.)

### Non-blocking (note)
- missing_pack_sha256 test: add a "manifest WAS fetched" assertion (med).
- clean() `rmtree` unguarded never-raises gap (N3) + resolver bare-except — pre-existing, previously deferred.

**Recommendation:** REJECT to close **B4** (confirmed cache-escape, completes R1) + **B5** (vacuous test), bundling **R4**. All fixes are small and localized. Threat model for B4 is a writer to the user's own XDG cache during a download window — real but marginal on single-user setups, hence surfacing the scope call.

## Delivery Findings

Agents record upstream observations discovered during their phase.
Each finding is one list item. Use "No upstream findings" if none.

**Types:** Gap, Conflict, Question, Improvement
**Urgency:** blocking, non-blocking

<!-- Agents: append findings below this line. Do not edit other agents' entries. -->

### Reviewer (review)
- **Gap** (blocking): `_is_safe_theme`'s character-blocklist still admits `"."` (→ `clean(".")` wipes the whole cache; `ensure_portraits(".")` extracts into the cache root) and null bytes (→ uncaught `ValueError`, breaks never-raises). Affects `pennyfarthing-dist/src/pf/package/portrait_cdn.py` (switch to an allowlist regex). *Found by Reviewer during review.*
- **Gap** (blocking): C3 `test_..._missing_pack_sha256_..._leaks_no_tmp` tmp-glob assertions are vacuous — the pre-download guard means no `.tmp` is ever created, so they cannot catch a regression. Affects `test_154_2_portrait_cdn_hardening.py`. *Found by Reviewer during review.*
- **Improvement** (non-blocking): CWE-59 symlink containment (project rule #5) — add a `Path.resolve()` containment check in `ensure_portraits`/`clean` beyond the string guard. Affects `portrait_cdn.py`. *Found by Reviewer during review.*

### TEA (test verification)
- **Improvement** (non-blocking): The portrait_cdn test harness (`_png_bytes`, `_make_pack`, `_manifest`, `_FakeResp`, `FakeCDN`, and the `cache`/`personas` fixtures) is duplicated between `test_154_1_portrait_cdn.py` and the new `test_154_2_portrait_cdn_hardening.py`. Affects both test files (extract the shared harness into `pennyfarthing-dist/src/pf/tests/conftest.py` or a shared `_portrait_cdn_helpers.py`, unifying the two `FakeCDN` variants — 154-1's is the richer superset). Deferred from 154-2 verify to keep the security diff focused. *Found by TEA (simplify-reuse) during test verification.*

### Architect (spec-check)
- No upstream findings during spec-check.

### Dev (implementation)
- No upstream findings during implementation.

### TEA (test design)
- **Improvement** (non-blocking): The tmp-download path name `f".{theme}.tar.gz.tmp"` is incidentally traversal-resistant (the leading `.` turns `..` into `...`), so a `..` theme currently fails late with an OSError rather than a validated rejection. Affects `pennyfarthing-dist/src/pf/package/portrait_cdn.py:150` (validate `theme` once, up front; do not rely on the prefix accident). *Found by TEA during test design.*
- **Question** (non-blocking): C5 has two valid fixes (bump `requires-python` floor vs. catch `TypeError`); I encoded the floor-bump as the contract because catching `TypeError` preserves the silent-skip failure mode. If Dev prefers catching `TypeError`, the floor test must be revisited and the choice logged. Affects `pennyfarthing-dist/pyproject.toml` + `portrait_cdn.py:167`. *Found by TEA during test design.*

## Impact Summary

**Upstream Effects:** 2 findings (1 Gap, 0 Conflict, 0 Question, 1 Improvement)
**Blocking:** 1 BLOCKING items — see below

**BLOCKING:**
- **Gap:** `_is_safe_theme`'s character-blocklist still admits `"."` (→ `clean(".")` wipes the whole cache; `ensure_portraits(".")` extracts into the cache root) and null bytes (→ uncaught `ValueError`, breaks never-raises). Affects `pennyfarthing-dist/src/pf/package/portrait_cdn.py`.

- **Improvement:** The tmp-download path name `f".{theme}.tar.gz.tmp"` is incidentally traversal-resistant (the leading `.` turns `..` into `...`), so a `..` theme currently fails late with an OSError rather than a validated rejection. Affects `pennyfarthing-dist/src/pf/package/portrait_cdn.py:150`.

### Downstream Effects

- **`pennyfarthing-dist/src/pf/package`** — 2 findings

### Deviation Justifications

5 deviations

- **C3+C4 reconciliation: `base_url` is required-present but its value is ignored**
  - Rationale: the two ACs together mean "the manifest must look well-formed, but we never trust its URL." Presence is a cheap schema sanity check; the value is attacker-controllable, so it cannot influence the fetch. The C4 test confirms a poisoned `base_url` still downloads from `CDN_BASE_URL`.
  - Severity: minor
  - Forward impact: if a future manifest schema drops `base_url`, this presence guard must be revisited; portrait_cdn no longer depends on `base_url` for any behavior.
- **C2 tested as "reject before fetch", stronger than "return success:False"**
  - Rationale: encodes the "up front" requirement so the test cannot be satisfied by an accidental late failure; forces real input validation.
  - Severity: minor
  - Forward impact: Dev must validate `theme` before `fetch_manifest`, not just before path construction.
- **C5 tested as a packaging floor (`requires-python >= 3.11.4`), not runtime TypeError-catching**
  - Rationale: catching `TypeError` keeps the silent-skip failure mode alive on 3.11.0–3.11.3 (extraction never runs, traversal guarantee false); bumping the floor removes the broken range honestly. One contract, not two.
  - Severity: minor
  - Forward impact: if Dev elects the catch-`TypeError` route instead, this test must be revised and the decision logged as a Dev deviation.
- **Theme validation widened from C1/C2's blocklist to an allowlist**
  - Rationale: Reviewer findings B1/B2 — the enumerated blocklist let `.` (→ `clean(".")` wiped the whole cache) and null bytes (→ uncaught `ValueError`) through. An allowlist closes the class. All real theme slugs match.
  - Severity: minor (stricter than spec; no legitimate input rejected)
  - Forward impact: any future theme name with uppercase-only-exotic chars must conform to the slug allowlist; none exist today.
- **Added `Path.resolve()` containment (`_within_cache`) beyond string validation**
  - Rationale: string validation cannot stop a pre-planted symlink at `cache/<valid-name>` from redirecting extraction/removal outside the cache (CWE-59, rule #5).
  - Severity: minor
  - Forward impact: none — legitimate (non-symlinked) cache dirs always satisfy containment.

## Design Deviations

Agents log spec deviations as they happen — not after the fact.
Each entry: what was changed, what the spec said, and why.

<!-- Agents: append deviations below this line. Do not edit other agents' entries. -->

### Dev (implementation)
- **C3+C4 reconciliation: `base_url` is required-present but its value is ignored**
  - Spec source: context-story-154-2.md, AC C3 + AC C4
  - Spec text: C3 — "malformed manifest (missing `base_url` / `pack_sha256`) returns `{success: False}`"; C4 — "pack URL is built from the hardcoded `CDN_BASE_URL` ... a poisoned `base_url` cannot redirect the fetch"
  - Implementation: `ensure_portraits` treats a missing `base_url` as a malformed manifest (`{success: False}`) per C3, but builds the actual pack URL from `CDN_BASE_URL` and never reads `base_url`'s value per C4. So the field is validated for presence yet ignored for routing.
  - Rationale: the two ACs together mean "the manifest must look well-formed, but we never trust its URL." Presence is a cheap schema sanity check; the value is attacker-controllable, so it cannot influence the fetch. The C4 test confirms a poisoned `base_url` still downloads from `CDN_BASE_URL`.
  - Severity: minor
  - Forward impact: if a future manifest schema drops `base_url`, this presence guard must be revisited; portrait_cdn no longer depends on `base_url` for any behavior.

### TEA (test design)
- **C2 tested as "reject before fetch", stronger than "return success:False"**
  - Spec source: context-story-154-2.md, AC C2
  - Spec text: "ensure_portraits rejects `/`, `\`, `..`, empty theme names before any path is built; no file/dir is created outside the cache"
  - Implementation: tests assert `cdn.urlopen_calls == []` (no network) in addition to `success is False`, because the current code happens to fail a `..` theme late with an incidental OSError — a success:False-only assertion would pass against the vulnerable code.
  - Rationale: encodes the "up front" requirement so the test cannot be satisfied by an accidental late failure; forces real input validation.
  - Severity: minor
  - Forward impact: Dev must validate `theme` before `fetch_manifest`, not just before path construction.
- **C5 tested as a packaging floor (`requires-python >= 3.11.4`), not runtime TypeError-catching**
  - Spec source: context-story-154-2.md, AC C5
  - Spec text: "floor is 3.11.4 or `TypeError` is caught — no silent skip"
  - Implementation: the test asserts only the `requires-python` floor; it does not also accept a catch-`TypeError` implementation.
  - Rationale: catching `TypeError` keeps the silent-skip failure mode alive on 3.11.0–3.11.3 (extraction never runs, traversal guarantee false); bumping the floor removes the broken range honestly. One contract, not two.
  - Severity: minor
  - Forward impact: if Dev elects the catch-`TypeError` route instead, this test must be revised and the decision logged as a Dev deviation.

### Dev (implementation — rework round 1)
- **Theme validation widened from C1/C2's blocklist to an allowlist**
  - Spec source: context-story-154-2.md, AC C1 + AC C2
  - Spec text: "reject `/`, `\`, `..`, empty theme names"
  - Implementation: `_is_safe_theme` now requires `fullmatch([A-Za-z0-9][A-Za-z0-9._-]*)`, which rejects the enumerated set AND additionally bare `.`, null bytes, whitespace, and `#`/`?`.
  - Rationale: Reviewer findings B1/B2 — the enumerated blocklist let `.` (→ `clean(".")` wiped the whole cache) and null bytes (→ uncaught `ValueError`) through. An allowlist closes the class. All real theme slugs match.
  - Severity: minor (stricter than spec; no legitimate input rejected)
  - Forward impact: any future theme name with uppercase-only-exotic chars must conform to the slug allowlist; none exist today.
- **Added `Path.resolve()` containment (`_within_cache`) beyond string validation**
  - Spec source: context-story-154-2.md, AC C1/C2 (CWE-22); Reviewer R1 (CWE-59); project rule #5
  - Spec text: "no file/dir is created outside the cache"
  - Implementation: `ensure_portraits`/`clean` now also require `theme_dir.resolve()` to be inside `cache.resolve()`, refusing symlink-redirected paths.
  - Rationale: string validation cannot stop a pre-planted symlink at `cache/<valid-name>` from redirecting extraction/removal outside the cache (CWE-59, rule #5).
  - Severity: minor
  - Forward impact: none — legitimate (non-symlinked) cache dirs always satisfy containment.

### Reviewer (deviation audit)
- **TEA — C2 "reject before fetch":** ACCEPTED. Correct call; the stronger assertion is what exposed that the original guard still admitted `.` (finding B1).
- **TEA — C5 floor-bump over catch-TypeError:** ACCEPTED. Sound — catching `TypeError` alone preserves silent-skip. Note N2: adding `except TypeError` as well makes the guarantee unconditional for already-installed 3.11.0–3.11.3 venvs (recommended, non-blocking).
- **Dev — C3+C4 base_url required-present but value ignored:** ACCEPTED with note. Matches AC C3's encoded contract (governing spec). Security flagged it as a low over-rejection risk (N5) — kept as-is per spec authority; spec-reconcile should record the trade-off.
- **Dev — theme validation widened from blocklist to allowlist (round 1):** ACCEPTED. Stricter than C1/C2's enumerated list, rejects no legitimate slug; required to close B1/B2. Confirmed by round-2 edge/security as complete (ASCII-literal class, no unicode/newline bypass).
- **Dev — `Path.resolve()` containment (`_within_cache`, round 1):** ACCEPTED. Satisfies rule #5 / CWE-59. Round-2 review found the pre-`mkdir` placement left a TOCTOU window (B4); that gap is now closed by the post-`mkdir` re-check (commit `ec557e450`).
### Architect (reconcile)

Reviewed all in-flight deviation entries (TEA test-design ×2, Dev implementation ×3) against the story/epic context and the C1–C8 + B/R findings. All five are accurate, self-contained (spec text quoted inline), and correctly classified; the Reviewer audit stamped each ACCEPTED.

**Manifest completeness:** The round-2 security fixes (B4 post-`mkdir` TOCTOU re-check, `clean` symlink refusal + `rmtree` try/except, R4 slug allowlist/containment) are *spec-conforming hardening* that implements the CWE-22/59 acceptance criteria — they are not deviations from spec and require no new entry.

**AC deferrals:** None. All ACs C1–C8 plus Reviewer B1–B5/R1–R4 are DONE (no DESCOPED/deferred ACs). The non-blocking N-items (N2 catch-`TypeError` belt-and-suspenders; pre-existing resolver `except Exception: pass`) are documented hardening debt, not unmet ACs.

- No additional deviations found.