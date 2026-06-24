---
story_id: "160-13"
jira_key: ""
epic: "160"
workflow: "tdd"
---
# Story 160-13: Shard-ref path containment: epic refs from sprint YAML build paths without resolve()/containment check (CWE-22) in shard_merge.py and ws_push.py (from 160-4 review finding)

## Story Details
- **ID:** 160-13
- **Jira Key:** (none)
- **Workflow:** tdd
- **Stack Parent:** none

## Workflow Tracking
**Workflow:** tdd
**Phase:** finish
**Phase Started:** 2026-06-24T20:43:11Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-06-24T20:16:27Z | 2026-06-24T20:18:33Z | 2m 6s |
| red | 2026-06-24T20:18:33Z | 2026-06-24T20:28:30Z | 9m 57s |
| green | 2026-06-24T20:28:30Z | 2026-06-24T20:33:20Z | 4m 50s |
| review | 2026-06-24T20:33:20Z | 2026-06-24T20:43:11Z | 9m 51s |
| finish | 2026-06-24T20:43:11Z | - | - |

## Delivery Findings

Agents record upstream observations discovered during their phase.
Each finding is one list item. Use "No upstream findings" if none.

**Types:** Gap, Conflict, Question, Improvement
**Urgency:** blocking, non-blocking

<!-- Agents: append findings below this line. Do not edit other agents' entries. -->

### TEA (test design)
- **Gap** (blocking): The story title names two files, but `ws_push.py` has TWO unchecked
  sites, not one. Affects `pennyfarthing-dist/src/pf/frame/ws_push.py:227` (the `ref_by_id`
  pre-merge `_load_file(sprint_dir / f"epic-{ref}.yaml")`) **and** `ws_push.py:278`
  (`shard_path = archive_dir / f"epic-{epic_ref}.yaml"` in the archive loop, read via
  `.read_text()`). Plus `shard_merge.py:62`. Dev must add the containment check at **all
  three** sites — fixing only `shard_merge` leaves the `ref_by_id` read (227) and the
  archive read (278) escaping. The integration tests pin 227+merge and 278 respectively.
- **Improvement** (non-blocking): The real exploit is symlink-based, not bare `../`. A bare
  `../` ref is accidentally gated out today by the `epic-` prefix + OS path-walk semantics
  of `.exists()`/`.is_file()` (no on-disk `epic-..` dir to traverse). The fix MUST use
  `Path.resolve()` for the containment check (resolves symlinks); a purely lexical `..`
  check would not catch the symlink vector. Affects all three sites.
  *Found by TEA during test design.*

### Dev (implementation)
- No upstream findings during implementation. (TEA's "ws_push has two sites" Gap was
  confirmed and fixed — all three sites now guarded; nothing new surfaced.)

### Reviewer (code review)
- **Gap** (blocking): Two MORE unguarded CWE-22 read sites of the same class exist OUTSIDE
  this story's named files (`shard_merge.py`/`ws_push.py`), so they are out of scope here
  but must be swept. Affects `pennyfarthing-dist/src/pf/sprint/loader.py:326`
  (`get_archived_stories` — `archive_dir / f"epic-{epic_ref}.yaml"` from `completed_epics`,
  `.exists()`-gated then `load_yaml_config` read; stories surface to `pf sprint status`/
  `backlog`/`reconcile`) and `pennyfarthing-dist/src/pf/sprint/archive_epic.py:193`
  (`load_archive`, read-and-return) **and** `archive_epic.py:144` (`backfill_epic_refs`,
  symlink would redirect a `_write_yaml_file`). Verified by Reviewer (read the source, not
  just the subagent claim). Fix: apply `is_safe_shard_path(shard_path, archive_dir)` before
  the `.exists()` at each. Follow-up story filed (see Reviewer Assessment). *Found by Reviewer during code review.*
