---
story_id: "154-1"
jira_key: ""
epic: ""
workflow: "tdd"
---
# Story 154-1: Implement portrait_cdn module with SHA256-verified theme packs and local cache

## Story Details
- **ID:** 154-1
- **Jira Key:** (none — local sprint only)
- **Workflow:** tdd
- **Stack Parent:** none
- **Points:** 8
- **Repo:** pennyfarthing
- **Branch:** feat/154-1-portrait-cdn

## Story Context

**GitHub Issue:** https://github.com/slabgorb/pennyfarthing/issues/17 (fully specified with drop-in reference module)

**Purpose:** Replace gh-CLI GitHub Contents API portrait download (`pf package download-portraits`) with on-demand per-theme delivery from live Cloudflare R2 CDN at https://portraits.darkatelier.org/v1.

**CDN Layout:**
- v1/manifest.json (etag, 24h cache)
- v1/themes/{theme}.tar.gz (immutable packs: small/medium/large/original)
- v1/themes/{theme}.sha256

**Core Implementation:**
- New module: `src/pf/package/portrait_cdn.py`
- Functions: fetch_manifest() (etag-cached, 24h rate limit), ensure_portraits(theme) (sentinel hot-path → download → SHA256 verify → extract → merge persona map), resolve_portrait(theme, agent, size)
- CLI helpers: list_cached, status, clean
- Cache dir: XDG ~/.local/share/pennyfarthing/portraits/{theme}/ with .complete sentinel

**Integration Points:**
- Call ensure_portraits(theme) at prime/agent activation
- Add CDN cache dir to discover_all_theme_dirs() (lowest priority)
- Local override directory (~/.pennyfarthing/portraits/) at highest priority
- No changes to portrait_resolver._find_portrait resolution logic — same {size}/{slug}.png layout

**Acceptance Criteria:**
- ensure_portraits(theme) downloads from CDN on first use
- SHA256 verification before extraction
- .complete sentinel for instant cache hit
- Manifest caching with etag (24h rate limit)
- pf portraits status / pf portraits clean CLI commands
- CDN cache added to theme dir discovery
- Local override directory at highest priority
- Graceful degradation: download/verify failures don't block sessions
- No auth required (public R2 bucket)

**Implementation Notes:**
- Reference module available in issue #17: `gh issue view 17 --repo slabgorb/pennyfarthing`
- CDN is live and synced (manifest lists 100 themes)
- Manifest timestamp reads 2026-04-26 but sync ran today — possibly R2 1h edge cache or async manifest generation
- Worth verifying manifest reflects current packs, but not a blocker

## SM Assessment

**Setup verdict:** Ready for RED. Story 154-1 is exceptionally well-positioned — issue #17 is fully specified with a drop-in reference module, so TEA has concrete function signatures and acceptance criteria to write failing tests against rather than discovering the contract from scratch.

**Why this story now:** User asked to "fix portrait sourcing once and for all by having the TUI read from R2." This story is exactly that — it replaces the GitHub Contents API download path with R2 CDN consumption. The CDN is live (`portraits.darkatelier.org`, 100 themes published) and was synced today, so the production dependency exists and is reachable.

**Context I set aside before starting:** 472 uncommitted portrait re-renders (14 themes) were stashed on `pennyfarthing` (`stash@{0}`) — they're already on R2, so they're not needed for this story and were kept out of the way to avoid polluting the 154-1 branch. Do NOT pull that stash into this branch; it's unrelated render work.

