---
story_id: "155-10"
jira_key: ""
epic: "155"
workflow: "tdd"
---
# Story 155-10: Backfill 77 historical epic:'' rows in sprint-2610-completed.yaml via prefix-parse migration (155-4 AC3)

## Story Details
- **ID:** 155-10
- **Jira Key:** (none)
- **Workflow:** tdd
- **Repos:** pennyfarthing
- **Branch:** chore/155-10-backfill-epic-refs
- **PR:** pennyfarthing#155 (https://github.com/slabgorb/pennyfarthing/pull/155, base develop)
- **Stack Parent:** none

## Workflow Tracking
**Workflow:** tdd
**Phase:** finish
**Phase Started:** 2026-07-30T14:11:50Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-07-30T13:51:38Z | 2026-07-30T13:53:25Z | 1m 47s |
| red | 2026-07-30T13:53:25Z | 2026-07-30T14:00:23Z | 6m 58s |
| green | 2026-07-30T14:00:23Z | 2026-07-30T14:04:08Z | 3m 45s |
| review | 2026-07-30T14:04:08Z | 2026-07-30T14:11:50Z | 7m 42s |
| finish | 2026-07-30T14:11:50Z | - | - |

## Sm Assessment

**Routing:** 2-point chore, but workflow is explicitly `tdd` in the sprint YAML — honoring the tag over the 1-2pt→trivial fallback. Phased TDD: setup → red (TEA) → green (Dev) → review → finish. Next agent: **tea**.

**Jira:** Story has no Jira key (`jira: null` in YAML). Claiming explicitly skipped — do not fabricate a key.

**Scope guard:** This story implements a prefix-parse migration (`144-5` → epic `144`) for HISTORICAL archive rows only — the 77 `epic: ''` rows in `sprint/archive/sprint-2610-completed.yaml` (orchestrator repo) from long-archived epics 143/144/145, which `archive_epic.backfill_epic_refs` marks irrecoverable because it only resolves from live sprint data. The live finish path's no-prefix-parse rule (established in 155-4) must NOT change. Note the cross-repo shape: the migration code lives in `pennyfarthing/` (branch created off `develop`), but the target data file lives in the orchestrator repo.

**Story context:** `sprint/context/context-story-155-10.md`. Original AC wording: 155-4 AC3 (see archived 155-4 session in `sprint/archive/` if present).

## TEA Assessment

**Tests Required:** Yes
**Reason:** Chore-typed but explicitly `workflow: tdd`; the story adds new behavior (a guarded migration mode) to `backfill_epic_refs` + its CLI.

**Test Files:**
- `pennyfarthing-dist/src/pf/tests/test_155_10_backfill_prefix_parse.py` — prefix-parse migration mode contract (13 tests; committed `2e3765f48` on `chore/155-10-backfill-epic-refs`)

**Tests Written:** 13 tests (11 RED + 2 intentional green guards) covering the TEA-authored AC set
**Status:** RED (verified via direct scoped run: 11 failed — 10 on the `pytest.fail` missing-`prefix_parse`-parameter assertion, 1 on the missing `--prefix-parse` CLI option assertion; 0 errored; existing sibling suite `test_archive_epic_field_validation.py` still 9/9 green)

**Designed interface for Dev (B.A.):**
- `backfill_epic_refs(project_root=None, *, prefix_parse=False)` — default path byte-identical to today.
- With `prefix_parse=True`: live-sprint lookup FIRST (live always wins — see precedence test), then for still-unresolved rows derive epic from the id iff it matches `^\d+-\d+$` exactly (strict: `144-5-6`, `144-x`, `ghost-99`, `144`, `144-`, `-5` all stay irrecoverable). Epic written as a STRING (`'144'`). All-or-nothing rewrite invariant unchanged (partially-resolved file never rewritten → `_write_archive_file` guard can never reject).
- CLI: `pf sprint backfill-epics --prefix-parse` passes the flag through; default invocation keeps the exit-nonzero-on-irrecoverable contract.
- After GREEN in the framework repo: run the actual migration from the ORCHESTRATOR root (`pf sprint backfill-epics --prefix-parse`) and verify `grep -c "epic: ''" sprint/archive/sprint-2610-completed.yaml` → 0. That run completes the story's data half (see Delivery Findings).

