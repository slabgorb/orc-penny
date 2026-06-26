---
story_id: "160-12"
jira_key: ""
epic: "160"
workflow: "tdd"
---
# Story 160-12: ws_push read hygiene sweep: archive loop + benchmark/persona fetchers silently swallow read/parse errors and lack encoding=

## Story Details
- **ID:** 160-12
- **Jira Key:** (none — kanban)
- **Workflow:** tdd
- **Stack Parent:** none
- **Repository:** pennyfarthing (targets `develop`)

## Workflow Tracking
**Workflow:** tdd
**Phase:** finish
**Phase Started:** 2026-06-25T11:11:58Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-06-25T10:39:05Z | 2026-06-25T10:41:05Z | 2m |
| red | 2026-06-25T10:41:05Z | 2026-06-25T10:54:01Z | 12m 56s |
| green | 2026-06-25T10:54:01Z | 2026-06-25T11:04:07Z | 10m 6s |
| review | 2026-06-25T11:04:07Z | 2026-06-25T11:11:58Z | 7m 51s |
| finish | 2026-06-25T11:11:58Z | - | - |

## Story Context

### Problem Statement
The pennyfarthing framework has ~6 `read_text()` call sites that silently swallow read/parse errors and do not explicitly specify `encoding="utf-8"`. These sites are found in:
- Archive loop (ws_push module)
- Benchmark fetchers
- Persona fetchers

### Technical Approach
This story hardens read hygiene across these sites in accordance with the project's **fail-loud principle** (issue #50) and **Return Results, Don't Throw** convention:

1. **Identify all ~6 `read_text` sites** — TEA will narrow down exact locations via failing tests
2. **Add explicit `encoding="utf-8"`** — ensure consistent UTF-8 handling across all sites
3. **Surface read/parse errors loudly** — replace silent error swallowing with explicit error handling/propagation
4. **Follow return-result pattern** — errors should be visible to callers, not hidden in silent catches

### Acceptance Criteria
- [ ] All ~6 `read_text` call sites in archive loop, benchmark fetchers, and persona fetchers now use explicit `encoding="utf-8"`
- [ ] All previously silent errors are now surfaced (logged/raised/returned) per fail-loud principle
- [ ] Read/parse failures propagate visibility to callers instead of being silently swallowed
- [ ] Consistent with project conventions: Return Results pattern and fail-loud design
- [ ] Test coverage validates that errors surface (TEA will design failing tests in red phase)

### Origin
Surfaced from 160-4 Dev/Reviewer findings as a follow-up read-hygiene hardening sweep.

## Delivery Findings

### TEA (test design)

- **Improvement** (non-blocking): `fetch_benchmark_history` reads `pipeline.yaml` twice — L508 then a redundant re-read at L526 guarded by `if not pipeline_data:`. On an L508 parse failure (`except Exception: pass`), `pipeline_data` is left UNBOUND, so the L525 `if not pipeline_data:` raises `NameError` which is in turn swallowed by the L524 `except Exception: pass`. Affects `pennyfarthing-dist/src/pf/frame/ws_push.py` (consolidate to a single read + initialize `pipeline_data = None` before the block; the read-hygiene fix is the natural place to do it). *Found by TEA during test design.*
- **Improvement** (non-blocking): The module's main sprint read at L171 (`yaml.safe_load(sprint_path.read_text())`, `except Exception: return {...}`) is the same anti-pattern as the named buckets and is swept by the AC1 encoding scan, but has no dedicated fail-loud behavioral test (a broken main sprint silently renders an empty panel). Affects `ws_push.py:fetch_sprint` (Dev may add a `warnings.warn` there for symmetry; out of strict scope but cheap). *Found by TEA during test design.*

### Dev (implementation)