**Flags for TEA (red phase):**
- Test the reference contract from #17 verbatim: `fetch_manifest()` etag/24h caching, `ensure_portraits()` sentinel hot-path + SHA256-verify-before-extract + graceful degradation, `resolve_portrait()` size fallback order, and the `status`/`clean` CLI helpers.
- **Graceful degradation is a first-class AC** — failures (network, 304, SHA mismatch, tar error) must return `{success: false, ...}` and NOT raise; tests should assert sessions survive a dead CDN. This aligns with SOUL principle #10 (return results, don't throw).
- Manifest `updated` timestamp anomaly (reads 2026-04-26 despite today's sync) is noted in context — verification target during implementation, not a test blocker.
- Repo is `pennyfarthing` → gitflow, targets `develop`. Branch `feat/154-1-portrait-cdn` is already cut off clean `develop`.
- LFS caveat: this story touches NO portrait binaries (it's the consumer module), so the LFS-filter gotcha shouldn't bite here — but if any test fixtures embed tar.gz packs, keep them tiny and synthetic, not real LFS assets.

**Handoff:** → Igor (TEA) for RED phase. Write the failing tests for `portrait_cdn`.

## TEA Assessment

**Tests Required:** Yes
**Reason:** 8-pt feature implementing a new module (`pf.package.portrait_cdn`) with a well-defined contract from issue #17 — full TDD warranted.

**Test Files:**
- `pennyfarthing-dist/src/pf/tests/test_154_1_portrait_cdn.py` — 31 hermetic tests against a `FakeCDN` (monkeypatched `urllib.request.urlopen`/`urlretrieve`, real tar.gz packs with real SHA256). No network, no live-CDN dependency, no real LFS assets.
- `pennyfarthing-dist/src/pf/package/portrait_cdn.py` — RED-phase stub (NotImplementedError bodies) so failures are *behavioral*, not import errors. **Dev replaces the bodies in GREEN.**

**Tests Written:** 31 tests covering all 9 issue-#17 acceptance criteria.
**Status:** RED — verified 31 failed / 0 passed / 0 errored (scoped single-file run, `uv run pytest … -q`, 0.32s). All failures are `NotImplementedError` from the stub. Clean collection, healthy fixtures.

**AC → test map:**
| AC (issue #17) | Test(s) |
|----------------|---------|
| downloads from CDN on first use | `test_ensure_portraits_downloads_and_extracts` |
| SHA256 verify before extraction | `test_ensure_portraits_verifies_sha256_before_extract` |
| `.complete` sentinel instant hit | `test_ensure_portraits_cache_hit_skips_network` |
| manifest etag + 24h rate limit | `test_fetch_manifest_*` (downloads, rate_limited, 304, if_none_match) |
| `status` / `clean` helpers | `test_status_*`, `test_clean_*`, `test_list_cached_*` |
| graceful degradation (no raise) | `test_*_graceful`, `test_ensure_portraits_dead_cdn_never_raises`, `test_fetch_manifest_network_error_*` |
| no auth required | `test_fetch_manifest_no_auth_header` |
| persona-map merge / resolve | `test_ensure_portraits_merges_persona_map`, `test_resolve_portrait_*` |
| XDG cache location | `test_cache_dir_respects_xdg_data_home`, `test_cache_dir_defaults_to_local_share` |

### Rule Coverage (lang-review/python.md)

| Rule | Test(s) | Status |
|------|---------|--------|
| #1 silent exception swallowing | graceful-degradation tests assert `{success: False, error}` (visible, not swallowed) | failing |
| #6 test quality (self-check) | removed vacuous `mb >= 0`; all 31 assert specific values/paths | n/a (own tests) |
| #7 resource leaks | `verifies_sha256` + `extraction_failure` assert no leaked `*.tmp` | failing |
| #8 unsafe deserialization (tar) | `test_ensure_portraits_rejects_path_traversal_in_pack` — malicious `../escaped.png` member must not escape theme dir | failing |

**Rules checked:** 4 of 8 lang-review rules have direct test coverage; #2 (mutable defaults) and #3 (type annotations) are satisfied structurally by the stub contract; #4 (logging) and #5 (path handling — `encoding=`) are flagged to Dev as Delivery Findings since they can't be unit-asserted in RED.
**Self-check:** 1 vacuous assertion found (`mb >= 0`) and fixed; no `assert True`, no skips, no truthy-without-value.

**Handoff:** To Ponder Stibbons (Dev) for GREEN. Implement the 7 functions in `portrait_cdn.py` to pass all 31 tests. Adopt the issue-#17 reference module but address the two security/correctness findings below (safe tar extraction + utf-8 text I/O).

## Dev Assessment

**Implementation Complete:** Yes — module **and** end-to-end wiring. (My earlier draft deferred the wiring; the user directed it be done now, so it was completed in this phase. The deferral is withdrawn.)

**Files Changed:**
- `pennyfarthing-dist/src/pf/package/portrait_cdn.py` — full issue-#17 module: `_cache_dir`, `fetch_manifest`, `_verify_sha256`, `ensure_portraits`, `resolve_portrait`, `list_cached`, `status`, `clean`. Hardened beyond #17: `filter="data"` safe extraction, `encoding="utf-8"` text I/O, and an explicit **User-Agent** on all requests (see UA finding below).
- `pennyfarthing-dist/src/pf/tui/portrait_resolver.py` — `resolve_portrait_path` (the single resolver behind TUI, Frame, peloton) now: (1) checks `~/.pennyfarthing/portraits/{theme}` override first; (2) local theme dirs; (3) **lazily `ensure_portraits()` + resolve from the R2 cache**; (4) LFS/cyclist legacy fallbacks.
- `pennyfarthing-dist/src/pf/hooks/session_start.py` — calls `ensure_portraits(theme)` at activation (lazy, graceful).
- `pennyfarthing-dist/src/pf/package/cli.py` + `cli.py` — new `pf portraits status|list|fetch|clean` group, registered in the lazy command map.
- `pennyfarthing-dist/src/pf/tests/test_154_1_portrait_cdn.py` — UA regression test + FakeCDN harness now serves the pack via `urlopen` (models the real CDN's UA requirement on every request).
- `pennyfarthing-dist/src/pf/tests/test_154_1_portrait_cdn_wiring.py` — **new** 7 integration tests (resolver↔CDN, override priority, CLI surface).

**Tests:** 39/39 story tests GREEN (32 module + 7 wiring) + 52 existing resolver/cli/portrait tests still green. Verified via scoped direct runs (avoiding the full-suite branch-leak; self-reviewing edits per the testing-runner-can-mutate-source gotcha).
**Branch:** feat/154-1-portrait-cdn (pushed).

**Live verification:** `pf portraits fetch neuromancer` pulled **44 SHA256-verified images (6.9 MB)** from the real R2 bucket; `resolve_portrait_path('neuromancer','dev')` returned the CDN-cached PNG (`from_cdn_cache: True`). End-to-end "TUI reads from R2" proven on real infrastructure, not just mocks.

**TEA findings resolved:** both blocking — safe extraction + utf-8 I/O.

**Self-review:**
- [x] Tests green, branch correct, no debug code
- [x] Returns result objects, never raises on failure paths (SOUL #10)
- [x] **Wired to consumers — YES** (resolver + activation + CLI), verified live.

**Handoff:** To Leonard of Quirm (Architect) for spec-check — please scrutinize: (a) the resolver priority order (override → local → CDN → legacy); (b) Dev's modification of the TEA test harness to model the CDN UA requirement; (c) whether the legacy LFS/cyclist fallbacks should now be deprecated.

## Architect Assessment (spec-check)

**Spec Alignment:** Drift detected — 1 minor mismatch, resolved in code's favor.
**Mismatches Found:** 1
**Gate:** spec_check structural validation passed (assessment_found, AC coverage, deviation logging all present).

All 9 issue-#17 acceptance criteria are covered and verified (live fetch of 44 SHA256-verified images + CLI surface confirmed: `status`/`list`/`fetch`/`clean`). The three "Worth considering from ADR-0014" items (WebP, theme-YAML portrait fields, source-of-truth repo) are explicitly follow-on and correctly out of scope — not implementing them is not a mismatch.

**Mismatch:**
- **Resolver places CDN above legacy LFS/cyclist fallbacks, not "lowest priority"** (Different behavior — Behavioral, Minor)
  - Spec: issue #17 integration note + context line 37 — "Add … pennyfarthing/portraits/{theme}/ as a new search location … *lowest priority* after core/packages/monorepo/custom."
  - Code: `resolve_portrait_path` order is override → local theme dirs → **CDN** → LFS self-heal → cyclist legacy. CDN sits above the two repo-bundled legacy paths.
  - Recommendation: **A — update spec.** The code's order is the better design: the CDN is the new *primary* remote source, so it should be consulted before triggering an expensive LFS pull or the deprecated cyclist path. Local bundled portraits still win over CDN, which honours the spec's actual intent. Logged here as a deviation; no code change needed.

**Response to Dev's three scrutiny points:**
- **(a) Resolver priority order** — Approved. Override → local → CDN → legacy is sound (see mismatch above). The override-first / local-second ordering exactly matches the override and discovery ACs.
- **(b) Dev edited TEA's test harness** — Acceptable in substance, but **flagged for TEA verify.** The edit *strengthened* the suite (models the real CDN's UA→403 constraint that mock-only tests missed; adds `test_requests_set_user_agent`). A Dev editing the tests they must pass is a process smell even when benign, so TEA must confirm during verify that: (1) RED integrity holds — the module tests still genuinely fail against a stub, and (2) no existing assertion was loosened, only the `urlopen` transport swapped in and the UA test added.
- **(c) Deprecate legacy LFS/cyclist fallbacks?** — **Defer (D), and they must STAY for now.** R2 rollout is incomplete — roughly 28 of ~41 themes are not yet rendered/uploaded to the bucket (portrait-style worksheet is mid-rollout). Removing the legacy fallbacks today would blank portraits for every theme not yet on R2. Deprecation is a valid future story *gated on confirmed full R2 coverage*, not this one.

**Decision:** Proceed to verify (TEA). No hand-back to Dev — the lone mismatch resolves in the code's favor (Option A) and requires no code change. TEA carries forward the two verify-phase checks under point (b).

## TEA Assessment (verify)

**Phase:** finish
**Status:** GREEN confirmed — 39/39 story tests pass (32 module + 7 wiring) on the merged `develop` code, scoped run (`uv run pytest … -q`, 1.78s). Full suite deliberately avoided (test_git_utils.py branch-leak gotcha).

**Harness-integrity check (Leonard's point b) — CLEARED:** Diffed TEA's RED test file (`4e2fa332b`) against Dev's GREEN version (`1d4729c1a`). No assertion was loosened. Changes were: (1) `_FakeResp` gained `BytesIO` + context-manager support and `FakeCDN.urlopen` now dispatches manifest-vs-pack — required because the module moved pack download from `urlretrieve` to `with urlopen(...)`; (2) **strengthenings** — added `test_requests_set_user_agent` (asserts 2 calls, both non-default UA) and added no-leaked-`.tmp` assertions to the download-failure test. The cache-hit test's `urlopen_calls == []` now covers manifest *and* pack (stricter). RED integrity holds — all assertions are behavioral/specific and would fail against a `NotImplementedError` stub.

### Simplify Report

**Teammates:** reuse, quality, efficiency
**Files Analyzed:** 4 (portrait_cdn.py, portrait_resolver.py, package/cli.py, session_start.py)

| Teammate | Status | Findings |
|----------|--------|----------|
| simplify-reuse | 2 findings (medium) | size-order logic duplicated + inconsistent across portrait_cdn / portrait_resolver |
| simplify-quality | 4 findings (3 high, 1 med) | 1 real (private `_cache_dir()` access); 3 false-positive (intentional graceful-degradation no-ops) |
| simplify-efficiency | 4 findings (2 high, 2 med) | 1 real in-scope (`status()` double rglob); 1 out-of-scope (`discovery.py`); 2 readability nits |

**Applied:** 0 — **PR #72 is already merged to `develop`; there is no open branch to commit refactors to.** Applying would require a new cleanup branch + PR, which is a scope decision, not a mechanical verify edit.
**Flagged for Review:** size-order cross-module inconsistency; private `_cache_dir()` coupling (both → Delivery Findings).
**Noted (non-defects):** 3 "ignored return value" findings are intentional graceful degradation (SOUL #10); `discovery.py` finding is out of story scope.
**Reverted:** 0.

**Overall:** simplify: clean of correctness issues — minor cleanup recommendations captured as non-blocking Delivery Findings for an optional follow-up.

**Quality Checks:** Story tests GREEN. Did NOT run full `pf check` — it triggers the full pytest suite which leaks a `feature/test` checkout onto the live repo (documented gotcha); scoped story-test run substituted.

**Blocking process flag:** The story's PR merged before Reviewer ran — see Delivery Findings → TEA (test verification). Handoff paused for a human decision rather than auto-relayed.

## Subagent Results

| # | Specialist | Received | Status | Findings | Decision |
|---|-----------|----------|--------|----------|----------|
| 1 | reviewer-preflight | Yes | clean | tests GREEN 39/39, ruff clean, mypy net-new clean (5 pre-existing errors in cli.py/package cli not from this story) | N/A |
| 2 | reviewer-edge-hunter | Yes | findings | 10 | confirmed 6, deferred 4 |
| 3 | reviewer-silent-failure-hunter | Yes | findings | 4 | confirmed 2, deferred 2 |
| 4 | reviewer-test-analyzer | Yes | findings | 8 | confirmed 4, deferred 4 |
| 5 | reviewer-comment-analyzer | Skipped | disabled | N/A | Disabled via settings |
| 6 | reviewer-type-design | Skipped | disabled | N/A | Disabled via settings |
| 7 | reviewer-security | Yes | findings | 6 | confirmed 5, deferred 1 |
| 8 | reviewer-simplifier | Skipped | disabled | N/A | Disabled via settings |
| 9 | reviewer-rule-checker | Skipped | disabled | N/A | Disabled via settings |

**All received:** Yes (5 enabled returned, 4 disabled)
**Total findings:** 8 confirmed (after dedup), 0 dismissed, 8 deferred-to-hardening

## Reviewer Assessment

**Verdict:** CHANGES REQUESTED — but the PR is **already merged** (#72), so this cannot gate the merge. Recommendation: a **fast-follow hardening story** (suggest `154-2`) bundling the confirmed security/correctness fixes. None of the confirmed issues are remotely exploitable without an HTTPS-MITM or local-cache poison; the one that alarms me is local and destructive (`clean()`). The feature works (GREEN, live-verified); these are robustness/security gaps the mock-heavy tests and the reference-module lineage let through.

**Note on review timing:** This is a retroactive review of merged code (the verify→review→merge ordering was broken upstream — see TEA's process flag). I reviewed harder, not softer, precisely because the merge already happened.

### Confirmed findings (→ hardening follow-up)

**C1 — `clean()` deletes arbitrary directories (CWE-22, Major).** `[EDGE]` `[SEC]` `portrait_cdn.py:252` — `d = cache / theme; shutil.rmtree(d)` with no containment check. `pf portraits clean ../../../../.ssh` resolves outside the cache, `is_dir()` passes, tree deleted with no confirmation. Reachable directly from the CLI arg. *Corroborated: edge-hunter + security.* Fix: `d = (cache/theme).resolve(); if cache.resolve() not in d.parents: return {success:False,...}`.

**C2 — `ensure_portraits()` theme-name traversal (CWE-22, Major).** `[EDGE]` `[SEC]` `portrait_cdn.py:134,150` — `cache / theme` and `cache / f".{theme}.tar.gz.tmp"` unsanitized. A crafted theme (CLI arg, config value, or a MITM manifest key with separators) places the theme dir / tmp file outside the cache. `filter="data"` protects tar *members*, not theme_dir placement. *Corroborated: edge-hunter + security.* Fix: reject `/`, `\`, `..`, empty in `theme` once, up front.

**C3 — Unguarded `manifest['base_url']` / `entry['pack_sha256']` break the "never raises" contract (Major).** `[EDGE]` `[SILENT]` `portrait_cdn.py:149,161` — bare key accesses outside any try/except. A malformed manifest → `KeyError` propagates; `pf portraits fetch` (no try/except) shows a raw traceback; the `pack_sha256` KeyError also leaks the downloaded `.tmp` (fires between the download-except and the sha-mismatch unlink). The manifest-timestamp anomaly noted in setup shows manifest generation isn't bulletproof. *Corroborated: edge-hunter + silent-failure-hunter.* Fix: `.get()` with guards returning `{success:False}`.

**C4 — SSRF via manifest `base_url` (CWE-918, Minor).** `[SEC]` `portrait_cdn.py:149` — `base_url` from the manifest body is interpolated into `pack_url` and passed to `urlopen`, which honors `file://`/`ftp://`/internal hosts. A MITM/poisoned-cache manifest can redirect the pack fetch (and supply a matching SHA256 from the same source, so integrity is no defense). Exploitability needs HTTPS-MITM or local cache poison. Fix: ignore `base_url` and build from the hardcoded `CDN_BASE_URL`, or validate scheme==https and host==expected.

**C5 — `filter="data"` raises TypeError on Python 3.11.0–3.11.3 (Minor).** `[SEC]` `portrait_cdn.py:167` — the `filter=` kwarg landed in 3.12 / backports (3.11.4+), but `requires-python = ">=3.11"`. On 3.11.0–3.11.3 the call raises `TypeError`, which is **not** a `TarError`, so it escapes the handler and is swallowed by the outer bare-excepts — extraction silently never runs and the documented traversal guarantee is false for a supported range. Fix: bump the floor to 3.11.4 or catch `TypeError` → visible failure.

**C6 — Wiring test hits the live CDN (Major, test).** `[TEST]` `test_154_1_portrait_cdn_wiring.py` — `test_resolver_returns_none_when_nothing_cached` seeds **no** sentinel, so `resolve_portrait_path → ensure_portraits` falls through to a real `urlopen` against `portraits.darkatelier.org`. Not hermetic: flaky offline, and could return a real Path online (fail). Fix: monkeypatch `urlopen` to fail, or install a `FakeCDN(fail_network=True)`.

**C7 — Vacuous tmp-cleanup assertions (Minor, test).** `[TEST]` `test_154_1_portrait_cdn.py:332` — `test_..._download_failure_is_graceful` asserts no `*.tmp` remains, but `urlopen` raises *before* the file is opened (compound `with`), so the file is never created and the assertion passes trivially without exercising `tmp.unlink()`. **Corrects my verify-phase note** — I credited this as a strengthening; it's partly vacuous. Fix: pre-create the tmp file, then assert it's removed.

**C8 — Traversal test under-asserts + partial-extraction not cleaned (Minor, test+impl).** `[TEST]` `test_154_1_portrait_cdn.py:386` — the path-traversal test never asserts `result["success"] is False` and never checks that partial members extracted before the `TarError` are cleaned. The implementation does **not** `rmtree(theme_dir)` on `TarError` (only `tmp` is removed), so a retry re-enters a populated-but-incomplete dir with no sentinel. Fix: assert the contract + have `ensure_portraits` clean `theme_dir` on extraction failure.

### Deferred (real, lower severity — fold into hardening or accept)
- Bare `except Exception: pass` in `session_start.py:317` + `portrait_resolver.py:169` swallows `ImportError`/programming bugs (pre-existing graceful-degradation pattern; recommend a `logger.debug(..., exc_info=True)`).
- Concurrent `ensure_portraits` race on the fixed tmp name → use `tempfile.NamedTemporaryFile`.
- No download size cap / zip-bomb guard (`pack_bytes` ignored).
- Stale/empty `.complete` sentinel always returns `cached`; `status()` `stat()`-after-`rglob` race + double `rglob` (TEA already logged the double-walk); `resolve_portrait` assumes dict value (AttributeError on corrupt manifest); missing `pf portraits fetch` CLI test; resolver reaching into private `_cache_dir()` (TEA already logged).

### Rule Compliance (lang-review/python.md)
- #1 silent exceptions — **partial**: intentional graceful degradation OK, but bare excepts over-broad (deferred) + C5 TypeError escapes handler.
- #5 path handling — **FAIL**: C1/C2 traversal (CWE-22); encoding= correctly applied everywhere (security agent verified 7/7).
- #6 test quality — **FAIL**: C6 (network), C7 (vacuous), C8 (under-assert).
- #7 resource leaks — **partial**: C3 leaks tmp on KeyError.
- #8 unsafe deserialization — **PASS**: SHA256 verified before extract; `filter="data"` present (modulo C5); no pickle/eval.
- #11 input validation at boundaries — **FAIL**: theme not validated at CLI entry (C1/C2); C4 base_url unvalidated.

**Handoff:** To Leonard of Quirm (Architect) for spec-reconcile. Confirmed findings recorded in Delivery Findings; recommend materializing story **154-2 (portrait_cdn hardening)** to carry C1–C8.

## Workflow Tracking
**Workflow:** tdd
**Phase:** finish
**Phase Started:** 2026-06-03T18:49:18Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-06-03T12:57:08Z | 2026-06-03T12:59:51Z | 2m 43s |
| red | 2026-06-03T12:59:51Z | 2026-06-03T13:12:54Z | 13m 3s |
| green | 2026-06-03T13:12:54Z | 2026-06-03T13:29:38Z | 16m 44s |
| spec-check | 2026-06-03T13:29:38Z | 2026-06-03T15:44:52Z | 2h 15m |
| verify | 2026-06-03T15:44:52Z | 2026-06-03T18:34:43Z | 2h 49m |
| review | 2026-06-03T18:34:43Z | 2026-06-03T18:47:22Z | 12m 39s |
| spec-reconcile | 2026-06-03T18:47:22Z | 2026-06-03T18:49:18Z | 1m 56s |
| finish | 2026-06-03T18:49:18Z | - | - |

## Delivery Findings

<!-- APPEND ONLY below this marker -->
### TEA (test design)
- **Improvement** (blocking): The issue-#17 reference module extracts theme packs with `tar.extractall(path=theme_dir)` and no member filter — a path-traversal risk (CWE-22) on a malicious/MITM'd pack even after SHA256 matches a compromised manifest. Affects `pennyfarthing-dist/src/pf/package/portrait_cdn.py` (`ensure_portraits`: use `tar.extractall(path=theme_dir, filter="data")` on Python 3.12+, or validate members reject `..`/absolute paths). Enforced by `test_ensure_portraits_rejects_path_traversal_in_pack`. *Found by TEA during test design.*
- **Improvement** (non-blocking): The #17 reference uses `Path.read_text()`/`write_text()` for JSON manifests with no `encoding=` — locale-dependent (CWE-838, lang-review rule #5). Affects `portrait_cdn.py` (manifest + cache-meta I/O — pass `encoding="utf-8"`). Not unit-asserted in RED; flag for Dev/Reviewer. *Found by TEA during test design.*
- **Question** (non-blocking): AC "CDN cache added to theme dir discovery" — the CDN cache is `~/.local/share/pennyfarthing/portraits/{theme}/` with no sibling `themes/*.yaml`, but `tui/portrait_resolver.py` derives portraits as `themes_dir.parent/"portraits"/theme` and resolves slugs from theme YAML. Wiring the flat CDN cache into `discover_all_theme_dirs()` therefore needs an integration decision (resolver may need a CDN-cache branch, or `resolve_portrait()` from this module is called directly). Affects `tui/portrait_resolver.py` + `common/themes.py`. Out of RED scope — Dev/Architect to resolve in GREEN/spec-check. *Found by TEA during test design.*

### Dev (implementation)
- **Gap** (blocking) — **RESOLVED in GREEN**: The four integration ACs (activation call, CDN participates in resolution, `pf portraits` CLI, `~/.pennyfarthing/portraits/` override) are now wired and tested (7 wiring tests) and verified against the live bucket. The resolver calls `portrait_cdn.ensure_portraits()` + `_find_portrait` on the CDN cache directly rather than via `discover_all_theme_dirs()` (the flat CDN cache doesn't fit that theme-yaml-sibling shape). *Found by Dev during implementation; resolved same phase.*
- **Improvement** (blocking) — **RESOLVED in GREEN**: **Live-CDN bug.** The CDN (Cloudflare) returns **403 Forbidden** to the default `Python-urllib/x.y` User-Agent — so the issue-#17 reference module (no UA) would have failed every fetch and "graceful degradation" would have meant the CDN portraits *never* load, silently. Confirmed empirically (default UA → 403; any real UA → 200/15060 bytes). Fixed: explicit `User-Agent: pennyfarthing-portrait-cdn/1.0` on both manifest and pack requests; pack download moved from `urlretrieve` (no header support) to `urlopen`+`Request`. Locked by `test_requests_set_user_agent`. Affects `package/portrait_cdn.py`. **The original 38 mock-only tests did not catch this — only real-CDN testing did. Reviewer: confirm UA is sent on all requests.** *Found by Dev during implementation; resolved same phase.*
- **Improvement** (non-blocking): The CDN manifest's `updated` field read `2026-04-26` while the bucket was synced today (carried over from SM/setup notes). Not a code issue — CDN-ops/manifest-regeneration concern. The module's etag + 24h rate limit handle staleness gracefully. *Noted by Dev during implementation.*
- Both TEA blocking findings were resolved in this phase: safe extraction (`tar.extractall(filter="data")`, rejection → graceful `TarError`) and `encoding="utf-8"` on all text I/O. No new code-level findings.

### TEA (test verification)
- **Conflict** (blocking — process): Story PR **#72 was already MERGED into `develop`** while the workflow is still at the `verify` phase (Reviewer has not yet reviewed). The TDD flow (verify → review → spec-reconcile → finish) was short-circuited; the code is live on `develop` un-reviewed. Affects sprint process, not code. Surfaced for the human/SM to decide whether a retroactive review or a corrective process fix is warranted. *Found by TEA during test verification.*
- **Improvement** (non-blocking): `portrait_cdn.status()` walks `(cache/t).rglob("*.png")` **twice** per theme — once to count, once to sum bytes. Affects `pennyfarthing-dist/src/pf/package/portrait_cdn.py` (`status`: collapse to a single walk accumulating count + size). Not applied — PR already merged; bundle into a follow-up cleanup. *Found by TEA during test verification.*
- **Improvement** (non-blocking): Cross-module size-fallback inconsistency — `portrait_cdn.resolve_portrait` orders the `large` preference as `[large, original, medium, small]` while `tui/portrait_resolver._find_portrait` uses `[large, medium, small, original]`. Both derive from the #17 reference but now disagree; a shared `_size_order(preferred)` helper would prevent drift. Affects `portrait_cdn.py` + `tui/portrait_resolver.py`. *Found by TEA during test verification.*
- **Question** (non-blocking): `tui/portrait_resolver.resolve_portrait_path` reaches into the private `portrait_cdn._cache_dir()`. Works, but couples the resolver to a private name; consider a public accessor or resolving via the public `resolve_portrait()`. Design call for Reviewer. *Found by TEA during test verification.*
- Note: simplify-quality's "ignored `ensure_portraits` return value" findings (session_start.py, resolver) were assessed as **intentional graceful degradation** (SOUL #10 — caller deliberately no-ops on failure so the session continues without portraits), not defects. simplify-efficiency's `discovery.py::has_portraits` finding is **out of scope** (not changed by this story).

### Reviewer (code review)
- **Improvement** (blocking — security, deferred to follow-up since PR already merged): `clean()` deletes arbitrary directories — `cache / theme` → `shutil.rmtree` with no containment check (CWE-22). `pf portraits clean ../../../../.ssh` removes `~/.ssh`. Affects `pennyfarthing-dist/src/pf/package/portrait_cdn.py:252` (resolve + assert child-of-cache before rmtree). *Found by Reviewer during review.*
- **Improvement** (blocking — security, deferred): `ensure_portraits()` does not sanitize `theme` before `cache / theme` and `cache / f".{theme}.tar.gz.tmp"` (CWE-22). Affects `portrait_cdn.py:134,150` (reject `/`,`\`,`..`,empty once up front). *Found by Reviewer during review.*
- **Improvement** (blocking — correctness, deferred): `manifest['base_url']` and `entry['pack_sha256']` are unguarded key accesses outside any try/except → `KeyError` on a malformed manifest breaks the documented "never raises" contract, tracebacks in `pf portraits fetch`, and leaks the `.tmp` on the sha path. Affects `portrait_cdn.py:149,161` (use `.get()` + guards). *Found by Reviewer during review.*
- **Improvement** (non-blocking — security, deferred): SSRF — `base_url` from the manifest body is interpolated into the pack URL and `urlopen` honors `file://`/`ftp://`/internal hosts (CWE-918); integrity is no defense since the SHA256 comes from the same manifest. Affects `portrait_cdn.py:149` (build from hardcoded `CDN_BASE_URL` or validate scheme/host). *Found by Reviewer during review.*
- **Improvement** (non-blocking — correctness, deferred): `tar.extractall(filter="data")` raises `TypeError` (not `TarError`) on Python 3.11.0–3.11.3, which is within `requires-python = ">=3.11"`; it escapes the handler and is swallowed by outer bare-excepts, so the traversal guarantee is false there. Affects `portrait_cdn.py:167` + `pyproject.toml` (bump floor to 3.11.4 or catch `TypeError`). *Found by Reviewer during review.*
- **Gap** (blocking — test, deferred): `test_resolver_returns_none_when_nothing_cached` is not network-isolated — with no sentinel seeded it falls through to a live `urlopen` against the real CDN. Affects `pennyfarthing-dist/src/pf/tests/test_154_1_portrait_cdn_wiring.py` (force `urlopen` failure / `FakeCDN(fail_network=True)`). *Found by Reviewer during review.*
- **Improvement** (non-blocking — test, deferred): `test_..._download_failure_is_graceful` tmp-cleanup assertions are vacuous (`urlopen` raises before the file is created, so `tmp.unlink` is never exercised). Affects `test_154_1_portrait_cdn.py:332`. Corrects the verify-phase note that credited this as a strengthening. *Found by Reviewer during review.*
- **Gap** (non-blocking — test+impl, deferred): the path-traversal test never asserts `success is False` nor that partially-extracted members are cleaned; `ensure_portraits` does not `rmtree(theme_dir)` on `TarError`, leaving a populated-but-sentinel-less dir for retries. Affects `test_154_1_portrait_cdn.py:386` + `portrait_cdn.py:166-174`. *Found by Reviewer during review.*
- **Recommendation:** materialize story **154-2 (portrait_cdn hardening)** under epic 154 to carry the eight findings above plus the deferred lower-severity items (bare-except logging, tmp-name race, download size cap, stale-sentinel, status() double-walk, `pf portraits fetch` test).

## Impact Summary

**Upstream Effects:** No upstream effects noted
**Blocking:** None

### Deviation Justifications

5 deviations

- **CLI command surface (`pf portraits status|clean`) tested at the module layer, not the click layer**
  - Rationale: Avoids coupling RED to an unspecified command-group wiring decision; the substance (cache stats + removal) is fully covered at the function level.
  - Severity: minor
  - Forward impact: Dev wires the click commands in GREEN; Reviewer confirms the CLI surface exists and delegates to the tested functions.
- **Integration wiring done in GREEN (resolver/activation/CLI) rather than deferred — and Dev modified TEA's test harness**
  - Rationale: User explicitly required end-to-end wiring this phase; deferring would not deliver "TUI reads from R2". New behaviour is covered by 7 wiring tests + a UA regression test, and verified against the live bucket. The harness edit models a real CDN constraint the original mocks missed.
  - Severity: major (cross-file integration + Dev touching test files — flagged for Reviewer scrutiny)
  - Forward impact: Reviewer/Architect should confirm the resolver priority order and the harness change. Legacy LFS/cyclist fallbacks remain in place (not removed) — candidate for a future deprecation once R2 coverage is confirmed for all themes.
- **Pack download transport changed from the reference's `urlretrieve` to `urlopen` + `shutil.copyfileobj`**
  - Rationale: `urlretrieve` cannot attach request headers; the live CDN 403s the default `Python-urllib` UA (confirmed empirically — see Delivery Findings → Dev). The transport had to move to `urlopen`/`Request` to send a UA on the pack fetch.
  - Severity: minor (behavior-preserving; required to make the documented "download from CDN" AC actually work against the real bucket)
  - Forward impact: the FakeCDN test harness was updated to serve the pack via `urlopen` (logged by Dev). No further downstream effect.
- **Security hardening added beyond the reference drop-in module**
  - Rationale: TEA flagged the unfiltered extraction (path traversal) and locale-dependent I/O as blocking findings; Dev resolved both in GREEN.
  - Severity: minor (additive hardening — improves on the spec, does not change the contract)
  - Forward impact: `filter="data"` is necessary-not-sufficient — Reviewer found it does not guard the *destination* `theme_dir` (CWE-22 via theme name) and raises `TypeError` on Python 3.11.0–3.11.3. Those gaps are tracked as Reviewer findings C1/C2/C5 for hardening story 154-2.
- **CLI surface expanded beyond the spec's `status`/`clean`**
  - Rationale: `list` surfaces `list_cached()` (already implemented for `status`) and `fetch` exposes `ensure_portraits()` for manual/operator use; both are thin wrappers over already-tested functions.
  - Severity: trivial (extra-in-code, additive; the two spec'd commands are present)
  - Forward impact: `fetch` is the unguarded entry point that surfaces the C3 KeyError traceback and the C1/C2 traversal — covered by hardening 154-2; it also lacks a dedicated wiring test (Reviewer deferred item).

## Design Deviations

### TEA (test design)
- **CLI command surface (`pf portraits status|clean`) tested at the module layer, not the click layer**
  - Spec source: issue #17 acceptance criteria, "pf portraits status / pf portraits clean CLI commands"
  - Spec text: "pf portraits status / pf portraits clean"
  - Implementation: RED tests assert the `status()`/`clean()`/`list_cached()` module-function contract the CLI wraps; the click command-group placement (`pf portraits` vs `pf package`) is unspecified in #17 and left to Dev, with a thin command-layer integration test deferred to verify/review.
  - Rationale: Avoids coupling RED to an unspecified command-group wiring decision; the substance (cache stats + removal) is fully covered at the function level.
  - Severity: minor
  - Forward impact: Dev wires the click commands in GREEN; Reviewer confirms the CLI surface exists and delegates to the tested functions.

### Dev (implementation)
- **Integration wiring done in GREEN (resolver/activation/CLI) rather than deferred — and Dev modified TEA's test harness**
  - Spec source: context-story-154-1.md + issue #17 ACs (CDN in discovery, ensure_portraits at activation, `pf portraits` CLI, local override) + user directive ("wire it up now")
  - Spec text: "Add ~/.local/share/pennyfarthing/portraits/{theme}/ as a new search location" / "Call ensure_portraits(theme) from prime/agent activation"
  - Implementation: Wired the CDN into `tui/portrait_resolver.py::resolve_portrait_path` (the shared resolver) with priority override→local→CDN→legacy, plus `~/.pennyfarthing/portraits/` override, `session_start` activation, and a `pf portraits` CLI group. Rather than add to `discover_all_theme_dirs()` (whose entries are *theme-yaml* dirs with sibling `portraits/`, a shape the flat CDN cache doesn't fit), the resolver calls `portrait_cdn.ensure_portraits()` + `_find_portrait` on the CDN cache directly — same `{size}/{slug}.png` layout, zero change to `_find_portrait`. **Dev also edited the TEA-authored test file** (`test_154_1_portrait_cdn.py`): `FakeCDN` now serves the pack via `urlopen` and a UA regression test was added, because the live-CDN UA bug (below) required moving pack download off `urlretrieve`.
  - Rationale: User explicitly required end-to-end wiring this phase; deferring would not deliver "TUI reads from R2". New behaviour is covered by 7 wiring tests + a UA regression test, and verified against the live bucket. The harness edit models a real CDN constraint the original mocks missed.
  - Severity: major (cross-file integration + Dev touching test files — flagged for Reviewer scrutiny)
  - Forward impact: Reviewer/Architect should confirm the resolver priority order and the harness change. Legacy LFS/cyclist fallbacks remain in place (not removed) — candidate for a future deprecation once R2 coverage is confirmed for all themes.

### Architect (reconcile)

Verified the TEA and Dev entries above — both are accurate and complete (6 fields, real spec sources, implementation matches code). Spec authority: the story context (`sprint/context/context-story-154-1.md`) is a stub with no formal ACs, so the binding spec is **GitHub issue #17** (the "drop-in reference module" + its 9-item acceptance-criteria list). No epic-154 context doc exists; epic 154 has no sibling stories, so there is no sibling-AC cross-reference and no AC-deferral table to reconcile. Three deviations from the #17 reference were not formally logged by TEA/Dev — recording them here for audit completeness:

- **Pack download transport changed from the reference's `urlretrieve` to `urlopen` + `shutil.copyfileobj`**
  - Spec source: issue #17, "Consuming the existing CDN from Python" reference module
  - Spec text: `urllib.request.urlretrieve(pack_url, tmp)`
  - Implementation: `portrait_cdn.py:153-156` issues a `urllib.request.Request(pack_url, headers={"User-Agent": …})` and streams the body with `with urlopen(...) as resp, open(tmp, "wb"): shutil.copyfileobj(...)`.
  - Rationale: `urlretrieve` cannot attach request headers; the live CDN 403s the default `Python-urllib` UA (confirmed empirically — see Delivery Findings → Dev). The transport had to move to `urlopen`/`Request` to send a UA on the pack fetch.
  - Severity: minor (behavior-preserving; required to make the documented "download from CDN" AC actually work against the real bucket)
  - Forward impact: the FakeCDN test harness was updated to serve the pack via `urlopen` (logged by Dev). No further downstream effect.

- **Security hardening added beyond the reference drop-in module**
  - Spec source: issue #17 reference module (`ensure_portraits`, manifest/cache text I/O)
  - Spec text: `tar.extractall(path=theme_dir)` and `Path.read_text()` / `write_text()` with no `encoding=`
  - Implementation: `portrait_cdn.py` extracts with `tar.extractall(path=theme_dir, filter="data")` (CWE-22 member guard) and passes `encoding="utf-8"` on all 7 text-I/O calls (CWE-838); an explicit `User-Agent` is sent on every request.
  - Rationale: TEA flagged the unfiltered extraction (path traversal) and locale-dependent I/O as blocking findings; Dev resolved both in GREEN.
  - Severity: minor (additive hardening — improves on the spec, does not change the contract)
  - Forward impact: `filter="data"` is necessary-not-sufficient — Reviewer found it does not guard the *destination* `theme_dir` (CWE-22 via theme name) and raises `TypeError` on Python 3.11.0–3.11.3. Those gaps are tracked as Reviewer findings C1/C2/C5 for hardening story 154-2.

- **CLI surface expanded beyond the spec's `status`/`clean`**
  - Spec source: issue #17 acceptance criteria
  - Spec text: "pf portraits status / pf portraits clean"
  - Implementation: `pf.package.cli` exposes a `portraits` group with `status`, `clean`, **plus `list` and `fetch`**, registered as a top-level lazy command in `cli.py`.
  - Rationale: `list` surfaces `list_cached()` (already implemented for `status`) and `fetch` exposes `ensure_portraits()` for manual/operator use; both are thin wrappers over already-tested functions.
  - Severity: trivial (extra-in-code, additive; the two spec'd commands are present)
  - Forward impact: `fetch` is the unguarded entry point that surfaces the C3 KeyError traceback and the C1/C2 traversal — covered by hardening 154-2; it also lacks a dedicated wiring test (Reviewer deferred item).

**Reconcile verdict:** The deviation manifest is complete and the implementation's divergences from #17 are all accounted for (logged or recorded above) — none are unaccounted-for spec violations. The eight Reviewer-confirmed findings (C1–C8) are **quality/security defects, not spec deviations** — issue #17's drop-in module simply carried them, and the spec never forbade them; they are tracked in Delivery Findings → Reviewer with a recommendation to materialize **story 154-2 (portrait_cdn hardening)**. Story 154-1 ships a working, spec-faithful feature with documented, downstream-tracked hardening debt.