### Rule Coverage

| Rule | Test(s) | Status |
|------|---------|--------|
| silent-exceptions / no silent fallback | `test_default_mode_numeric_id_stays_irrecoverable`, `test_default_cli_still_exits_nonzero_on_numeric_irrecoverable` | green guards (preservation) |
| input-validation | `test_prefix_parse_rejects_non_conforming_ids` (6 parametrized ids) | failing |
| fix-regressions | `test_prefix_parse_prefers_live_sprint_resolution`, `test_prefix_parse_mixed_file_keeps_all_or_nothing_rewrite` | failing |
| test-quality (self-check) | 0 vacuous assertions found; every test asserts concrete values/content | done |

**Rules checked:** 4 of 13 lang-review rules applicable to this diff have coverage; the rest (async, resource-leaks, deserialization, etc.) don't apply to a pure-YAML repair helper — existing 151-2/155-8 suites already cover path handling and the write guard.
**Self-check:** 0 vacuous tests found

**Handoff:** To Dev (B.A. Baracus) for GREEN

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/src/pf/sprint/archive_epic.py` — `backfill_epic_refs` gains keyword-only `prefix_parse: bool = False`; after the live-sprint lookup fails, an unambiguous numeric `{epic}-{seq}` id (`re.fullmatch(r"(\d+)-\d+", sid)`) resolves to its prefix. Placement after the live lookup gives live-wins precedence; the all-or-nothing rewrite condition is untouched. Docstring documents the 155-4 guard rationale.
- `pennyfarthing-dist/src/pf/sprint/cli.py` — `pf sprint backfill-epics --prefix-parse` flag passes through; default invocation unchanged.

**Tests:** 13/13 story tests passing (GREEN); regression batch 78/78 across `test_archive_epic_field_validation`, `test_archive_epic`, `test_155_3/4/7/8/9`, `test_get_archive_path`; ruff clean on all three touched/new files.
**Branch:** chore/155-10-backfill-epic-refs (pushed; commits `2e3765f48` tests, `b2db76856` impl)

**Data half executed (the story's actual deliverable):** ran `pf sprint backfill-epics --prefix-parse` from the orchestrator root — all 77 target rows in `sprint/archive/sprint-2610-completed.yaml` backfilled (`144-5 → '144'` etc., quoted strings), verified `grep -c "epic: ''"` → 0 and a YAML reload shows 161 rows / 0 empty-epic. The rewrite went through `_write_archive_file`, so it passed the non-empty-epic guard by construction. File left uncommitted for SM's finish commit (orchestrator-owned path). Two genuinely epic-less rows in the older sprint-2606 archive remain irrecoverable by design — see Delivery Findings.

**Handoff:** To Reviewer (Colonel Decker) for code review

## Reviewer Assessment

**Verdict:** APPROVED

**Data flow traced:** story id from archive YAML (`sid = str(story.get("id") or "").strip()`) → `re.fullmatch(r"(\d+)-\d+", sid)` → `match.group(1)` (digit-only str by construction) → `story["epic"]` → `_write_archive_file` (non-empty-epic guard, ruamel auto-quotes `'144'`). Safe because the derived value is `[0-9]+` by construction, lands only in YAML scalar content, and never reaches a `Path` — shard filenames (`epic-{ref}.yaml`) are built exclusively from `completed_epics`, which this function never writes (verified in `migrate_completed_archive`/`load_archive`).

**Pattern observed:** lookup-then-guarded-fallback ordering at `archive_epic.py:388-396` — live resolution first, opt-in fallback second, both feeding the untouched all-or-nothing rewrite guard at `archive_epic.py:404-405`. Good pattern: the new mode composes with existing invariants instead of re-implementing them.

**Error handling:** the new path cannot raise — `sid` is guaranteed str, `re.fullmatch` on str never raises, `.group(1)` is guarded by `if match:`; non-conforming ids land in `irrecoverable` and drive the CLI's pre-existing nonzero-exit (`ClickException`) path. SOUL #10 preserved ([RULE] #14 verified).

**Observations:**
1. [VERIFIED] Inverse-binding probe: source reverted to origin/develop with the branch test file kept → 11 failed / exactly the 2 intentional guards passed; restored, `git status --porcelain` empty. Tests bind to the fix. Complies with tests-must-bind discipline and the TEA green-guard deviations.
2. [VERIFIED] Real-data migration: `sprint/archive/sprint-2610-completed.yaml` now has 161 rows, 0 empty or non-string epics (`yaml.safe_load` recount), `grep -c "epic: ''"` → 0 — 155-4 AC3 discharged. Complies with the story's data-half AC and the `_write_archive_file` guard (write succeeded through it).
3. [TEST] Mutation testing (test-analyzer): 4/4 designed probes killed (default-flip, loose regex, order swap, int leak) plus a self-devised CLI-wiring mutation (hardcode `prefix_parse=True` in cli.py) killed by the CLI guard — the two green guards pin distinct layers (function default vs flag threading). Two LOW gaps confirmed non-blocking (CLI mixed-file with flag; `--json × --prefix-parse`).
4. [SEC] Security clean: digit-only capture group cannot carry separators or `..`; opt-in default keyword-only at both layers; regex linear-time (no ReDoS); archive YAML is local self-authored config — no trust boundary crossed.
5. [RULE] Rule-checker: 16 rules × 24 instances, 0 violations; independently confirmed `re.fullmatch(r"(\d+)-\d+", ...)` ≡ `^\d+-\d+$` against all 6 adversarial ids, and the rewrite guard is untouched line-for-line.
6. [EDGE] (domain covered directly — subagent disabled) `\d` matches Unicode decimal digits: `١٤٤-٥` → epic `'١٤٤'`. Confirmed LOW non-blocking (opt-in mode, self-authored local YAML, digit-class value, no path flow); `re.ASCII` is the optional hardening. Boundary ids `0-1`/`044-5` conform and resolve to `'0'`/`'044'` — no such rows exist in any archive; harmless.
7. [SILENT] (domain covered directly) No new try/except, no swallows; every unresolved row is reported in `irrecoverable` and the CLI exits nonzero — fail-loud contract intact in both modes.
8. [TYPE] `dict[str, Any]` return vs TypedDict — confirmed LOW, pre-existing pattern; annotations at the changed boundary are complete.
9. [DOC] (domain covered directly) Docstring and flag help are accurate and story-scoped; the CLI command body docstring doesn't restate the flag (the flag's own help does) — fine.
10. [SIMPLE] (domain covered directly) 6-line core change, zero new imports, reuses module-level `re` — minimal.

### Rule Compliance

| Rule (lang-review python.md) | Instances in diff | Verdict |
|---|---|---|
| #1 silent exceptions | 1 (test helper `_backfill_prefix` explicit TypeError→pytest.fail) | compliant — no production try/except added |
| #2 mutable defaults | `backfill_epic_refs` (bool), `backfill_epics` (click flag) | compliant |
| #3 type annotations at boundaries | `backfill_epic_refs` fully annotated; CLI return unannotated per file-wide convention | compliant |
| #4 logging | no logging imports in touched modules | N/A |
| #5 path handling | no new Path construction or file opens in diff | N/A (pre-existing `encoding=` omissions in untouched I/O → already covered by backlog encoding-sweep story) |
| #6 test quality | 13 tests, all specific-value assertions, no mocks, 6 parametrized cases hit distinct regex boundaries (mutation-proven) | compliant |
| #7 resource leaks | none introduced | N/A |
| #8 unsafe deserialization | regex on local YAML-sourced str; no pickle/eval/shell | compliant |
| #9 async | none | N/A |
| #10 import hygiene | zero new imports across all 3 files | compliant |
| #11 input validation | anchored fullmatch, digit-only; CLI boundary is a bool flag | compliant |
| #12 dependency hygiene | no dep changes | N/A |
| #13 fix-introduced regressions | validation applied uniformly in the loop; rewrite guard untouched; no new catch | compliant |
| SOUL #10 result objects | new path cannot raise; return shape unchanged | compliant |
| SOUL no-silent-fallback | opt-in keyword-only + flag, default byte-identical (mutation-proven) | compliant |

### Devil's Advocate

Suppose this code is broken. The most damaging failure would be the migration writing a WRONG epic ref that silently corrupts history: a story id like `144-5` whose real parent epic was renamed or was actually a Jira-keyed epic — prefix-parse writes `'144'` where a sibling resolved row says `PROJ-16358`. That inconsistency is real and visible in the migrated file (143-14 carries `PROJ-16358` while 143-16 now carries `'143'`). Is that corruption? No — it is exactly what the story specifies: the Jira mapping for long-archived epics is unrecoverable (that's WHY these rows were empty), and the numeric prefix is the only truth left. Nothing downstream joins `completed_stories[].epic` to `completed_epics` refs except `migrate_completed_archive`'s orphan grouping, where a non-matching ref degrades to orphan — the pre-migration state. A malicious or careless archive author could craft `999999999999-1` and mint epic `'999999999999'` — but they own the file; the write is local, loud, and git-tracked. A confused user might run `--prefix-parse` habitually instead of once — the second run reports zero work (idempotency test pins this), and genuinely-new empty rows from live epics still resolve live-first, so habit does no damage beyond masking nothing: unresolvable non-numeric rows still exit nonzero (sprint-2606's two rows prove that live today). A stressed filesystem failing mid-`write_text` could half-write the archive — pre-existing exposure in `_write_archive_file` (no atomic tmp-rename), unchanged by this diff, recoverable via git. The `144-5-6` ambiguity case is refused rather than guessed. I could not construct a scenario where this diff makes any state worse than pre-diff; the residual risks I found (Unicode digits, CLI test gaps, TypedDict) are all recorded as LOW non-blocking findings above.

**Handoff:** To Lieutenant Peck (SM) for finish-story — note the orchestrator working-tree data file awaits the finish commit.

## Subagent Results

| # | Specialist | Received | Status | Findings | Decision |
|---|-----------|----------|--------|----------|----------|
| 1 | reviewer-preflight | Yes | clean | none (48/48 green, ruff clean, no smells) | N/A |
| 2 | reviewer-edge-hunter | Skipped | disabled | N/A | Disabled via settings — domain covered directly by Reviewer (unicode-digit regex probe, boundary ids; 1 LOW finding confirmed) |
| 3 | reviewer-silent-failure-hunter | Skipped | disabled | N/A | Disabled via settings — domain covered directly by Reviewer (no new try/except in diff; failures land in `irrecoverable` + nonzero exit; clean) |
| 4 | reviewer-test-analyzer | Yes | findings | 2 (low) | confirmed 2 as LOW non-blocking (CLI-level mixed-file-with-flag gap; --json × --prefix-parse combination untested); 4/4 mutation probes killed + a 5th self-devised CLI-wiring mutation killed |
| 5 | reviewer-comment-analyzer | Skipped | disabled | N/A | Disabled via settings — domain covered directly by Reviewer (docstring/help text accurate; CLI command body docstring omits flag mention but flag help is complete; clean) |
| 6 | reviewer-type-design | Yes | findings | 1 (low) | confirmed 1 as LOW non-blocking (dict[str,Any] → TypedDict suggestion; pre-existing pattern) |
| 7 | reviewer-security | Yes | clean | none | N/A (independently confirmed: digit-only capture can't traverse; derived value never reaches a Path; opt-in default; no ReDoS) |
| 8 | reviewer-simplifier | Skipped | disabled | N/A | Disabled via settings — domain covered directly by Reviewer (6-line addition, no over-engineering; clean) |
| 9 | reviewer-rule-checker | Yes | clean | none (16 rules, 24 instances, 0 violations) | N/A |

**All received:** Yes (5 returned, 4 disabled with domains covered directly)
**Total findings:** 4 confirmed (all LOW, non-blocking), 0 dismissed, 0 deferred without decision

## Delivery Findings

Agents record upstream observations discovered during their phase.
Each finding is one list item. Use "No upstream findings" if none.

**Types:** Gap, Conflict, Question, Improvement
**Urgency:** blocking, non-blocking

<!-- Agents: append findings below this line. Do not edit other agents' entries. -->

### TEA (test design)
- **Gap** (non-blocking): The 77-row migration target is cross-repo — the data file lives in the ORCHESTRATOR repo, so framework pytest proves the tool only on replica fixtures.
  Affects `sprint/archive/sprint-2610-completed.yaml` (after GREEN, someone must actually run `pf sprint backfill-epics --prefix-parse` from the orchestrator root and verify `grep -c "epic: ''" sprint/archive/sprint-2610-completed.yaml` returns 0; the rewrite passing the `_write_archive_file` guard is implied by the file being rewritten at all).
  *Found by TEA during test design.*
- **Question** (non-blocking): In a partially-resolved file, `backfill_epic_refs` appends resolved rows to `backfilled` even though the file is NOT rewritten (pre-existing behavior) — the result slightly overstates work done. My mixed-file test pins only the no-rewrite invariant, not the reporting.
  Affects `pennyfarthing-dist/src/pf/sprint/archive_epic.py` (Dev may tighten the reporting or leave as-is; existing suite doesn't pin it either).
  *Found by TEA during test design.*

### Dev (implementation)
- **Gap** (non-blocking): The real migration run surfaced 2 additional epic-less rows the story's `grep "epic: ''"` count missed — `sprint/archive/sprint-2606-completed.yaml` rows `PROJ-14394` (standalone bug) and `td-3` (tech-debt initiative) have the epic KEY ABSENT rather than empty-string; both are genuinely epic-less and correctly stay irrecoverable under the strict `^\d+-\d+$` rule, but they make `pf sprint backfill-epics` exit non-zero even after a fully successful 2610 migration.
  Affects `sprint/archive/sprint-2606-completed.yaml` (needs a scoping decision — assign a category/sentinel, exempt standalone rows, or accept the non-zero exit; follow-up story candidate for epic 155).
  *Found by Dev during implementation.*
- **Improvement** (non-blocking): The migrated data file is left as an uncommitted working-tree modification in the orchestrator repo for SM's finish ceremony.
  Affects `sprint/archive/sprint-2610-completed.yaml` (SM commits it with the sprint bookkeeping; verified `grep -c "epic: ''"` → 0, 161 rows, epics written as quoted strings).
  *Found by Dev during implementation.*

### Reviewer (code review)
- **Improvement** (non-blocking): `\d` in the prefix regex matches Unicode decimal digits, so a pathological id like `١٤٤-٥` would prefix-parse to epic `'١٤٤'`; opt-in mode + local self-authored YAML + digit-only value (never path-interpolated) make this LOW.
  Affects `pennyfarthing-dist/src/pf/sprint/archive_epic.py` (optional hardening: pass `re.ASCII` to the fullmatch; fold into any future touch of this function).
  *Found by Reviewer during code review.*
- **Improvement** (non-blocking): No CLI-level test drives `--prefix-parse` over a mixed file (nonzero exit + "Backfilled: 1 / Irrecoverable: 1" output), and `--json × --prefix-parse` is untested; library-level tests cover the mechanics and the CLI output path is flag-independent shared code.
  Affects `pennyfarthing-dist/src/pf/tests/test_155_10_backfill_prefix_parse.py` (two small CLI tests if the file is ever revisited).
  *Found by Reviewer during code review (test-analyzer).*
- **Improvement** (non-blocking): `backfill_epic_refs` returns `dict[str, Any]`; a TypedDict (`BackfillResult`) would type-check the CLI's `entry['id']`/`entry['epic']` accesses — pre-existing pattern, not introduced here.
  Affects `pennyfarthing-dist/src/pf/sprint/archive_epic.py` (only if the function grows further).
  *Found by Reviewer during code review (type-design).*

## Design Deviations

Agents log spec deviations as they happen — not after the fact.
Each entry: what was changed, what the spec said, and why.

<!-- Agents: append deviations below this line. Do not edit other agents' entries. -->

### TEA (test design)
- **Prefix-parse mode pinned as OPT-IN (`prefix_parse=False` default + `--prefix-parse` CLI flag)**
  - Spec source: context-story-155-10.md, Problem section
  - Spec text: "add a prefix-parse fallback path for historical/archived ids (guarded so it does NOT weaken the live finish path's no-prefix-parse rule from 155-4)"
  - Implementation: Tests require an explicit keyword/flag; two green-on-arrival guards make an always-on fallback fail
  - Rationale: The context doesn't dictate the guard's shape. An always-on fallback inside `backfill_epic_refs` would silently patch any future numeric-id row on every default run — a silent-fallback regression of the 155-4 fail-loud contract. Opt-in is the only shape a test can enforce mechanically.
  - Severity: minor
  - Forward impact: Dev must add the keyword + CLI flag; may propose an alternative guard shape via consultation, but it must keep both green guards passing
- **ACs authored by TEA (context had none)**
  - Spec source: context-story-155-10.md, Acceptance Criteria section
  - Spec text: "No acceptance criteria recorded in the sprint YAML — TEA to define during the RED phase."
  - Implementation: ACs = the test contract in test_155_10_backfill_prefix_parse.py docstring (opt-in mode, live-wins ordering, `^\d+-\d+$` strict id validation, string epic values, all-or-nothing rewrite invariant, CLI flag + preserved default exit contract)
  - Rationale: Derived from the Problem statement, 155-4 AC3 wording, and the real offender data (all 77 rows verified unambiguous numeric `{epic}-{seq}`, prefixes 143–151)
  - Severity: minor
  - Forward impact: Reviewer should treat the test docstring as the AC record
- **Two intentional GREEN-on-arrival guard tests**
  - Spec source: context-story-155-10.md ("does NOT weaken the live finish path's no-prefix-parse rule")
  - Spec text: preservation requirement, not new behavior
  - Implementation: `test_default_mode_numeric_id_stays_irrecoverable` and `test_default_cli_still_exits_nonzero_on_numeric_irrecoverable` pass on HEAD by design
  - Rationale: Preservation ACs are correctly green (ac-as-green-regression-guard); they go red only if the fix over-applies
  - Severity: minor
  - Forward impact: Gate/Reviewer must not read the 2 passing tests as spurious
- **Actual 77-row backfill not covered by pytest**
  - Spec source: context-story-155-10.md ("backfill the 77 rows, and verify the rewrite passes the _write_archive_file non-empty-epic guard")
  - Spec text: as quoted
  - Implementation: Fixtures replicate the real file's shape (real ids/titles, mixed resolved/unresolved rows) but the real orchestrator-repo file is not touched by tests
  - Rationale: Framework tests cannot mutate another repo's data; the one-time run is an execution step, not a test
  - Severity: minor
  - Forward impact: Logged as a Delivery Finding — the CLI run + grep verification must happen before finish

### Dev (implementation)
- No deviations from spec. Implemented TEA's designed interface verbatim (opt-in keyword, live-wins ordering via lookup-then-fallback placement, strict `re.fullmatch(r"(\d+)-\d+", ...)`, string epic values — ruamel quotes numeric-looking strings on dump, so `'144'` needs no special handling). Left TEA's non-blocking `backfilled`-reporting Question as-is (pre-existing behavior, no test pins it).

### Reviewer (audit)
- **TEA: Prefix-parse mode pinned as OPT-IN** → ✓ ACCEPTED by Reviewer: the only mechanically-enforceable guard shape; mutation probe #1 + the CLI-wiring mutation prove both guards bind at distinct layers. Agrees with author reasoning.
- **TEA: ACs authored by TEA (context had none)** → ✓ ACCEPTED by Reviewer: context file explicitly delegated AC authorship to TEA; the test-file docstring is a complete, precise AC record consistent with 155-4 AC3 and the real offender data.
- **TEA: Two intentional GREEN-on-arrival guard tests** → ✓ ACCEPTED by Reviewer: verified via inverse-binding probe (11 failed / exactly these 2 passed on develop source) and mutation testing — they are preservation guards, not spurious greens.
- **TEA: Actual 77-row backfill not covered by pytest** → ✓ ACCEPTED by Reviewer: cross-repo data can't be owned by framework pytest; I independently verified the executed migration (161 rows, 0 empty/non-string epics, `grep -c "epic: ''"` → 0).
- **Dev: No deviations from spec** → ✓ ACCEPTED by Reviewer: diff matches the designed interface line-for-line; rule-checker confirmed the rewrite guard untouched.