- **Gap** (non-blocking, RESOLVED in this commit): TEA's `test_ac2_malformed_archive_index_warns_and_survives` had a fixture-setup bug — it wrote the archive index via `write_text()` without first creating the `sprint/archive/` directory, raising `FileNotFoundError` at setup. It therefore failed RED for the wrong reason and never actually exercised the L275 warning. Fixed by adding `archive.mkdir(parents=True, exist_ok=True)` (fixture only — the `pytest.warns` assertion is unchanged). Affects `pennyfarthing-dist/src/pf/tests/test_160_12_ws_push_read_hygiene.py`. *Found by Dev during implementation.*
- **Improvement** (non-blocking, RESOLVED): The redundant `pipeline.yaml` double-read + latent `NameError`-under-`except:pass` (TEA's finding) is fixed — `fetch_benchmark_history` now reads `pipeline.yaml` once into `pipeline_data` (initialized to `None`), and the date/token/duration blocks consume that single value. Affects `ws_push.py:fetch_benchmark_history`. *Found by Dev during implementation.*
- No other upstream findings during implementation.

### Reviewer (code review)

- **Improvement** (non-blocking): The main sprint read at L171 has no dedicated fail-loud behavioral test (only the AC1 encoding scan covers it); its warning says "Failed to read sprint file" even for a parse failure. Affects `pennyfarthing-dist/src/pf/frame/ws_push.py:fetch_sprint` (a future test + read-vs-parse wording split). *Found by Reviewer during code review.*
- **Improvement** (non-blocking): Several PRE-EXISTING silent swallows remain elsewhere in `ws_push.py` and are out of this story's scope — `fetch_git` (subprocess parse, `except Exception: pass`), `fetch_context` (degraded shape on failure), the outer `fetch_persona` catch-all, and the in-sprint epic-shard `_load_file` path. Affects `ws_push.py` (a follow-up read/error-hygiene sweep could extend the fail-loud treatment to these). *Found by Reviewer during code review.*
- **Improvement** (non-blocking): `_read_yaml_file`'s parse-error warning interpolates `str(exc)`, which for a YAML error quotes a snippet of file content. Zero blast radius on this single-user local tool reading self-authored files, but worth noting if these warnings ever surface to a shared/remote sink. Affects `ws_push.py:_read_yaml_file`. *Found by Reviewer (corroborated by reviewer-security, low confidence).*

## Design Deviations

### TEA (test design)

- **AC1 encoding scan sweeps ALL read_text sites, not just the named 6**
  - Spec source: context-story-160-12.md, Title ("archive loop + benchmark/persona fetchers ... (6 read_text sites)")
  - Spec text: "archive loop + benchmark/persona fetchers silently swallow read/parse errors and lack encoding= (6 read_text sites)"
  - Implementation: `test_ac1_all_read_text_calls_specify_utf8_encoding` is an AST scan that enforces `encoding="utf-8"` on EVERY `read_text()` in ws_push.py — 8 unfixed sites (L171, 275, 291, 408, 483, 508, 526, 551), one more than the literal "6" because it also includes the main sprint read at L171.
  - Rationale: The story is a "read hygiene **sweep**"; a fix-agnostic source-scan that catches every site (incl. L171 and the redundant L526 re-read) is more durable than enumerating exactly 6, and adding encoding to L171 is pure win. SOUL #1 (fix the system).
  - Severity: minor
  - Forward impact: Dev must add `encoding="utf-8"` to all 8 sites, not just the 3 named buckets, for AC1 to pass.

- **3 acceptance tests are intentionally GREEN on HEAD (regression guards)**
  - Spec source: SOUL.md #6 (Gates Over Goodwill), AC5 (no over-warning)
  - Spec text: "A genuinely absent file stays SILENT, and an all-healthy input set emits no read-failure warning."
  - Implementation: `test_ac2_missing_archived_shard_stays_silent`, `test_ac3_healthy_agent_file_emits_no_read_warning`, `test_ac4_healthy_run_emits_no_read_warning` pass today and must STAY green post-fix. They guard against the fix over-warning on the common missing/healthy case.
  - Rationale: Per `ac-as-green-regression-guard` — a preservation requirement is correctly green-on-arrival; forcing a spurious RED would be dishonest. Documented so Reviewer/gate know they are not vacuous.
  - Severity: minor
  - Forward impact: Dev must not introduce warnings for absent/healthy files; these 3 stay green.

- **Fail-loud realized as `warnings.warn` + graceful degradation, not raise**
  - Spec source: context-story-160-12.md (Technical Approach: "Surface read/parse errors loudly per #50"); SOUL.md #10 (Return Results, Don't Throw)
  - Spec text: "Surface read/parse errors loudly ... instead of silently swallowing them."
  - Implementation: Tests assert `pytest.warns(UserWarning)` + a graceful return (`result["type"]=="init"` / `== {}`), NOT a raised exception.
  - Rationale: These fetchers run inside the long-lived Frame poll loop (`send_initial_data`/`poll_and_broadcast`) whose outer `except Exception: pass` would swallow a raise and blank the panel with zero diagnostics — strictly worse than today. Mirrors the 160-4 `_load_file` reference contract exactly.
  - Severity: minor
  - Forward impact: Dev surfaces via `warnings.warn` naming the offending file; must not propagate the exception.

### Dev (implementation)

- **Shared `_read_text_file`/`_read_yaml_file` helpers instead of inlining the taxonomy at all 8 sites**
  - Spec source: TEA Assessment, "GREEN contract for Dev" step 2; SOUL.md #2 (One Truth, One Place)
  - Spec text: "route present-but-broken inputs into a `warnings.warn(...)` that names the offending file, then continue/skip/return {}"
  - Implementation: Added two module-level helpers carrying the encoding + FileNotFoundError-silent + (OSError, UnicodeDecodeError)-warn + yaml-parse-warn taxonomy once; all 8 sites call them (except L171, which keeps its bespoke early-return shape with an inline warn).
  - Rationale: Inlining the 4-branch taxonomy 7× is exactly the duplication that produced this bug class; one helper is the durable fix (mirrors the 160-4 `_load_file` precedent). Slightly beyond "minimal" but reduces future drift.
  - Severity: minor
  - Forward impact: Future read sites in ws_push.py should reuse these helpers.

- **`or {}` empty-file coercion replaced with `isinstance(..., dict)` guard at the archive sites**
  - Spec source: existing ws_push.py archive loop (L275/L291 used `yaml.safe_load(...) or {}`)
  - Spec text: "archive_data = yaml.safe_load(archive_path.read_text()) or {}"
  - Implementation: Now `archive_data = _read_yaml_file(...)` + `if not isinstance(archive_data, dict): continue`. A present-but-empty (valid-YAML→None) archived shard is now SKIPPED instead of rendered as a blank epic entry (id="", title="").
  - Rationale: A blank epic card from an empty shard is junk; skipping is cleaner and consistent with the non-dict guard. No test depended on the old blank-entry behavior.
  - Severity: minor
  - Forward impact: none — empty/missing archive shards simply don't render (they didn't carry useful data before either).

