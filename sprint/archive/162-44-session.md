---
story_id: "162-44"
jira_key: ""
epic: "162"
workflow: "tdd"
---
# Story 162-44: Complete the CWE-22 shard-path sweep (162-12 tail): archive_epic.archive_epic() ~547 FIRST (unguarded read + write + shutil.move — strictly worse than anything fixed, missed by every prior inventory); then validate/adapters/sprint.py:25-26, story_add.py:242, findings/aggregate.py x4, sprint/cli.py x5, epic_reindex.py:39, epic_add.py:88, yaml_io.py x3 (one write). Ship the architectural fix in the same pass: safe_shards() guarded iterator + safe_ref_path() helper so the invariant lives in the API, not convention. Also: add the warn convention to ws_push's three silent guard sites together; positive-path coverage for migrate_completed_archive; note TOCTOU/O_NOFOLLOW as an architect decision (from 162-12 review)

## Story Details
- **ID:** 162-44
- **Jira Key:** (none — Jira not configured)
- **Workflow:** tdd
- **Stack Parent:** none
- **Branch:** feat/162-44-cwe22-shard-path-sweep
- **PR:** (none yet — recorded when the PR is created)

## SM Assessment

**Spec:** the title IS the full spec (162-12 review). This is the TAIL of the CWE-22 shard-path sweep chain: 160-13 → 162-12 → this. 3 points; security-sensitive; carries a real architectural elevation. I read the code and the prior test suites; grounded below.

### The established convention (inherit it — do NOT invent a new one)
- `pf.sprint.path_validation.validate_shard_filename(ref)` / `validate_sprint_id(id)` — charset fail-closed (`[A-Za-z0-9._-]`, rejects `..`, empty), returns ref unchanged, raises `ValueError`.
- `pf.sprint.shard_merge.is_safe_shard_path(candidate, base_dir)` — `resolve()`-based **containment** check (160-13). The genuinely-exploitable vector is a **symlink inside** sprint/archive whose name matches, plus a ref/name routing through it; a lexical `..` check does NOT catch it, only `resolve()`. Bare `epic-../../x.yaml` is accidentally safe today (the `epic-` prefix glues to the first component so `.exists()` gates it) — that accidental safety must remain (regression pin).
- The skip convention: a candidate that fails is **SKIPPED, never opened/written**, and the skip is surfaced via `warnings.warn`. Fail closed.

### Deliverable A — the architectural fix (ship in the SAME pass; the point of the story)
The invariant currently lives in *convention* — every caller must remember to call `is_safe_shard_path`. Elevate it into the API so misuse is impossible:
1. **`safe_ref_path(base_dir, ref, *, prefix="epic-", suffix=".yaml")`** — validates `ref` (charset via `validate_shard_filename`) AND containment (`is_safe_shard_path` on the built path), returns the safe `Path`, or fail-closed (raise `ValueError` for the write/interpolation sites that must abort; the glob/loop sites use `safe_shards`). One function that BOTH interpolation flavours route through.
2. **`safe_shards(base_dir, pattern="epic-*.yaml")`** — guarded generator: globs `pattern` under `base_dir`, yields only paths that pass `is_safe_shard_path`, `warnings.warn`-ing on each skip. Replaces every raw `glob("epic-*.yaml")` / `glob("sprint-*-completed.yaml")` / `glob("initiative-*.yaml")` read loop.
- **Placement:** co-locate with `is_safe_shard_path` in `shard_merge.py` (or a thin `path_validation` addition that imports it) — whichever avoids an import cycle (162-30 caution: `pf.sprint.__init__` eagerly imports the CLI; keep the helper importable without dragging the CLI). Recommend `shard_merge.py` since `is_safe_shard_path` already lives there and it's imported widely.