- **Gap** (non-blocking): `merge_epic_shards`' own orphan-scan loops read shards found via
  `sprint_dir.glob("epic-*.yaml")`; an attacker-planted symlink FILE named `epic-*.yaml`
  inside `sprint_dir` is read out-of-bounds (Reviewer reproduced: `outside/secret.yaml` was
  read). Lower severity — content is NOT merged into the returned epics (only used to derive
  an "unindexed shard" warning) and it requires planting a symlink file (FS-write capability).
  Affects `pennyfarthing-dist/src/pf/sprint/shard_merge.py` (orphan loop ~line 105 and
  `detect_orphan_shards` ~line 181). Roll into the same sweep follow-up. *Found by Reviewer during code review.*
- **Improvement** (non-blocking): pre-existing broad `except Exception` around the `load_file`
  call in `merge_epic_shards` (now adjacent to the new guard) swallows every loader failure
  (incl. MemoryError) into warn+skip — rule #1 / SOUL #10. Narrow to
  `(OSError, UnicodeDecodeError, ValueError)` in a future pass; not introduced by this diff.
  Affects `pennyfarthing-dist/src/pf/sprint/shard_merge.py` (load_file call site). *Found by Reviewer during code review.*
- **Question** (non-blocking): TOCTOU between `is_safe_shard_path` resolve-check and the
  actual open — theoretical on a single-user local tool (sprint dir is the user's own;
  no privilege boundary crossed). Documented residual, no action required for this threat model. *Found by Reviewer during code review.*

## Design Deviations

Agents log spec deviations as they happen — not after the fact.
Each entry: what was changed, what the spec said, and why.

<!-- Agents: append deviations below this line. Do not edit other agents' entries. -->

### TEA (test design)
- **Two preservation guards are intentionally GREEN on HEAD**
  - Spec source: context-story-160-13.md (no ACs recorded; title defines intent — "containment check, CWE-22")
  - Spec text: "epic refs ... build paths without resolve()/containment check (CWE-22)"
  - Implementation: `test_benign_ref_still_loads` and `test_lexical_dotdot_ref_stays_contained` pass today (not RED). The benign one guards that containment must not reject legit refs. The lexical one pins that a bare `../` ref is currently safe (gated by `.exists()`/`epic-` prefix) and must STAY safe after the fix introduces `resolve()` — i.e. resolve() must not convert the currently-safe lexical case into a leak.
  - Rationale: per `ac-as-green-regression-guard`, a "behavior X stays safe/unchanged" requirement is correctly green-on-HEAD; forcing a spurious RED would be dishonest. The three symlink tests carry the genuine RED.
  - Severity: minor
  - Forward impact: none — Dev should keep all five tests; the two green ones are regression guards, not pending work.
