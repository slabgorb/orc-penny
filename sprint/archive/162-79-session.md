---
story_id: "162-79"
jira_key: ""
epic: ""
workflow: "tdd"
---
# Story 162-79: Extend pf sprint story update with --type and --depends-on

## Story Details
- **ID:** 162-79
- **Jira Key:** (none — Jira-less project)
- **Workflow:** tdd
- **Stack Parent:** none
- **Branch:** feat/162-79-extend-story-update-type-depends-on
- **PR:** (none yet — recorded when the PR is created)

## Workflow Tracking
**Workflow:** tdd
**Phase:** finish
**Phase Started:** 2026-08-11T20:35:09Z
**Round-Trip Count:** 1

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-08-11T18:32:22Z | 2026-08-11T18:33:58Z | 1m 36s |
| red | 2026-08-11T18:33:58Z | 2026-08-11T18:42:43Z | 8m 45s |
| green | 2026-08-11T18:42:43Z | 2026-08-11T18:53:23Z | 10m 40s |
| review | 2026-08-11T18:53:23Z | 2026-08-11T19:04:52Z | 11m 29s |
| green | 2026-08-11T19:04:52Z | 2026-08-11T19:15:38Z | 10m 46s |
| review | 2026-08-11T19:15:38Z | 2026-08-11T20:35:09Z | 1h 19m |
| finish | 2026-08-11T20:35:09Z | - | - |

## Sm Assessment

**Story:** Extend `pf sprint story update` with `--type` and `--depends-on`, closing two CLI gaps surfaced by the epic-162 consolidation (see `docs/adr/0043` Implementation Sketch). Both are field-flag additions to the same command.

**Technical approach (for TEA/Dev — do not treat as prescriptive):**
- Target repo: `pennyfarthing/` (gitflow, off `develop`).
- Implementation: `pennyfarthing/pennyfarthing-dist/src/pf/sprint/story_update.py` + CLI wiring in `pennyfarthing/pennyfarthing-dist/src/pf/sprint/cli.py`.
- Mirror the existing sibling-flag plumbing: result-object return (`{success, data?, error?}` — Rule 6, no throw), `--dry-run`, and `--jira` sync behavior.
- The story schema already carries both fields: `type` (values in use: bug/chore/refactor/test/feature/doc) and `depends_on`. This wires `update` to write them; `add` already can.

**Acceptance criteria (authoritative text in `sprint/context/context-story-162-79.md` / epic YAML):**
- `pf sprint story update ID --type <value>` sets the story `type` field.
- `pf sprint story update ID --depends-on <ID>` sets/clears `depends_on`.
- Both honor `--dry-run` (truthful preview, no write) and `--jira` (sync) like sibling flags.
- Invalid `--type` values and self/nonexistent `--depends-on` targets fail loud via result objects, not exceptions.

**Context:** clean tree on `feat/162-79-extend-story-update-type-depends-on`; Jira-less (no claim); tdd/phased → routes to TEA for RED.

**Verdict:** Ready for RED phase. Handing to TEA (Igor).

## Tea Assessment

**RED state: confirmed.** 18 tests in `pennyfarthing-dist/src/pf/tests/test_162_79_story_update_type_depends_on.py` (commit `33f2f91c0`). 16 fail on HEAD for the intended reasons — `TypeError: update_story() got an unexpected keyword argument 'story_type'/'depends_on'` at the function level; `No such option: --type/--depends-on` at the CLI level. 2 passes are legitimate baselines (omitting `--type` preserves existing; unknown-option exit). No import/collection errors.

**Contract pinned for Dev (GREEN):**
- `update_story(..., story_type=X)` → `story["type"] = X`; canonical value accepted, unknown value rejected via result object (no throw), on-disk value unchanged on rejection.
- `update_story(..., depends_on=Y)` → `story["depends_on"] = Y`; **self-reference** and **nonexistent target** both fail loud (target must resolve via `find_story_in_data`); rejection does not mutate the shard.
- Both honor `--dry-run` (success + `dry_run: True`, zero on-disk change) and must be added to the `--epic` conflict `field_flags` dict (epic-160 no-silent-drop).
- CLI: `--type` and `--depends-on` options wired through, listed in `--help`; a rejected `--depends-on` target exits non-zero.
- Keyword naming mirrors `story_add` (`story_type`, `depends_on`) — the tests couple to those names for cross-function consistency.

**Rule Coverage (`gates/lang-review/python.md` + SOUL):**
- SOUL #10 return-results-don't-throw → `test_invalid_type_fails_loud_not_raises`, `test_self_dependency_fails_loud`, `test_nonexistent_target_fails_loud` (assert result objects, never exceptions).
- Rule 6 CLI truthfulness → `test_cli_depends_on_nonexistent_target_is_error_exit` (failed validation ⇒ non-zero exit, not silent 0).
- No new file I/O introduced (reuses the shard-aware `write_sprint` path), so the `encoding=`/CWE-838 checklist item is not applicable to this diff.

**Verdict:** RED confirmed, tests committed and signed. Handing to Dev (Ponder Stibbons) for GREEN.

## Dev Assessment

**GREEN: confirmed.** Commit `521ae0780` on `feat/162-79-extend-story-update-type-depends-on` (pushed). 18/18 story tests pass; 210/210 `story_update`/`epic` regression tests pass; no regressions.

