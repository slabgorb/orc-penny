# Story 154-2 Context

## Title
portrait_cdn hardening: path-traversal in clean()/ensure_portraits, manifest SSRF + KeyError guards, py3.11 filter, test isolation (Reviewer C1-C8)

## Metadata
- **Story ID:** 154-2
- **Type:** bug
- **Points:** 5
- **Priority:** p1
- **Workflow:** tdd
- **Repo:** pennyfarthing
- **Epic:** R2 CDN portrait distribution

## Problem
Story 154-1 shipped `portrait_cdn.py` (the R2 CDN consumer module) to develop today
(PR #72). PR #73 then excluded bundled portraits from the wheel — so this module is now
the **primary** portrait source for every installed user. The Reviewer (Granny Weatherwax)
confirmed **eight defects (C1–C8)** during the 154-1 review and deferred them to this
hardening story. These are quality/security defects, NOT spec deviations — issue #17's
drop-in module carried them in. Full findings: `sprint/archive/154-1-session.md` (Reviewer
section, lines ~215–245).

## Technical Approach
TDD: each finding below has a recommended fix and most name the exact line. TEA writes a
failing test per finding (RED), Dev makes them pass (GREEN). Module under change:
`pennyfarthing-dist/src/pf/package/portrait_cdn.py`. Test files:
`pennyfarthing-dist/src/pf/tests/test_154_1_portrait_cdn.py` and
`test_154_1_portrait_cdn_wiring.py`. Preserve the "never raises" contract: all guarded
failures return `{success: False, ...}`, they do not throw.

## Confirmed Findings (C1–C8) — the spec
- **C1 — `clean()` deletes arbitrary directories (CWE-22, Major).** `portrait_cdn.py:252` —
  `shutil.rmtree(cache/theme)` with no containment check; `pf portraits clean ../../../.ssh`
  escapes the cache. Fix: resolve and assert `cache.resolve()` is an ancestor before rmtree.
- **C2 — `ensure_portraits()` theme-name traversal (CWE-22, Major).** `portrait_cdn.py:134,150`
  — `cache/theme` and the `.tmp` path are unsanitized; a crafted theme name (CLI arg, config,
  or MITM manifest key) places dirs/files outside the cache. `filter="data"` guards tar
  *members*, not theme_dir placement. Fix: reject `/`, `\`, `..`, empty in `theme` up front.
- **C3 — Unguarded `manifest['base_url']` / `entry['pack_sha256']` (Major).**
  `portrait_cdn.py:149,161` — bare key access outside try/except; malformed manifest →
  `KeyError` breaks the "never raises" contract, tracebacks in `pf portraits fetch`, and the
  `pack_sha256` KeyError leaks the downloaded `.tmp`. Fix: `.get()` with guards returning
  `{success: False}`.
- **C4 — SSRF via manifest `base_url` (CWE-918, Minor).** `portrait_cdn.py:149` — `base_url`
  from the manifest body flows into `urlopen`, which honors `file://`/`ftp://`/internal hosts;
  SHA256 is no defense (same source). Fix: build from hardcoded `CDN_BASE_URL`, or validate
  scheme==https and host==expected.
- **C5 — `filter="data"` raises `TypeError` on Python 3.11.0–3.11.3 (Minor).**
  `portrait_cdn.py:167` — the `filter=` kwarg landed in 3.12/3.11.4+, but
  `requires-python = ">=3.11"`. On 3.11.0–3.11.3 it raises `TypeError` (not `TarError`),
  escapes the handler, gets swallowed → extraction silently never runs, traversal guarantee
  false. Fix: bump floor to 3.11.4 (pyproject.toml) or catch `TypeError` → visible failure.
- **C6 — Wiring test hits the live CDN (Major, test).** `test_154_1_portrait_cdn_wiring.py`
  `test_resolver_returns_none_when_nothing_cached` seeds no sentinel → real `urlopen` against
  `portraits.darkatelier.org`. Not hermetic. Fix: monkeypatch `urlopen` to fail / install
  `FakeCDN(fail_network=True)`.
- **C7 — Vacuous tmp-cleanup assertion (Minor, test).** `test_154_1_portrait_cdn.py:332` —
  `test_..._download_failure_is_graceful` asserts no `*.tmp` remains, but `urlopen` raises
  before the file is created, so it passes trivially without exercising `tmp.unlink()`. Fix:
  pre-create the tmp file, then assert removal.
- **C8 — Traversal test under-asserts + partial-extraction not cleaned (Minor, test+impl).**
  `test_154_1_portrait_cdn.py:386` never asserts `result["success"] is False` nor that partial
  members are cleaned; `ensure_portraits` does not `rmtree(theme_dir)` on `TarError`, leaving a
  populated-but-sentinel-less dir for retries. Fix: assert the contract + clean `theme_dir` on
  extraction failure.

## Scope
- In scope: C1–C8 above, in `portrait_cdn.py` and its two test files (+ pyproject.toml floor
  for C5).
- Out of scope: new CDN features, manifest-generation changes, the broader bare-except cleanup
  noted as deferred in 154-1 (unless a finding's fix touches it directly).

## Acceptance Criteria
- C1: `clean(theme)` with a traversing name returns `{success: False}` and deletes nothing
  outside the cache; regression test covers it.
- C2: `ensure_portraits` rejects `/`, `\`, `..`, empty theme names before any path is built;
  no file/dir is created outside the cache.
- C3: malformed manifest (missing `base_url` / `pack_sha256`) returns `{success: False}`,
  raises nothing, and leaves no `.tmp` behind.
- C4: pack URL is built from the hardcoded `CDN_BASE_URL` (or scheme/host validated); a
  poisoned `base_url` cannot redirect the fetch.
- C5: extraction works (or fails visibly) across the full supported Python range; floor is
  3.11.4 or `TypeError` is caught — no silent skip.
- C6: the wiring test is hermetic — no network call to the live CDN.
- C7: the tmp-cleanup test pre-creates the tmp file and proves `tmp.unlink()` runs.
- C8: the traversal test asserts `success is False` and that `theme_dir` is cleaned after a
  `TarError`; retries do not re-enter a populated dir.

---
_Enriched by SM from Reviewer findings in `sprint/archive/154-1-session.md`._