- **Symlink vector chosen over bare `../` for the RED demonstration**
  - Spec source: context-story-160-13.md, title (CWE-22)
  - Spec text: "build paths without resolve()/containment check (CWE-22)"
  - Implementation: RED tests exploit an in-dir symlink (`epic-link -> outside`) + a crafted ref, rather than a bare `../../../` ref.
  - Rationale: a bare `../` ref is gated out by `.exists()` today (the `epic-` prefix means the OS path-walk needs a real `epic-..` dir, which doesn't exist) so it produces no actual out-of-bounds read — it cannot drive a faithful RED. The symlink case reads out-of-bounds against HEAD (verified) and is exactly the case `.resolve()` is required to catch.
  - Severity: minor
  - Forward impact: Dev's containment check must use `resolve()` (not a lexical prefix compare) to satisfy the symlink tests.

### Dev (implementation)
- **Skip+warn on a traversal ref, not a raised exception / `{success: False}` result object**
  - Spec source: Sm Assessment ("return a fail-loud result object per issue #50"); tests `test_160_13_*`
  - Spec text: "On violation, return a fail-loud result object per issue #50 — do not silently skip."
  - Implementation: A non-contained ref is skipped via `continue` and surfaced with `warnings.warn(...)` (consistent with `merge_epic_shards`' existing missing/orphan warnings). `merge_epic_shards` still returns the merged data; `fetch_sprint` still returns its payload.
  - Rationale: Neither `merge_epic_shards` (returns merged data) nor `fetch_sprint` (returns a panel payload) is a result-object API — raising or returning `{success: False}` would break their contracts and the sibling tests (160-4 asserts `warnings.warn`; `fetch_sprint` must still return a payload). TEA's tests require "not read / not leaked / payload still returned", which skip+warn satisfies. The SM note explicitly marked the surfacing mechanism "Dev's call". This is surfaced (warn), not silent.
  - Severity: minor
  - Forward impact: none — the read is refused and the operator gets a warning naming the offending ref.
- **Shared public helper `is_safe_shard_path` rather than three inline checks**
  - Spec source: SOUL.md #2 (One Truth, One Place); story title (two files)
  - Spec text: "epic refs from sprint YAML build paths without resolve()/containment check (CWE-22) in shard_merge.py and ws_push.py"
  - Implementation: Added `is_safe_shard_path(candidate, base_dir)` to `shard_merge.py` (the canonical shard module) and imported it into `ws_push.py`; applied at all three sites.
  - Rationale: One containment definition for every shard-path read avoids drift between the three sites; `ws_push` already imports from `shard_merge`.
  - Severity: minor
  - Forward impact: any future shard-ref read should reuse `is_safe_shard_path` rather than re-deriving the check.

### Reviewer (audit)
- **TEA — "Two preservation guards are intentionally GREEN on HEAD"** → ✓ ACCEPTED by Reviewer: correct application of `ac-as-green-regression-guard`; a "stays-safe/unchanged" property is properly green-on-HEAD. The guards are meaningful (assert concrete merged ids / read paths), not vacuous.
- **TEA — "Symlink vector chosen over bare `../`"** → ✓ ACCEPTED by Reviewer: independently verified — the `epic-` prefix + OS path-walk gates out bare `../` at `.exists()`, so the symlink is the only faithful RED. The fix's use of `resolve()` (not a lexical compare) is exactly what this vector demands; confirmed it catches the symlink and rejects null-byte/absolute injection.
- **Dev — "Skip+warn, not a raised/result-object error"** → ✓ ACCEPTED by Reviewer: sound. Neither `merge_epic_shards` (returns merged data) nor `fetch_sprint` (returns a payload) is a result-object API; raising would break their contracts and the 160-4 warning tests. The traversal ref IS surfaced (warn in merge_epic_shards), so it is not a silent drop. SM's "result object" note was explicitly Dev's call.
- **Dev — "Shared public helper `is_safe_shard_path`"** → ✓ ACCEPTED by Reviewer: aligns with SOUL #2; one containment definition for all shard-path reads. As a bonus it gives the follow-up (loader.py / archive_epic.py sweep) a ready-made primitive — exactly the central-hardening shape I'd ask for.

## Sm Assessment

**Story:** 160-13 — Shard-ref path containment (CWE-22). Security follow-up from the 160-4 review. 1 pt, but explicitly tagged `tdd` (phased), so we run TEA → Dev → Reviewer. Repo: `pennyfarthing` (gitflow → `develop`).

**The vulnerability (confirmed):** Epic refs read from sprint YAML are interpolated into filesystem paths without `resolve()`/containment validation, so a crafted ref escapes the sprint base dir.

- `pennyfarthing-dist/src/pf/sprint/shard_merge.py:62` — `shard_file = sprint_dir / f"epic-{ref}.yaml"`. `ref` flows from `data["epics"]` (sprint YAML) unchecked. A ref like `../../../etc/passwd` or `../secrets` escapes `sprint_dir`.
- `pennyfarthing-dist/src/pf/frame/ws_push.py` — sibling pattern building a shard/epic path from a ref; locate the exact line during RED.

**Fix direction (Dev's call, not mine):** after constructing the candidate path, `resolve()` it and assert it stays within the resolved base dir (e.g. `base in candidate.resolve().parents` / `is_relative_to`). On violation, return a fail-loud result object per issue #50 — do not silently skip. Keep it to these two sites; no unrelated refactors.

**TEA (RED):** Write a failing test that feeds a traversal ref (`../`-style) through the shard-merge path and asserts it is rejected / does not read outside the sprint dir. Define the ACs the YAML lacks. Two call sites means likely two tests.

**Routing:** Handing off to TEA for the RED phase. No PR/merge from sub-phases — Reviewer reviews, SM owns finish ceremony.

## TEA Assessment

**Tests Required:** Yes
**Reason:** Security fix (CWE-22 path containment) — the property must be pinned by tests.

**Test Files:**
- `pennyfarthing-dist/src/pf/tests/test_160_13_shard_ref_path_containment.py` (new) — 5 tests.

**Tests Written:** 5 tests (3 RED + 2 intentional green guards). No ACs in YAML; ACs defined below.
**Status:** RED confirmed — `3 failed, 2 passed, 0 errored` via scoped `uv run pytest src/pf/tests/test_160_13_shard_ref_path_containment.py -q`. Failures assert the security property (out-of-bounds read / leak), not imports.

**Acceptance Criteria (defined by TEA — YAML had none):**
- **AC1:** A crafted epic ref that resolves outside `sprint_dir` (symlink vector) must NOT be read or merged by `merge_epic_shards` (`shard_merge.py:62`).
- **AC2:** `fetch_sprint()` must not read/leak an out-of-`sprint_dir` shard for a traversal ref in `data["epics"]` — covers the `ref_by_id` pre-merge read (`ws_push.py:227`) and the merge.
- **AC3:** `fetch_sprint()` must not read/leak an out-of-`archive_dir` shard for a traversal ref in `archive_data["completed_epics"]` (`ws_push.py:278`).
- **AC4 (preservation):** Benign in-dir refs still load; a bare lexical `../` ref stays contained even after `resolve()` is introduced.

### Rule Coverage

| Rule (lang-review python) | Test(s) | Status |
|---------------------------|---------|--------|
| Path traversal / untrusted input → filesystem (CWE-22) | `test_symlink_ref_not_merged_by_merge_epic_shards`, `test_fetch_sprint_symlink_epic_ref_not_leaked`, `test_fetch_sprint_archive_symlink_ref_not_leaked` | failing (RED) |
| No over-application (legit refs preserved) | `test_benign_ref_still_loads` | green (guard) |
| Currently-safe path stays safe post-fix | `test_lexical_dotdot_ref_stays_contained` | green (guard) |

**Rules checked:** path-traversal/unsafe-read rule has 3 enforcement tests across all 3 sites; 2 preservation guards bound over-application.
**Self-check:** 0 vacuous tests — every test asserts a concrete leaked/merged id, a recorded read path, or a payload marker. No `let _ =`, no `assert True`, no always-None checks.

**Test design notes:**
- Path arithmetic verified empirically before writing (the `epic-` prefix + `.exists()` OS path-walk gates out bare `../`; symlink is the real vector — verified to leak against HEAD).
- Integration tests redirect `fetch_sprint` via `FRAME_PROJECT_DIR` (mirrors `test_160_4_fetch_sprint_malformed_shard.py`) and spy on `Path.read_text` to catch out-of-bounds reads that don't surface in the payload (notably `ws_push.py:227`).

**Handoff:** To Dev (Reverend Mother) for GREEN. Add the `resolve()`+containment check at all THREE sites (see Delivery Findings) — fixing only `shard_merge.py` will leave 2 integration tests red.

## Dev Assessment

**Implementation Complete:** Yes

**Files Changed:**
- `pennyfarthing-dist/src/pf/sprint/shard_merge.py` — added `is_safe_shard_path(candidate, base_dir)` (symlink-safe `resolve()` containment, fail-closed) and applied it in `merge_epic_shards` before the `exists()`/read (warns + skips on a non-contained ref).
- `pennyfarthing-dist/src/pf/frame/ws_push.py` — imported `is_safe_shard_path`; guarded the `ref_by_id` pre-merge read (was line 227) and the archive loop read (was line 278) against `sprint_dir` / `archive_dir` respectively.

**Approach:** All three TEA-identified sites guarded by one shared helper (SOUL #2). The check uses `Path.resolve()` so symlink traversal is caught — a lexical `..` compare would not be. Fails closed on resolution error.

**Tests:** GREEN — new file `5/5` passing (3 RED→GREEN + 2 guards still green). Regression set (sibling shard_merge/fetch_sprint/loader/yaml_io/validator/panel consumers) all pass:
- `test_160_13_shard_ref_path_containment.py` + 160-4 + 156-4 + epic_shard_validation + tour_practice: `122 passed, 2 skipped`.
- yaml_io + sprint_validator + 151-3 + 153-4 + 156-1 add/update shards + sprint_panel(_provenance): `210 passed, 1 skipped`.
- `ruff check` on both changed files: clean.
- Missing-ref "not found" warning preserved (160-4 distinction intact); benign + lexical-`../` cases unchanged.

**Branch:** `feat/160-13-shard-ref-path-containment` (pushed to origin, pennyfarthing/develop base).

**Self-review (judgment checks):**
- [x] Wired into the live read paths (`merge_epic_shards` + both `fetch_sprint` reads) — not a dead utility.
- [x] Follows project patterns (warns like the existing shard warnings; `is_relative_to` containment).
- [x] All ACs met (AC1 shard_merge, AC2 ws_push:227+merge, AC3 ws_push:278 archive, AC4 preservation).
- [x] Error handling: fail-closed on `resolve()` error; reads refused + surfaced via warning.

**Handoff:** To Reviewer (Leto II) for adversarial review. Note: surfacing is skip+warn, not a raised/result-object error — see Dev Design Deviation (the functions are not result-object APIs; TEA's tests require the payload still returns). Possible Reviewer interest: `detect_orphan_shards` (shard_merge.py) and `loader.py`/`yaml_io.py` build the same `epic-{ref}.yaml` paths from already-merged epic ids — those refs are post-containment (a layer removed) and only `.exists()`-gated (no content read), so left unguarded as out of scope; flag if a follow-up is wanted.

## Subagent Results

| # | Specialist | Received | Status | Findings | Decision |
|---|-----------|----------|--------|----------|----------|
| 1 | reviewer-preflight | Yes | findings | 1 (cosmetic) | confirmed 0, dismissed 0, deferred 1 (LOW warning-gap note) |
| 2 | reviewer-edge-hunter | No | Skipped | disabled | Disabled via settings — edges enumerated by Reviewer |
| 3 | reviewer-silent-failure-hunter | No | Skipped | disabled | Disabled via settings — assessed by Reviewer |
| 4 | reviewer-test-analyzer | No | Skipped | disabled | Disabled via settings — test quality assessed by Reviewer |
| 5 | reviewer-comment-analyzer | No | Skipped | disabled | Disabled via settings — docs assessed by Reviewer |
| 6 | reviewer-type-design | No | Skipped | disabled | Disabled via settings — types assessed by Reviewer |
| 7 | reviewer-security | Yes | findings | 4 (2 high, 2 low) | confirmed 4, dismissed 0, deferred 4 to follow-up (all out-of-diff/threat-model) |
| 8 | reviewer-simplifier | No | Skipped | disabled | Disabled via settings — complexity assessed by Reviewer |
| 9 | reviewer-rule-checker | No | Skipped | disabled | Disabled via settings — rule compliance done by Reviewer below |

**All received:** Yes (2 enabled subagents returned; 7 disabled via `workflow.reviewer_subagents`, pre-filled as Skipped)
**Total findings:** 0 blocking-for-this-PR confirmed; 4 confirmed sibling/residual findings deferred to follow-up story 160-14 (2 high CWE-22 out-of-diff, 1 low orphan-glob, 1 low TOCTOU) + 1 LOW cosmetic warning-gap note.

## Reviewer Assessment

**Verdict:** APPROVED

**Summary:** The three in-scope CWE-22 read sites (`shard_merge.py` merge loop, `ws_push.py` ref_by_id pre-merge read, `ws_push.py` archive loop) are correctly and completely guarded by one shared, symlink-safe `is_safe_shard_path` helper. No bypass survived adversarial probing. All five tests green; full regression set green; ruff clean. No Critical/High issue exists **within the diff**. Two pre-existing same-class sites in OTHER files (`loader.py`, `archive_epic.py`) and the orphan-glob loops are real but out of this story's named scope — captured as Delivery Findings and filed as follow-up **160-14**.

**Data flow traced:** untrusted `ref`/`epic_ref` (sprint/archive YAML) → `base_dir / f"epic-{ref}.yaml"` → `is_safe_shard_path` (`resolve()` + `is_relative_to`, fail-closed) → read only if contained. Safe: the read is gated on resolved containment, so a symlink-routed ref is refused before `exists()`/`read`.

### Rule Compliance (lang-review python.md)

- **#5 Path handling (CWE-59 — `resolve()` before security checks):** COMPLIANT. `is_safe_shard_path` calls `candidate.resolve()` and `base_dir.resolve()` before `is_relative_to`. Both sides resolved. The reads themselves keep `encoding="utf-8"` (existing `_load_file`/`load_yaml_config`); the diff adds no new `open()` without encoding. ✓
- **#11 Input validation (CWE-22 — file paths from input checked against allowed dirs):** COMPLIANT for all 3 in-scope sites (enumerated: merge loop, ref_by_id, archive loop — each guarded). VIOLATION (pre-existing, out-of-diff) at `loader.py:326`, `archive_epic.py:193`/`:144`, and `shard_merge` orphan-glob — deferred to 160-14.
- **#1 Silent exception swallowing:** The NEW helper uses a typed `except (OSError, ValueError, RuntimeError)` returning False (fail-closed) — COMPLIANT and appropriate for `resolve()` failure modes. Pre-existing broad `except Exception` around `load_file` is noted as a non-blocking Improvement (not introduced here).
- **#6 Test quality:** COMPLIANT. Every test asserts concrete values (merged ids, recorded read paths, payload markers). No `assert True`, no bare-truthy, no assertion-free tests. The 2 green guards are intentional and documented (not vacuous). `read_recorder` monkeypatch is fixture-scoped (auto-undone). ✓
- **#3 Type annotations:** COMPLIANT. `is_safe_shard_path(candidate: Path, base_dir: Path) -> bool` fully annotated at the module boundary. ✓
- **#2/#7/#8/#9/#10/#12:** N/A to this diff (no mutable defaults, no new resources without context managers, no new deserialization of untrusted input, no async, no star imports, no dependency changes).

### Observations (tagged by source)

1. `[SEC]` `[RULE]` **[HIGH→deferred]** `loader.py:326` `get_archived_stories` reads archive shards from `completed_epics` refs with no containment — same CWE-22 vector, surfaces to `pf sprint status`/`backlog`/`reconcile`. Verified by reading source. Out-of-diff → follow-up 160-14. (Note: Dev's handoff guessed loader.py was "no content read" — that's the merge-time `loader.py:58`; the **archive** read at :326 *does* read+surface. Corrected here.)
2. `[SEC]` `[RULE]` **[HIGH→deferred]** `archive_epic.py:193` `load_archive` (read-and-return) + `:144` `backfill_epic_refs` (write redirect via symlink). Same class. Follow-up 160-14.
3. `[SEC]` **[LOW→deferred]** orphan-glob loops in `shard_merge.py` (~105) + `detect_orphan_shards` (~181) read a planted symlink FILE out-of-bounds; content not merged (warning-only), needs FS-write capability. Reviewer reproduced. Follow-up 160-14.
4. `[SEC]` **[LOW]** TOCTOU between resolve-check and open — theoretical on a single-user local tool (no privilege boundary). Documented residual; no action.
5. `[VERIFIED]` Containment is bypass-resistant — evidence: absolute-path injection neutralized (`f"epic-{ref}.yaml"` always starts with `epic-`, so the `/` operator never treats `ref` as a root; `/etc/passwd` → `sprint/epic-/etc/passwd.yaml`, contained); null-byte ref → `resolve()` raises `ValueError` → caught → False (fail-closed); `candidate == base_dir` structurally impossible (always a `/epic-*.yaml` child). Confirmed experimentally and corroborated by reviewer-security.
6. `[VERIFIED]` Guard ordering correct at all 3 sites — evidence: `shard_merge.py:78` guard precedes `.exists()`; `ws_push.py:227` guard precedes `_load_file`; `ws_push.py:283` guard precedes `.is_file()`. The unsafe path is never stat'd/opened.
7. `[VERIFIED]` No regression to benign/missing/lexical paths — evidence: `122 passed`+`210 passed` scoped regression incl. `test_160_4` (malformed-shard "not found" warning preserved), `test_epic_shard_validation` (loader path), `test_156_4` (inline epics). `[TEST]` test-analyzer disabled, assessed here: coverage maps 1:1 to the 3 sites + 2 preservation properties.
8. `[EDGE]` (subagent disabled — enumerated by Reviewer): empty ref `""`→`epic-.yaml` contained, not found; `..` ref→`epic-..yaml` contained; deeply-nested traversal→rejected by resolve(). No unhandled edge.
9. `[SILENT]` (disabled — assessed): the new helper's catch is fail-CLOSED (safe direction) and the traversal ref is surfaced via `warnings.warn` in `merge_epic_shards`; ws_push ref_by_id's silent `continue` is non-silent in aggregate (merge warns the same ref). LOW cosmetic.
10. `[TYPE]` (disabled — assessed): `bool` return, `Path` params — clean, no stringly-typed surface. `[DOC]` (disabled — assessed): helper docstring is accurate (explains CWE-22 + why resolve() over lexical); test docstring accurately explains symlink-vs-lexical. `[SIMPLE]` (disabled — assessed): minimal — one helper, three call sites, no over-engineering. Could the orphan sweep have been folded in? Yes, but correctly deferred to keep this story scoped.

### Devil's Advocate

Let me argue this code is broken. First attack: the containment check resolves `candidate` and compares against `base_dir.resolve()`, but the *read* happens on a separately-evaluated path object moments later — a classic TOCTOU. A malicious actor races the check, swapping `epic-42.yaml` for a symlink to `/etc/shadow` after `is_safe_shard_path` returns True but before `load_file` opens it. **Rebuttal:** to win that race the attacker must already have write access to the project's `sprint/` directory — i.e. local filesystem write as the same user running `pf`. At that point they can simply overwrite any source file or sprint YAML directly; no privilege boundary is crossed. On a single-user dev tool this is self-inflicted, not a vulnerability. Documented as a residual (finding 4).

Second attack: what if a confused user has a legitimately symlinked sprint directory (e.g. `sprint` itself is a symlink into a synced drive)? Does `resolve()` over-reject and silently drop their real epics? **Rebuttal:** `base_dir.resolve()` resolves the *same* symlinks as `candidate.resolve()`, so a shard genuinely inside the (symlinked) sprint dir still passes `is_relative_to`. The benign and missing-file tests confirm legit refs load and the "not found" warning still fires. No over-rejection.

Third attack: a stressed filesystem — `resolve()` hitting `ELOOP` (symlink cycle) or `ENAMETOOLONG`. **Rebuttal:** those raise `OSError`, caught → returns False → the ref is skipped with a warning. Fail-closed: a pathological path is treated as unsafe, never read. Correct direction.

Fourth attack: config with unexpected shapes — a non-string ref, a ref that is an int, a `completed_epics` entry that is a dict. **Rebuttal:** the merge loop guards `isinstance(ref, str)`; ws_push's loops likewise. A non-string never reaches path construction. An f-stringified odd value would just produce a contained, non-existent filename.

Where the devil DOES land: the story fixes its three named sites but leaves *four* structurally identical reads (`loader.py`, `archive_epic.py` ×2, orphan-glob) wide open. A reviewer who rubber-stamps "CWE-22 fixed" would be wrong — the *class* is not eradicated, only three instances. That is the real residual risk, and it is why 160-14 is filed as a blocking-for-that-story sweep rather than a vague note. The map (3 green tests) is not the territory (5 vulnerable sites).

**Pattern observed:** clean reusable security primitive (`is_safe_shard_path`) at `shard_merge.py:17` — the right shape; the follow-up sweep reuses it verbatim.
**Error handling:** fail-closed on resolution error (`shard_merge.py:29-31`); traversal ref surfaced via `warnings.warn` (`shard_merge.py:79`).
**Deviations:** all 4 logged deviations audited → ACCEPTED (see Reviewer audit).
**Follow-up filed:** story **160-14** (p2, tdd) — sweep `loader.py:326`, `archive_epic.py:193`/`:144`, orphan-glob loops with `is_safe_shard_path`.
**Handoff:** To SM (Stilgar) for finish-story.