**Changes (2 files):**
- `sprint/validator.py` — new `VALID_STORY_TYPES` constant beside `VALID_STORY_STATUSES`.
- `sprint/story_update.py` — `update_story` gains `story_type` + `depends_on` keywords; CLI gains `--type` (dest `story_type`) + `--depends-on`. Validation order preserves the no-mutation-on-rejection guarantee: `--type` and self-dependency checked before file read; nonexistent-target checked after the story loads (needs `data` for `find_story_in_data`). Both added to the `--epic` conflict `field_flags` dict. Mutations applied alongside the sibling fields; CLI failure raises `click.ClickException` → non-zero exit.

**Decisions (for Reviewer):**
- Canonical type set = generous **union** of on-disk corpus values + the 162 tagging request (`feature, fix, bug, chore, refactor, test, doc, docs, comment`). TEA flagged this as an explicit Dev/PM decision; I chose the union so no existing story is invalidated and every requested tag works. Logged under Design Deviations.
- Did **not** back-port target validation to `story add` (TEA Improvement finding) — out of scope for this story; left for a follow-up.

## Dev Assessment (Rework r1)

**Implementation Complete:** Yes — all 5 must-fix/folded findings (F1–F5) plus the optional F6 simplifications addressed.

**GREEN: confirmed.** Commit `91b22e92d` on `feat/162-79-extend-story-update-type-depends-on` (pushed). 21/21 story tests pass (18 original + 3 new); 1838 passed / 2 skipped across the `story_update`/`epic`/`validator`/`162` regression batch; ruff clean on both changed files. No regressions.

**Findings resolved:**
- **F1 (HIGH help-drift):** `--type` help string derived from `VALID_STORY_TYPES` — `help=f"Story type tag ({', '.join(sorted(VALID_STORY_TYPES))})"`. One source of truth; `docs` now discoverable.
- **F3 (MEDIUM under-built):** `type=click.Choice(sorted(VALID_STORY_TYPES), case_sensitive=False)` on the option. Resolves F1 + case-normalisation (`--type Feature` → `feature`) + exit-code consistency (invalid value → Click parse-error exit 2, matching `--status`/`--review-verdict`) in one change. Runtime `VALID_STORY_TYPES` check kept in `update_story` for direct callers. New tests: `test_cli_type_is_case_insensitive`, `test_cli_help_enumerates_all_valid_types` (asserts every value incl `docs`).
- **F2 (HIGH tautological test):** 162-3 fixture type → `chore`; sibling assertion now `== "chore"` (162-2 is updated to `feature`), so a clobber-every-story-to-updated-value bug is caught.
- **F4:** `test_cli_depends_on_nonexistent_target_is_error_exit` now asserts `"does not resolve" in result.output` — pins the reason, not just a non-zero exit.
- **F5:** added `test_cli_merged_view_reflects_depends_on_update` paralleling the `--type` merged-view test — shard→index merge path now covered for `depends_on`.
- **F6 (folded, free):** (a) self-dependency check folded into the post-read `depends_on` guard — one coherent block, self-dep reported only after the story resolves (also closes the D3 ordering nit); (b) the split implicitly-concatenated existence-failure f-string collapsed to one line.

**Files Changed (2):**
- `sprint/story_update.py` — `--type` option gains `click.Choice`/derived help; `depends_on` guard consolidated post-read.
- `tests/test_162_79_story_update_type_depends_on.py` — F2 fixture+assertion, F4 reason-pin, F5 + F3 new tests.

