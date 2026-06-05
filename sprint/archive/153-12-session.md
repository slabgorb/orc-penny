---
story_id: "153-12"
jira_key: ""
epic: "Epic 153"
workflow: "tdd"
---
# Story 153-12: Portraits: R2 is the only source — resolver fetches via portrait_cdn only

## Story Details
- **ID:** 153-12
- **Jira Key:** (none — Jira-less project)
- **Workflow:** tdd
- **Repo:** pennyfarthing (gitflow → develop branch)
- **Points:** 3
- **Stack Parent:** none

## Workflow Tracking
**Workflow:** tdd
**Phase:** finish
**Phase Started:** 2026-06-05T15:48:28Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-06-05T00:00:00Z | 2026-06-05T15:22:16Z | 15h 22m |
| red | 2026-06-05T15:22:16Z | 2026-06-05T15:30:21Z | 8m 5s |
| green | 2026-06-05T15:30:21Z | 2026-06-05T15:40:57Z | 10m 36s |
| review | 2026-06-05T15:40:57Z | 2026-06-05T15:48:28Z | 7m 31s |
| finish | 2026-06-05T15:48:28Z | - | - |

## Branch Strategy
- **Branch Strategy:** gitflow (feat/153-12-portraits-r2-only-source)
- **Target Branch:** develop (pennyfarthing repo)
- **PR Strategy:** standard

## Delivery Findings

Agents record upstream observations discovered during their phase.
Each finding is one list item. Use "No upstream findings" if none.

**Types:** Gap, Conflict, Question, Improvement
**Urgency:** blocking, non-blocking

### TEA (test design)
- **Gap** (blocking): Deleting `_install_portraits` will break existing tests that exercise it directly. Affects `pennyfarthing-dist/src/pf/tests/test_153_10_portrait_cache_fingerprint.py` (imports/calls `_install_portraits` and asserts on `pf init --force-portraits` — the whole file becomes obsolete; delete it as part of GREEN).
- **Gap** (blocking): Three `patch("pf.init.core._install_portraits", ...)` call sites will raise `AttributeError` once the function is gone. Affects `pennyfarthing-dist/src/pf/tests/test_init_custom_agents.py` (lines ~456/483/506 — remove the patches; init no longer installs portraits).
- **Improvement** (non-blocking): After removing `_install_portraits`/`_symlink_portraits`, the helpers `_get_portraits_data_dir`, `_find_portraits_source`, `_compute_portraits_fingerprint`, and the init-local `_is_lfs_pointer` likely become dead code in `init/core.py`. Dev should delete any that are no longer referenced (AC1: "dead code deletion is confirmed").
- **Improvement** (non-blocking): The `pf init` output block prints `portraits installed` / `portraits symlinked` (`init/cli.py:129-135`) and `init_project` returns `portraits`/`portraits_linked` keys (`core.py:563,583-584`). Remove these once the install/symlink paths are gone so the CLI doesn't reference removed data.

