---
story_id: "160-4"
jira_key: ""
epic: "160"
workflow: "tdd"
---
# Story 160-4: fetch_sprint _load_file silently drops malformed-but-present shards (catch->None->silent continue) — warn/surface per #50 fail-loud (from 156-4 M1)

## Story Details
- **ID:** 160-4
- **Jira Key:** none (local-only)
- **Epic:** 160 (Sprint CRUD & validator hardening)
- **Workflow:** tdd
- **Stack Parent:** none

## Workflow Tracking
**Workflow:** tdd
**Phase:** finish
**Phase Started:** 2026-06-10T20:47:08Z
**Round-Trip Count:** 1

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-06-10T19:53:20Z | 2026-06-10T19:54:28Z | 1m 8s |
| red | 2026-06-10T19:54:28Z | 2026-06-10T19:58:08Z | 3m 40s |
| green | 2026-06-10T19:58:08Z | 2026-06-10T20:28:36Z | 30m 28s |
| review | 2026-06-10T20:28:36Z | 2026-06-10T20:36:41Z | 8m 5s |
| red | 2026-06-10T20:36:41Z | 2026-06-10T20:40:41Z | 4m |
| green | 2026-06-10T20:40:41Z | 2026-06-10T20:42:42Z | 2m 1s |
| review | 2026-06-10T20:42:42Z | 2026-06-10T20:47:08Z | 4m 26s |
| finish | 2026-06-10T20:47:08Z | - | - |

## Sm Assessment

**Story:** 160-4 — fetch_sprint's `_load_file` catches parse errors on shard files, returns None, and the caller silently continues; a malformed-but-present epic shard vanishes from the merged sprint with no warning. Violates fail-loud (gh #50). From 156-4 review finding M1. 1 point.

**Scope:** The fetch_sprint code path in pennyfarthing-dist/src/pf/sprint/. Fix the silent catch→None→continue: a shard that EXISTS but fails to parse must surface visibly. The existing warn-on-missing-ref behavior (missing shard file) is adjacent prior art — match its surfacing mechanism (warnings.warn or logger) for consistency. Distinguish: missing file (already warned) vs malformed present file (this story).

**Acceptance criteria:**
1. A malformed (unparseable YAML) epic shard referenced by current-sprint.yaml produces a visible warning identifying the shard path and the parse problem.
2. The merged sprint result still loads (other shards unaffected) — warn, don't crash, unless existing fail-loud conventions in this module dictate harder failure (derive from code/#50 conventions).
3. A shard that parses but yields a non-dict (e.g. YAML scalar) is also surfaced, not silently treated as empty.
4. Missing-file behavior unchanged (existing warn-on-missing-ref).
5. No regression in fetch_sprint/loader tests.

**Technical approach:** TEA inspects `_load_file` and callers, pins current silent-drop behavior with failing tests (pytest.warns), derives warn-vs-error from module conventions. Dev implements minimal surfacing. Keep result-object discipline — don't throw.

**Routing:** tdd (phased) — TEA (red) → Dev (green) → Reviewer (review). 1 point, repo pennyfarthing, branch `feat/160-4-fetch-sprint-shard-fail-loud` off develop.

