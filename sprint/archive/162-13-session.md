---
story_id: "162-13"
jira_key: ""
epic: "162"
workflow: "tdd"
---
# Story 162-13: Sprint validator rejects list-form depends_on (treats list as scalar) (gh #116)

## Story Details
- **ID:** 162-13
- **Jira Key:** (none — Jira disabled)
- **Workflow:** tdd
- **Stack Parent:** none
- **Branch:** feat/162-13-validator-list-depends-on
- **PR:** (none yet — recorded when the PR is created)

## Workflow Tracking
**Workflow:** tdd
**Phase:** finish
**Phase Started:** 2026-08-06T12:38:31Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-08-05T20:27:27Z | 2026-08-05T20:28:33Z | 1m 6s |
| red | 2026-08-05T20:28:33Z | 2026-08-05T21:56:29Z | 1h 27m |
| green | 2026-08-05T21:56:29Z | 2026-08-05T22:04:15Z | 7m 46s |
| review | 2026-08-05T22:04:15Z | 2026-08-06T12:38:31Z | 14h 34m |
| finish | 2026-08-06T12:38:31Z | - | - |

## Sm Assessment

**Scope:** 2-pt p2 bug (gh #116), TDD. `_validate_depends_on` in `pennyfarthing-dist/src/pf/sprint/validator.py` treats `depends_on` as scalar-only — a list-form value (multiple dependencies) stringifies and fails to match any story id, a false-negative validation error.

**Canonical contract (SM call, pin it):** scalar OR list both valid; normalize to list internally; every referenced story id must exist (active + archived); cycle detection runs across the expanded edge set. Consumers must agree: check the stacked-PR logic and the stack-ready gate read of depends_on — if they're scalar-only too, either extend them in scope (if cheap) or pin their current behavior and log a finding for follow-up (a validator that accepts what consumers can't read would be the 162-11 lesson repeated).

**Technical approach for TEA:** Failing tests: list-form with all-valid refs passes; list-form with one bad ref names THAT ref; scalar unchanged; empty list / list-with-blank handled loudly; cycle detection across list edges (A→[B], B→[A]); consumer-agreement pins per the above.

**Acceptance criteria:**
1. Validator accepts scalar and list depends_on; rejects unknown refs naming the specific ref.
2. Cycle detection covers list-form edges.
3. Consumers (stack-ready gate, stacked-PR logic) either handle list-form or their scalar-only behavior is pinned + logged for follow-up.
4. Suite exit 0 (7 loud 162-5 xfails only).

**Run mode:** Peloton-inline — agents spawned as subagents by SM, no relay markers, SM owns PR create/merge/finish.

## Delivery Findings

**Issue:** gh #116 reports that `_validate_depends_on` in `pennyfarthing-dist/src/pf/sprint/validator.py` treats `depends_on` as a scalar-only field. When a story defines `depends_on` as a YAML list (multiple dependencies), the validator stringifies the entire list and fails to match any story ID.

**Current implementation (line ~587):**
```python
dep = story.get("depends_on")
if dep is None:
    continue
dep = str(dep)  # str(['MSSCI-12646']) -> "['MSSCI-12646']"
if dep in all_story_ids:  # never true for a list
```

**Expected contract:** Support both scalar and list forms of `depends_on`, normalize to list internally, validate each reference, and run cycle detection across the expanded edge set. Backward compat: scalar `depends_on` continues to work.

**Scope:** 
1. Modify `_validate_depends_on()` to detect and normalize list/scalar `depends_on` fields
2. Validate each resolved reference against active + archived story IDs
3. Expand cycle detection to handle multi-edge scenarios
4. Update type hints in story_add.py / story_move.py if needed (currently `str | None`)
5. Add test coverage for list-form `depends_on` in validation suite

## TEA Assessment

**Tests Required:** Yes
**Test Files:**
- `pennyfarthing-dist/src/pf/tests/test_162_13_list_depends_on.py` — 30 tests over list-form depends_on: validity, ref naming, scalar regression pins, degenerate forms, cycle detection over expanded edges, consumer agreement.

**Tests Written:** 30 tests covering ACs 1-4. **Status:** RED — 20 failing, 10 passing (the 10 are scalar/regression pins plus two coincidental passes noted below).
**Commit:** 10a1ed941 `test(sprint): add failing tests for list-form depends_on (162-13)` (GPG signed).
**Suite baseline:** 20 failed (all mine), 5829 passed, 4 skipped, 7 xfailed — matches the expected 162-5 xfail count, no collateral reds.