### Deliverable B — route every listed site through the new API (archive_epic FIRST)
Order matters — `archive_epic.archive_epic()` first (strictly worst: unguarded read + write + `shutil.move`):
- **`archive_epic.py`**: `archive_epic()` builds `shard_file`/`archive_shard` from a validated `_get_epic_ref` (OK) — BUT the context-file loop at ~575 and ~607-610 interpolates the **raw** `epic.get('id','')` fallback into `context-epic-{id}.md` and `shutil.move`s it UNGUARDED. That is the "strictly worse" site. Also audit `migrate_completed_archive` (~177), `load_archive` (~235), `backfill_epic_refs` (~388-404 glob), `get_completed_epics` — route their `epic-{ref}` builds + globs through `safe_ref_path`/`safe_shards`.
- **`validate/adapters/sprint.py:25-26`** — `sprint_dir.glob("epic-*.yaml")` → `safe_shards`.
- **`story_add.py:242`** — ref→path build → `safe_ref_path`.
- **`findings/aggregate.py` ×4** — the four shard path builds/globs.
- **`sprint/cli.py` ×5**.
- **`epic_reindex.py:39`**, **`epic_add.py:88`**.
- **`yaml_io.py` ×3 (one is a WRITE — `write_sprint`'s `sprint_dir / f"epic-{ref}.yaml"` at ~428; a write to an escaped path is the worst case).**
- (The exact counts/lines drift — TEA/Dev must grep and confirm the live set; treat the spec's list as the floor, not the ceiling. If a site is already guarded, pin it and move on.)

### Deliverable C — ws_push's three SILENT guard sites
`frame/ws_push.py` already skips unsafe shards but does so **silently** at three sites (it uses `is_safe_shard_path` without the `warnings.warn` the convention requires). Add the warn convention to all three together so a skipped shard is surfaced, not swallowed (SOUL: no silent failure).

### Deliverable D — positive-path coverage for `migrate_completed_archive`
Add a test that `migrate_completed_archive` succeeds on a well-formed archive (the sweep's guards must not regress the happy path).

### Deliverable E — TOCTOU / O_NOFOLLOW: architect DECISION, not implementation
The `resolve()`-then-open containment check is TOCTOU-racy (symlink swapped between check and open) and doesn't use `O_NOFOLLOW`. Do NOT implement a full TOCTOU-safe open in this story. Instead, DOCUMENT the decision: record in the session (and a short code comment or ADR pointer) that TOCTOU/O_NOFOLLOW hardening is a deliberate deferral — the threat model here is local metadata-derived refs, not a concurrent attacker with write access to the sprint dir; note what a future hardening would take (`O_NOFOLLOW` + `openat`/dir-fd, or a re-check after open). Surface it as a filed follow-up rather than scope creep.

**TEA (RED):** per the 160-13/162-12 pattern — **symlink-based leak tests**, not bare `..`:
- For EACH site in Deliverable B: a symlink inside the sprint/archive dir + a crafted ref (or crafted shard filename for glob sites) that resolves OUTSIDE base → assert the site does NOT read/write/move the out-of-bounds target (fail-closed skip or ValueError). Verify each leaks against HEAD first (the test must be RED for the right reason).
- archive_epic: pin the raw-`epic.get('id')` context-file `shutil.move` specifically — a crafted epic `id` must not move a file outside `archive_dir`.
- The new API: `safe_ref_path` rejects unsafe ref (charset + symlink-containment) and returns the correct path for benign refs; `safe_shards` yields benign shards, skips+warns on a symlinked-out shard.
- Deliverable C: assert `warnings.warn` fires (e.g. `pytest.warns`) at each of ws_push's three skip sites.
- Deliverable D: positive-path `migrate_completed_archive` green.
- Regression pins: bare lexical `epic-../../x.yaml` stays contained; all benign refs/globs still work; the 160-13/162-12 suites stay green.

**Dev (GREEN):** build Deliverable A first, then route B/C through it, minimal. Preserve the fail-closed + `warnings.warn` convention verbatim. Don't touch `validate_shard_filename`/`is_safe_shard_path` semantics (inherited invariants). File the Deliverable-E TOCTOU follow-up.

**Constraints (binding):** edit **source** under `pennyfarthing-dist/src/pf/` — never `.pennyfarthing/`. SCOPED runs: the new test file + `test_160_13_shard_ref_path_containment.py` + `test_162_12_shard_ref_sweep.py` + `test_164_3_epic_shard_archive_path_hardening.py` + the archive_epic/yaml_io/findings/validate suites you touch. NEVER full suite. Result objects, not throws, at the CLI boundary (the helpers may raise ValueError internally — callers translate to `{success:False,error}` where that's the site's contract, per archive_epic's existing `except ValueError` pattern). `ruff check`. No import cycles (162-30).

## TEA Assessment

**Tests Required:** Yes
**Reason:** n/a

**Test Files:**
- `pennyfarthing/pennyfarthing-dist/src/pf/tests/test_162_44_cwe22_shard_path_sweep.py` — 50 tests: Deliverable A (new API contract), B (per-site symlink leak tests + preservation guards), C (ws_push warn convention), D (positive path), plus lexical regression pins.

**Tests Written:** 50 tests — 33 RED, 17 green (preservation guards / already-safe pins / positive path)
**Status:** RED (failing — ready for Dev)

**Scoped run:** `cd pennyfarthing/pennyfarthing-dist && uv run pytest src/pf/tests/test_162_44_cwe22_shard_path_sweep.py src/pf/tests/test_160_13_shard_ref_path_containment.py src/pf/tests/test_162_12_shard_ref_sweep.py src/pf/tests/test_164_3_epic_shard_archive_path_hardening.py -q`
→ `33 failed, 142 passed` — every failure is in the new file; 160-13 / 162-12 / 164-3 stay green. `ruff check` clean.

**API placement expectation:** `pf.sprint.shard_merge` — co-located with `is_safe_shard_path`, already imported by `loader`, `archive_epic`, `ws_push`; no `pf.sprint` package-level imports, so it stays importable without dragging in the CLI (162-30).

**RED inventory (proven leak at HEAD):**
| Site | Leak proven | Kind |
|------|-------------|------|
| `archive_epic.archive_epic` ~607 raw `epic['id']` | yes | out-of-sprint READ + DELETE + WRITE (`shutil.move`) |
| `yaml_io.write_sprint` ~420/~448 | yes | out-of-sprint **DELETE** (`stale.unlink()`) |
| `story_add.add_initiative_story` ~244 | yes | out-of-sprint READ + WRITE |
| `findings/aggregate.py` :93 / :117 / :119 / :135 | yes (×4) | out-of-bounds READ |
| `sprint/cli._resolve_epic_ref` (via `_epic_shard_path` :654) | yes | out-of-bounds READ |
| `sprint/cli._find_epic_in_initiatives` (`initiative-*` glob) | yes | out-of-bounds READ |
| `epic_reindex.reindex_epic` :39 | yes | out-of-bounds READ (+ persists traversal ref) |
| `validate/adapters/sprint._discover_files` :25-26 | yes | hands escapees to the validator |
| `ws_push.fetch_sprint` ×3 (~367/~416/~427) | n/a (already fail-closed) | **silent** skip — must `warnings.warn` |

**Already safe — pinned GREEN (no RED fabricated):**
`epic_add.add_epic` :88 · `yaml_io` ~428 shard write (`os.replace` replaces the symlink) · `archive_epic.migrate_completed_archive` / `load_archive` / `backfill_epic_refs` / `get_completed_epics` (guarded by 162-12).

**Handoff:** To Dev for implementation (build A first, then route B/C through it).

## Workflow Tracking
**Workflow:** tdd
**Phase:** finish
**Phase Started:** 2026-08-12T17:42:14Z
**Round-Trip Count:** 1

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-08-12T16:24:51Z | 2026-08-12T16:28:43Z | 3m 52s |
| red | 2026-08-12T16:28:43Z | 2026-08-12T16:37:46Z | 9m 3s |
| green | 2026-08-12T16:37:46Z | 2026-08-12T16:49:55Z | 12m 9s |
| review | 2026-08-12T16:49:55Z | 2026-08-12T17:21:28Z | 31m 33s |
| green | 2026-08-12T17:21:28Z | 2026-08-12T17:34:55Z | 13m 27s |
| review | 2026-08-12T17:34:55Z | 2026-08-12T17:42:14Z | 7m 19s |
| finish | 2026-08-12T17:42:14Z | - | - |

## Dev Assessment

**Implementation Complete:** Yes

**Deliverable A — new guarded API (built FIRST)**
- `pennyfarthing-dist/src/pf/sprint/shard_merge.py`
  - `safe_ref_path(base_dir, ref, *, prefix="epic-", suffix=".yaml")` — charset (`validate_shard_filename`) + `resolve()`-containment (`is_safe_shard_path`); returns the UNRESOLVED built path (drop-in for the raw interpolation), raises `ValueError` fail-closed.
  - `safe_shards(base_dir, pattern="epic-*.yaml")` — guarded generator; skips non-contained matches with `warnings.warn`; tolerates a missing base dir.
  - `is_safe_shard_path` / `validate_shard_filename` semantics unchanged (inherited invariants).
  - Deliverable E: TOCTOU / `O_NOFOLLOW` deferral + threat model documented in the `is_safe_shard_path` docstring, beside the containment check.

**Deliverable B — site → helper mapping**
| File | Site | Routed through |
|------|------|----------------|
| `sprint/archive_epic.py` | new `_safe_context_candidates()`; both context loops (dry-run ~576 + `shutil.move` ~607) | `safe_ref_path(..., prefix="context-epic-", suffix=".md")` on BOTH move ends (src `sprint/context/`, dst `archive_dir`) |
| `sprint/yaml_io.py` | `write_sprint` `old_indexed` build (~420) | `safe_ref_path` + warn-skip |
| `sprint/yaml_io.py` | `write_sprint` stale `stale.unlink()` (~448) | defensive `is_safe_shard_path` re-check before the irreversible delete |
| `sprint/story_add.py` | `add_initiative_story` `initiative-{slug}.yaml` (~244) | `safe_ref_path(..., prefix="initiative-")`, `ValueError` → `{success: False, error}`; the "available" glob → `safe_shards` |
| `findings/aggregate.py` | new `_safe_shard()`; sites :93 / :117 / :119 / :135 | `safe_ref_path` (lazy import, module import cycle) returning `None` to preserve the `if shard.exists()` skip shape |
| `sprint/cli.py` | shared `_epic_shard_path` (:654) — now `Path \| None` | `safe_ref_path`; 6 `shard.exists()` call sites guarded with `shard is not None`; the shard WRITE site (~864) raises `ClickException` |
| `sprint/cli.py` | 4 × `glob("initiative-*.yaml")` (~688 / ~807 / ~1094 / ~2022) | `safe_shards(sprint_dir, "initiative-*.yaml")`; ~2022 materialised to a list (truth-tested + iterated twice) |
| `sprint/epic_reindex.py` | `reindex_epic` :39 | `safe_ref_path`, `ValueError` → `{success: False, error}` |
| `validate/adapters/sprint.py` | `_discover_files` :25-26 (epic + initiative globs) | `safe_shards` (function-local import, mirrors `run()`'s deferred pattern) |

**Deliverable C — `frame/ws_push.py` `fetch_sprint`, 3 silent skips now surfaced**
- ~367 `ref_by_id` pre-merge loop → `warnings.warn`
- ~416 `sprint-*-completed.yaml` glob → replaced with `safe_shards` (warns on skip for free)
- ~427 `completed_epics` ref build → `warnings.warn`

**Deliverable D** — already-safe sites untouched and still green: `epic_add.add_epic` :88, `yaml_io` ~428 shard write (`os.replace`), `migrate_completed_archive` / `load_archive` / `backfill_epic_refs` / `get_completed_epics`.

**Tests:** GREEN across every scoped run:
- target + prior art (`162_44` + `160_13` + `162_12` + `164_3`): **175 passed** (was 33 failed / 142 passed) — all 50 target tests pass
- archive_epic / yaml_io / story_add suites: **135 passed, 1 skipped**
- cli / validate / findings / ws_push suites: **158 passed, 2 skipped**
- sharded-write + archive + epic-from-plan suites: **188 passed**

**Ruff:** `ruff check` clean on all 9 touched files. `ruff format --check` clean on the 5 files that were formatted at HEAD; the other 4 (`shard_merge`, `archive_epic`, `cli`, `ws_push`) were already unformatted at HEAD — verified via `ruff format --diff` that no hunk touches new code.

**Branch:** `feat/162-44-cwe22-shard-path-sweep` (pushed)


### Round 2 (post-review) — reviewer REJECTED round 1 and demonstrated two live leaks

**Fixed — demonstrated leaks (blockers), RED-first:**
| File | Site | Kind | Helper |
|------|------|------|--------|
| `sprint/cli.py` | `initiative_cancel` (~1396 build → ~1481 `open(init_file,"w")`) | **out-of-bounds WRITE** — the outside file was rewritten to `status: canceled`, exit 0 | `safe_ref_path(sprint_dir, name, prefix="initiative-")` → `ClickException` |
| `sprint/cli.py` | `initiative_show` (~1303) | **out-of-bounds READ** — `--json` printed outside contents | same guard |
| `sprint/yaml_io.py` | `write_sprint` string-ref branch (~447) | **persisted** an unvalidated traversal ref back into `current-sprint.yaml` | `safe_ref_path` + warn, ref dropped from the index rather than persisted |

**Deliverable A completed properly:** all **6** hand-rolled guard sites *inside* `shard_merge.py` now route through the new helpers — `merge_epic_shards` ref build + initiative glob + epic glob, and `detect_orphan_shards` ref build + initiative glob + epic glob. Two ref sites → `safe_ref_path`; four glob sites → `safe_shards`. The invariant now genuinely lives in the API, including for the module that defines it.

**`_epic_shard_path` annotated** `-> "Path | None"` with a `TYPE_CHECKING` import (module-scope imports kept minimal for CLI startup speed).

**TUI inventory result (item 5) — PROBED, all five sites LEAK, all now guarded.**
`tui/story_detail_data.py` was in no prior inventory. I probed it with a dedicated RED suite; **5 of 5** leak tests failed at HEAD for real, all reachable from normal TUI navigation (`sprint_panel`/`progress_panel` → `story_detail_screen` → `fetch_story_detail`). All are READs; there is no write/unlink/move in the file. Refs are category (b): `ws_push` ships `epic_data['id']` and the shard's `jira:` verbatim from `merge_epic_shards` to the TUI, so anything that can write sprint YAML controls them.

| Site | Build | Provenance | Helper |
|------|-------|-----------|--------|
| `_check_context_files` ~201 | `context-epic-{epic_num}.md` | `story_id.split("-")[0]` ← sprint YAML | `_safe_str_path(..., prefix="context-epic-", suffix=".md")` |
| `_check_context_files` ~210 | bare `glob("epic-*.yaml")` | glob name-match follows symlinks | `safe_shards` |
| `_check_context_files` ~225 | `context-epic-{jira_key}.md` | **worst**: raw text after `jira:` in shard YAML → file-content disclosure primitive | `_safe_str_path` |
| `_check_context_files` ~236 | `context-story-{story_id}.md` | sprint YAML story id | `_safe_str_path` |
| `_find_session_file` ~38/~63 | `{story_id}-session.md` / `{jira_key}-session.md` | sprint YAML id / jira key | `_safe_str_path(prefix="", suffix="-session.md")` |

New `_safe_str_path()` adapter bridges `safe_ref_path` to this module's `os.path` string paths; returns `None` (rendered as "no such file") rather than raising into the TUI event loop.

**LEFT for SM follow-up (per reviewer instruction, not fixed):**
- Stale **symlinked** shards are no longer cleaned up by `write_sprint` — the guard skips them, so a symlinked stale shard now lingers instead of being unlinked. Correct trade (never delete out of bounds) but it does leave litter.
- Charset rejection surfaces only as a `UserWarning` on the read/glob paths; refs that were previously "not found" are now a warning-plus-skip. Louder than before, quieter than an error.

**Round 2 test counts (every scoped run):**
| Scope | Result |
|-------|--------|
| target + new TUI suite + prior art (`162_44` + `162_44_tui` + `160_13` + `162_12` + `164_3`) | **187 passed** |
| TUI suites (`story_detail_data` consumers) | **191 passed** |
| cli / yaml_io / archive / story_add | **215 passed, 3 skipped** |
| shard_merge consumers (validate / findings / ws_push / frame) | **254 passed, 2 warnings** |
| sharded-write + archive + epic flows | **188 passed** |

New leak tests: **8 failed → passed** (3 in `test_162_44_cwe22_shard_path_sweep.py`, 5 in the new `test_162_44_tui_context_path_containment.py`), each verified to fail at HEAD for a real leak — the cancel test showed the outside file's `status: active` → `status: canceled`, the show test showed the outside path in the `open()` spy, the yaml_io test showed `link/epic-PWNED` persisted into the index.

**Ruff:** `check` clean on all round-2 files. `format --check` clean on `yaml_io`, `story_detail_data` (was clean at HEAD — kept clean) and both test files; `shard_merge` and `cli` were already unformatted at HEAD, verified via `ruff format --diff` that no hunk touches new code.

**Handoff:** To Reviewer

## Delivery Findings

Agents record upstream observations discovered during their phase.
Each finding is one list item. Use "No upstream findings" if none.

**Types:** Gap, Conflict, Question, Improvement
**Urgency:** blocking, non-blocking

<!-- Agents: append findings below this line. Do not edit other agents' entries. -->

### TEA (test design)
- **Gap** (blocking): `yaml_io.write_sprint`'s stale-shard cleanup is an out-of-bounds **DELETE**, not the write the spec anticipated. `old_indexed` is built from the *on-disk* index refs with a raw interpolation (`yaml_io.py:420` — no `_get_epic_ref`, no containment), then `stale.unlink()` fires unconditionally at `yaml_io.py:448-450`. A traversal ref left in `current-sprint.yaml` deletes an arbitrary file outside `sprint/`. Strictly worse than the ~428 write the spec flagged. Affects `pennyfarthing-dist/src/pf/sprint/yaml_io.py` (guard both the `old_indexed` build and the unlink). *Found by TEA during test design.*
- **Gap** (non-blocking): The ~428 **write** at `yaml_io.py` is already safe — `_get_epic_ref` charset-validates (no `/` possible) and `_write_yaml_file` uses `os.replace`, which replaces an escaping symlink rather than writing through it. Pinned green (`test_write_sprint_shard_write_stays_inside_sprint_dir`) so the refactor can't regress it. The spec's "one is a WRITE, the worst case" premise is wrong; the DELETE above is the real one. *Found by TEA during test design.*
- **Gap** (non-blocking): `story_add.py`'s real vector is `initiative-{slug}.yaml` at ~244 (the spec cited `:242` as a ref→path build). `initiative_slug` is a raw CLI argument and the file is read *and* dumped back — an out-of-bounds write. Needs `safe_ref_path(..., prefix="initiative-")`. *Found by TEA during test design.*
- **Gap** (non-blocking): `archive_epic`'s context-file move needs `safe_ref_path` with a **non-YAML** prefix/suffix (`context-epic-`/`.md`). Deliverable A's signature must parameterise both, not hardcode `epic-`/`.yaml`. Tests pin all three flavours (`epic-`, `initiative-`, `context-epic-`+`.md`). *Found by TEA during test design.*
- **Gap** (non-blocking): `sprint/cli.py` has **4** unguarded `glob("initiative-*.yaml")` loops (~673, ~792, ~1077, ~2005) plus the shared `_epic_shard_path` helper at ~654 — the spec said "×5" without locating them. All four globs route through one helper opportunity: `safe_shards(sprint_dir, "initiative-*.yaml")`. Only two are directly unit-testable (`_find_epic_in_initiatives`, `_resolve_epic_ref`); the other two sit inside Click commands and are covered transitively once the helper is guarded. *Found by TEA during test design.*
- **Improvement** (non-blocking): `archive_epic.migrate_completed_archive`, `load_archive`, `backfill_epic_refs` and `get_completed_epics` were listed for audit but are **already guarded** (162-12 fixed the first three; `get_completed_epics` reads via `load_sprint` → guarded `merge_epic_shards`). No RED fabricated for them; Deliverable D covers the positive path. Dev should route them through `safe_shards`/`safe_ref_path` only as a de-duplication, not a fix. *Found by TEA during test design.*
- **Improvement** (non-blocking): `epic_add.add_epic` (~88) is already safe via `_get_epic_ref`. Pinned green with a result-object assertion so routing it through `safe_ref_path` preserves `{success: False, error}` at the CLI boundary rather than letting a `ValueError` escape. *Found by TEA during test design.*
- **Question** (non-blocking): Deliverable E (TOCTOU / `O_NOFOLLOW`) is untestable without a concurrent-attacker harness, so no test was written — by design. TEA's containment tests all assert post-hoc filesystem state, which a TOCTOU race would defeat. Architect decision + follow-up story still owed per the spec.

### Reviewer (round-2 re-review)
- **Improvement** (non-blocking): The `safe_ref_path`-wrap-and-return-`None` adapter now exists in three places (`findings/aggregate._safe_shard`, `sprint/cli._epic_shard_path`, `tui/story_detail_data._safe_str_path`). A single `safe_ref_path_or_none` in `shard_merge.py` would stop a future fix landing in one and not the others. Affects those 3 files. *Found by Reviewer during round-2 code review.*
- **Improvement** (non-blocking): `safe_shards` warns per skipped match, and `_check_context_files` runs on every TUI story-detail repaint — one symlinked shard would emit a `UserWarning` per render. Consider a once-per-process warning or debug log on TUI render paths. Affects `pf/tui/story_detail_data.py`. *Found by Reviewer during round-2 code review.*
- **Gap** (non-blocking): Confirmed `story_finish.py`:1334/:1479 (`.session/{story_id}-session.md` and `-dialogue.md` from a raw CLI arg) is the same CWE-22 class, is untouched by round 2, and is correctly outside this story's sprint-shard scope. Needs its own story. Affects `pf/sprint/story_finish.py`. *Found by Reviewer during round-2 code review.*

### Reviewer (code review)
- **Gap** (blocking → **RESOLVED in round 2**, verified by re-running the original repro): The sweep's site inventory was derived from the 162-12 tail list and never independently swept `sprint/cli.py` for the `initiative-{name}.yaml` shape. `initiative_show` (:1303, read+echo) and `initiative_cancel` (:1389, read + `open(...,"w")`) both leak out of the sprint tree via an in-sprint symlink — the *identical* shape guarded in `story_add.py` :249 in this same story. Affects `pennyfarthing-dist/src/pf/sprint/cli.py` (route both through `safe_ref_path(..., prefix="initiative-")`). *Found by Reviewer during code review.*
- **Gap** (non-blocking): Zero test coverage anywhere in `src/pf/tests/` for `initiative_show` / `initiative_cancel` — which is why an unguarded read+write in a swept module survived TEA's RED inventory and Dev's GREEN. Affects the test suite (add symlink-leak + happy-path coverage for both commands). *Found by Reviewer during code review.*
- **Improvement** (non-blocking): Deliverable A's stated goal ("the invariant lives in the API, not convention") is only half-achieved — nine sites still hand-roll `is_safe_shard_path` + warn, including four inside `shard_merge.py` itself. A follow-up de-duplication story would let a future reader trust "if it isn't `safe_ref_path`/`safe_shards`, it's a bug". Affects `shard_merge.py`, `archive_epic.py`, `sprint/loader.py`. *Found by Reviewer during code review.*
- **Gap** (non-blocking): `pf/tui/story_detail_data.py` (:201/:210/:225) has the same unguarded `context-epic-{...}.md` + raw `glob("epic-*.yaml")` shape and appears in no CWE-22 inventory across 160-13 / 162-12 / 162-44. Needs its own story. *Found by Reviewer during code review.*
- **Question** (non-blocking): `write_sprint` :448 persists an unvalidated string ref into `current-sprint.yaml`. Is index-write validation intentionally out of scope for the sweep, or an oversight? `epic_reindex.py`'s guard comment treats ref persistence as part of the harm. *Found by Reviewer during code review.*


### Dev (implementation)
- **Gap** (non-blocking): `story_finish.py:1334` and `:1479` build `.session/{story_id}-session.md` and `.session/{story_id}-dialogue.md` (plus `{jira_key}-session.md` / `{jira_key}-dialogue.md` archive names) from a RAW CLI argument with no charset or containment guard, then read the files AND move them into `sprint/archive/`. Same CWE-22 shape and same filename family as the five sites closed in `tui/story_detail_data.py` this story. Affects `pennyfarthing-dist/src/pf/sprint/story_finish.py` (route through `safe_ref_path(base, story_id, prefix="", suffix="-session.md")` and the `-dialogue.md` equivalent, and guard the archive-name build). NOT fixed here: absent from TEA's inventory and the reviewer's list, and `story_finish` is a large module with its own suites — wants its own story with its own RED tests. *Found by Dev during round-2 rework while verifying no other sites of this class remained.*
- **Improvement** (non-blocking): `archive_epic.py:177`/`:235` and `loader.py:336` still use the hand-rolled `is_safe_shard_path` + `warnings.warn` pattern rather than `safe_shards`/`safe_ref_path`. They are functionally guarded (162-12) so this is de-duplication only — TEA explicitly scoped it out — but it means three more copies of the invariant survive outside the API that now owns it. *Found by Dev during round-2 rework.*
- **Question** (non-blocking): guarding `write_sprint`'s stale-shard cleanup means a stale shard that is a SYMLINK is now skipped rather than unlinked, so it lingers in `sprint/` indefinitely. Correct security trade (never delete out of bounds) but it converts a cleanup bug into a litter bug. Reviewer elected to file this as a follow-up rather than have it fixed here. *Found by Dev during round-2 rework.*

## Design Deviations

Agents log spec deviations as they happen — not after the fact.
Each entry: what was changed, what the spec said, and why.

<!-- Agents: append deviations below this line. Do not edit other agents' entries. -->

### TEA (test design)
- **Deliverable A imports are lazy, not module-level:** Spec implied normal imports of `safe_ref_path`/`safe_shards`. A module-level `from pf.sprint.shard_merge import safe_ref_path` would raise `ImportError` at *collection* time and take the whole file down, hiding all 14 site-sweep failures behind one error. Tests resolve both names via a `_new_api(name)` helper (`getattr` + assertion). Reason: RED must fail for the right reason, per-test.
- **ws_push warn assertions match on the escaping ref/path substring, not on message text:** Spec said "assert `warnings.warn` fires (e.g. `pytest.warns`)". Bare `pytest.warns(UserWarning)` would pass spuriously — `merge_epic_shards` already warns in the same call. Each of the three scenarios is constructed so only the target site can produce a warning (site 1 uses an inline-dict first epic so `merge_epic_shards` early-returns without warning), and the assertion requires a warning naming `epic-PWNED` / the archive filename. Reason: Dev's exact wording is unknown; the ref must appear in any usable message.
- **`epic_add`, `migrate_completed_archive`, `load_archive`, `backfill_epic_refs`, `get_completed_epics` and the `yaml_io` ~428 write are GREEN pins, not RED:** Spec listed them for sweeping. They are already guarded at HEAD — no leak is demonstrable. Per instruction, pinned green instead of fabricating a RED.
- **`yaml_io` RED targets the stale-shard `unlink()` (~420/~448), not the ~428 write:** see Delivery Findings. Reason: the write is already contained by `os.replace`; the delete is the actual leak.

### Dev (implementation)
- **`sprint/cli._epic_shard_path` now returns `Path | None`:** Spec said "guard the helper". The helper had 8 call sites; returning a sentinel-free `None` and updating each `shard.exists()` to `shard is not None and shard.exists()` was the smallest change that keeps every site fail-closed. Reason: raising from a helper called inside 6 read loops would abort whole listings on one bad ref.
- **`sprint/cli.py` shard WRITE site (~864, `_cancel_epic_in_initiatives`) raises `click.ClickException`, not a skip:** TEA's inventory only listed reads for cli. This site is an unguarded `open(shard, "w")` with no `exists()` gate, so a `None` from the guarded helper had to go somewhere. A silent skip would swallow a failed cancel write. Reason: fail loud on a refused write inside a Click command.
- **`yaml_io` got a SECOND guard at the `unlink()` itself, not just at the `old_indexed` build:** TEA's finding said guard both. The build-time `safe_ref_path` alone already closes the leak; the pre-unlink `is_safe_shard_path` re-check is belt-and-braces because a delete is irreversible.
- **`findings/aggregate._safe_shard` imports `safe_ref_path` lazily:** module-scope import of `pf.sprint.shard_merge` pulls `pf/sprint/__init__.py` → `pf.sprint.cli` → `pf.sprint.findings_cmd` → back into the still-initialising `aggregate` module. Same cycle already documented at that module's scope for `pf.sprint.session_parse` (162-30). Same reasoning for the function-local imports in `validate/adapters/sprint.py` and `sprint/cli.py`.
- **`archive_epic`'s two context loops share a new `_safe_context_candidates()` helper:** the dry-run and real loops built the same two candidate names from the same raw `epic['id']`. Guarding them independently would have let the two paths drift. Both ends of the `shutil.move` (source AND destination) are guarded, not just the source.
- **Did NOT route `archive_epic`'s `backfill_epic_refs` / `get_completed_epics` globs through `safe_shards`:** TEA confirmed they are already guarded (162-12) and flagged the change as de-duplication only. Skipped as scope creep; the unused import was removed.
- **Deliverable E documented in `is_safe_shard_path`'s docstring** rather than a separate ADR — it is the exact function the deferral is about, so the note sits where a future reader hits the race. SM owes the follow-up story.

### Reviewer (audit)
- **UNDOCUMENTED:** no deviation logged for leaving `sprint/cli.py`'s two raw `initiative-{name}.yaml` builds (`initiative_show` :1303, `initiative_cancel` :1389) unguarded while guarding the *identical* shape (`initiative-{slug}.yaml` from a raw CLI argument, read + write) in `story_add.py` :249. Both leak — see Reviewer Assessment CRITICAL/HIGH.

**Deviation stamps:**
- `_epic_shard_path` → `Path | None` — **ACCEPTED.** All 7 live call sites verified (`grep -n _epic_shard_path`): :701, :827, :1334, :1411, :1448, :2145 all gate on `shard is not None and shard.exists()`; :867 (the write) raises `ClickException`. No None-deref, no unguarded fallthrough.
- ClickException at the cli write site — **ACCEPTED.** Fail-loud on a refused write is correct; a silent skip would have swallowed a failed cancel.
- Second guard at the `unlink()` — **ACCEPTED.** Verified independently: both layers hold (probes A and B below).
- Lazy imports in `aggregate` / `validate/adapters/sprint` / `cli` — **ACCEPTED.** All 9 touched modules import cleanly; the 162-30 cycle rationale is real.
- TEA's "`yaml_io` ~428 write already safe via `os.replace`" — **ACCEPTED.** `os.replace(tmp, path)` replaces the symlink entry rather than writing through it; charset via `_get_epic_ref` blocks the lexical vector.
- Deliverable E in the docstring rather than an ADR — **ACCEPTED.** Threat model stated accurately.
- Skipping `backfill_epic_refs` / `get_completed_epics` as "scope creep" — **FLAGGED (Low).** The individual dismissal is correct (I verified containment is present at each), but the same reasoning left 9 hand-rolled guard sites in place — see Reviewer Assessment LOW.

## Subagent Results

Nine specialists were spawned in parallel at review start (preflight, security, edge-hunter, silent-failure-hunter, test-analyzer, comment-analyzer, simplifier, type-design, rule-checker). **None returned within the review window** (~18 min of waiting plus targeted nudge messages to five of them requesting interim reports). Rather than block the gate or — worse — attribute invented findings to specialists that never reported, I ran each specialist's verification category **myself, directly**, with real probes. Every finding below is my own first-hand evidence. Nothing is inferred from a specialist report.

**All received: No** — all 9 specialists timed out without returning (explicit error notation: `TIMEOUT — no result returned`). Every row is accounted for below, and every category was re-run first-hand by the Reviewer. I am deliberately **not** writing "All received: Yes", because it would be false; the gate should be resolved by SM on the strength of the direct verification, or the review re-run once the subagent transport is working.

| # | Specialist | Received | Status | Findings | Decision |
| 1 | reviewer-preflight | No — TIMEOUT | ran directly instead | 4 scoped suites **175 passed**; `ruff check` clean on all 10 touched files; repo-wide `ruff check src/pf/` = 94 errors — **identical count on `develop`** (verified in a scratch worktree), so zero lint regression | N/A — verified myself |
| 2 | reviewer-security | No — TIMEOUT | ran directly instead | **2 demonstrated leaks** at `sprint/cli.py`:1303 (OOB read) and :1389 (OOB **write**), both via an in-sprint symlink; routed sites all verified fail-closed with symlink + lexical probes | Confirmed → CRITICAL + HIGH |
| 3 | reviewer-edge-hunter | No — TIMEOUT | ran directly instead | No false positives (6 real-world ref shapes accepted, 5 hostile rejected); all 7 `_epic_shard_path` call sites handle `None`; `future()` correctly materialises the generator | Confirmed clean |
| 4 | reviewer-silent-failure-hunter | No — TIMEOUT | ran directly instead | Inner `except ValueError` in `write_sprint` fires before the outer `except Exception: pass`, so the `old_indexed` loop continues correctly (verified by probe — warning fired *and* the benign ref was still processed); `warnings.warn` at Click boundaries is weak but non-blocking | Confirmed → LOW |
| 5 | reviewer-test-analyzer | No — TIMEOUT | ran directly instead | **Tests are NOT vacuous**: neutered `safe_ref_path`/`safe_shards`/the pre-unlink recheck in a scratch copy → **26 of 50 failed**. The 24 that still pass are the declared positive-path and already-safe pins. Gap: **zero** tests anywhere for `initiative_show`/`initiative_cancel` | Confirmed → coverage gap |
| 6 | reviewer-comment-analyzer | No — TIMEOUT | ran directly instead | `_epic_shard_path`'s "every epic-shard read AND write in this module" is technically true but misleading (the *initiative*-shard builds at :1303/:1389 bypass it); `write_sprint`'s "GUARDED" comment overclaims given :448 | Confirmed → MEDIUM/LOW |
| 7 | reviewer-simplifier | No — TIMEOUT | ran directly instead | Nine hand-rolled guard sites not de-duplicated through the new helpers, four of them inside `shard_merge.py` itself; `_safe_shard`/`_epic_shard_path` are duplicate wrappers | Confirmed → LOW |
| 8 | reviewer-type-design | No — TIMEOUT | ran directly instead | `_epic_shard_path` is **unannotated** while its contract silently changed `Path` → `Path \| None`; `safe_ref_path` returns a bare `Path` indistinguishable from an unvalidated one, so "misuse is impossible" is not literally true | Confirmed → LOW |
| 9 | reviewer-rule-checker | No — TIMEOUT | ran directly instead | All rules **COMPLIANT** — see [RULE] below | Confirmed clean |

**[RULE] Project-rule verification (run directly):**
- *"Never edit `.pennyfarthing/` symlinked dirs — edit source at `pennyfarthing/pennyfarthing-dist/`"* — **COMPLIANT.** All 10 changed files are under `pennyfarthing-dist/src/pf/`; none is in a `never_edit` zone or a symlinked path per `.pennyfarthing/repos.yaml`.
- *"Return result objects `{success, data?, error?}` — don't throw"* — **COMPLIANT.** `epic_reindex.reindex_epic` → `{"success": False, "error": str(e)}` surfaced as `ClickException(result["error"])` (`epic_reindex.py`:154); `story_add.add_initiative_story` → result object checked at :405. Helpers raising `ValueError` internally is the pattern SM explicitly sanctioned. No `ValueError` escapes a result-object boundary.
- *Branch strategy — framework repo is gitflow, PRs target `develop`* — **COMPLIANT.** `develop` is an ancestor of HEAD; no orchestrator-repo file in the framework commits.
- *Commit format `<type>(<scope>): <subject>`* — **COMPLIANT.** `feat(162-44): ...` and `test: ...`.
- *"NEVER skip GPG/SSH commit signing"* — **COMPLIANT.** Both commits report `%G? == G` (good signature).
- *No import cycles (162-30)* — **COMPLIANT.** All 9 touched modules import cleanly in isolation.
- *Review is read-only* — **COMPLIANT.** Framework tree clean; all probe artefacts removed.
- *"Use `.js` extensions in relative TypeScript imports"* — **N/A** (Python-only diff).

## Reviewer Assessment

*(Round 2 — FINAL. Round-1 detail retained below as history.)*

**Verdict:** APPROVED

**Scope:** `git diff 81472605c..2a9c15877` only — 4 source files (`sprint/cli.py`, `sprint/shard_merge.py`, `sprint/yaml_io.py`, `tui/story_detail_data.py`) + 2 test files.

Both round-1 blockers are genuinely closed — I re-ran my **exact** round-1 repro scripts against round 2 and both now fail closed. The new `tui` sweep holds against my own symlink and lexical probes at all 8 sites, including the `context-epic-{jira_key}.md` content-disclosure primitive. Deliverable A is now actually complete. No new leak, no false positive, no regression.

### Round-1 blockers: re-verified against my original repro

Setup for both: in-sprint symlink `sprint/initiative-pwned.yaml → <outside>/target.yaml`.

| Round-1 finding | Round-1 result | Round-2 result |
|---|---|---|
| [CRITICAL] `initiative_cancel` OOB **WRITE** (`cli.py`:1398) | target rewritten to `status: canceled`, **exit 0** | `modified=False`, **exit 1**, `Error: Invalid initiative name: ... escapes ...` |
| [HIGH] `initiative_show` OOB **READ** (`cli.py`:1306) | printed `{"name": "TOP SECRET", ...}` | `leak=False`, **exit 1**, same fail-closed error |

Also probed the lexical vector (`initiative show/cancel ../../outside/lex`) — both rejected on charset with exit 1. And the benign path is intact: `initiative show tech-debt --json` exit 0 returning `Tech Debt`; `initiative cancel tech-debt --dry-run` exit 0. **No false positive.** Routing through `ClickException` (rather than a silent skip) is the right call for a command the user explicitly invoked, and matches Dev's own `:867` precedent.

### The new `tui` sweep — all 8 sites probed independently, all fail closed

`tui/story_detail_data.py`:326/:333 genuinely `open()` and read `epic_context_path` / `story_context_path`, so this really was a content-disclosure primitive, not just path disclosure. Every site verified with a real `os.symlink` **and** a lexical ref:

| Site | Probe | Result |
|---|---|---|
| `context-epic-{epic_num}.md` :223 | symlink → outside | closed (`path=''`) |
| `context-epic-{jira_key}.md` :246 — **the disclosure primitive** | symlink `context-epic-OP-99.md → outside`, shard `jira: OP-99` | closed |
| same, hostile ref inside the shard | shard `jira: ../../outside/secret` | closed (charset) |
| `glob("epic-*.yaml")` → `safe_shards` :236 | symlinked `epic-evil.yaml` → outside, whose `jira:` points at an *in-bounds* context file | closed, 1 warning — the symlinked shard is never opened, so the laundering path is cut |
| `context-story-{story_id}.md` :258 | symlink; and lexical `story_id` | closed (both) |
| `.session/{story_id}-session.md` :59 | symlink | closed |
| `sprint/archive/{story_id}-session.md` :80 | symlink | closed |
| `sprint/archive/{jira_key}-session.md` :86 | symlink; and lexical `jira_key` | closed (both) |
| end-to-end content read | symlinked epic **and** story context | closed — no path returned, so `:326`/`:333` never open anything |

**Methodology note:** my first `_find_session_file` run reported 4 false leaks. Cause was my own probe harness, not the code — `_find_session_file` walks up from CWD, and CWD was inside the real orc-penny repo, so it found the genuine `.session/162-44-session.md`. Re-run with CWD isolated in a bare tmp dir: **all 5 closed, all 3 preservation cases intact** (active → `is_archived=False`; archive-by-local-id and archive-by-jira-key → `is_archived=True`). Recording this because the mistake was mine and the corrected result is what the verdict rests on.

Choosing `None`-means-absent here (rather than raising) is right: these are display lookups on a TUI render path, and a `ValueError` into the event loop would be worse than rendering the doc as missing.

### Remaining round-2 verification

- **[SEC] `yaml_io` string-ref branch (:447)** — confirmed no longer persists a traversal ref. `write_sprint(idx, {"epics": ["42", "../../outside/evil", "ok-2"]})` → index contains `'42'` and `ok-2`, the traversal ref is **absent**, one warning fired, and nothing was created outside. Note this *drops* the offending ref from the index rather than round-tripping it — correct per "refuse to persist what we would refuse to read", it warns, and no `unlink` follows (the ref fails the `old_indexed` guard too, so it never enters the delete set).
- **[SEC] Deliverable A completeness** — the 6 hand-rolled guards inside `shard_merge.py` are gone; `merge_epic_shards` and `detect_orphan_shards` now route through `safe_ref_path`/`safe_shards`. No regression from the refactor: with a symlinked `epic-evil.yaml`, a symlinked `initiative-evil.yaml` and a traversal ref all present, `merge_epic_shards` returned only `['42']` (`PWNED` not leaked) and `detect_orphan_shards` listed only `epic-42.yaml`.
- **[SEC] False-positive sweep on the charset tightening.** `merge_epic_shards` previously applied containment *only*; it now also applies charset, so this was the highest regression risk in the diff. All 8 synthetic ref shapes merged 8/8 (`42`, `162`, `OP-1234`, `PROJ-12792`, `tour-practice`, `1.0`, `a_b`, `epic-40`), and I scanned **93 distinct real refs** out of this repo's `sprint/*.yaml` + `sprint/archive/*.yaml` through `validate_shard_filename` — **zero rejected**.
- **[TEST] Tests are not vacuous.** Neutered `safe_ref_path` / `safe_shards` / the pre-unlink recheck in a scratch copy: main suite **29 failed** (up from 26 in round 1 — the 3 new round-2 tests bind, including `test_initiative_show_must_not_read_outside_sprint_dir` and `test_write_sprint_does_not_persist_unvalidated_string_ref`); new tui suite **5 failed / 2 passed**, an exact match to the claimed "5 leak + 2 preservation".
- **[TYPE]** `_epic_shard_path` now annotated `-> "Path | None"` via `TYPE_CHECKING`, closing my round-1 LOW. Costs nothing at runtime — appropriate given CLI startup is on the hot path.
- **[RULE]** All 6 changed files under `pennyfarthing-dist/src/pf/`; no `never_edit` or symlinked path touched; result-object/`ClickException` contracts intact; framework tree clean; no import cycle (the new module-level `shard_merge` import in `tui/story_detail_data.py` resolves fine — that module already imported `pf.sprint.session_parse` at module scope).

### Known deferrals — confirmed genuinely out of scope, not newly broken
`story_finish.py`:1334/:1479 is **untouched** by round 2 (0 files matched). The sites build `.session/{story_id}-session.md` / `-dialogue.md` — same CWE class, but a different domain (`.session`, not sprint shards) with its own ownership; correctly filed as a Delivery Finding rather than swept here. Stale symlinked-shard litter and charset-rejection-as-`UserWarning` are unchanged and remain accepted LOWs.

### Non-blocking observations (do not gate the merge)
| Severity | Issue | Location |
|---|---|---|
| [LOW] | Third copy of the "wrap `safe_ref_path`, return `None`" adapter (`_safe_shard`, `_epic_shard_path`, now `_safe_str_path`). One shared `safe_ref_path_or_none` in `shard_merge.py` would end the drift risk. | `findings/aggregate.py`:57; `sprint/cli.py`:653; `tui/story_detail_data.py`:19 |
| [LOW] | `safe_shards` warns per skipped match inside `_check_context_files`, which runs on every TUI story-detail render — a single symlinked shard would emit a `UserWarning` on every repaint. | `tui/story_detail_data.py`:236 |

### Test + lint status (run myself)
- Target + tui + prior art (`162_44` + `162_44_tui` + `160_13` + `162_12` + `164_3`): **187 passed, 0 failed.**
- Broad consumer selection (sprint / shard / yaml_io / archive / story_add / findings / validate / ws_push / tui / epic / initiative / tour): **1422 passed, 3 skipped, 0 failed.**
- `ruff check` on all 6 round-2 files: **All checks passed.** Repo-wide **94** — byte-identical to the `develop` baseline, so still zero lint regression.
- 160-13 / 162-12 / 164-3 invariants intact; bare lexical `epic-../../x.yaml` still contained.

**Observations:** 2 new LOW findings; 2 round-1 blockers + 2 round-1 LOWs closed and re-verified by demonstration.

**Handoff:** To SM for finish-story. Follow-ups still owed: Deliverable-E TOCTOU/`O_NOFOLLOW`; `story_finish.py` `.session` path sweep; the three-way adapter de-duplication.

---

### Round 1 (superseded — retained for history)

- **Round-1 verdict:** REJECTED (superseded by the APPROVED round-2 verdict above)

Two out-of-bounds accesses — one of them a **WRITE** — demonstrated leaking in `sprint/cli.py`, the same module this story swept. Everything the story *did* route is genuinely fail-closed (independently verified with real symlink probes); the defect is an incomplete sweep at exactly the parameter class the story guarded elsewhere.

| Severity | Issue | Location | Fix Required |
|----------|-------|----------|--------------|
| [CRITICAL] [SEC] [TEST] | `initiative_cancel` builds `init_file = sprint_dir / f"initiative-{name}.yaml"` from a raw CLI arg with **no** charset or containment check, then `open(init_file, "w")` + `yaml.dump`. An in-sprint symlink `sprint/initiative-pwned.yaml → /outside/important.yaml` causes an **out-of-bounds WRITE** that clobbers the target and exits **0** reporting success. Demonstrated. | `pennyfarthing-dist/src/pf/sprint/cli.py`:1389 (write at :1474) | Route through `safe_ref_path(sprint_dir, name, prefix="initiative-")`; translate `ValueError` → `click.ClickException` (fail loud on a refused write, matching Dev's own :867 precedent) |
| [HIGH] [SEC] [TEST] | `initiative_show` — same unguarded build, then `open(init_file)` and `click.echo(json.dumps(init_data))`. The same in-sprint symlink makes `pf sprint initiative show pwned --json` **print the full contents of a file outside the sprint tree**. Demonstrated (`"name": "TOP SECRET"` echoed). | `pennyfarthing-dist/src/pf/sprint/cli.py`:1303 | Same fix; `ValueError` → `ClickException` |
| [MEDIUM] [SEC] | `write_sprint`'s string-ref branch is the one path in the hardened function still using a raw interpolation: `written_shards.add(sprint_dir / f"epic-{epic}.yaml")` and `epic_refs.append(epic)` **persist an unvalidated ref into `current-sprint.yaml`**. The story's own `epic_reindex.py` comment names "persists the escape" as part of the harm and guards against it — inconsistent here. Not a direct leak (set membership only), but it seeds the traversal ref the new `old_indexed` guard then warns about on every subsequent write, forever. | `pennyfarthing-dist/src/pf/sprint/yaml_io.py`:448 | `safe_ref_path` (or at minimum `validate_shard_filename`) on the string-ref branch before it is persisted |
| [LOW] [TYPE] | The API elevation is half-done. Nine sites still hand-roll `is_safe_shard_path` + `warnings.warn` instead of using the new helpers — including **inside `shard_merge.py` itself**, the module that defines `safe_shards`. Deliverable A said the helper "replaces every raw `glob(...)` read loop". All nine are functionally safe (I verified containment is present at each), but they skip the charset layer and they perpetuate exactly the "invariant lives in convention" problem the story exists to eliminate. | `shard_merge.py`:207,226,304,323; `archive_epic.py`:177,235,404; `loader.py`:310,336 | Route through `safe_shards`/`safe_ref_path`, or record an explicit deviation |
| [LOW] [SEC] | Out-of-scope but same class, no coverage: `context-epic-{epic_num}.md` builds and a raw `glob("epic-*.yaml")` read loop. An in-sprint symlink yields an out-of-bounds read of the target's leading lines. The `tui` module appears in no inventory. | `pennyfarthing-dist/src/pf/tui/story_detail_data.py`:201,210,225 | File as a follow-up story (do not expand this one) |
| [LOW] [SEC] | `write_sprint` now refuses to unlink a *legitimately* stale shard that happens to be a symlink (probe A: the symlink survived along with its target). Correct fail-closed behaviour, but the stale shard leaks on disk with only a warning. | `pennyfarthing-dist/src/pf/sprint/yaml_io.py`:466 | Accept, or unlink the link itself (`os.path.islink` + `os.unlink`) after confirming the link *entry* is in-dir |
| [LOW] [TYPE] | `sprint/cli.py::_epic_shard_path` is unannotated (`def _epic_shard_path(sprint_dir, ref: str):`) yet its return contract silently changed from `Path` to `Path \| None`. Nothing mechanical protects the 7 call sites; I verified all 7 by hand, but the next caller added has no type-checker safety net. Relatedly, `safe_ref_path` returns a bare `Path` indistinguishable from an unvalidated one, so Deliverable A's "misuse is impossible" is aspirational, not enforced. | `pennyfarthing-dist/src/pf/sprint/cli.py`:645; `shard_merge.py`:52 | Annotate `-> Path \| None`; consider a `NewType("SafeShardPath", Path)` so an unvalidated `Path` cannot be passed where a validated one is required |
| [LOW] | Charset rejection at CLI boundaries now surfaces as a Python `UserWarning` on stderr where the user previously got a plain not-found. Acceptable per Deliverable C, but it is not an actionable message for a user who simply typed a bad ref. | `sprint/cli.py`:657, `findings/aggregate.py`:74 | Non-blocking; consider `click.echo` at Click boundaries |

**Demonstrated leak (reproduction).** In-sprint symlink `sprint/initiative-pwned.yaml → <outside>/important.yaml`:
- `pf sprint initiative show pwned --json` → printed `{"name": "TOP SECRET", ...}` from outside the sprint tree.
- `pf sprint initiative cancel pwned` → rewrote the outside file to `status: canceled`, **exit 0**.
Control: the identically-shaped `story_add.add_initiative_story` *is* guarded. Neither `initiative_show` nor `initiative_cancel` has any test anywhere in the suite (`grep` across `src/pf/tests/`: zero hits).

**Data flow traced:** raw `epic['id']` (archive_epic) → `_safe_context_candidates` → `safe_ref_path(context_dir, ref, prefix="context-epic-", suffix=".md")` **and** `safe_ref_path(archive_dir, ...)` → `shutil.move`. Safe: I probed a symlinked source (`context/context-epic-PWN.md → <outside>/steal-me.md`) → 0 candidates + 1 warning, and a lexical `../../outside/steal-me` id → 0 candidates + warning. **Both ends genuinely closed.**

**[RULE] Project rules:** all COMPLIANT — no `.pennyfarthing/` or `never_edit` path touched (all 10 files under `pennyfarthing-dist/src/pf/`); result-object contract held at both CLI boundaries (`epic_reindex.py`:154, `story_add.py`:405); branch correctly off `develop`; both commits match `<type>(<scope>): <subject>` and are **GPG-signed** (`%G? == G`); no import cycles (162-30); framework tree clean. Full evidence in the [RULE] block under Subagent Results. No rule-matching finding was dismissed.

**Pattern observed:** the fail-closed + `warnings.warn` skip convention is applied consistently and correctly at every routed site (`shard_merge.py`:44-120). The `safe_ref_path` contract — raise for interpolation/write sites, `safe_shards` skip-and-warn for glob loops, callers translating `ValueError` to a result object — is the right decomposition and is honoured at every routed call site.

**Error handling verified:**
- `yaml_io.py`:472 `stale.unlink()` — the headline out-of-bounds DELETE is **closed**. Probe A (in-sprint symlink `epic-99.yaml → <outside>/victim.txt`, ref `'99'` in the on-disk index): victim survived, warning fired. Probe B (lexical ref `../../outside/victim2`): victim survived, warning fired. The build-time guard catches both; the pre-unlink re-check is redundant but harmless.
- `safe_ref_path` false-positive sweep: `42`, `OP-1234`, `epic-thing`, `tour-practice`, `1.0-rc`, `a_b` all accepted and equal to the raw interpolation they replace; `../x`, `..`, `""`, `a/b`, `a b` all rejected. No benign real-world ref is broken.
- Result-object contract preserved: `epic_reindex` → `raise click.ClickException(result["error"])` (`epic_reindex.py`:154); `story_add` → `if result["success"]` (`story_add.py`:405). No `ValueError` escapes a result-object boundary.

**Verification run myself:**
- `test_162_44` + `test_160_13` + `test_162_12` + `test_164_3` → **175 passed** (matches Dev's claim; 160-13/162-12/164-3 invariants intact).
- `ruff check` on all 10 touched files → **All checks passed.** (94 repo-wide errors are pre-existing in untouched test files.)
- Import-cycle check (162-30): all 9 touched modules import cleanly in isolation.

**Observations:** 8 findings (1 Critical, 1 High, 1 Medium, 5 Low) + 6 verified-good items above.

**Handoff:** Back to Dev. The Critical and High are a two-line fix each in `sprint/cli.py` using the helper this story already built; TEA should add symlink-leak coverage for `initiative_show` / `initiative_cancel` (currently zero tests) before Dev re-greens.
- **Two `initiative-{name}.yaml` sites in `sprint/cli.py` were MISSED in round 1 (reviewer demonstrated both):** round 1 guarded `_epic_shard_path` and the four `initiative-*.yaml` GLOBS, but not the two direct `initiative-{name}.yaml` INTERPOLATIONS driven by a raw CLI argument (`initiative_show` ~1303 read, `initiative_cancel` ~1396 build → ~1481 write). These are the identical shape I had already correctly guarded in `story_add.py`. Root cause: I swept the module by grepping for `glob(` and for the shared `_epic_shard_path` helper, and took TEA's inventory as the site list for cli.py instead of grepping the module for every `f"initiative-` / `f"epic-` interpolation independently. The `initiative cancel` miss was an out-of-bounds WRITE that exited 0 — the most severe finding of the story, in a module the story claimed to have swept. Lesson: for a sweep story, enumerate the pattern across the whole module directly; never inherit the inventory as the ceiling (the spec even said "floor, not ceiling").
- **`tui/story_detail_data.py` guarded, not deferred:** reviewer flagged it LOW and offered "guard it or file a Delivery Finding explaining why it's safe". I probed it and all five sites leaked, so filing a finding would have meant knowingly leaving five demonstrated out-of-bounds reads. Guarded via a `_safe_str_path` adapter (the module uses `os.path` strings, not `Path`). The session-file family (`{story_id}-session.md`) is a different filename family from the story's `epic-`/`initiative-` class but the identical CWE-22 shape and the same helper closed it, so I included it rather than splitting hairs on scope.
- **`_safe_str_path` returns `None` instead of raising:** these are TUI display lookups on a render path. Each caller already had an `os.path.isfile` miss branch, so `None` reuses it and a hostile ref renders as "no context file" — raising would take down the TUI event loop for a cosmetic lookup.
- **`shard_merge`'s internal glob guards lost their site-specific warning text:** routing the four globs through `safe_shards` replaced messages like "Initiative shard X escapes the sprint directory" with `safe_shards`'s generic "Shard X escapes {base}". No test asserted the old wording; accepted as the cost of the invariant living in one place.