## Summary
In `pennyfarthing-dist/src/pf/sprint/fetch_sprint.py`, the `_load_file()` function catches parse errors on shard files (epic-*.yaml), returns None, and the caller silently continues. This drops malformed-but-present shards from the merged sprint without warning — violating the fail-loud principle (gh issue #50).

**Requirement:** Warn/surface malformed shards so they produce visible warnings/errors rather than silently disappearing. Acceptance criteria should include:
1. Detect when a shard file parse fails
2. Log a warning or raise an appropriate error
3. Do not silently discard the shard
4. Provide clear feedback to the user (e.g., via logs, exception message)

**Related:** Story 160-7 will add pytest.warns coverage for existing warn-on-missing-ref; this story focuses on malformed-but-present shards.

## Delivery Findings

Agents record upstream observations discovered during their phase.
Each finding is one list item. Use "No upstream findings" if none.

**Types:** Gap, Conflict, Question, Improvement
**Urgency:** blocking, non-blocking

<!-- Agents: append findings below this line. Do not edit other agents' entries. -->
- No upstream findings

### Dev (implementation)
- **Improvement** (non-blocking): fetch_sprint's archive-loading section uses its own inline `yaml.safe_load` wrapped in silent `except Exception: continue` (two sites), so a malformed archive file or archived epic shard still vanishes silently — same fail-loud violation as this story, different code path. Affects `pennyfarthing-dist/src/pf/frame/ws_push.py` (archive loop, ~lines 255-275: surface parse failures with the same `warnings.warn` convention). Out of scope here (no AC/test covers archives); candidate follow-up story. *Found by Dev during implementation.*

### Reviewer (code review)
- **Gap** (blocking): A present-but-non-UTF-8 shard raises `UnicodeDecodeError` out of `fetch_sprint` (develop silently dropped it; branch blanks the whole panel). Affects `pennyfarthing-dist/src/pf/frame/ws_push.py` (`_load_file` must catch decode failures into the parse-warning branch; read with `encoding="utf-8"`). *Found by Reviewer during code review.*
- **Gap** (non-blocking): Present-but-unreadable shard (PermissionError) silently vanishes — `except OSError` masks it and `exists()=True` suppresses the "not found" warning. Affects `pennyfarthing-dist/src/pf/frame/ws_push.py` (narrow to `FileNotFoundError`, warn on other OSErrors). *Found by Reviewer during code review.*
- **Improvement** (non-blocking): Shard refs from parsed sprint YAML build paths (`sprint_dir / f"epic-{ref}.yaml"`) with no `resolve()`/containment check (CWE-22) — pre-existing in both ws_push.py and shard_merge.py, untouched by this diff. Affects `pennyfarthing-dist/src/pf/sprint/shard_merge.py` and `ws_push.py` (add containment validation at the path-construction sites); candidate follow-up story. *Found by Reviewer during code review.*
- **Improvement** (non-blocking): Module-wide hygiene — 6 other `read_text()` sites in ws_push.py lack `encoding=` (CWE-838: lines ~171, 270, 282, 399, 474/499/517/542) and most sit inside broad `except Exception` silent guards (same fail-loud class; overlaps Dev's archive finding and extends it to the benchmark-history/persona fetchers). Affects `pennyfarthing-dist/src/pf/frame/ws_push.py` (one sweep: add encoding + surface or narrow the catches); fold into the same follow-up story as the archive-loop finding. *Found by Reviewer during code review (round 2).*

## Design Deviations

Agents log spec deviations as they happen — not after the fact.
Each entry: what was changed, what the spec said, and why.

<!-- Agents: append deviations below this line. Do not edit other agents' entries. -->

### TEA (test design)
- **Location:** Spec named `fetch_sprint._load_file` in `pf/sprint/`. The actual code path lives in `pf/frame/ws_push.py` (`fetch_sprint()` + its nested `_load_file`). `pf/sprint/loader.py`/`shard_merge.py` is the *canonical* loader fetch_sprint delegates to (and the source of the prior-art `warnings.warn`). Tests target `pf.frame.ws_push.fetch_sprint`, consistent with the existing 156-4 test file. No behavior deviation — location note only.
- **AC3 finding:** A non-dict scalar shard does not just silently drop — today it raises `AttributeError` inside `merge_epic_shards` (`.get` on a str), swallowed by the runtime `except` in `send_initial_data` → blank panel. Test AC3 pins both the crash and the missing surfacing.
- **Rework 1: non-blocking MEDIUM also pinned with a test**
  - Spec source: Reviewer Assessment (160-4-session.md), severity table row 2
  - Spec text: "(Non-blocking, recommended) Catch `FileNotFoundError` silently; `warnings.warn` for other `OSError`s."
  - Implementation: Added `test_rework1_unreadable_shard_warns_and_survives` (RED) forcing the PermissionError fix, not just recommending it
  - Rationale: Gates over goodwill (SOUL #6) — an untested recommended fix is goodwill; the test makes the rework verifiable and guards the AC4 boundary (warning must not say "not found" for a present file)
  - Severity: minor
  - Forward impact: none — Dev fixes both findings in one branch of the same try block

### Dev (implementation)
- **Warn-per-load instead of exactly-once per malformed shard**
  - Spec source: Tea Handoff (160-4-session.md), "Designed interface for Dev" item re: `_load_file` pre-resolve note
  - Spec text: "if you prefer exactly-once, surface at the merged-epics consumer loop instead and keep `_load_file`'s pre-resolve tolerant"
  - Implementation: Warning emitted inside `_load_file` itself, so a malformed shard warns up to 3× per fetch (ref_by_id pre-resolve, merge, orphan-scan) rather than exactly once
  - Rationale: TEA explicitly sanctioned this option ("tests don't count occurrences, only presence/absence"); warning at the single load chokepoint is the minimal change and can't miss a future call site
  - Severity: minor
  - Forward impact: none — duplicate UserWarnings on an already-broken shard; dedupe trivially later if it ever gets noisy
- **Missing-file `OSError` swallowed silently in `_load_file`**
  - Spec source: Tea Handoff, AC4
  - Spec text: "a referenced-but-absent shard must keep emitting only the existing 'not found' warning, and must NOT trip the new parse warning"
  - Implementation: `_load_file` catches `OSError` (incl. FileNotFoundError) and returns None with no warning, leaving the "not found" warning to `merge_epic_shards`' `exists()` branch
  - Rationale: The pre-resolve ref_by_id loop calls `_load_file` on paths that may not exist; warning there would misreport missing files as parse failures and break the AC4 missing-vs-malformed distinction
  - Severity: minor
  - Forward impact: none — warning ownership for missing files stays in shard_merge.py, matching prior art
- **Rework 1:** No deviations — implemented TEA's designed interface verbatim (utf-8 read, FileNotFoundError silent, OSError/UnicodeDecodeError → warn naming shard, no "not found" wording).

### Reviewer (audit)
- **TEA "Location" deviation (ws_push.py not pf/sprint/)** → ✓ ACCEPTED by Reviewer: verified `fetch_sprint`'s nested `_load_file` lives at ws_push.py:186 and is the actual silent-drop site; sm Assessment's `pf/sprint/` path was approximate.
- **TEA "AC3 finding" (scalar shard crashes merge, not just drops)** → ✓ ACCEPTED by Reviewer: confirmed `.get` AttributeError at shard_merge.py:79 in RED run; test pins both crash and surfacing.
- **Dev "Warn-per-load instead of exactly-once"** → ✓ ACCEPTED by Reviewer: TEA's handoff explicitly sanctioned per-load warnings; duplicates only occur on already-broken shards; chokepoint placement is the more robust choice.
- **Dev "Missing-file OSError swallowed silently in `_load_file`"** → ✗ FLAGGED by Reviewer: the rationale holds for `FileNotFoundError` only. The broad `OSError` catch silently hides PermissionError/IsADirectoryError on PRESENT files (empirically proven: chmod-000 shard → zero warnings, exists()=True so the "not found" warning never fires) — MEDIUM finding in assessment. Worse, the narrowed-catch rewrite lets `UnicodeDecodeError` (ValueError, not OSError) escape entirely — the HIGH blocking finding. Both attach to this deviation's try block.

### Reviewer (audit — Round 2)
- **Round-1 FLAGGED Dev OSError deviation** → ✓ RESOLVED: rework `b9aa1be72` narrows the silent branch to `FileNotFoundError` exactly and warns on all other OSErrors + UnicodeDecodeError; both flagged behaviors now pinned by `test_rework1_*` tests. Flag lifted.
- **TEA "Rework 1: non-blocking MEDIUM also pinned with a test"** → ✓ ACCEPTED by Reviewer: agrees — SOUL #6 gates-over-goodwill is exactly the right call; the test also guards the AC4 wording boundary I would otherwise re-check by hand every round.
- **Dev "Rework 1: No deviations"** → ✓ ACCEPTED by Reviewer: verified against TEA's designed interface items 1–5 line by line; implementation matches verbatim (utf-8 read at :189, FileNotFoundError-silent at :190-192, warn branch at :193-199, exception order correct).

## Tea Assessment

**Tests Required:** Yes
**Reason:** Bug story (fail-loud violation) — RED tests pin the silent drop empirically.

**Test File:**
- `pennyfarthing-dist/src/pf/tests/test_160_4_fetch_sprint_malformed_shard.py` — 6 tests over the 5 ACs.

**Tests Written:** 6 tests covering 5 ACs.
**Status:** RED (4 failing as designed; 2 guard tests + 6 pre-existing 156-4 tests pass).

**Handoff:** To Dev for implementation (GREEN).

## Tea Handoff

**Mechanism pinned:** `warnings.warn` (UserWarning), asserted via `pytest.warns`. This is the module's established surfacing convention — `pf/sprint/shard_merge.py` uses `warnings.warn` for the adjacent missing-ref prior art (`"Sprint epic ref '<ref>' not found: <path>"`, line 86) and orphan-shard warnings. Dev MUST use `warnings.warn`, not `logging`, for consistency.

**Bug confirmed empirically:** A malformed-but-present `epic-<ref>.yaml` → `fetch_sprint()` returns `epics=[]` with ZERO warnings (silent drop). A non-dict scalar shard → `AttributeError` in `merge_epic_shards` (swallowed at runtime → blank panel).

**Root cause / fix point:** `fetch_sprint`'s nested `_load_file(path)` in `pf/frame/ws_push.py` (lines ~186-190):
```python
def _load_file(path: Path) -> Any:
    try:
        return yaml.safe_load(path.read_text()) or {}
    except Exception:
        return None   # <- swallows parse error; merge then `continue`s silently
```
Returning `None` makes `merge_epic_shards` hit `if epic_data is None: continue` (a present file silently vanishes, and the missing-ref warn never fires because `shard_file.exists()` is True). Returning a scalar makes `merge_epic_shards` crash on `.get`.

**Designed interface for Dev (GREEN):**
1. In `_load_file` (or at its call sites in `fetch_sprint`): when a shard file EXISTS but `yaml.safe_load` raises, emit `warnings.warn(...)` whose text contains the shard filename (`epic-<ref>.yaml`) AND surfaces the parse nature (must match `epic-99\.yaml` and one of `pars|malform|load|yaml|invalid`, case-insensitive). Then skip that shard but keep going — warn, don't crash, don't raise.
2. When a shard parses to a NON-DICT (scalar/list), emit a warning identifying the shard and skip it — do NOT pass the scalar into `merge_epic_shards` (which crashes on `.get`), and do NOT treat it as a loaded epic.
3. Sibling shards must still load and `fetch_sprint()` must still return its payload in both cases (AC2/AC3 assert the healthy `"88"` epic survives).
4. Do NOT regress the missing-FILE path: a referenced-but-absent shard must keep emitting only the existing "not found" warning, and must NOT trip the new parse warning (AC4).
5. Do NOT over-warn: healthy shards/inline epics must emit no parse/non-dict warning (AC5).
- Keep result-object discipline / no `raise` out of `fetch_sprint`.
- Note: `_load_file` is also used at lines ~199-200 to pre-resolve `ref_by_id` before the merge. If you warn inside `_load_file` directly, that pre-resolve loop will warn too — acceptable (still one surfacing per malformed shard is fine; tests don't count occurrences, only presence/absence), but if you prefer exactly-once, surface at the merged-epics consumer loop instead and keep `_load_file`'s pre-resolve tolerant.

**Test names (`test_160_4_fetch_sprint_malformed_shard.py`):**
- `test_ac1_malformed_present_shard_emits_warning` — FAILING (DID NOT WARN)
- `test_ac1_malformed_warning_names_parse_problem` — FAILING (no parse-problem warning)
- `test_ac2_other_shards_still_load_when_one_is_malformed` — FAILING (DID NOT WARN)
- `test_ac3_non_dict_scalar_shard_is_surfaced` — FAILING (crash chained into DID NOT WARN)
- `test_ac4_missing_file_still_warns_not_found_only` — PASSING (regression guard)
- `test_ac5_healthy_shards_emit_no_warning` — PASSING (regression guard)

**Targeted run:** `python3 -m pytest pennyfarthing-dist/src/pf/tests/test_160_4_fetch_sprint_malformed_shard.py pennyfarthing-dist/src/pf/tests/test_156_4_fetch_sprint_inline_epics.py` → 4 failed, 8 passed. Do NOT run full pytest (branch-switch hazard).

**Commit:** `26b08fc71` (GPG-signed, verified).

## Dev Assessment

**Implementation Complete:** Yes

**Files Changed:**
- `pennyfarthing-dist/src/pf/frame/ws_push.py` — `_load_file` no longer swallows parse errors: a present-but-unparseable shard emits `warnings.warn("Failed to parse sprint shard epic-<ref>.yaml: <exc>")`; a shard parsing to a non-dict emits `warnings.warn("Sprint shard <name> is not a mapping (parsed to <type>) — skipping")` and returns None so `merge_epic_shards` skips it instead of crashing on `.get`. `OSError` (missing file) stays silent — shard_merge's existing "not found" warning owns that case. Empty-file `→ {}` semantics preserved. 22 insertions, 2 deletions; no other files touched.

**Tests:** 12/12 passing (GREEN) — 6 story tests (`test_160_4_fetch_sprint_malformed_shard.py`) + 6 pre-existing 156-4 guards. Regression sweep over all other ws_push/shard_merge consumers (`test_143_13_branch_protection.py`, `test_148_5_audit_log_otel.py`, `test_148_6_debug_pane_otel.py`, `test_161_1_frame_resource_hygiene.py`, `test_tour_practice.py`): 138/138 passing. RED verified before implementation (4 failed on assertions, per TEA design). Scoped runs only — full suite avoided per branch-leak hazard.

**Branch:** `feat/160-4-fetch-sprint-shard-fail-loud` (pushed; commit `12204dc79`, GPG-signed `G`)

**AC trace:** AC1 warn-with-path-and-parse-problem ✓; AC2 warn-don't-crash, siblings survive ✓; AC3 non-dict surfaced + skipped, no AttributeError ✓; AC4 missing-file behavior unchanged ✓; AC5 no spurious warnings on healthy shards ✓.

**Handoff:** To review phase (Reviewer).

## Subagent Results

| # | Specialist | Received | Status | Findings | Decision |
|---|-----------|----------|--------|----------|----------|
| 1 | reviewer-preflight | Yes | clean | 1 (style note) | confirmed 1 as LOW (redundant local `import re` in tests), dismissed 0, deferred 0 |
| 2 | reviewer-edge-hunter | Skipped | disabled | N/A | Disabled via settings — domain self-assessed (decode-error edge found, see [EDGE]) |
| 3 | reviewer-silent-failure-hunter | Skipped | disabled | N/A | Disabled via settings — domain self-assessed (PermissionError swallow found, see [SILENT]) |
| 4 | reviewer-test-analyzer | Skipped | disabled | N/A | Disabled via settings — domain self-assessed (missing decode-error test, see [TEST]) |
| 5 | reviewer-comment-analyzer | Skipped | disabled | N/A | Disabled via settings — domain self-assessed (OSError comment imprecise, see [DOC]) |
| 6 | reviewer-type-design | Skipped | disabled | N/A | Disabled via settings — domain self-assessed (`-> Any` on private nested helper acceptable, see [TYPE]) |
| 7 | reviewer-security | Yes | findings | 4 | confirmed 4 (1 escalated to HIGH after my empirical verification, 1 MEDIUM, 2 LOW), dismissed 0, deferred 0 |
| 8 | reviewer-simplifier | Skipped | disabled | N/A | Disabled via settings — domain self-assessed (implementation is minimal, see [SIMPLE]) |
| 9 | reviewer-rule-checker | Skipped | disabled | N/A | Disabled via settings — rule-by-rule enumeration done by Reviewer (see Rule Compliance) |

**All received:** Yes (2 enabled returned, 7 disabled via settings)
**Total findings:** 5 confirmed, 0 dismissed, 0 deferred

## Reviewer Assessment

**Verdict:** REJECTED

| Severity | Issue | Location | Fix Required |
|----------|-------|----------|--------------|
| [HIGH] | [EDGE][SEC] Non-UTF-8 shard crashes `fetch_sprint()`: `path.read_text()` raises `UnicodeDecodeError` (a `ValueError`, NOT `OSError`) which the rewritten `_load_file` no longer catches; it escapes via the pre-resolve `ref_by_id` loop. Empirically proven: branch → `RAISED UnicodeDecodeError`, healthy sibling epic lost, whole panel blanks (runtime swallows in `send_initial_data`); develop baseline → shard silently dropped, sibling survived (`epics: ['88']`). The diff REGRESSES an in-class input (present-but-unparseable shard), violating AC2 warn-don't-crash and the Tea Handoff's "no `raise` out of fetch_sprint" (SOUL #10). | `pennyfarthing-dist/src/pf/frame/ws_push.py:189` | Read with `encoding="utf-8"` and route `UnicodeDecodeError` into the existing parse-warning branch (warn naming the shard + return None). TEA: pin with a RED test writing `write_bytes(b"id: '66'\ntitle: caf\xe9 \xff\xfe\n")` to a referenced shard, asserting `pytest.warns` + sibling survival + no raise. |
| [MEDIUM] | [SILENT][SEC][RULE python.md #1] Present-but-unreadable shard (PermissionError) still silently vanishes: `except OSError: return None` treats permission-denied as missing, but `shard_file.exists()` is True so the "not found" warning never fires either — empirically proven (chmod 000 → `epics: []`, zero warnings). Same silent-drop class this story fixes. NOT a regression (develop behaves identically) and out of AC scope — non-blocking, but trivially fixable in the same rework: narrow to `except FileNotFoundError`, warn on other OSErrors. | `pennyfarthing-dist/src/pf/frame/ws_push.py:190` | (Non-blocking, recommended) Catch `FileNotFoundError` silently; `warnings.warn` for other `OSError`s. |
| [LOW] | [SEC][RULE python.md #5] `read_text()` without `encoding=` (CWE-838) — module-wide pre-existing convention (8+ sites), but the HIGH fix should add `encoding="utf-8"` to the touched call as part of the rework. | `ws_push.py:189` | Subsumed by HIGH fix. |
| [LOW] | [SEC][RULE python.md #11] Shard ref from parsed YAML used in `sprint_dir / f"epic-{ref}.yaml"` with no `resolve()` containment check (CWE-22). Pre-existing pattern NOT touched by this diff (also present in shard_merge.py); operator-controlled local file. Captured as non-blocking Delivery Finding. | `ws_push.py:219` | Follow-up story, not this PR. |
| [LOW] | [SEC] Warning embeds raw `{exc}` — YAML errors include document context snippets. Local single-user display channel showing the operator their own file; no credentials/PII class. No action required; optional truncation noted. | `ws_push.py:196` | Optional polish, not required. |
| [LOW] | [TEST] Redundant local `import re` inside two test functions (module could import once at top). Style only; ruff clean. | `test_160_4_fetch_sprint_malformed_shard.py` | Optional cleanup if TEA touches the file anyway. |

### Rule Compliance (python.md lang-review)

| # | Rule | Instances in diff | Judgment |
|---|------|-------------------|----------|
| 1 | Silent exception swallowing | `except OSError: return None` (ws_push.py:190); `except Exception as exc:` + warn (196) | **Violation (MEDIUM):** OSError branch swallows PermissionError silently on a file-I/O path. Parse branch now compliant (was the story's bug, fixed). |
| 2 | Mutable default arguments | None in diff | Compliant — no defaults added. |
| 3 | Type annotation gaps at boundaries | `_load_file(path: Path) -> Any` | Compliant — [TYPE] private nested helper (exempt per rule text); `Any` is the genuine contract (dict/None/{}), matches pre-change signature. |
| 4 | Logging coverage/correctness | `warnings.warn` × 2 | Compliant — module convention is `warnings.warn` (shard_merge.py prior art), not `logging`; TEA pinned this mechanism. No sensitive data (LOW note on exc snippets, same-user channel). |
| 5 | Path handling | `path.read_text()` (189) | **Violation (LOW):** no `encoding=` (CWE-838) — and the decode failure it implies is the HIGH finding's root. Pathlib used throughout ✓. |
| 6 | Test quality | 6 new tests | Compliant — real assertions, pytest.warns with match patterns, negative assertions (AC4/AC5), no skips, no vacuous asserts. [TEST] gap: no decode-error case (drives the HIGH). |
| 7 | Resource leaks | `read_text()` | Compliant — Path.read_text manages the handle. |
| 8 | Unsafe deserialization | `yaml.safe_load` (194) | Compliant — verified `safe_load` at all 7 yaml call sites in ws_push.py; no `yaml.load`. |
| 9 | Async pitfalls | None — `_load_file` is sync, called via executor | Compliant. |
| 10 | Import hygiene | `import warnings` top-level | Compliant — stdlib, no cycles. |
| 11 | Input validation at file parsers | non-dict isinstance gate (new); ref→path construction (pre-existing, untouched) | New code compliant for payload shape; **pre-existing violation (LOW, out of diff)** on ref containment (CWE-22) → Delivery Finding. |
| 12 | Dependency hygiene | No dep changes | Compliant — N/A. |
| 13 | Fix-introduced regressions (meta-check) | The whole diff | **Violation (HIGH):** the fix narrowed `except Exception` to `except OSError` around `read_text()` and let `UnicodeDecodeError` escape — exactly the "adding error handling but catching too broadly/narrowly" regression class this check exists for. |

### Observations (adversarial review)

1. [HIGH][EDGE][SEC] UnicodeDecodeError regression — see severity table row 1; proven on branch AND develop baseline.
2. [VERIFIED] AC1/AC2/AC3 surfacing works — `ws_push.py:196-199` warns with `path.name` + exc (matches `epic-99\.yaml` + parse-problem pattern); `ws_push.py:202-208` warns on non-dict and returns None so `merge_epic_shards:73` skips instead of crashing at `:79`. 12/12 story+guard tests green; complies with fail-loud rule and warnings.warn convention (rule #4).
3. [VERIFIED] AC4 ownership split — `ws_push.py:190` returns None on missing file with no warning; `shard_merge.py:86-89` emits the sole "not found" warning via its `exists()` branch. Test `test_ac4` green; complies with the AC's "unchanged" requirement.
4. [VERIFIED] Wiring — `fetch_sprint` registered as the `"sprint"` channel fetcher at `ws_push.py:604`; consumers enumerated (only test_156_4, test_160_4, and ws_push itself reference it — subset-green hazard checked, no untested callers).
5. [VERIFIED] Empty-file semantics preserved — `loaded is None → {}` (`ws_push.py:200-201`) replicates the old `or {}` for empty/comment-only shards; falsy scalars (`0`, `false`) now warn+skip instead of silently becoming `{}`, which is AC3-aligned and strictly more correct.
6. [SILENT][MEDIUM] PermissionError silent drop — severity table row 2; empirically proven, non-blocking (develop-identical).
7. [SIMPLE][VERIFIED] No over-engineering — 22-line change confined to the single chokepoint; no new abstractions; merge_epic_shards' own `except Exception` path becomes unreachable for this caller but stays live for loader.py/yaml_io.py callbacks that DO raise.
8. [DOC][LOW] Comment `# Missing file: merge_epic_shards owns the "not found" warning.` (ws_push.py:190) is imprecise — the branch also catches PermissionError/IsADirectoryError, which merge does NOT surface. Reword when fixing the MEDIUM.
9. [TYPE][VERIFIED] `-> Any` on `_load_file` — private nested helper, exempt from rule #3 boundary annotation; returns the deliberate dict/None/{} union consumed by merge_epic_shards' duck-typed contract.
10. [TEST][LOW] Redundant `import re` inside test functions; tests otherwise high quality (negative assertions, regex-pinned warning text robust to wording).

**Data flow traced:** operator-edited `sprint/epic-*.yaml` → `read_text()` → `yaml.safe_load` → isinstance-dict gate → `merge_epic_shards` → epic_entry dicts → JSON over WebSocket → TUI SprintPanel. Warning text → `warnings.warn` → stderr/TUI (same-user display; no shell/HTML/SQL sink — injection clean). Failure path traced: byte `0xe9` → UnicodeDecodeError at ws_push.py:189 → uncaught through ref_by_id loop → `fetch_sprint` raises → swallowed by `send_initial_data` broad except → blank panel (the exact gh #50 symptom this story exists to kill).

**Hard questions:** Huge shard file → full read into memory; local operator files, not a network DoS vector — acceptable. Race (shard deleted between `exists()` and `read_text`) → OSError → None → silent skip after the "exists" check passed; degenerate case of the MEDIUM, same fix. Symlinked shard pointing outside sprint/ → followed (pre-existing module-wide behavior, CWE-59 note rides with the CWE-22 Delivery Finding). Concurrent fetches → `_load_file` is pure read, no shared state — safe.

### Devil's Advocate

Assume this diff is broken and I must prove it. The author replaced one broad `except Exception` with two typed try blocks — the classic way to make a swallow-everything bug into a crash-something bug. What can `path.read_text()` raise that `OSError` doesn't cover? `UnicodeDecodeError`. Sprint shards are hand-edited YAML; a contributor on a latin-1 locale, a copy-paste from a Word doc with smart quotes saved as cp1252, or a half-written file from a crashed editor produces exactly those bytes. I wrote that file, ran the branch, and `fetch_sprint()` blew up — taking the healthy epic with it, where develop kept it alive. The story shipped a fail-loud fix that converts a one-shard silent drop into a whole-panel blank for a sibling input class. That is not a hypothetical: it is the single most likely real-world malformed shard after indentation errors. What else? A confused user might point FRAME_PROJECT_DIR at a directory where `sprint/epic-99.yaml` is itself a directory — `read_text()` raises `IsADirectoryError` → OSError → silent None → merge sees exists()=True → silent drop with no warning: the original bug, third flavor. A stressed filesystem returning EIO mid-read: same silent path. The non-dict gate: a shard whose top level is a list of epics (plausible user error) warns and skips — correct, and the warning names the file — good. Could the warning itself mislead? It says "Failed to parse" for what might be tab characters; YAML's exc text clarifies. The fix's core surfacing logic is sound; its exception taxonomy is not. The decode crash alone justifies rejection.

**Pattern observed:** Good — single-chokepoint surfacing at `_load_file` (ws_push.py:186-213) matching shard_merge.py's warnings.warn prior art. Bad — exception-narrowing without enumerating the raisable set of the guarded call (read_text raises ValueError-family, not just OSError).

**Error handling:** Parse failures and non-dict payloads now surface (verified, tests green); decode failures crash (HIGH, blocking); permission failures stay silent (MEDIUM, non-blocking).

**Verdict rationale:** One HIGH (regression, testable logic bug) → REJECT per blocking rule. Route back through TEA (red) to pin the decode-error case with a failing test before Dev fixes — findings are testable.

**Handoff:** Back to Thufir Hawat (TEA) for rework — RED test for the UnicodeDecodeError case, then Reverend Mother Mohiam (Dev) makes it green alongside the MEDIUM if trivial.

## Tea Assessment (Rework Round 1)

**Tests Required:** Yes
**Reason:** Reviewer REJECTED with one HIGH (UnicodeDecodeError regression) and one recommended MEDIUM (PermissionError silent drop) — both empirically reproducible, both pinned RED.

**Test File:**
- `pennyfarthing-dist/src/pf/tests/test_160_4_fetch_sprint_malformed_shard.py` — +2 rework tests appended (now 8 tests in file).

**Tests Written:** 2 new tests covering both Reviewer findings.
**Status:** RED confirmed via testing-runner — exactly 2 failed (both `DID NOT WARN`, the decode case crashing with UnicodeDecodeError before any warning), 12 passed (6 prior story tests + 6 pre-existing 156-4 guards). Shape matched prediction exactly.

### Designed interface for Dev (rework GREEN)

1. `text = path.read_text(encoding="utf-8")` — explicit encoding (clears the LOW CWE-838 note on the touched line).
2. `UnicodeDecodeError` must land in the SAME warning branch as YAML parse failures (warn naming `epic-<ref>.yaml`, return None, siblings survive, no raise). Simplest shape: keep the read inside its own try but add `except UnicodeDecodeError as exc:` → same warn-and-None as the parse branch — or move the decode into the parse try by reading bytes first; either passes.
3. OSError split: `except FileNotFoundError: return None` (silent — AC4's "not found" warning stays owned by merge_epic_shards) and `except OSError as exc:` → warn naming the shard, return None. The warning text must NOT contain "not found" (test asserts this negative) — say what actually happened (e.g. "Failed to read sprint shard epic-99.yaml: <exc>").
4. Tests pin the filename (`epic-99.yaml`) in the warning, not exact wording — wording is Dev's choice within the above constraint.
5. Existing 6 story tests + AC4/AC5 guards must stay green — do not over-warn on missing files or healthy shards.

**Commit:** `7f339151a` (GPG-signed, pushed).

**Handoff:** To Dev for rework implementation (GREEN).
## Dev Assessment (Rework Round 1)

**Implementation Complete:** Yes

**Files Changed:**
- `pennyfarthing-dist/src/pf/frame/ws_push.py` — `_load_file` read block reworked per review: `path.read_text(encoding="utf-8")` (clears CWE-838 LOW on the touched line); `except FileNotFoundError: return None` (silent — AC4 "not found" ownership unchanged); `except (OSError, UnicodeDecodeError) as exc:` → `warnings.warn("Failed to read sprint shard <name>: <exc>")` + return None. The HIGH (decode crash) and MEDIUM (permission silent-drop) are both closed by the same branch. 10 insertions, 2 deletions.

**Tests:** 152/152 passing (GREEN) — 8 story tests (incl. both rework RED tests) + 6 pre-existing 156-4 guards + 138 regression sweep (same file set as round 1). RED verified before fix (exactly 2 failed). Scoped runs only.

**Branch:** `feat/160-4-fetch-sprint-shard-fail-loud` (pushed; commit `b9aa1be72`, GPG-signed `G`)

**Review findings trace:** HIGH UnicodeDecodeError → warns + siblings survive + no raise ✓ (`test_rework1_undecodable_shard_warns_and_survives`); MEDIUM PermissionError → warns, not "not found" ✓ (`test_rework1_unreadable_shard_warns_and_survives`); LOW encoding= ✓ on the touched call.

**Handoff:** To Reviewer for re-review (round 2).
## Subagent Results (Round 2)

| # | Specialist | Received | Status | Findings | Decision |
|---|-----------|----------|--------|----------|----------|
| 1 | reviewer-preflight | Yes | clean | 1 (style note) | confirmed 1 as LOW (late `import re` in new test fn — matches round-1 note), dismissed 0, deferred 0 |
| 2 | reviewer-edge-hunter | Skipped | disabled | N/A | Disabled via settings — domain self-assessed: raisable taxonomy of `read_text(encoding="utf-8")` enumerated (FileNotFoundError/PermissionError/IsADirectoryError/EIO/UnicodeDecodeError) and all probed or caught; see [EDGE] |
| 3 | reviewer-silent-failure-hunter | Skipped | disabled | N/A | Disabled via settings — domain self-assessed: no silent paths remain in `_load_file`; module's other silent reads are pre-existing + out of scope; see [SILENT] |
| 4 | reviewer-test-analyzer | Skipped | disabled | N/A | Disabled via settings — domain self-assessed: both rework tests assert warning + sibling survival + negative ("not found" absent); skipif justified; see [TEST] |
| 5 | reviewer-comment-analyzer | Skipped | disabled | N/A | Disabled via settings — domain self-assessed: round-1 [DOC] imprecise-comment finding RESOLVED (comment now sits on the FileNotFoundError-only branch, accurate); see [DOC] |
| 6 | reviewer-type-design | Skipped | disabled | N/A | Disabled via settings — no type surface changed in rework; see [TYPE] |
| 7 | reviewer-security | Yes | findings | 1 new LOW | confirmed 1 as LOW (full path in PermissionError exc text), dismissed 0, deferred 0; round-1 HIGH + MEDIUM verified CLOSED |
| 8 | reviewer-simplifier | Skipped | disabled | N/A | Disabled via settings — rework is 10 insertions, minimal shape TEA specified; see [SIMPLE] |
| 9 | reviewer-rule-checker | Skipped | disabled | N/A | Disabled via settings — security ran the exhaustive python.md scan (9 read sites, 7 rules); results in Rule Compliance round-2 notes; see [RULE] |

**All received:** Yes (2 enabled returned, 7 disabled via settings)
**Total findings:** 2 confirmed (both LOW), 0 dismissed, 0 deferred

## Reviewer Assessment (Round 2)

**Verdict:** APPROVED

**Round-1 findings closure (verified empirically by Reviewer, not taken on faith):**
- [EDGE][SEC] HIGH UnicodeDecodeError — CLOSED. Probe: non-UTF-8 shard → `ids=['88']`, warning "Failed to read sprint shard epic-99.yaml: 'utf-8' codec can't decode byte 0xe9...", no raise. Pinned by `test_rework1_undecodable_shard_warns_and_survives`.
- [SILENT][SEC][RULE] MEDIUM PermissionError — CLOSED. Probe: chmod-000 shard → `ids=['88']`, warning "[Errno 13] Permission denied", no raise, no "not found" masquerade. Pinned by `test_rework1_unreadable_shard_warns_and_survives` (skipif-root justified).
- Bonus: round-1 Devil's Advocate IsADirectoryError flavor — also CLOSED by the same branch (probe: warning "[Errno 21] Is a directory", siblings survive).
- LOW encoding= on touched line — CLOSED (`read_text(encoding="utf-8")`, ws_push.py:189).
- [DOC] Imprecise OSError comment — RESOLVED: "Missing file" comment now guards the `FileNotFoundError`-only branch (accurate); the new warn branch has its own accurate comment.

**Round-2 rule compliance ([RULE], python.md):** #1 — `_load_file` now has zero silent swallows (FileNotFoundError-silent is by design: merge_epic_shards' exists()-gated "not found" warning is the single diagnostic voice, and the same branch correctly absorbs the exists()→read TOCTOU race). #5 — touched call compliant; 6 pre-existing `read_text()` sites elsewhere in the module lack `encoding=` (out of diff → Delivery Finding). #8 — all 6 yaml call sites `safe_load` ✓. #13 — fix-diff re-scan: exception ordering correct (`FileNotFoundError` before its `OSError` parent — reversed order would break AC4), no new raisable paths, no new I/O. [TYPE] no type surface changed. [SIMPLE] rework is the minimal 10-line shape TEA specified; no scope creep.

**New findings (both LOW, non-blocking):**
| Severity | Issue | Location | Disposition |
|----------|-------|----------|-------------|
| [LOW][SEC] | `{exc}` in the read-failure warning embeds the full absolute path from the OS errno string (CWE-209 flavor). Local single-user display channel showing the operator their own path; same format as the pre-existing parse branch. | `ws_push.py:197` | Optional polish; noted, not required. |
| [LOW][TEST] | Late `import re` inside the new permission test (matches round-1 style note on sibling tests). Ruff clean. | `test_160_4_...py` | Optional cleanup. |

**Tests:** 152/152 green (8 story + 6 inline-epic guards + 138 regression sweep); RED→GREEN cycle verified for both rework tests (2 failed before `b9aa1be72`, 0 after). Preflight: ruff clean, zero smells, tree clean, commits `7f339151a`/`b9aa1be72` GPG-signed `G`.

**Data flow traced (round 2 delta):** hostile shard bytes → `read_text(encoding="utf-8")` → typed catches → `warnings.warn` (filename always; full path only via OS errno text) → stderr/TUI; payload path unaffected, sibling epics flow through merge → WebSocket as before. No injection sink.

### Devil's Advocate (Round 2)

Assume the rework is still broken. The exception taxonomy: `read_text(encoding="utf-8")` raises FileNotFoundError (silent — but is silent right? Yes: merge warns "not found" for referenced shards, AC4-pinned, and the TOCTOU deletion race lands there correctly), PermissionError/IsADirectoryError/EIO (all OSError → warn branch, two probed live), and UnicodeDecodeError (probed live). LookupError on a bad encoding name is impossible — the literal "utf-8" is hardcoded. MemoryError on a gigantic shard is out of any reasonable threat model for operator-owned local YAML. Could the exception ORDER betray us? `except FileNotFoundError` precedes `except (OSError, UnicodeDecodeError)`; reversed, missing files would warn "Failed to read" and break AC4 — the order is correct and AC4's negative assertion would catch a future swap. Could warnings be filtered out in production so "fail loud" is still silent? Python's default filter shows UserWarning once per call site — the first occurrence surfaces, which is the convention shard_merge.py already relies on; not a defect of this diff. Could the new warn-on-OSError over-warn during the orphan-scan glob on files that vanish mid-scan? Only via the FileNotFoundError branch — silent. The one residue I can manufacture: a shard readable but containing a UTF-16 BOM decodes as garbage YAML and lands in the parse branch — warned correctly. I cannot construct an input class that crashes fetch_sprint or vanishes silently through `_load_file` anymore. The remaining silent reads (index, archive, benchmark panels) are pre-existing, enumerated, and filed as Delivery Findings — not this story's diff.

**Verdict rationale:** Zero Critical/High. Both blocking-class findings closed with empirical verification + pinned tests. Remaining items are LOW polish or pre-existing module debt captured as Delivery Findings.

**Handoff:** To Stilgar (SM) for finish — PR creation and merge.