### Designed interface for Dev

`_validate_depends_on` in `pennyfarthing-dist/src/pf/sprint/validator.py` (line 568) must:

1. **Normalize** — read `depends_on`, accept a scalar or a list, produce `list[str]` of stripped string refs. Non-string scalars coerce via `str()` (a YAML-unquoted numeric id must still resolve — pinned by a test).
2. **Resolve per-ref** — each ref checked against `all_story_ids` then the lazily-loaded archived id set (keep the existing lazy `_get_archived_story_ids` call so the archive is only read on a miss). One error per unresolved ref, message naming that ref alone; the current stringified-list text must never appear (a test greps for `['` in messages). Error path stays `{sid}.depends_on`.
3. **Fail loudly on degenerate forms** — empty list, blank/whitespace-only entry, blank scalar all add an ERROR whose message contains "empty" or "blank" (tests match case-insensitively on either word, so wording is yours). A nested container entry must be reported as invalid, not raise.
4. **Cycle detection over adjacency lists** — replace `deps: dict[str, str]` plus the single-successor while loop with `dict[str, list[str]]` and a DFS (recursion-stack colouring, not one shared visited set). Required behaviours: mutual list cycle, self-reference, cycle reachable only via a non-first list element, mixed scalar-to-list cycle, three-node cycle. Critical false-positive guard: a **diamond** (A→[B,C], B→[D], C→[D]) is acyclic and must report nothing — a naive shared visited set fails this test. Cycle message must name every story in the cycle and keep the `Circular` prefix (tests filter on it).

### Consumer table (AC3)

| Consumer | Location | Behaviour on list form | Call |
|---|---|---|---|
| `_validate_depends_on` | validator.py:568 | Broken — `str(dep)` false-negative, cycles invisible | **Fix (core of story)** |
| `_rewrite_dependencies` | story_move.py:46 | Broken — whole-value equality vs `old_id`, so list entries are never rewritten; move leaves a dangling ref | **Extended in scope** — match entry-wise, preserve order, keep whole-value comparison so the `10-10` substring decoy survives. 4 tests. |
| `move_story` post-move validation | story_move.py | Hard-fails today: moving a story when any list-form `depends_on` exists aborts the move with a false "references non-existent story" error (observed in the RED run). Falls out of fix 1. | Covered by the end-to-end move test |
| stack-ready gate | `pennyfarthing-dist/gates/stack-ready.md` | Cannot express multi-parent — resolves the parent by shell-capturing `pf sprint story field <id> depends_on`, which echoes `str(value)`, then feeds that straight back as a single story id | **Pinned scalar-only + logged.** Two tests pin the boundary: scalar read equals the id exactly; list read arrives as a real list and `str()` of it is not a story id. Dev must not change these without changing the gate. |
| `pf sprint story field` CLI | sprint/cli.py:1931 | `click.echo(str(value))` renders the bracketed repr | Pinned by the tests above; no change in scope |
| `story_add` | story_add.py:72,340 | Type hint `str \| None`; CLI takes one string, so it can only author scalars | No change needed — authoring list form is a YAML-edit path. Widening the hint is optional cosmetics. |
| `story_split` | story_split.py:138 | Writes a scalar parent id | Form-compatible, no change |
| `yaml_io` | yaml_io.py:66 | Key-order only, value-shape agnostic | No change |

### Notes for Dev

- Two tests pass today for the wrong reason and will keep passing after the fix: `test_error_names_the_offending_ref` (the stringified list happens to contain the ref substring) and `test_nested_container_entry_errors_without_crashing`. Their real teeth are in the sibling tests. Do not treat their green as coverage.
- Do not touch `pennyfarthing-dist/build/lib/` — build output, has its own stale copy of validator.py.

**Handoff:** To Dev for GREEN.

## Delivery Findings