- **L171 main sprint read: added a warning while preserving the early-return shape**
  - Spec source: TEA Delivery Finding (L171 "out of strict scope but cheap"); AC1 encoding scan
  - Spec text: "Dev may add a `warnings.warn` there for symmetry"
  - Implementation: L171 now reads with `encoding="utf-8"` AND warns on failure, but still returns the original `{"sprint": {}, "epics": []}` minimal payload (NOT routed through the helper, to preserve the distinct early-return contract).
  - Rationale: Satisfies AC1 + adds fail-loud symmetry without changing the broken-main-sprint return shape that downstream SprintPanel handling may rely on.
  - Severity: minor
  - Forward impact: none.

### Reviewer (audit)

- **TEA: AC1 encoding scan sweeps ALL read_text sites (8, incl. L171), not just the named 6** → ✓ ACCEPTED by Reviewer: a fix-agnostic AST scan is the right enforcement for a "sweep"; including L171 + the redundant L526 is pure win (SOUL #1). Verified the scan flags exactly the 8 encoding-less sites and passes post-fix.
- **TEA: 3 acceptance tests intentionally GREEN on HEAD (regression guards)** → ✓ ACCEPTED by Reviewer: empirically confirmed — on `origin/develop` source these 3 pass while the other 10 fail (10 failed / 3 passed), so they are genuine no-over-warning guards, not vacuous.
- **TEA: Fail-loud realized as `warnings.warn` + graceful degradation, not raise** → ✓ ACCEPTED by Reviewer: correct for poll-loop display fetchers whose outer `except Exception: pass` would swallow a raise and blank the panel; consistent with the 160-4 `_load_file` precedent and the `pytest.warns` contract.
- **Dev: Shared `_read_text_file`/`_read_yaml_file` helpers instead of inlining at 8 sites** → ✓ ACCEPTED by Reviewer: DRY consolidation of the taxonomy (SOUL #2); the helpers correctly catch `FileNotFoundError` (silent), `(OSError, UnicodeDecodeError)` (warn) — the explicit `UnicodeDecodeError` is the 160-4 round-1 lesson applied.
- **Dev: `or {}` empty-file coercion replaced with `isinstance(..., dict)` guard at archive sites** → ✓ ACCEPTED by Reviewer: a present-but-empty shard now skips rather than rendering a blank `id=""`/`title=""` epic card; observable output is strictly cleaner, no regression (the file-existence gates are unchanged).
- **Dev: L171 main sprint read — added a warning while preserving the early-return shape** → ✓ ACCEPTED by Reviewer: satisfies AC1 + adds symmetry without changing the `{"sprint": {}, "epics": []}` minimal-payload contract. Minor wording note (a parse failure warns "Failed to read") — non-blocking, captured below.

## Sm Assessment

Story 160-12 is a 2-point hygiene hardening sweep in the core framework. It follows naturally from 160-4 Dev/Reviewer findings and aligns with the fail-loud and return-result conventions. The scope is well-defined (~6 sites), the acceptance criteria are clear (explicit encoding + error surfacing), and the tdd workflow is appropriate for framework hardening.

Technical approach is sound: TEA identifies exact sites and writes failing tests; Dev implements the fixes; Reviewer validates error handling and encoding consistency.

Ready for handoff to test engineer (Thufir Hawat) for red phase.

## TEA Assessment

**Tests Required:** Yes
**Reason:** p1 read-hygiene hardening with a prior rejection history (160-4 round 1 was rejected for a missed `UnicodeDecodeError`); behavioral + structural coverage required.

**Test Files:**
- `pennyfarthing-dist/src/pf/tests/test_160_12_ws_push_read_hygiene.py` — 13 tests covering AC1–AC5 across the archive loop, persona fetcher, and benchmark fetcher in `pf/frame/ws_push.py`.

**Tests Written:** 13 tests (10 RED + 3 intentional GREEN regression guards) covering 5 ACs
**Status:** RED confirmed (10 failed / 3 passed / **0 errored** via scoped `uv run pytest src/pf/tests/test_160_12_ws_push_read_hygiene.py -q`)

### Acceptance Criteria (TEA-defined)

- **AC1 — encoding:** every `read_text()` in ws_push.py specifies `encoding="utf-8"`. (AST source-scan; flags 8 sites: L171/275/291/408/483/508/526/551.)
- **AC2 — archive loop fail-loud:** a present-but-malformed/undecodable `sprint-*-completed.yaml` (L275) or archived `epic-<ref>.yaml` (L291) emits a `warnings.warn` naming the file and degrades gracefully (siblings survive, payload returns).
- **AC3 — persona fetcher fail-loud:** a present-but-undecodable/unreadable active-agent file (L408) warns and degrades to `{}`.
- **AC4 — benchmark fetcher fail-loud:** a present-but-malformed/undecodable `score.yaml` (L483), `pipeline.yaml` (L508), or `narrative.md` (L551) warns and the runs payload still returns.
- **AC5 — no over-warning:** absent files and all-healthy inputs emit no read-failure warning.

### RED Verification (per-test, right-reason)

| Test | Site | Taxonomy | Reason RED |
|------|------|----------|------------|
| `test_ac1_all_read_text_calls_specify_utf8_encoding` | all | encoding | AST: 8 sites missing `encoding=` |
| `test_ac2_malformed_archive_index_warns_and_survives` | L275 | yaml parse | DID NOT WARN |
| `test_ac2_malformed_archived_epic_shard_warns` | L291 | yaml parse | DID NOT WARN |
| `test_ac2_undecodable_archived_epic_shard_warns` | L291 | **UnicodeDecodeError** | DID NOT WARN |
| `test_ac3_undecodable_agent_file_warns_and_degrades` | L408 | **UnicodeDecodeError** | DID NOT WARN |
| `test_ac3_unreadable_agent_file_warns` | L408 | PermissionError | DID NOT WARN |
| `test_ac4_malformed_score_yaml_warns_and_survives` | L483 | yaml parse | DID NOT WARN |
| `test_ac4_undecodable_score_yaml_warns` | L483 | **UnicodeDecodeError** | DID NOT WARN |
| `test_ac4_malformed_pipeline_yaml_warns` | L508 | yaml parse | DID NOT WARN |
| `test_ac4_undecodable_narrative_md_warns` | L551 | **UnicodeDecodeError** | DID NOT WARN |
| `test_ac2_missing_archived_shard_stays_silent` | L291 | missing | GREEN guard (intentional) |
| `test_ac3_healthy_agent_file_emits_no_read_warning` | L408 | healthy | GREEN guard (intentional) |
| `test_ac4_healthy_run_emits_no_read_warning` | L483/508/551 | healthy | GREEN guard (intentional) |

### Rule Coverage (lang-review/python.md)

| Rule | Test(s) | Status |
|------|---------|--------|
| #1 Silent exception swallowing | all AC2/AC3/AC4 fail-loud tests | failing (RED) |
| #5 Path handling — missing `encoding=` (CWE-838) | `test_ac1_all_read_text_calls_specify_utf8_encoding` | failing (RED) |
| #6 Test quality | self-check below | pass |

**Rules checked:** 3 of 10 applicable python lang-review rules have test coverage (the 3 relevant to read hygiene).
**Self-check (vacuous assertions):** 0 found — every test asserts `pytest.warns`/AST offenders + a graceful-return/identity assertion; no `let _ =`, no `assert True`, no always-None checks.

### GREEN contract for Dev (Reverend Mother Gaius Helen Mohiam)

Mirror the 160-4 `_load_file` reference (ws_push.py L187–218) at the remaining sites:
1. Add `encoding="utf-8"` to all 8 `read_text()` calls (AC1).
2. At each fetcher's read site, route present-but-broken inputs into a `warnings.warn(...)` that **names the offending file**, then `continue`/skip/`return {}` so the fetcher degrades gracefully — do NOT raise.
3. Keep `FileNotFoundError`/absent-file paths SILENT (the `is_file()`/`exists()` gates already own them); only PRESENT-but-broken surfaces.
4. Catch the full taxonomy: yaml parse errors AND `UnicodeDecodeError` (a `ValueError`, NOT an `OSError`) AND `PermissionError`/`OSError`. A narrowed `except OSError` will let the decode case crash — the 160-4 round-1 rejection.
5. See Delivery Findings for the redundant L508/L526 `pipeline.yaml` double-read (consolidate while here).

**Handoff:** To Dev for GREEN implementation.

## Dev Assessment

**Implementation Complete:** Yes

**Files Changed:**
- `pennyfarthing-dist/src/pf/frame/ws_push.py` — added two module-level read helpers (`_read_text_file`, `_read_yaml_file`) carrying the explicit-utf-8 + fail-loud-on-present-but-broken + silent-on-missing taxonomy; rewired all 8 unfixed `read_text()` sites (archive index/shard, persona agent file, benchmark score/pipeline/narrative, main sprint read) through them; consolidated the redundant `pipeline.yaml` double-read into a single read with `pipeline_data` initialized to `None`; removed the now-dead inline `import yaml` in `fetch_benchmark_history`.
- `pennyfarthing-dist/src/pf/tests/test_160_12_ws_push_read_hygiene.py` — fixed a fixture-setup bug (missing `archive/` mkdir) in `test_ac2_malformed_archive_index_warns_and_survives` (assertion unchanged).

**Tests:** 13/13 passing (GREEN) — `uv run pytest src/pf/tests/test_160_12_ws_push_read_hygiene.py`. Full taxonomy green: yaml-parse, UnicodeDecodeError, PermissionError, missing-stays-silent, no-over-warning.
**Regression:** 160-4 + frame suite green (`test_160_4_*`, `test_frame_*`, `test_159_8_*`, `test_161_1_*` → 184 + 137 passed across two batches). `ruff check ws_push.py` clean.
**Branch:** feat/160-12-ws-push-read-hygiene-sweep (pushed)

**Self-review:**
- All 8 `read_text()` sites now specify `encoding="utf-8"` (AC1 AST scan green).
- Each fetcher surfaces present-but-broken reads via `warnings.warn` naming the file, then degrades gracefully (warn, never raise — safe for the Frame poll loop).
- Missing/absent files stay silent; healthy inputs emit no warning (AC5 guards green).
- `UnicodeDecodeError` caught explicitly (a `ValueError`, not `OSError`) — the 160-4 round-1 rejection is covered.

**Handoff:** To Reviewer (Leto II) for code review.

## Subagent Results

| # | Specialist | Received | Status | Findings | Decision |
|---|-----------|----------|--------|----------|----------|
| 1 | reviewer-preflight | Yes | clean | 0 new smells (7 pre-existing noted) | confirmed 0, dismissed 0, deferred 0 |
| 2 | reviewer-edge-hunter | No | Skipped | disabled | Disabled via settings (covered manually) |
| 3 | reviewer-silent-failure-hunter | No | Skipped | disabled | Disabled via settings (covered manually) |
| 4 | reviewer-test-analyzer | No | Skipped | disabled | Disabled via settings (covered manually) |
| 5 | reviewer-comment-analyzer | No | Skipped | disabled | Disabled via settings (covered manually) |
| 6 | reviewer-type-design | No | Skipped | disabled | Disabled via settings (covered manually) |
| 7 | reviewer-security | Yes | clean | 0 (1 low-confidence note) | confirmed 0, dismissed 0, deferred 1 (captured as Delivery Finding) |
| 8 | reviewer-simplifier | No | Skipped | disabled | Disabled via settings (covered manually) |
| 9 | reviewer-rule-checker | No | Skipped | disabled | Disabled via settings (covered manually) |

**All received:** Yes (2 enabled returned clean; 7 disabled via `workflow.reviewer_subagents` and covered by Reviewer's own analysis)
**Total findings:** 0 confirmed blocking, 0 dismissed, 3 non-blocking Improvements deferred to Delivery Findings

## Reviewer Assessment

**Verdict:** APPROVED

This is a textbook follow-up: it extends the 160-4 `_load_file` fail-loud contract to the remaining 8 `read_text()` sites in `ws_push.py`, and — critically — it applies the exact lesson that sank 160-4 round 1.

**Empirical taxonomy verification (the 160-4 lesson):**
- `_read_text_file` catches `FileNotFoundError` → silent (callers gate on `exists()`/`is_file()`; missing is normal), then `(OSError, UnicodeDecodeError)` → `warnings.warn` + None. `UnicodeDecodeError` is a `ValueError`, NOT an `OSError` — caught EXPLICITLY, so an undecodable file warns instead of escaping a narrowed catch. This is the precise regression that rejected 160-4 round 1, and it is covered.
- I proved test fidelity: `git checkout origin/develop -- ws_push.py` + branch tests → **10 failed / 3 passed** (the 3 passing are the intentional no-over-warning guards). The 10 behavioral tests genuinely bind to the fix; restored HEAD clean.

**Data flow traced:** broken local file (sprint/archive YAML, agent file, benchmark YAML/md) → `_read_text_file`/`_read_yaml_file` → `warnings.warn(name+exc)` + None → caller skips/degrades → fetcher returns its normal payload shape → poll loop broadcasts. No raise escapes into the poll loop's outer `except Exception: pass`. Safe.

**Observations (12):**
- [VERIFIED] Full read taxonomy handled — `ws_push.py:23-29`: `FileNotFoundError` silent, `(OSError, UnicodeDecodeError)` warn. Complies with python.md #1 (surfaced, not swallowed) and #5 (encoding). Empirically probed via develop-revert RED check.
- [VERIFIED] Encoding on every read — AC1 AST scan (`test_ac1_all_read_text_calls_specify_utf8_encoding`) green; preflight + reviewer-security both confirm all `read_text()` carry `encoding="utf-8"`. Complies with python.md #5 (CWE-838).
- [VERIFIED] `yaml.safe_load` (not `yaml.load`) preserved — `ws_push.py:86,216`; reviewer-security confirmed. Complies with python.md #8.
- [VERIFIED] Path containment preserved — `is_safe_shard_path(shard_path, archive_dir)` still gates the archive shard read (`ws_push.py` archive loop, unchanged by this diff); reviewer-security confirmed CWE-22 containment intact.
- [SILENT] (self, disabled subagent) No NEW silent swallow introduced — the diff REMOVES 6 `except Exception: continue/pass`; the remaining broad catches (`fetch_persona` outer, `fetch_git`, `fetch_context`, mtime fallback) are pre-existing and out of scope. Captured as a non-blocking follow-up Delivery Finding.
- [SILENT] (self) `_read_yaml_file`'s `except Exception` wraps only `yaml.safe_load` and WARNS — acceptable surfacing (not a swallow), consistent with the 160-4 `_load_file` parse branch. Verified `ws_push.py:47-51`.
- [EDGE] (self, disabled subagent) `fetch_persona` mtime ordering — `latest_mtime` now advances only AFTER a successful read (`ws_push.py:450-454`), so an unreadable newest file warns and falls back to the latest READABLE file instead of returning `{}`. Improvement over develop (which returned `{}`). No regression.
- [EDGE] (self) Benchmark `if pipeline_data:` truthiness gate — verified an empty-dict `pipeline.yaml` yields identical observable output (empty run_date→mtime fallback, empty token_usage, None duration) as the old `if pipeline_file.exists():` gate. No regression.
- [DOC] (self, disabled subagent) The consolidation comment (`ws_push.py:543-546`) accurately describes the latent NameError; docstrings on both helpers are accurate. [VERIFIED] additionally: the consolidation fixes a BONUS cross-iteration stale-data leak (loop-local `pipeline_data` previously carried a prior run's values on a malformed file) — `pipeline_data = None` reset each iteration closes it.
- [TYPE] (self, disabled subagent) `_read_text_file -> str | None` and `_read_yaml_file -> Any` are correctly annotated at the helper boundary; `pipeline_data: dict[str, Any] | None` is precise. Complies with python.md #3.
- [SEC] reviewer-security: CLEAN — 0 violations across rules #1/#5/#8; one low-confidence note (parse-error message includes a file-content snippet via `str(exc)`) — zero blast radius on a single-user local tool, captured as a non-blocking Delivery Finding.
- [SIMPLE] (self, disabled subagent) / [RULE] (self, disabled subagent) The shared-helper refactor is a net simplification (removed ~6 try/except blocks + the redundant double-read); rule-by-rule compliance below. No over-engineering.
- [TEST] (self, disabled subagent) 13 tests cover the full taxonomy per bucket (yaml-parse, `UnicodeDecodeError`, `PermissionError`, missing-silent, no-over-warning). No vacuous assertions — every test pairs `pytest.warns`/AST-offenders with a graceful-return/identity check. The 3 green guards are proven non-vacuous (RED-on-develop check: 10 fail / 3 pass). One coverage thinness: L171 main sprint read is encoding-scanned but not behaviorally tested — captured as non-blocking. Complies with python.md #6.

### Rule Compliance (lang-review/python.md)

| Rule | Applicable instances in diff | Verdict |
|------|------------------------------|---------|
| #1 Silent exception swallowing | `_read_yaml_file` except (warns), `fetch_sprint` L171 except (warns), 6 sites converted from `except: continue/pass` to surfacing helpers | COMPLIANT — all surface via `warnings.warn`; 0 new silent swallows |
| #3 Type annotation gaps at boundaries | `_read_text_file`, `_read_yaml_file`, `pipeline_data` | COMPLIANT — helpers + new local fully annotated |
| #4 Logging coverage | module uses `warnings.warn`, not `logging` | N/A — module does not import logging; `warnings` is the established 160-4 convention |
| #5 Path handling (encoding CWE-838 / resolve CWE-59) | 8 `read_text()` sites + `is_safe_shard_path` | COMPLIANT — all reads `encoding="utf-8"`; containment guard unchanged |
| #6 Test quality | 13 tests in the new test file | COMPLIANT — no vacuous assertions; every test asserts `pytest.warns`/AST-offenders + a graceful-return/identity check; 3 green guards proven non-vacuous via develop-revert |
| #7 Resource leaks | `read_text()` (context-managed internally) | COMPLIANT — no bare `open()`/handle leak |
| #8 Unsafe deserialization | `yaml.safe_load` ×3 | COMPLIANT — no `yaml.load`/`pickle`/`eval` |

### Devil's Advocate

Let me argue this code is broken. First attack: the warning mechanism. `warnings.warn` defaults to "once per (message, category, module, lineno)" — so a persistently-broken file polled every 5s in the Frame loop warns ONCE then goes silent forever. Is that fail-loud enough? Counter: the message text embeds the filename, so each DISTINCT broken file gets its own registry key and warns once; on every fresh panel connect, `send_initial_data` re-enters and re-warns. One alert per file per process is sufficient surfacing, and it matches the 160-4 contract the project already accepted. Not broken — but I'd prefer logging for a long-running server; captured as non-blocking.

Second attack: a malicious or confused user drops a 2 GB `score.yaml` or a YAML billion-laughs bomb into a results dir. `_read_yaml_file` calls `yaml.safe_load`, which does not expand aliases into exponential memory the way `yaml.load` would; a genuinely huge file would consume memory on read, but that risk is identical to develop and pre-dates this story — not introduced here. `except Exception` in the helper would even catch a `RecursionError` from deep nesting and warn rather than crash. Acceptably robust.

Third attack: cross-iteration contamination. Could `pipeline_data` from run A bleed into run B? On develop, YES — the loop-local var persisted and the malformed-file path left it stale; that was a real latent bug. The fix resets `pipeline_data = None` at the top of each iteration, so B cannot inherit A's date/tokens/duration. The attack is closed by this very change.

Fourth attack: the `or {}` removal. Could skipping an empty archived shard hide a real epic? An empty (valid-YAML→None) shard carried no `id`/`title`/`stories` — it only ever rendered a blank card stamped with the ref. Skipping loses nothing of substance and is cleaner. The file-existence gates (`is_file()`) are unchanged, so a PRESENT non-empty shard still renders.

Fifth attack: `fetch_persona` now shows a STALE persona when the newest agent file is corrupt (falls back to an older readable file). A confused user might see the "wrong" agent. Counter: develop showed a BLANK panel (`{}`) in the same scenario, and the new code WARNS about the corrupt file — strictly more informative. Degradation, not breakage. Verdict stands: APPROVED.

**Handoff:** To SM (Stilgar) for finish-story.