### Dev (implementation)
- **Gap** (non-blocking): A pre-existing, unrelated test failure lives on the branch base. Affects `pennyfarthing-dist/src/pf/tests/test_init_justfile.py::TestLegacyMigration::test_reports_migrated_count` (asserts 2 migrated recipes, gets 1 — `gui` not migrated). Verified failing on base via `git stash` before any 153-12 change; out of scope for this story (justfile recipe migration, not portraits). Flagged for separate triage.
- **Improvement** (non-blocking): `test_init_custom_agents.py` carries pre-existing `ruff format` drift (multi-line method signatures ruff would collapse) in regions untouched by this story. Affects `pennyfarthing-dist/src/pf/tests/test_init_custom_agents.py` (left as-is to keep this PR's diff scoped to portraits; my edited lines are format-clean).
- All four TEA delivery findings (2 blocking, 2 non-blocking) were addressed during implementation — see Design Deviations → Dev.

### Reviewer (review)
- **Improvement** (non-blocking): `portrait_cdn._download` writes CDN bytes to the cache without a post-download PNG-magic check, so a corrupt/mis-served object is returned once before the next-call self-heal catches it. Affects `pennyfarthing-dist/src/pf/package/portrait_cdn.py` (`_download` / the miss path — could validate magic post-write and treat a bad body as a failed download). Pre-existing, low severity, out of scope for 153-12. *Found by Reviewer during review.*
- **Improvement** (non-blocking): This story's `ruff format` pass reflowed unrelated regions of `init/core.py`. Affects `pennyfarthing-dist/src/pf/init/core.py` (format-only churn). Consider formatting changed regions only in future edits to keep diffs scoped. *Found by Reviewer during review.*

## Impact Summary

**Upstream Effects:** No upstream effects noted
**Blocking:** None

### Deviation Justifications

6 deviations

- **Two AC3/AC4 tests are intentionally GREEN on HEAD (preservation guards)**
  - Rationale: AC3/AC4 have a positive direction (CDN result is returned; a healthy cache is served offline) that a pure RED test can't express. These pin it so Dev's removals don't over-apply and break the happy path. The genuinely-RED coverage is the 10 negative/self-heal tests.
  - Severity: minor
  - Forward impact: none — Dev must keep both green.
- **AC4 self-heal logging asserts via `caplog` (logging module), not stdout**
  - Rationale: enforces `logging.getLogger(...).debug(...)` (lang-review #4, library-appropriate) rather than `print()`. Dev must use the logging module for the self-heal event.
  - Severity: minor
  - Forward impact: Dev implements self-heal logging via `logging`, not `print`.
- **AC1 call-site removal tested by source scan**
  - Rationale: a `hasattr` check proves the def is gone but not the call sites; the source scan directly encodes the AC's "call sites gone" requirement.
  - Severity: minor
  - Forward impact: none.
- **Deleted the entire orphaned portrait-install helper chain, not just the two named functions**
  - Rationale: AC1 explicitly asks for dead-code confirmation; these helpers were referenced only by the removed entry points (verified by grep — no external callers).
  - Severity: minor
  - Forward impact: none — all confirmed unreferenced before deletion.
- **PNG validation checks the full 8-byte signature, not just the 4 bytes the AC names**
  - Rationale: every real PNG carries the full 8-byte signature, so this is a strict superset of the named 4 bytes — it accepts all valid PNGs and rejects the same stubs, with zero false negatives. TEA's valid fixtures use the full signature.
  - Severity: minor
  - Forward impact: none.
- **Resolved TEA's two blocking delivery findings by deleting obsolete tests**
  - Rationale: those tests exercise the now-deleted installer; leaving them would error at collection.
  - Severity: minor
  - Forward impact: none — both files now pass.

## Design Deviations

Agents log spec deviations as they happen — not after the fact.
Each entry: what was changed, what the spec said, and why.

### TEA (test design)
- **Two AC3/AC4 tests are intentionally GREEN on HEAD (preservation guards)**
  - Spec source: context-story-153-12.md, AC-3 ("Only path: portrait_cdn.fetch_portrait()") and AC-4 (valid PNG cache hit must still resolve)
  - Spec text: "Portrait resolver checks R2 CDN only" / "Cache hit path validates PNG magic … on entry load"
  - Implementation: `test_resolver_returns_the_cdn_result` and `test_valid_png_cache_hit_is_served_without_network` assert behavior that already holds and MUST survive the fix; they pass now and after GREEN.
  - Rationale: AC3/AC4 have a positive direction (CDN result is returned; a healthy cache is served offline) that a pure RED test can't express. These pin it so Dev's removals don't over-apply and break the happy path. The genuinely-RED coverage is the 10 negative/self-heal tests.
  - Severity: minor
  - Forward impact: none — Dev must keep both green.
- **AC4 self-heal logging asserts via `caplog` (logging module), not stdout**
  - Spec source: context-story-153-12.md, AC-4
  - Spec text: "Self-heal logged to debug output"
  - Implementation: `test_self_heal_is_logged` captures DEBUG records from the logging framework and matches the slug or a self-heal keyword.
  - Rationale: enforces `logging.getLogger(...).debug(...)` (lang-review #4, library-appropriate) rather than `print()`. Dev must use the logging module for the self-heal event.
  - Severity: minor
  - Forward impact: Dev implements self-heal logging via `logging`, not `print`.
- **AC1 call-site removal tested by source scan**
  - Spec source: context-story-153-12.md, AC-1
  - Spec text: "Both call sites (439, 485) are gone … Function definition (1184) is gone"
  - Implementation: `test_no_install_or_symlink_call_sites_remain_in_core` greps `init/core.py` source for the symbol names (paired with `hasattr` behavioral checks).
  - Rationale: a `hasattr` check proves the def is gone but not the call sites; the source scan directly encodes the AC's "call sites gone" requirement.
  - Severity: minor
  - Forward impact: none.

### Dev (implementation)
- **Deleted the entire orphaned portrait-install helper chain, not just the two named functions**
  - Spec source: context-story-153-12.md, AC-1
  - Spec text: "init._install_portraits is removed and dead code deletion is confirmed"
  - Implementation: Removed `_install_portraits` and `_symlink_portraits` AND their now-orphaned dependencies in `init/core.py` (`_get_portraits_data_dir`, `_find_portraits_source`, `_compute_portraits_fingerprint`, the init-local `_is_lfs_pointer`) plus the now-unused `import hashlib`. Also removed the resolver's dead helpers (`_find_portrait`, `_has_lfs_stubs`, `_is_lfs_pointer`).
  - Rationale: AC1 explicitly asks for dead-code confirmation; these helpers were referenced only by the removed entry points (verified by grep — no external callers).
  - Severity: minor
  - Forward impact: none — all confirmed unreferenced before deletion.
- **PNG validation checks the full 8-byte signature, not just the 4 bytes the AC names**
  - Spec source: context-story-153-12.md, AC-4
  - Spec text: "validate PNG magic bytes (0x89 'P' 'N' 'G')"
  - Implementation: `_is_valid_png` compares against `b"\x89PNG\r\n\x1a\n"` (the complete PNG signature).
  - Rationale: every real PNG carries the full 8-byte signature, so this is a strict superset of the named 4 bytes — it accepts all valid PNGs and rejects the same stubs, with zero false negatives. TEA's valid fixtures use the full signature.
  - Severity: minor
  - Forward impact: none.
- **Resolved TEA's two blocking delivery findings by deleting obsolete tests**
  - Spec source: session Delivery Findings → TEA (test design)
  - Spec text: "test_153_10 … becomes obsolete; delete it" / "remove the _install_portraits patches in test_init_custom_agents.py"
  - Implementation: `git rm`'d `test_153_10_portrait_cache_fingerprint.py`; removed the `_install_portraits`/`_symlink_portraits` `patch()` wrappers (and de-nested) in `test_init_custom_agents.py`.
  - Rationale: those tests exercise the now-deleted installer; leaving them would error at collection.
  - Severity: minor
  - Forward impact: none — both files now pass.

### Reviewer (deviation audit)
- **TEA: Two AC3/AC4 preservation guards green on HEAD** → **ACCEPTED.** Correct pattern for the positive direction of a removal AC; both confirmed green at preflight (178 passed). Prevents over-application of the removals.
- **TEA: AC4 self-heal logging via caplog** → **ACCEPTED.** Enforcing `logging` over `print` is the right call (lang-review #4); Dev implemented `logger.debug(...)` accordingly.
- **TEA: AC1 call-site removal via source scan** → **ACCEPTED.** A `hasattr`+source-scan pair is the precise encoding of "def AND call sites gone"; I verified the source scan passes (no `_install_portraits`/`_symlink_portraits` strings remain in `init/core.py`).
- **Dev: Deleted the whole orphaned helper chain, not just the two named fns** → **ACCEPTED.** AC1 explicitly asks for dead-code confirmation. I independently confirmed via grep that `_get_portraits_data_dir`/`_find_portraits_source`/`_compute_portraits_fingerprint`/init-local `_is_lfs_pointer` and the resolver helpers had no external callers; `import hashlib` was correctly dropped with them.
- **Dev: PNG validation uses the full 8-byte signature, not the 4 named bytes** → **ACCEPTED.** A strict superset — every real PNG carries the full signature; zero false negatives, rejects the same stubs. Sound.
- **Dev: Resolved TEA's two blocking findings by deleting obsolete tests** → **ACCEPTED.** `test_153_10` tested the deleted installer (correctly removed); the `test_init_custom_agents` patches would have `AttributeError`'d (correctly removed). Preflight confirms both files green.

---

## Sm Assessment

**Setup complete. Routing to TEA (red phase).** Phased TDD workflow, 3 pts, pennyfarthing repo (gitflow → develop). Branch `feat/153-12-portraits-r2-only-source` cut off `develop`. Jira-less project — no claim needed.

**Why this story is genuinely NOT done** (verified against `develop` before starting, so TEA/Dev don't chase a false "already delivered"):
- The R2 *fetch path exists* (PR #86 `feat/portrait-cdn-direct-png` delivered `portrait_cdn.fetch_portrait`; resolver calls it). But it is one source among five — the story is about making it the **only** one.
- All four "kill" targets are still live in the code; the PNG-magic self-heal is absent. This is the actual scope.

**Corrected file paths** (setup's Technical Summary listed two without their subpackage — use these):
- `pennyfarthing-dist/src/pf/init/core.py` — `_install_portraits` def `:1184`, called `:439` & `:485`; symlink behavior `:1272`; `force_portraits` param `:344`
- `pennyfarthing-dist/src/pf/init/cli.py` — `--force-portraits` flag `:17`
- `pennyfarthing-dist/src/pf/tui/portrait_resolver.py` — `~/.pennyfarthing/portraits/<theme>` override `:143`; theme-sibling + Cyclist npm fallbacks `:190–203`
- `pennyfarthing-dist/src/pf/package/portrait_cdn.py` — cache-hit path `:145–149` (add PNG-magic validation here)

**Note for TEA:** decree on record (project memory) — R2 is the ONLY source, no managed local copies ever. The PNG-magic check must reject LFS pointer text and truncated files on a cache hit, discard, and re-download. Test the self-heal end-to-end, not just the magic-byte predicate.

**Handoff:** TEA → red phase.

---

## TEA Assessment

**Tests Required:** Yes
**Reason:** 3-pt source-removal + validation story; every AC is testable behavior.

**Test Files:**
- `pennyfarthing-dist/src/pf/tests/test_153_12_portraits_r2_only.py` (new) — 14 tests covering all 5 ACs.

**Tests Written:** 14 tests covering 5 ACs — **12 failing (RED)**, 2 intentional preservation guards (green; see Design Deviations).
**Status:** RED (failing for the right reasons — all assertion failures, zero collection/import errors). Verified with scoped single-file run (`uv run pytest src/pf/tests/test_153_12_portraits_r2_only.py -q` → `12 failed, 2 passed in 0.21s`). Full suite NOT run (leaks a `feature/test` checkout — project lore).

**Coverage by AC:**
| AC | Tests | State |
|----|-------|-------|
| AC1 — `_install_portraits`/symlink removed | `test_install_portraits_function_is_removed`, `test_symlink_portraits_function_is_removed`, `test_no_install_or_symlink_call_sites_remain_in_core` | RED |
| AC2 — `--force-portraits` flag/param removed | `test_init_help_has_no_force_portraits_flag`, `test_init_project_signature_has_no_force_portraits_param` | RED |
| AC3 — resolver is CDN-only | `test_resolver_ignores_home_override_dir`, `test_resolver_ignores_cyclist_package_fallback`, `test_resolver_does_not_attempt_lfs_self_heal` (RED) + `test_resolver_returns_the_cdn_result` (guard) | RED + guard |
| AC4 — PNG-magic cache-hit self-heal | `test_cache_hit_lfs_stub_is_discarded_and_refetched`, `test_cache_hit_empty_file_is_discarded_and_refetched`, `test_poisoned_cache_with_dead_cdn_returns_none_not_stub`, `test_self_heal_is_logged` (RED) + `test_valid_png_cache_hit_is_served_without_network` (guard) | RED + guard |
| AC5 — suite green, tree clean | Verified at GREEN (Dev) | n/a (red phase) |

### Rule Coverage (lang-review/python.md)

| Rule | Test(s) | Status |
|------|---------|--------|
| #4 logging coverage/correctness | `test_self_heal_is_logged` (forces `logging`, not `print`, for the self-heal event) | failing |
| #6 test quality (meaningful assertions) | self-check below — every test asserts a value/path/count, no `assert True`, no bare truthy on always-None | pass |
| #7 resource leaks | self-heal magic read reuses the binary-read idiom; behavioral tests confirm end-to-end (no explicit leak test) | n/a |

**Rules checked:** logging (#4) and test-quality (#6) are the applicable lang-review rules for these changed files; both have coverage. Path/deserialization/async rules are not engaged by this diff.
**Self-check:** 0 vacuous tests. Every assertion checks a concrete value (`read_bytes() == PNG_BYTES`), identity (`is None`), path equality, `call_count == 0`, or a substring match on a log message — none can pass while the behavior is wrong.

**Key design notes for Dev (Reverend Mother):**
- AC4 is the heart: on a cache HIT, validate the file starts with the PNG signature (`b"\x89PNG"`). If it fails, treat the entry as a MISS and fall through to the CDN download (which atomically overwrites the poisoned path). A still-bad/dead CDN must yield `None` — **never** return the poisoned stub.
- AC3: collapse `resolve_portrait_path` to "compute slug → `return portrait_cdn.fetch_portrait(...)` (guarded)". Remove the override dir, the theme-sibling portraits search, the LFS self-heal block, and the Cyclist fallback. Keep the two preservation guards green.
- Two existing test files reference soon-deleted symbols — see Delivery Findings (blocking). Delete `test_153_10_portrait_cache_fingerprint.py` and the `_install_portraits` patches in `test_init_custom_agents.py` as part of GREEN.

**Handoff:** To Dev for implementation (GREEN).

---

## Dev Assessment

**Implementation Complete:** Yes

**Files Changed:**
- `pennyfarthing-dist/src/pf/package/portrait_cdn.py` — added `_PNG_MAGIC`, `_is_valid_png`, a module `logger`, and PNG-magic validation on the cache-hit path of `fetch_portrait` (poisoned stub → debug-log + discard + re-fetch; dead CDN → `None`). [AC4]
- `pennyfarthing-dist/src/pf/tui/portrait_resolver.py` — `resolve_portrait_path` collapsed to "compute slug → `portrait_cdn.fetch_portrait`"; removed the `~/.pennyfarthing` override, theme-sibling search, Git-LFS self-heal, and Cyclist fallback, plus the dead helpers `_find_portrait`/`_has_lfs_stubs`/`_is_lfs_pointer`; refreshed the module + function docstrings. [AC3]
- `pennyfarthing-dist/src/pf/init/core.py` — removed `_install_portraits`, `_symlink_portraits`, their orphaned helper chain, both call sites, the `force_portraits` param, the `portraits`/`portraits_linked` return keys, and the now-unused `import hashlib`. [AC1/AC2]
- `pennyfarthing-dist/src/pf/init/cli.py` — removed the `--force-portraits` flag, its param, the threaded arg, and the portrait output block. [AC2]
- `pennyfarthing-dist/src/pf/tests/test_153_10_portrait_cache_fingerprint.py` — **deleted** (obsolete; tested the removed installer). [TEA finding]
- `pennyfarthing-dist/src/pf/tests/test_init_custom_agents.py` — removed the `_install_portraits`/`_symlink_portraits` `patch()` wrappers (de-nested); fixed import order. [TEA finding]

**Tests:** 14/14 of the 153-12 suite passing (GREEN). Verified scoped across all affected files: `178 passed, 1 skipped` (portrait_cdn, portrait_protocol, init_custom_agents, init_command, init_auto_setup + 153-12). The two preservation guards stay green. One pre-existing unrelated failure (`test_init_justfile.py`) confirmed on base via `git stash` — see Delivery Findings.
**Lint/Format:** `ruff check` clean on all changed source; `ruff format --check` clean on my files (pre-existing drift in `test_init_custom_agents.py` left out of scope — noted).
**Net change:** +102 / −647 (kills the dead wood; R2 is the lone source).
**Branch:** `feat/153-12-portraits-r2-only-source` (pushed).

**Self-review:**
- [x] All 5 ACs met (AC5 = suite green for the story's scope).
- [x] Code follows project patterns (result/None, never-raise CDN contract, `logging` over `print`, `with open()` for the magic read).
- [x] Error handling: `_is_valid_png` never raises; resolver/CDN degrade to `None`.
- [x] No debug code, tree clean, correct branch (gitflow → develop).

**Handoff:** To Reviewer (Leto II) for code review.

---

## Subagent Results

| # | Specialist | Received | Status | Findings | Decision |
|---|-----------|----------|--------|----------|----------|
| 1 | reviewer-preflight | Yes | success | none (178 passed, 0 failed, 1 skipped; ruff clean; 0 smells) | n/a |
| 2 | reviewer-edge-hunter | No | Skipped | disabled | Disabled via settings |
| 3 | reviewer-silent-failure-hunter | No | Skipped | disabled | Disabled via settings |
| 4 | reviewer-test-analyzer | No | Skipped | disabled | Disabled via settings |
| 5 | reviewer-comment-analyzer | No | Skipped | disabled | Disabled via settings |
| 6 | reviewer-type-design | No | Skipped | disabled | Disabled via settings |
| 7 | reviewer-security | Yes | clean | none (4 rule classes checked, 0 violations) | n/a |
| 8 | reviewer-simplifier | No | Skipped | disabled | Disabled via settings |
| 9 | reviewer-rule-checker | No | Skipped | disabled | Disabled via settings |

**All received:** Yes
**Total findings:** 0 confirmed, 0 dismissed, 2 noted (low/informational — see assessment)

Only `preflight` and `security` are enabled via `workflow.reviewer_subagents`; the other seven were skipped per settings.

---

## Reviewer Assessment

**Verdict:** APPROVED

**Summary:** A clean, well-scoped removal story. R2 CDN is now the single portrait source: the resolver fetches via `portrait_cdn.fetch_portrait` and nothing else; `fetch_portrait` validates the PNG signature on a cache hit and self-heals a poisoned stub (discard + log + re-fetch); the init-time installer/symlink chain and the `--force-portraits` escape hatch are gone. Net `+102/−647` — the dead wood is cut. Both enabled specialists returned clean; preflight is green (178 passed) and security found zero violations across path-handling, resource-leak, deserialization, and input-validation rule classes.

**AC verification:**
- **AC1** (install/symlink removed) — ✓ `_install_portraits`, `_symlink_portraits`, both call sites, and the orphaned helper chain (+`import hashlib`) are gone; source-scan test passes.
- **AC2** (`--force-portraits` flag/param removed) — ✓ gone from CLI, `init_project` signature, and the threaded arg; `--help` test + signature test pass.
- **AC3** (resolver CDN-only) — ✓ override / theme-sibling / Git-LFS self-heal / Cyclist fallbacks all removed; the three negative tests + the CDN-result guard pass. I traced the new body: compute slug → `return portrait_cdn.fetch_portrait(...)` guarded by `except → None`. Correct.
- **AC4** (PNG-magic cache-hit self-heal) — ✓ `_is_valid_png` (full 8-byte signature, context-managed read, OSError→False); poisoned hit is logged at DEBUG, unlinked, and re-fetched; a dead CDN yields `None`, never the stub. The four self-heal tests + the healthy-cache guard pass.
- **AC5** (suite green, tree clean) — ✓ confirmed for the story's scope (178 passed across all affected files), tree clean, correct branch.

**Specialist incorporation:**
- `[SEC]` (reviewer-security) — returned **clean, 0 findings** across 4 rule classes (path-handling/CWE-59, resource leaks, unsafe deserialization, input-validation/CWE-22) plus SOUL #10. It explicitly cleared the new `local.unlink(missing_ok=True)` containment (allowlisted `theme`/`slug`, hardcoded `size`, `_within_cache` gate), `_is_valid_png` (context-managed `rb` read, OSError-scoped, no exploitable TOCTOU — cache is user-owned), and the debug-log interpolation (lazy `%s`, no sensitive data). It independently flagged the post-download magic gap as **pre-existing and acceptable** (worst case: a one-shot display error that self-heals). I concur with all of its conclusions and adopt them; no `[SEC]` finding requires action.

**Adversarial probes (all cleared):**
- *Containment of `local.unlink(missing_ok=True)`:* `theme`/`slug` pass the `_is_safe_segment` allowlist, `size` is from a hardcoded tuple, and `_within_cache` gates the branch — no traversal. `[SEC]` independently confirmed; unlinking a planted symlink removes the link, not its target.
- *`_is_valid_png` TOCTOU / leak:* reads 8 bytes under `with`, writes nothing, OSError-scoped — not exploitable (cache is user-owned).
- *Trust shift to the CDN:* removing local fallbacks means a single point of truth; the post-download bytes are not re-validated for magic, but this is **pre-existing** behavior (the download path was never magic-checked) and the worst case is a one-shot display error that self-heals on the next call. Acceptable.

**Noted (non-blocking, no action required):**
1. *(Low) Whole-file ruff-format churn in `init/core.py`.* Running `ruff format` on the file reflowed several unrelated regions (`generate_custom_agent_commands` dict literals, `_install_tmux_files`, the gitignore stale-list). Deterministic formatter output, zero logic change — but it widens the diff beyond portraits. Recorded for honesty (Prove the Work); not worth a rework cycle to revert (the revert would itself be churn).
2. *(Info) Pre-existing post-download magic gap* — see above; out of scope for this story, candidate for a future hardening if CDN integrity ever becomes a concern.

**Handoff:** To SM (Stilgar) for the finish phase (PR creation + merge).

**Goal:** Make R2 CDN the only portrait source. Eliminate local installation, overrides, and fallbacks. Add PNG magic validation to self-heal poisoned cache entries.

**Key Changes:**
1. Remove `init._install_portraits()` and symlink behavior
2. Remove `--force-portraits` CLI flag
3. Remove `~/.pennyfarthing/portraits/<theme>` override lookup
4. Remove theme-sibling and Cyclist npm package fallbacks
5. Add PNG magic validation (0x89 'P' 'N' 'G') on cache-hit path

**Files to Modify:**
- `pennyfarthing-dist/src/pf/init/core.py` (lines 439, 485, 1184, 1272, 344)
- `pennyfarthing-dist/src/pf/init/cli.py` (line 17)
- `pennyfarthing-dist/src/pf/portrait_resolver.py` (lines 143, 190–203)
- `pennyfarthing-dist/src/pf/portrait_cdn.py` (lines 145–149)

**Context Document:** `/Users/slabgorb/Projects/orc-penny/sprint/context/context-story-153-12.md`

See acceptance criteria in story context for detailed requirements.