### TEA (test design)
- **Gap** (non-blocking): the stack-ready gate cannot resolve a multi-parent `depends_on`. It shell-captures `pf sprint story field <id> depends_on` and uses the raw output as one story id, so a list yields a bracketed string and the parent-status lookup returns null. Affects `pennyfarthing-dist/gates/stack-ready.md` (needs to iterate refs and require *all* parents done) and `pennyfarthing-dist/src/pf/sprint/cli.py` (needs a machine-readable emission for list values). Pinned scalar-only in this story; follow-up needed before anyone stacks PRs on a multi-parent story. *Found by TEA during test design.*
- **Improvement** (non-blocking): `story_add` still types `depends_on` as `str | None` and the CLI accepts a single value, so list-form dependencies are only authorable by hand-editing YAML. Affects `pennyfarthing-dist/src/pf/sprint/story_add.py` (repeatable option + list-aware type). *Found by TEA during test design.*
- **Gap** (non-blocking, observed): `move_story` currently aborts outright ("Validation failed after move") for any sprint containing a list-form `depends_on`, because it re-validates through the buggy validator. Fixing the validator clears it; noting it because it makes gh #116 worse than the report describes — it is not merely a spurious warning, it blocks a mutation path. *Found by TEA during RED verification.*

## Design Deviations

### TEA (test design)
- **story_move extended rather than pinned:** SM offered pin-or-extend for consumers. `_rewrite_dependencies` is extended (4 failing tests) because leaving it scalar-only would let a move silently create a dangling ref that the newly list-aware validator then hard-fails — the 162-11 lesson. Change is entry-wise matching inside the existing walk, cheap for a 2-pointer.
- **Empty list / blank entry are ERRORs, not warnings:** the spec said "loud" without pinning severity. Tests assert ERROR severity with "empty" or "blank" in the message, matching how every other depends_on defect in this validator is reported.

### Dev (implementation)
- No deviations from spec. TEA's designed interface was implemented as specified: normalize-then-resolve-per-ref, degenerate forms as ERRORs, DFS recursion-stack colouring for cycles, entry-wise rewrite in story_move, stack-ready gate left scalar-only.

### Reviewer (audit)
- **story_move extended rather than pinned** → ✓ ACCEPTED by Reviewer: agrees with author reasoning — a scalar-only rewrite would let a move create a dangling ref the now-list-aware validator hard-fails on (the 162-11 lesson); verified end-to-end by the 4 move tests, and the post-move validation abort-before-write confirms the safety chain.
- **Empty list / blank entry are ERRORs, not warnings** → ✓ ACCEPTED by Reviewer: consistent with how every other depends_on defect in this validator reports (ERROR at `{sid}.depends_on`); erroring is strictly louder than the pre-fix silent skip, so severity is monotonic-improvement.
- No undocumented deviations found: implementation matches TEA's designed interface point-for-point (normalize contract, per-ref resolution with lazy archive, message wording constraints, DFS shape, entry-wise rewrite, scalar-only pins), verified against the diff and live probes.

## Dev Assessment

**Implementation Complete:** Yes

**Files Changed:**
- `pennyfarthing-dist/src/pf/sprint/validator.py` — rewrote `_validate_depends_on`; extracted two helpers.
  - `_normalize_depends_on(dep, sid, result)` expands a scalar or list value into a list of stripped string refs. Empty list, blank entry, blank scalar, and a nested container entry each add an ERROR at path `{sid}.depends_on` naming the entry position; no message ever embeds a container repr, so the stringified-list regression cannot recur. Non-string scalars coerce via `str()`, keeping the unquoted-numeric-id path working.
  - Per-ref resolution: each ref is checked against `all_story_ids`, then against the lazily-loaded archived id set (the lazy `_get_archived_story_ids` call is preserved — the archive is still only read on a first miss). One error per unresolved ref, naming that ref alone, so two bad refs in one list report separately and a valid sibling ref is never flagged.
  - `_report_dependency_cycles(adjacency, result)` replaces the `dict[str, str]` single-successor while loop with `dict[str, list[str]]` plus DFS three-colour marking. Only a successor still GREY (on the current recursion stack) is a cycle, which is what keeps the diamond clean — a shared visited set would have false-positived there. Cycles are deduped by node set so one cycle yields one error; message keeps the `Circular dependency detected:` prefix and names every story on the cycle path. Edges are added only for refs that resolve to active stories, matching the previous behaviour where archived and dangling refs are terminal.