**Deferred (unchanged from round 1):** D1 (transitive cycle detection), D2 (dep on canceled/done/archived), D3 (`Literal`/`frozenset` hardening — partially touched by F6's ordering fix but not the type-hardening itself), D4 (pre-existing `except` blocks). All remain logged in Delivery Findings as follow-ups.

**Tests:** 21/21 story (GREEN). **Branch:** `feat/162-79-extend-story-update-type-depends-on` (pushed).

**Handoff:** To Reviewer (Granny Weatherwax) for re-review.

**Verdict:** GREEN, pushed. Handing to Reviewer (Granny Weatherwax).

## Subagent Results

**Working-tree audit (`pf reviewer audit-tree`):** exit 0 = PASS. The tool printed a "DIRTY" warning citing only `sprint/context/context-story-162-79.md` — an untracked **orchestrator setup artifact created by sm-setup**, not a source mutation. The code under review (`pennyfarthing/`) is clean (`git -C pennyfarthing status --short` empty). No `git clean` run (it would destroy the legitimate context file). False positive; proceeding.

| # | Specialist | Received | Status | Findings | Decision |
|---|-----------|----------|--------|----------|----------|
| 1 | reviewer-preflight | Yes | clean | 462 tests green, 0 smells, ruff clean | N/A |
| 2 | reviewer-edge-hunter | Yes | findings | 7 | confirmed 1, folded 2, deferred 3, dismissed 1 |
| 3 | reviewer-silent-failure-hunter | Yes | findings | 2 | deferred 2 (both pre-existing, not in diff) |
| 4 | reviewer-test-analyzer | Yes | findings | 6 | confirmed 1, folded 2, deferred 3 |
| 5 | reviewer-comment-analyzer | Yes | findings | 1 | confirmed 1 |
| 6 | reviewer-type-design | Yes | findings | 3 | confirmed 1, deferred 2 |
| 7 | reviewer-security | Yes | findings | 1 | dismissed 1 (existence check is a stronger gate) |
| 8 | reviewer-simplifier | Yes | findings | 3 | confirmed 1 (dup of F1), folded 2 |
| 9 | reviewer-rule-checker | Yes | findings | 2 | confirmed 2 (Rule 6 + Rule 13) |

**All received:** Yes (9 returned, 8 with findings)
**Total findings:** 3 confirmed must-fix, 2 folded (cheap, same cycle), 6 deferred (follow-ups), 1 dismissed (with rationale)

## Reviewer Assessment

**Round-Trip Count:** 0

The feature is correct, secure, and meets its ACs (462 tests green, security surface nil — pure in-memory validation + YAML field write, confirmed by [SEC]). But two HIGH-consensus defects and a converging consistency cluster warrant one rework pass before merge. In the *truthfulness* epic, a `--help` that lies about accepted values and a test that cannot catch its own regression are not polish.

### Confirmed findings — MUST FIX (rework)

- **F1 [DOC][RULE] HIGH — `--type` help omits `docs`.** `story_update.py:386` help lists `feature, fix, bug, chore, refactor, test, doc, comment`; `VALID_STORY_TYPES` (validator.py) also accepts **`docs`**. Corroborated by comment-analyzer, simplifier, and rule-checker (Rule 13) — three independent subagents. A user passing `--type docs` succeeds but cannot discover it from `--help`. Fix: derive the help string from the set — `help=f"Story type tag ({', '.join(sorted(VALID_STORY_TYPES))})"` — one source of truth.
- **F2 [TEST][RULE] HIGH — tautological sibling assertion.** `test_162_79_...py:157` asserts `sibling["type"] == "feature"`, but the 162-3 fixture is *already* `type: feature` (line 88). A bug that clobbers every story's type to `"feature"` passes this test. Verified directly against the fixture. Corroborated by test-analyzer + rule-checker (Rule 6). Fix: set 162-3's fixture type to `chore` and assert it stays `chore` (or assert a non-contaminable field).
- **F3 [TYPE][EDGE] MEDIUM — `--type` is under-built vs its siblings.** No `click.Choice` (type-design, high) and no case normalization (edge-hunter): `--type Feature` is hard-rejected while `--status` normalizes via `normalize_status`, and invalid `--type` exits 1 (ClickException) where `--status`/`--review-verdict` exit 2 (Click parse error) — scripts distinguishing these misclassify. **One fix resolves F1 + case-handling + exit-code consistency at once:** `type=click.Choice(sorted(VALID_STORY_TYPES), case_sensitive=False)` on the option (keep the runtime `VALID_STORY_TYPES` check in `update_story` for direct callers).

### Folded into the same rework (cheap, test-quality)

- **F4 [TEST] — CLI negative test proves too little.** `test_cli_depends_on_nonexistent_target_is_error_exit` asserts only `exit_code != 0`; add `assert "does not resolve" in result.output` so it pins the *reason*, not any non-zero exit.
- **F5 [TEST] — no `--depends-on` merged-view test.** `--type` has `test_cli_merged_view_reflects_type_update`; add the `depends_on` parallel so the shard→index merge path is covered.
- **F6 [SIMPLE] — two cheap simplifications** (simplifier, medium/high). (a) The `depends_on` guard is split across a pre-read self-check (`story_update.py:163`) and a post-read existence check (`:180`); fold the self-check into the post-read block for one coherent guard (also resolves the D3 ordering nit — self-dep would then be reported only after the story resolves). (b) Collapse the two-part implicitly-concatenated f-string in the existence-failure error (`:185`) into a single line. Both optional but free while Dev is in the file. (Simplifier's third finding — the hardcoded `--type` help list — is the same defect as F1.)

### Deferred — follow-ups, NOT this cycle (logged in Delivery Findings)

- **D1 [EDGE] MEDIUM — no transitive cycle detection.** Only `depends_on == story_id` is caught; a 2-hop cycle (A→B, B→A) is not, and the shard-file route (`validate_epic_shard`) never calls `_validate_depends_on`. No AC required cycle detection; it touches validator routing. Legitimate follow-up (candidate story), not a scope-add to 162-79.
- **D2 [EDGE] LOW — `depends_on` to a canceled/done/archived story is accepted.** Needs a product decision consistent with epic-160's "archived dependencies treated as satisfied." Follow-up.
- **D3 [TYPE] — `Literal` StoryType / `frozenset` for the constants.** Type-hardening; `frozenset` also applies to the pre-existing `VALID_STORY_STATUSES`. Optional.
- **D4 [SILENT] — two pre-existing `except` blocks** (`jira me` best-effort `pass`; archive-loader `except: return set()`). Not introduced by this diff; note only.

### Dismissed

- **[SEC] no format regex on `depends_on` at the CLI boundary (low).** Dismissed: `find_story_in_data` requires the value to resolve to a *real* story — a strictly stronger gate than a `NNN-NN` format regex for the only realistic risk. A format check adds no security value for a local CLI tool. (Not a rule-matching finding — no project rule mandates format pre-validation when a semantic existence check is present.)

### Rule Compliance (`gates/lang-review/python.md`, exhaustive)

Rule-checker enumerated 47 instances across 13 checks; I re-verified the two violations against source:
- **Rule 13 (fix-introduced regression) — VIOLATED:** F1 help/validator drift. Confirmed at `story_update.py:386` vs `validator.py`.
- **Rule 6 (test quality) — VIOLATED:** F2 tautological assertion. Confirmed at test line 157 vs fixture line 88.
- Rules 1,2,3,4,5,7,8,9,10,11,12 — **compliant.** No new `except`/mutable-defaults/path-I/O/deserialization/async/star-imports; new params fully annotated at both boundaries; input validated against a closed set before any use; `depends_on` never reaches a path join, subprocess, or regex ([SEC] confirmed).
- **SOUL #10 (return results, don't throw) — compliant:** all three new rejection paths return `{success: False, error}`; CLI surfaces them via `click.ClickException` (non-zero exit).

### Verified good

- `[VERIFIED]` `--type`/`--depends-on` correctly added to the `--epic` conflict `field_flags` dict — `story_update.py:123-124`; tested by `TestEpicConflictAndDryRun`. Complies with epic-160 no-silent-drop.
- `[VERIFIED]` dry-run writes nothing — `story_update.py:230-245` writes to a `tempfile.TemporaryDirectory()` then returns; tests assert byte-identical shard before/after.
- `[VERIFIED]` no CWE-22/injection surface — `depends_on` used only as a lookup key + dict field write; shard paths derive from `epic.id` (pre-loaded), not user input ([SEC]).
- `[VERIFIED]` `VALID_STORY_TYPES` union is deliberate and documented — accepts every on-disk value, so no existing story is invalidated by the post-mutation `validate_sprint_document`.

### Devil's Advocate

Argue this is broken. A user tagging stories after the 162 consolidation types `pf sprint story update 162-71 --type Bug` — capitalised, because that is how English works — and the tool rejects it outright instead of normalising to `bug`, even though `--status In_Progress` would have been accepted. They try `--type docs` because they saw `docs` in the corpus, it works, but `--help` never told them it would; then they try `--type documentation` and get a rejection listing values that don't match what `--help` showed — the tool contradicts itself. Now the deeper danger: the whole point of `--depends-on` is *sequencing*, and the implementation guards only the trivial self-loop. An agent wiring 162-61→162-65 and later 162-65→162-61 builds a cycle the tooling accepts; a downstream stack-ready gate or an agent that walks `depends_on` to find "what's unblocked" can spin. The shard-file validation route doesn't even run `_validate_depends_on`, so the one place cycles *could* be caught is bypassed when someone passes `--sprint-file epic-162.yaml`. And the test suite? It reports green while containing an assertion that would survive a function clobbering every story's type — so "462 passing" overstates the real coverage. A confused user, a scripted CI harness reading exit codes, and an agent traversing dependencies each hit a different sharp edge. None corrupts data or leaks secrets — the blast radius is UX honesty, test integrity, and sequencing safety — but for an epic whose charter is *truthfulness*, those are the exact things that matter. F1–F3 close the honesty and consistency edges now; D1 (cycles) is real and belongs in a follow-up, flagged so the next reviewer doesn't have to re-derive it.

### Verdict

**Verdict:** REJECTED — 2 HIGH-consensus quality defects (F1 help-drift, F2 tautological test) + the F3 `--type` consistency cluster. No Critical/High correctness or security defects, but these are cheap, well-evidenced, and on-theme for the truthfulness epic.

**Rework target: GREEN (Dev)** — per the tdd workflow's `recovery_config` (reviewer-verdict → rework → target_phase: green). Dev owns this rework end to end, tests included:
- F1 — derive the `--type` help from `VALID_STORY_TYPES` (one source of truth).
- F3 — `type=click.Choice(sorted(VALID_STORY_TYPES), case_sensitive=False)` on the option (keep the runtime set-check in `update_story`); add tests that `--type Feature` normalizes and that help enumerates all 9 values incl `docs`.
- F2 — change 162-3's fixture type to `chore` and assert it stays `chore` (de-tautologize).
- F4 — assert `"does not resolve"` in the CLI negative test output.
- F5 — add a `--depends-on` merged-view test paralleling the `--type` one.

Defer D1–D4 as follow-ups (logged in Delivery Findings). Handing to Dev (Ponder Stibbons).

## Delivery Findings

Agents record upstream observations discovered during their phase.
Each finding is one list item. Use "No upstream findings" if none.

**Types:** Gap, Conflict, Question, Improvement
**Urgency:** blocking, non-blocking

<!-- Agents: append findings below this line. Do not edit other agents' entries. -->

- **[TEA] Question / non-blocking** — The canonical story-`type` set is undefined. The live corpus mixes inconsistent values (`bug` 143 / `fix` 1, `docs` 2 / no `doc`, plus `chore`/`refactor`/`feature`/`test`), and the story text itself gives two mismatched lists: schema "bug/chore/refactor/test/feature/doc" vs the user's original tagging request "comment/test/doc/feature/fix". RED pins only *behavior* (a canonical value like `feature` is accepted, obvious garbage is rejected). **Dev/PM must define `VALID_STORY_TYPES` deliberately** — decide fix-vs-bug, docs-vs-doc, and whether `comment` is a real type — before hardcoding the reject set. A generous union that accepts every value already on disk avoids invalidating 315 existing stories.
- **[TEA] Improvement / non-blocking** — Validation asymmetry: this story makes `update --depends-on` reject self/nonexistent targets, but `story add --depends-on` (`story_add.py:134`) still writes `depends_on` unvalidated. Consider back-porting the same target-existence + self-reference guard to `add` in a follow-up so the truthfulness contract is uniform across both entry points.
- **[TEA] Note / non-blocking** — `test_cli_depends_on_nonexistent_target_is_error_exit` currently passes for the wrong reason (Click rejects the not-yet-existing `--depends-on` option). It remains valid post-GREEN because the impl must still reject `999-999` with a non-zero exit — Dev should confirm the nonexistent-target path produces a non-zero CLI exit, not a silent success.
- **[REVIEWER] Improvement / non-blocking (follow-up story candidate)** — No transitive dependency-cycle detection. `update_story` guards only `depends_on == story_id`; a 2-hop cycle (A→B, B→A) is undetected, and the shard-file validation route (`validate_epic_shard`) never invokes `_validate_depends_on`. No AC required cycle detection and it touches validator routing — defer to a dedicated story. Relevant to epic-162's sequencing/truthfulness charter.
- **[REVIEWER] Question / non-blocking (follow-up)** — `depends_on` accepts a target whose status is `canceled`/`done`/archived. Needs a deliberate decision consistent with epic-160's "archived dependencies treated as satisfied" — reject, warn, or allow. Pair with the `story add --depends-on` validation-asymmetry finding TEA raised.
- **[REVIEWER] Improvement / non-blocking (optional)** — Type-hardening: express the valid-type contract as `Literal`/derive the runtime set from it, and make `VALID_STORY_TYPES` (and pre-existing `VALID_STORY_STATUSES`) `frozenset`. Low value, no behavior change.

### Dev (rework r1)
- No new upstream findings during the F1–F6 rework. Deferrals D1–D4 (above) remain the outstanding follow-ups; none was in-scope for this cycle.

### Reviewer (re-review r1)
- **[REVIEWER] Improvement / non-blocking (follow-up story candidate)** — No way to clear `depends_on`. `--depends-on` can set/re-point a dependency but there is no `--clear-depends-on` flag (parallel to `--clear-ac`); a mistakenly-set dependency can only be removed by hand-editing YAML, which the project rules forbid. No AC required clear semantics — candidate story. Affects `pennyfarthing-dist/src/pf/sprint/story_update.py`.
- **[REVIEWER] Improvement / non-blocking (fast-follow, trivial)** — Two on-theme comment/test nits safe to sweep in any nearby edit: (a) `story_update.py:386` comment bundles case-normalisation into the "matching `--status`/`--review-verdict`" claim, but those siblings are case-*sensitive* — reword to scope the parity to exit-2 only; (b) `test_cli_help_enumerates_all_valid_types` uses a bare `value in flattened` substring check, so `doc` passes vacuously off `docs` — use a word-boundary regex. Neither blocks merge (help is derived from the set, so drift is structurally impossible). Affects `pennyfarthing-dist/src/pf/sprint/story_update.py`, `pennyfarthing-dist/src/pf/tests/test_162_79_story_update_type_depends_on.py`.
- **[REVIEWER] Improvement / non-blocking (test-quality)** — Optional test hardening: `test_self_dependency_fails_loud` should assert the shard is unmutated after rejection (its sibling does); the function-level rejection tests assert error presence not content; the merged-view tests don't gate on `exit_code == 0`; `test_type_update_succeeds` is subsumed by the persistence test. All cosmetic/robustness, none affects behaviour coverage materially. Affects `pennyfarthing-dist/src/pf/tests/test_162_79_story_update_type_depends_on.py`.

## Impact Summary

**Upstream Effects:** No upstream effects noted
**Blocking:** None

### Deviation Justifications

2 deviations

- **Defined `VALID_STORY_TYPES` as a generous union rather than a strict enum**
- **`--type` invalid-value CLI exit code changed 1 → 2**
  - Severity: minor
  - Forward impact: minor — any script that specifically distinguished `--type`'s old exit-1 from Click's exit-2 would now see exit 2; this is the intended alignment, not a regression. No test asserted exit 1 for invalid `--type`.

## Design Deviations

Agents log spec deviations as they happen — not after the fact.
Each entry: what was changed, what the spec said, and why.

<!-- Agents: append deviations below this line. Do not edit other agents' entries. -->

### Dev (implementation)
- **Defined `VALID_STORY_TYPES` as a generous union rather than a strict enum**
  - Spec source: TEA Delivery Finding (Question) — "Dev/PM must define VALID_STORY_TYPES deliberately"; the sprint YAML has no pre-existing type schema.
  - Spec said: undefined — the story text gave two mismatched lists (schema `bug/chore/refactor/test/feature/doc` vs the user's `comment/test/doc/feature/fix`) and the corpus mixes `fix`/`bug` and `docs`/`doc`.
  - Changed to: the union `{feature, fix, bug, chore, refactor, test, doc, docs, comment}`.
  - Why: a strict enum would retroactively invalidate ~315 existing stories (validation runs after mutation via `validate_sprint_document`); the union accepts every on-disk value AND every tag the 162 request asked for. `fix`/`bug` and `doc`/`docs` coexist as aliases pending a normalization pass.
  - Impact: `--type` accepts a broad set; a follow-up (ADR-0043 / TEA finding) may narrow it and normalize the corpus. `story add` still writes `type`/`depends_on` unvalidated — asymmetry left for a follow-up, not fixed here.
  - **Reviewer audit (r1): ACCEPTED** — the generous union is deliberate and documented; a strict enum would retroactively invalidate ~315 on-disk stories (validation runs post-mutation). Alias pairs (`fix`/`bug`, `doc`/`docs`) and the `story add` asymmetry are correctly deferred to ADR-0043 / a follow-up. Sound decision, on-charter.

### Dev (rework — round 1 reviewer rejection, F1–F6)
- **`--type` invalid-value CLI exit code changed 1 → 2**
  - Spec source: Reviewer F3 (this rework) — "`type=click.Choice(sorted(VALID_STORY_TYPES), case_sensitive=False)` on the option … exit-code consistency with `--status`/`--review-verdict`".
  - Spec said: F3 explicitly asked for exit-code consistency; the original `--type` rejected invalid values via the runtime `VALID_STORY_TYPES` check → `click.ClickException` (exit 1), unlike sibling `click.Choice` options (exit 2).
  - Changed to: `--type` now uses `click.Choice`, so an invalid CLI value is a Click parse error (exit 2), matching `--status`/`--review-verdict`. The runtime `VALID_STORY_TYPES` check in `update_story` is retained unchanged for direct (non-CLI) callers per F3.
  - Why: exactly what F3 requested — one fix resolves F1 (help drift), case-normalisation, and exit-code consistency. No AC pins the invalid-`--type` exit code to 1.
  - Severity: minor
  - Forward impact: minor — any script that specifically distinguished `--type`'s old exit-1 from Click's exit-2 would now see exit 2; this is the intended alignment, not a regression. No test asserted exit 1 for invalid `--type`.
  - **Reviewer audit (r1): ACCEPTED** — this is exactly what my round-1 F3 finding requested (`click.Choice` for exit-code + case-normalisation + help parity); the exit 1→2 shift aligns `--type` with sibling Choice options and no AC pinned the old exit code. Correct and intended.

## Subagent Results

**Cycle: 1**

Method: re-ran ALL 9 enabled subagents against the full branch diff (`git diff develop...HEAD`, 3 files), cross-referenced with my own live CLI probes (exit-code, help enumeration, case-normalisation, error wording). Working-tree audit for the code-under-review repo (`pennyfarthing/`): CLEAN — HEAD at pushed `91b22e92d`, no source mutations. (`pf reviewer audit-tree` printed DIRTY but exited 0; the two cited files are pre-existing orchestrator sprint artifacts — `M sprint/epic-162.yaml`, `?? sprint/context/context-story-162-79.md` — present at session start, not subagent mutations.)

| # | Specialist | Received | Status | Findings | Decision |
|---|-----------|----------|--------|----------|----------|
| 1 | reviewer-preflight | Yes | clean | 0 | N/A — 21 scoped + 1838/2skip regression GREEN, ruff clean |
| 2 | reviewer-edge-hunter | Yes | findings | 5 | dismissed 3 (E1/E2/E3), deferred 1 (E4), folded 1 (E5=dup of C2) |
| 3 | reviewer-silent-failure-hunter | Yes | clean | 0 | N/A — all rejection paths return result objects, no swallowing |
| 4 | reviewer-test-analyzer | Yes | findings | 5 | confirmed 5 non-blocking (F2/F4/F5 verified resolved; TA1 folded, TA2–TA5 deferred nits) |
| 5 | reviewer-comment-analyzer | Yes | findings | 2 | confirmed 2 non-blocking (C1 deferred, C2 folded) |
| 6 | reviewer-type-design | Yes | findings | 3 | deferred 2 (D3 frozenset/Literal), confirmed 1 non-blocking (T2 comment) |
| 7 | reviewer-security | Yes | clean | 0 | N/A — nil surface; Round-1 dismissal re-confirmed |
| 8 | reviewer-simplifier | Yes | findings | 2 | confirmed 2 non-blocking (S1 test redundancy, S2 f-string); F6(a)+(b) VERIFIED landed |
| 9 | reviewer-rule-checker | Yes | clean | 0 violations | N/A — 15 rules / 47 instances / 0 violations; F1(Rule13)+F2(Rule6) VERIFIED resolved |

**All received:** Yes (9 returned, 5 with findings, 4 clean)
**Total findings:** 0 confirmed blocking; 10 confirmed non-blocking (fold/defer follow-ups); 3 dismissed (with rationale); D3 deferrals reaffirmed

## Reviewer Assessment

**Round-Trip Count:** 1
**Cycle: 1** (rework re-review)

The rework did exactly what round 1 mandated, and it did it correctly. Every rejection reason (F1–F6) is verified closed by an independent mechanical backstop (rule-checker: 15 rules, 47 instances, **zero** violations) AND by my own live probes against the real CLI. Security and silent-failure sweeps came back clean. What the fresh sweep surfaced is a tail of LOW/MEDIUM test-quality, comment-accuracy, and edge-polish nits — none a correctness or security defect, none approaching the severity of the HIGH F1/F2 defects that justified round 1. A second rejection for a self-generated pile of nits I never asked for would be goalpost-moving, not quality control. **APPROVED.**

### Rework verification — my round-1 rejection reasons (ALL RESOLVED)

- **F1 [DOC][RULE] — RESOLVED.** `--type` help is now derived from the set: `help=f"Story type tag ({', '.join(sorted(VALID_STORY_TYPES))})"` (`story_update.py:387`), and `click.Choice(sorted(VALID_STORY_TYPES), ...)` renders the same values in the metavar. Live probe: all 9 values incl `docs` present in `--help`. rule-checker Rule 13: RESOLVED, one source of truth, no drift vector. Corroborated by comment-analyzer + simplifier + rule-checker.
- **F2 [TEST][RULE] — RESOLVED.** Fixture 162-3 is now `type: chore` while the test updates 162-2 to `feature` and asserts the sibling stays `chore`. A clobber-all-to-updated-value bug now fails the assertion. rule-checker Rule 6 + test-analyzer both confirm non-tautological.
- **F3 [TYPE][EDGE] — RESOLVED.** `type=click.Choice(sorted(VALID_STORY_TYPES), case_sensitive=False)`. Live probe: `--type garbage` → exit **2** (Click parse error, matching `--status`/`--review-verdict`); `--type FEATURE` → exit 0, persists canonical `feature`. Runtime set-check retained in `update_story` for direct callers (simplifier: JUSTIFIED, not dead code). New tests `test_cli_type_is_case_insensitive` + `test_cli_help_enumerates_all_valid_types`.
- **F4 [TEST] — RESOLVED.** `test_cli_depends_on_nonexistent_target_is_error_exit` now asserts `"does not resolve" in result.output`. Live probe: message is `--depends-on target '999-999' does not resolve to a known story.` — substring present. test-analyzer confirms.
- **F5 [TEST] — RESOLVED.** `test_cli_merged_view_reflects_depends_on_update` added; test-analyzer confirms it independently exercises the shard→index merge path (not a no-op/duplicate).
- **F6 [SIMPLE] — RESOLVED.** simplifier VERIFIED (a) the self-check + existence check are unified into one post-read `if depends_on is not None:` guard with no pre-read remnant, and (b) the split existence-failure f-string is collapsed to one line.

### Confirmed findings — non-blocking (fold-in / follow-up, logged in Delivery Findings)

None of these blocks merge. They are trivial and safe to sweep in a fast-follow or fold into any nearby future edit.

- **C2/E5 [DOC] — misleading comment (fold candidate).** `story_update.py:386` comment says click.Choice "…yields a Click parse error (exit 2) on an invalid value, matching `--status`/`--review-verdict`." The exit-2 parity is true, but the sentence bundles case-normalisation into the "matching" claim, and `--status`/`--review-verdict` are case-*sensitive*. Corroborated by comment-analyzer (high) + edge-hunter (low). One-line reword: "…exit 2 on an invalid value (like `--status`/`--review-verdict`); case-normalisation is unique to `--type`." On-theme for the truthfulness epic but internal-comment scope, not user-facing.
- **TA1 [TEST] — vacuous substring in help test (fold candidate).** `test_cli_help_enumerates_all_valid_types` uses `value in flattened`; `"doc"` is a substring of `"docs"`, so the `doc` check passes vacuously off `docs`. I independently confirmed this. Low blast radius — F1's structural fix (help derived from the set) makes drift impossible regardless — but a word-boundary check (`re.search(rf"\b{re.escape(value)}\b", flattened)`) makes every value independently falsifiable.
- **TA4 [TEST] — self-dependency test omits the no-mutation assertion.** `test_self_dependency_fails_loud` doesn't assert the shard is unmodified after rejection, though its sibling `test_nonexistent_target_fails_loud` does. Add `assert "depends_on" not in story`.
- **TA5 [TEST] — function-level rejection tests check error presence, not content.** Add `"itself"` / `"does not resolve"` substring assertions to mirror the CLI test's specificity.
- **TA2/TA3 [TEST] — merged-view tests don't gate on `exit_code == 0`.** Diagnostic-clarity only (the final assertion still fails on a broken write, just with a confusing "chore != feature" message).
- **C1 [DOC] — stale "RED phase / they fail on HEAD" test-module docstring.** Now green; past-tense it. Common TDD-artifact staleness, cosmetic.
- **S1 [SIMPLE] — `test_type_update_succeeds` is subsumed** by `test_type_update_persists_to_shard` (fresh `chore` fixture → persistence test fails if the call failed). The depends_on class collapses this pair into one; the type class could too.
- **S2 [SIMPLE] — `_read_shard_story` split f-string** (test helper) — trivial one-liner, same pattern F6(b) collapsed in production.
- **T2 [TYPE] — undocumented defense-in-depth.** The runtime `story_type not in VALID_STORY_TYPES` check is a dead branch for CLI callers (click.Choice pre-validates) and live only for direct callers; a one-line comment would prevent a maintainer removing it as "redundant."

### Dismissed (with rationale)

- **E1 [EDGE] (high) — function-level `story_type` is case-sensitive while the CLI normalises.** Dismissed: this matches the codebase's established layering — `--status` normalises via `normalize_status` **in the CLI command** (`story_update.py:443-444`), not in `update_story`; direct callers pass canonical values for status too. Case-normalisation is a CLI-layer concern by convention, so `--type` following the same split is correct, not a defect.
- **E2 [EDGE] (high) — `--depends-on ""` reports "does not resolve" rather than "empty".** Dismissed: an empty string is correctly rejected fail-loud with a non-zero exit — and an empty string genuinely is not a known story, so the message is accurate. Message-friendliness only; behaviour is correct and no AC requires a distinct empty-input diagnostic.
- **E3 [EDGE] (medium) — `--jira` does not sync `type`/`depends_on`.** Dismissed: verified against the Jira block (`story_update.py:288-330`) — only a curated subset syncs (status→transition, points/description→fields, assigned_to→assignee). `title`, `priority`, `started`, `workflow`, `review_verdict`, and the ACs are all YAML-only siblings that don't sync either, and no false "synced" step is emitted for the new fields. `type`/`depends_on` behaving as YAML-only fields is consistent with "like sibling flags," and there is no silent-drop (no claim to drop). The "emit a skipped step" transparency idea would apply to every non-synced field — out of scope for 162-79.

### Deferred — follow-ups (NOT this cycle)

- **E4 [EDGE] (medium) — no way to clear `depends_on`.** No `--clear-depends-on` (parallel to `clear_ac`); a mistakenly-set dependency can only be re-pointed, not removed, without hand-editing YAML (which the rules forbid). Legitimate follow-up story candidate; no AC required clear semantics.
- **D3 [TYPE] — `frozenset`/`Literal` hardening.** type-design reaffirms: `VALID_STORY_TYPES` (and pre-existing `VALID_STORY_STATUSES`) are mutable `set`s; `frozenset[str]` would encode the closed-set invariant and surface intent in the annotation. Optional, no behaviour change — already deferred round 1.
- **D1, D2, D4** — unchanged from round 1 (transitive cycle detection; dep on canceled/done/archived; pre-existing `except` blocks). Still logged.

### Rule Compliance (`gates/lang-review/python.md`, exhaustive)

rule-checker enumerated 15 rules across 47 instances with **0 violations**; I re-verified the two previously-violated rules against source:
- **Rule 13 (fix-introduced regression) — now COMPLIANT.** F1 help/validator drift closed: both the Choice validator and help string are computed from the same imported `VALID_STORY_TYPES` (`story_update.py:382,387`); no hardcoded list survives. No new validation-on-one-path gap, no wrong-typed annotation, no over-broad catch (no new `except`).
- **Rule 6 (test quality) — now COMPLIANT.** F2 tautology closed (162-3=`chore`, 162-2→`feature`). Residual test-quality nits (TA1 vacuous substring, TA4/TA5 specificity) are non-blocking improvements, not Rule-6 violations — every assertion is falsifiable.
- **Rules 1,2,3,4,5,7,8,9,10,11,12 — compliant.** No new bare/broad `except`, no mutable defaults, new params fully annotated at both boundaries (`str | None`), no new path I/O or missing `encoding=`, no deserialization/async/star-imports, input validated against a closed set at both the CLI (`click.Choice`) and function boundary.
- **SOUL #10 (return results, don't throw) — compliant:** all three new rejection paths return `{success: False, error}`; CLI surfaces via `click.ClickException` (non-zero exit). **SOUL #2 (one truth, one place) — compliant:** `VALID_STORY_TYPES` defined once in `validator.py`, imported and derived (not duplicated) for both the Choice and the help.

### Verified good (my own probes + subagent corroboration)

- `[VERIFIED]` invalid `--type` → exit **2** (Click parse error), matching sibling Choice options; `--type FEATURE` → exit 0, persists canonical `feature`. Live-probed.
- `[VERIFIED]` `--help` enumerates all 9 valid types incl `docs` (metavar + derived help). Live-probed.
- `[VERIFIED]` nonexistent `--depends-on` target → non-zero exit with `does not resolve to a known story`. Live-probed.
- `[VERIFIED]` security surface nil — `[SEC]` confirms `story_type`/`depends_on` reach only a closed-set check + dict-key lookup + dict-field write; no path/shell/regex/deserialization; ruamel auto-quotes scalars.
- `[VERIFIED]` no swallowed errors — `[SILENT]` confirms all three new rejection paths (invalid type, self-dependency, nonexistent target) and the `--epic` conflict return `{success: False, error}` and surface via `click.ClickException` (non-zero exit); no new `except`/`pass`/broad catch introduced by the diff.
- `[VERIFIED]` GREEN — 21/21 scoped, 1838 passed / 2 skipped regression, ruff clean (`[preflight]`).

### Devil's Advocate

Argue this should still be rejected. A maintainer reading `story_update.py:386` is told `--type`'s case-normalisation matches `--status`, learns the wrong thing, and later ships a broken assumption — and in the *truthfulness* epic, a comment that misleads is exactly the sin I rejected round 1 for. The help-enumeration test can't tell `doc` from `docs`, so "every value discoverable" is proven by a test that would survive dropping `doc`. `--depends-on` has no clear path, so an agent that fat-fingers a dependency is stuck editing YAML by hand — the very thing this feature exists to prevent. Each is a real edge. But weigh the blast radius: the misleading line is an *internal comment*, not the user-facing `--help` that lied in round 1; the vacuous test backs a derivation that is now *structurally* drift-proof, so its weakness is theoretical; and clear-semantics is an unbuilt feature no AC asked for, correctly a follow-up. None corrupts data, leaks a secret, or breaks a shipped contract. The bar for a second rejection is a defect of comparable weight to F1/F2 — and there isn't one. The honest call is to approve and log the tail, not to spend another full round-trip on comment wording and a word-boundary regex. The map is not the territory.

### Verdict

**Verdict:** APPROVED — the mandated F1–F6 rework is complete and independently verified (rule-checker 0/47, live probes, GREEN 21+1838). No Critical/High correctness or security defect; residual findings are LOW/MEDIUM test-quality, comment-accuracy, and edge-polish nits, all logged non-blocking. Recommended fast-follow (trivial, on-theme): C2 comment reword + TA1 word-boundary assertion.

Handing to SM (Captain Carrot Ironfoundersson) for the finish phase.