- `pennyfarthing-dist/src/pf/sprint/story_move.py` — `_rewrite_dependencies` now matches list entries individually inside the existing walk, rebuilding the list in order with whole-value equality, so a `10-1` move rewrites a `10-1` entry and leaves the `10-10` decoy alone. Scalar path unchanged. This also clears the observed hard failure where `move_story` aborted post-move validation for any sprint holding a list-form value.

**Consumers not changed (AC3):** the stack-ready gate and `pf sprint story field` stay scalar-only, pinned by the two boundary tests. TEA's Delivery Findings already record the follow-up.

**Tests:** 30/30 passing in `test_162_13_list_depends_on.py` (GREEN). Full suite exit 0: 5849 passed, 4 skipped, 7 xfailed — the 7 are the expected 162-5 xfails, no collateral reds (TEA baseline was 5829 passed + 20 of mine failing).
**Lint:** `ruff check` clean on both changed files and the test file.
**Commit:** 2cea0f06a `fix(sprint): accept list-form depends_on in validator and story move (162-13)` — GPG signed, good signature.
**Branch:** feat/162-13-validator-list-depends-on (pushed, tracking origin)

**Handoff:** To Reviewer.

## Delivery Findings

### Dev (implementation)
- **Improvement** (non-blocking): duplicate entries in a list-form `depends_on` (e.g. the same ref twice) are accepted silently — each copy resolves, and the duplicate edge is harmless to the DFS. Not covered by any test, so intentionally left alone. Affects `pennyfarthing-dist/src/pf/sprint/validator.py` (a dedupe or a WARNING in `_normalize_depends_on` if authors want it flagged). *Found by Dev during implementation.*
- **Improvement** (non-blocking): `_report_dependency_cycles` recurses once per graph edge, so a pathological dependency chain thousands of stories deep could exhaust the Python recursion limit. Real sprints are two orders of magnitude smaller, so an iterative rewrite is not worth the complexity today. Affects `pennyfarthing-dist/src/pf/sprint/validator.py` (convert to an explicit stack if sprint size ever grows). *Found by Dev during implementation.*

## Subagent Results

| # | Specialist | Received | Status | Findings | Decision |
|---|-----------|----------|--------|----------|----------|
| 1 | reviewer-preflight | Yes | clean | none | N/A — 30/30 story tests, ruff clean, 33 sibling caller tests green, no smells |
| 2 | reviewer-edge-hunter | Skipped | disabled | N/A | Disabled via settings — domain covered directly by Reviewer (live probes of `_normalize_depends_on` with bool/float/int/dict/set/tuple/bytes/date/None: zero raises; cycle dedup probed; attribution checked) |
| 3 | reviewer-silent-failure-hunter | Skipped | disabled | N/A | Disabled via settings — domain covered directly by Reviewer (every degenerate path adds an ERROR then continues per-entry; lazy archive fallback preserved; no swallows in diff) |
| 4 | reviewer-test-analyzer | Yes | findings | 4 | confirmed 4 (all non-blocking test-polish/coverage notes), dismissed 0, deferred 0 |
| 5 | reviewer-comment-analyzer | Skipped | disabled | N/A | Disabled via settings — domain covered directly by Reviewer (docstrings in both files verified accurate against live probe behavior) |
| 6 | reviewer-type-design | Yes | findings | 4 | confirmed 3 (HIGH downgraded to MEDIUM with rationale), dismissed 1 (rule-text citation) |
| 7 | reviewer-security | Yes | findings | 3 | confirmed 2 (LOW / MEDIUM-LOW), noted 1 (VERY LOW plausible) |
| 8 | reviewer-simplifier | Skipped | disabled | N/A | Disabled via settings — domain covered directly by Reviewer (both helpers test-required; no dead code; tuple acceptance mild over-generality, harmless) |
| 9 | reviewer-rule-checker | Yes | findings | 2 | confirmed 2 (1 rule-#5 violation LOW deferred, 1 SOUL-#2 unify note LOW) |

**All received:** Yes (5 enabled returned, 4 disabled covered directly)
**Total findings:** 11 confirmed, 1 dismissed (with rationale), 0 deferred-unassessed

### Finding adjudication detail

1. **[TYPE] int entries not rewritten by `_rewrite_dependencies`** (story_move.py:66) — subagent rated HIGH; **downgraded to MEDIUM non-blocking** with rationale: (a) the scalar path had identical behavior pre-fix (`dep == old_id`, unchanged by this diff) — the residual is strictly narrower than the bug fixed; (b) reachability requires a hand-authored pure-numeric story id as the move target, which the `{epic}-{n}` id convention never produces; (c) failure mode is a loud abort before write (story_move.py:178 error-return precedes the write at :184) — no corruption. Captured as Delivery Finding with fix shape.
2. **[TYPE] `story_add` hint `str | None` not widened** — confirmed; duplicate of TEA's logged Improvement finding; deferred to it.
3. **[TYPE] frozenset dedup can suppress a second distinct cycle over the same node set** — confirmed LOW; verified by live probe that rotations collapse correctly and distinct sub-cycles each report; message names all involved nodes so the fix hint stays actionable.
4. **[TYPE] `dep: Any` lacks justifying comment** — DISMISSED citing rule text: lang-review python.md #3 states "Internal/private helpers are exempt"; `_normalize_depends_on` is private with a contract docstring.
5. **[SEC] CWE-117 newline/ANSI injection via ref into error message** (validator.py:600-603 → format_validation_errors → stdout) — confirmed LOW non-blocking: pre-fix code had the identical f-string sink; local CLI stdout; self-authored YAML; same class as the 155-12 baseRefName precedent.
6. **[SEC] CWE-674 unbounded recursion in `_report_dependency_cycles`** (~990-story chain → RecursionError, violates SOUL #10) — confirmed MEDIUM-LOW non-blocking: crash is loud, no state stranded (move validation precedes write); duplicate of Dev's logged Delivery Finding.
7. **[SEC] CWE-704 str() coercion confused-deputy** (bool→"True", date→ISO) — noted VERY LOW; verified by my live probes; no realistic id collision.
8. **[RULE] python.md #5: `open()` without `encoding=`** (test_162_13_list_depends_on.py:271, CWE-838) — rule-matching, confirmed (cannot dismiss), LOW non-blocking: test-only ASCII fixture; deferred to the epic-164 encoding-sweep story per 155-9 precedent.
9. **[RULE]/[TYPE] `isinstance(dep, (list, tuple))` in validator vs `isinstance(dep, list)` in story_move** — confirmed LOW (SOUL #2 drift risk); YAML never yields tuples; unify in follow-up.
10. **[TEST] diamond false-positive guard is single-test coverage** — Mutation B (shared visited set) killed only 5 tests, `test_diamond_is_not_a_cycle` the sole direct guard — confirmed MEDIUM test-polish, non-blocking.
11. **[TEST] `test_two_bad_refs_are_reported_separately` is coincidentally green pre-fix and never asserts `len(_dep_errors) == 2`** — confirmed LOW test-polish, non-blocking.
12. **[TEST] duplicate-in-list behavior unpinned** — confirmed; duplicate of Dev's logged Delivery Finding.

### Rule Compliance

Rule-by-rule over the diff (lang-review python.md #1–#13; rule-checker enumeration cross-checked by my own reads):

- **#1 silent exceptions:** compliant — no try/except in any changed hunk (`_normalize_depends_on`, `_report_dependency_cycles`, rewritten `_validate_depends_on`, `_walk`); pre-existing `except Exception` in `_get_archived_story_ids` (:563) is outside the diff.
- **#2 mutable defaults:** compliant — no mutable defaults in any new signature (checked all 4 new/changed functions plus test helpers).
- **#3 type annotations:** compliant — all new functions private (exempt) yet fully annotated (`list[str]`, `None` returns); `dep: Any` covered by the exemption clause (see dismissal #4).
- **#4 logging:** N/A — module reports via `ValidationResult.add_error`, no logging import.
- **#5 path handling:** VIOLATION (confirmed LOW, deferred) — test file :271 `open(..., "w")` without `encoding=`; production changes do no I/O.
- **#6 test quality:** compliant — bare `assert errs` instances (:588, :604, :617, :635) each followed by message-content asserts; mock.patch targets patched where-used; no skips/vacuous asserts. Residuals #10/#11 above are polish, not violations.
- **#7 resource leaks:** compliant — `with open(...)` in the only I/O site.
- **#8 unsafe deserialization:** compliant — no pickle/eval/yaml.load/shell=True in changed files.
- **#9 async:** N/A.
- **#10 import hygiene:** compliant — no new imports in production files; test imports explicit.
- **#11 input validation:** compliant — `_normalize_depends_on` IS the boundary validation; no ref reaches Path/subprocess/shell (grep-verified by me and security independently).
- **#12 dependency hygiene:** N/A — no manifest changes.
- **#13 fix-introduced regressions:** compliant — consumer enumeration (validator, story_move fixed; story_add/story_split scalar-write-by-design; yaml_io type-agnostic; stack-ready gate + `pf sprint story field` pinned by AC3 tests). Residual: sm-setup.md:340 and sm.md:112 are two MORE scalar-only shell-capture sites of the stack-ready class — added to the follow-up Delivery Finding below.

### Devil's Advocate

Assume this code is broken. The most dangerous claim is the DFS: graph algorithms fail quietly. Could a cycle go unreported? Only if every node on it is BLACK before any GREY revisit — but a node goes BLACK only after all successors are explored, so a back edge inside an unexplored cycle always finds GREY; the top-level loop visits every adjacency key, and nodes reachable only as targets are visited inside their source's DFS. A malicious author could craft a 990-deep chain and crash validation with a RecursionError traceback — loud, no write stranded, confirmed finding #6. What would a confused author see? An error path of `{cycle_nodes[0]}.depends_on` that may not be the story they last edited — mildly misleading for tooling that jumps to the path, but the message names the whole cycle. Could the empty-list error mask a real dependency? No — `[]` declares nothing; erroring is strictly louder than the old silent skip. Could the rewrite corrupt a sprint? The int-entry gap (finding #1) leaves a dangling ref, but the post-move validator now CATCHES exactly that and aborts before writing — the new validator is itself the backstop for the rewrite's residual gap. Could the stack-ready pin rot? Only by breaking one of two boundary tests that name the gate in their docstrings. What about a story that is both active and archived? Active-first short-circuit means no archive read — correct and cheaper, though unpinned (test-analyzer's MEDIUM-confidence gap; polish). Nothing here rises to blocking; the uncovered corners are all loud-failure or hand-authored-YAML territory.

### Reviewer observations (data flow, wiring, patterns)

- **Data flow traced:** sprint YAML → `read_sprint` (safe_load) → `validate_full_sprint` → `_validate_depends_on` walk → `_normalize_depends_on` (per-entry validation) → adjacency (active refs only) → `_report_dependency_cycles` → `ValidationResult` → `format_validation_errors` (validator.py:935) → stdout print (:988). Safe: no ref reaches Path/subprocess/shell; only dict-key lookups and message strings.
- **Wiring:** `pf sprint story move` CLI → `move_story` → `_rewrite_dependencies` → `validate_sprint_document` (:178) → write (:184) only on success — the validator fix is what un-blocks the previously hard-failing move path, verified by the 4 end-to-end move tests.
- **[VERIFIED] `_normalize_depends_on` never raises on malformed input — live-probed with bool/float/int/dict/set/tuple/empty-tuple/None-entry/bytes/date: every degenerate form added an ERROR, zero raises. Complies with SOUL #10 (validators accumulate, never throw on bad data).**
- **[VERIFIED] Diamond stays acyclic — validator.py:625-631 flags only GREY (recursion-stack) successors; Mutation B (shared visited set) flipped exactly the diamond test to red, proving the guard binds.**
- **[VERIFIED] Lazy archive read preserved — validator.py `archived_ids` stays None until first active-set miss; complies with the designed interface §2. Preflight's sibling run of test_160_8_archived_depends_on (11 green) confirms no regression.**
- **[VERIFIED] Substring decoy safe — story_move.py:66 whole-value equality; Mutation D (substring matching) killed by `test_substring_decoy_in_list_is_not_rewritten`. (The int-entry residual is finding #1, separately confirmed — no contradiction: the VERIFIED covers the string-entry path.)**
- **[VERIFIED] Story promise "no message ever embeds a container repr" holds — container entries short-circuit to a type-name error before any str(); pinned by `test_error_does_not_stringify_the_whole_list`.**
- **Pattern (good):** three-colour DFS with node-set dedup at validator.py:608-651 — textbook, documented rationale in the docstring explaining WHY a shared visited set fails (diamond), which is exactly the comment density this module uses elsewhere.
- **Tenant isolation:** N/A — local single-user CLI tool, no tenant-bearing data structures in the diff; audited the two changed modules for tenant-like fields: none exist.
- **Binding evidence:** test commit 10a1ed941 precedes impl commit 2cea0f06a with 20 RED verified at the test commit (TEA record), and Mutation A (full list-branch revert) killed 19 tests — the tests bind to the fix.

## Reviewer Assessment

**Verdict:** APPROVED
**Data flow traced:** sprint YAML → read_sprint → _validate_depends_on → _normalize_depends_on → adjacency → _report_dependency_cycles → ValidationResult → format_validation_errors → local stdout (safe: refs never reach Path/subprocess/shell; container reprs never reach messages)
**Pattern observed:** three-colour DFS with recursion-stack colouring and node-set cycle dedup at pennyfarthing-dist/src/pf/sprint/validator.py:608-651 — correct false-positive guard (diamond), rationale documented in-code
**Error handling:** every degenerate depends_on form (empty list, blank entry/scalar, nested container, non-string scalar) adds a positional ERROR at `{sid}.depends_on` and continues — live-probed, zero raises (validator.py:568-607); move failure aborts loudly before write (story_move.py:178→184)
**Subagent coverage:** [EDGE] covered directly (disabled) — live edge probes clean; [SILENT] covered directly (disabled) — no swallows; [TEST] 4 confirmed polish findings, suite binds (Mutation A killed 19); [DOC] covered directly (disabled) — docstrings accurate; [TYPE] 3 confirmed (HIGH→MEDIUM downgrade with rationale), 1 dismissed per rule exemption; [SEC] 2 confirmed LOW-class, 1 noted; [SIMPLE] covered directly (disabled) — no over-engineering; [RULE] 1 confirmed LOW violation (deferred to epic-164 sweep), 1 unify note
**Blocking findings:** none — 11 confirmed findings, all MEDIUM or below, all non-blocking per severity-by-blast-radius
**Handoff:** To SM for finish-story

## Delivery Findings

### Reviewer (code review)
- **Improvement** (non-blocking): `_rewrite_dependencies` compares entries with strict equality, so an int-valued dep (`depends_on: 162` or `[162, ...]` unquoted, paired with a pure-numeric story id) is not rewritten on move — loud post-move validation abort, no corruption. Pre-existing behavior on the scalar path; residual on the new list path. Affects `pennyfarthing-dist/src/pf/sprint/story_move.py` (compare `str(entry) == old_id`, plus a pin test since it also changes scalar semantics). *Found by Reviewer during code review (via reviewer-type-design).*
- **Gap** (non-blocking): the multi-parent follow-up TEA logged for the stack-ready gate must ALSO cover `pennyfarthing-dist/agents/sm-setup.md:340` and `pennyfarthing-dist/agents/sm.md:112` — both shell-capture `pf sprint story field ... depends_on` scalar-style, same class as the gate. *Found by Reviewer during code review.*
- **Improvement** (non-blocking): `open()` at `pennyfarthing-dist/src/pf/tests/test_162_13_list_depends_on.py:271` lacks `encoding="utf-8"` (lang-review #5, CWE-838; test-only ASCII fixture). Fold into the epic-164 encoding-sweep story rather than filing new work. *Found by Reviewer during code review (via reviewer-rule-checker).*
- **Improvement** (non-blocking): test polish — `test_two_bad_refs_are_reported_separately` never asserts `len(_dep_errors) == 2` (coincidentally green pre-fix), and `test_diamond_is_not_a_cycle` is the sole direct guard against a shared-visited-set regression (Mutation B evidence). Add a count assert and a second acyclic-graph guard (e.g. longer diamond) in a test-polish pass. Affects `pennyfarthing-dist/src/pf/tests/test_162_13_list_depends_on.py`. *Found by Reviewer during code review (via reviewer-test-analyzer).*
- **Improvement** (non-blocking): unify container detection — validator accepts `(list, tuple)` while story_move checks `list` only (SOUL #2 drift risk; YAML never yields tuples, so no runtime impact today). Affects both changed files. *Found by Reviewer during code review.*
- **Improvement** (non-blocking): sanitize refs before embedding in validator error messages (CWE-117: embedded newline/ANSI in a hand-authored ref reaches local stdout via format_validation_errors; pre-existing sink, not widened by this diff). Affects `pennyfarthing-dist/src/pf/sprint/validator.py`. *Found by Reviewer during code review (via reviewer-security).*