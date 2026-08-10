---
story_id: "162-11"
jira_key: ""
epic: ""
workflow: "tdd"
---
# Story 162-11: schema-validation hook: require Branch/PR session fields on session writes

## Story Details
- **ID:** 162-11
- **Jira Key:** (not applicable — no Jira integration)
- **Workflow:** tdd
- **Stack Parent:** none
- **Branch:** feat/162-11-schema-hook-branch-pr-fields
- **PR:** #183

## Workflow Tracking
**Workflow:** tdd
**Phase:** finish
**Phase Started:** 2026-08-05T19:51:00Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-08-05T18:38:44Z | 2026-08-05T18:40:34Z | 1m 50s |
| red | 2026-08-05T18:40:34Z | 2026-08-05T19:06:22Z | 25m 48s |
| green | 2026-08-05T19:06:22Z | 2026-08-05T19:14:01Z | 7m 39s |
| review | 2026-08-05T19:14:01Z | 2026-08-05T19:31:50Z | 17m 49s |
| green | 2026-08-05T19:31:50Z | 2026-08-05T19:39:49Z | 7m 59s |
| review | 2026-08-05T19:39:49Z | 2026-08-05T19:51:00Z | 11m 11s |
| finish | 2026-08-05T19:51:00Z | - | - |

## Sm Assessment

**Scope:** 2-pt p2, TDD. Mechanical backstop (SOUL 11) for the 155-33 template contract: the schema-validation hook (`pf hooks schema-validation`, PreToolUse on Write, code in `pennyfarthing-dist/src/pf/hooks/`) must require the Branch and PR field lines in the Story Details block whenever an agent writes a `.session/*-session.md` file. Background: 155-32's false-done — sm-setup's template omitted those lines, finish resolved nothing, took the no-PR arm, marked done with an open PR.

**Technical approach for TEA:**
1. Failing tests: hook BLOCKS a session write missing the Branch line, missing the PR line, or both; error message names the missing line(s) and shows the expected shape. Placeholder values pass (the LINES must exist, values may be "(none yet)"). Hook ALLOWS: non-session files, archived sessions (`sprint/archive/...`), files not matching the session path pattern, and session writes with both lines present.
2. Find the hook's existing test suite + dispatch shape first (there's an existing schema-validation hook wired via agent frontmatter `PreToolUse: matcher: Write`) — extend, don't fork.
3. Forward-compat: enforcement must accept a future multi-repo per-repo PR shape without redesign (162-33) — e.g. require at least one PR-field line rather than exactly one; note the choice.
4. Suite exit 0 (7 loud 162-5 xfails only).

**Acceptance criteria:**
1. Session writes missing Branch or PR lines are blocked with an actionable message.
2. Non-session writes, archives, and complete sessions pass.
3. Placeholder values accepted; forward-compatible with per-repo PR lines.
4. Suite exit 0.

**Run mode:** Peloton-inline — agents spawned as subagents by SM, no relay markers, SM owns PR create/merge/finish.

## Tea Assessment

**Tests Required:** Yes
**Status:** RED (22 failing, ready for Dev)

**Test Files:**
- `pennyfarthing-dist/src/pf/tests/test_162_11_schema_hook_session_fields.py` — new suite, 46 tests (22 red / 24 green regression guards)
- `tests/python/test_hooks_subpackage.py` — narrowed one obsolete assertion (see Design Deviations)

**Suite location note:** the green suite in this repo is `pennyfarthing-dist/src/pf/tests/` (5754 passed, 7 xfailed at base e240f7564). `tests/python/` is broadly red at base (287 failures, all pre-existing and unrelated: missing `reflector_check` module, `cyclist_pretooluse`, renamed `session_start` helpers). I put the story suite in the green one, following its `test_{story}_{slug}.py` convention. The existing schema-validation unit tests live in the red suite; I extended the hook's coverage rather than forking a second hook.

**Verification:** `python3 -m pytest pennyfarthing-dist/src/pf/tests/ -q` → 22 failed, 5778 passed, 4 skipped, 7 xfailed. The 22 failures are exactly this story's reds; the 7 xfails are the expected loud 162-5 ones. No collateral breakage.

**AC coverage:**
- AC-1 (blocked with actionable message): `TestMissingFieldsBlocked` (7), `TestBlankValuesBlocked` (4), `TestLookalikeLabels` (2), `TestProseIsNotAField` (2), `TestStoryDetailsAuthority` (1), `TestErrorMessageQuality` (4), `TestHookDenies` (2 red + 1 guard)
- AC-2 (non-session/archive/complete pass): `TestAllowedWrites` (8), `TestHookDenies::test_complete_write_is_allowed`
- AC-3 (placeholders + forward compat): `TestPlaceholdersAccepted` (8 via parametrize), `TestForwardCompatPrShape` (3)
- AC-4 (suite exit 0 apart from reds): verified above

**Designed interface for Dev:** extend `_validate_session` in `pennyfarthing-dist/src/pf/hooks/schema_validation.py`. A markdown session is field-complete when its `## Story Details` section contains at least one line-anchored field line (the shape `story_finish.SESSION_FIELD_RE` parses: optional list bullet, bold label, colon) whose lowercased label is exactly `branch`, and at least one whose label is `pr` or `pr` plus a parenthesized/bracketed repo qualifier — each with a non-blank value. Errors must name the missing field, say the lines belong in Story Details, and carry a backtick-quoted example line that itself parses as that field (`TestErrorMessageQuality::test_suggested_shape_actually_parses_as_the_field` closes that loop).

**Key design choices:**
1. **Enforcement mirrors the consumer, not a fresh rule.** `story_finish._parse_session` gives the Story Details section authority over the `branch`/`pr` keys (155-40) and matches only line-anchored field lines. The hook requires exactly that, so a passing session is by construction one finish can read. Consequence: field lines that appear only in a later assessment section do not satisfy the hook, even though finish has a fallback for them — the 155-33 contract puts them in Story Details.
2. **PR is at-least-one, qualifier-tolerant** (forward compat with the per-repo shape 162-33 will design, opened by 162-6's multi-repo stories). A rule of "exactly one line labelled exactly PR" would need redesigning to ship that story. Qualified shapes with parens or brackets pass; a genuinely different field whose label merely starts with those letters (a PR-status line) does not — 155-33 established that a lookalike label does not parse as the session field, so it must not satisfy the requirement either.
3. **Blank values are treated as missing.** A valueless field line and an absent one both extract to `None` at finish time, so accepting the former would ship a hook that green-lights the 155-32 failure. Placeholders (parenthesized notes) still pass — the lines are the contract, the values fill in later.
4. **XML-shaped sessions keep XML-only validation.** The Story Details block is a markdown-session contract; an XML session has no such block and its own required tags are already checked. Pinned in `TestScopeBoundaries`. This is a documented evasion path (adding an XML session tag skips field enforcement) — see Delivery Findings.
5. **Write only, not Edit.** The hook already exempts Edit (it sees a fragment, not the file). Pinned as a scope boundary, not fixed here.

## Dev Assessment

**Implementation Complete:** Yes

**Files Changed:**
- `pennyfarthing/pennyfarthing-dist/src/pf/hooks/schema_validation.py` — extended `_validate_session`: markdown sessions now route to a new `_validate_session_fields`, backed by `_story_details_field_labels` (section-scoped, line-anchored, qualifier-normalizing label scan). Added `_FIELD_LINE_RE`, `_QUALIFIER_RE`, `STORY_DETAILS_SECTION`, `SESSION_REQUIRED_FIELDS`. +64/-1, no other file touched.

**Tests:** 46/46 in `pennyfarthing-dist/src/pf/tests/test_162_11_schema_hook_session_fields.py` (GREEN). Full dist suite: 5800 passed, 4 skipped, 7 xfailed, exit 0 — the 7 xfails are the expected loud 162-5 ones. `ruff check` clean on both files.

Branch (pushed): feat/162-11-schema-hook-branch-pr-fields at 353ab07c1, GPG signed (good signature, key 7B37E56D8E241397).

**Implementation notes:**
- The XML-session early return is preserved verbatim; only the markdown arm changed, so the previous `return []` for markdown is the single behavioral replacement.
- Label matching is one normalization step: strip a trailing parenthesized or bracketed qualifier, then lowercase, then require exact equality with the field key. That is what makes per-repo lines pass while a lookalike-label line (a status field) fails, without a second code path per field.
- Blank-value lines are dropped during the scan rather than checked afterwards, so a valueless line and an absent line reach the error builder identically — matching how finish sees them.
- Error text per field is a single dict entry, so each message names only the field actually missing; each carries a backtick-quoted example line that parses as that field under the consumer's own regex (pinned by the round-trip test).

**Handoff:** To review.

### Dev Addendum — review rejection fix (round 2)

Reviewer's HIGH was correct and I verified it directly before touching anything: the consumer's label class is word-and-space only, so `- **PR (pennyfarthing):** #182` and `- **PR [ui]:** #7` both parse to `None`, while the bare line parses to label `PR`. My first cut stripped the qualifier before comparing, so a qualified-only PR line satisfied the hook AND my denial message actively recommended that shape. An agent obeying the message would have produced a session that passes the backstop and contributes nothing to finish's resolution — the 155-32 class, shipped by the very hook meant to prevent it.

**Root cause, not just the symptom:** two regexes for one concept. My round-1 deviation argued the qualifier tolerance forced a looser label class. That was backwards — the tolerance requirement was satisfiable without it, because a line the consumer cannot parse contributes no label and is therefore ignored, i.e. tolerated as an extra without being counted. Recognizing qualified lines was never necessary.

**Changes:**
- `_FIELD_LINE_RE` is now the consumer's exact pattern; `_QUALIFIER_RE` and the label-normalization step are deleted. Qualified lines fall through unparsed, so they are tolerated beside a bare line and refused as a substitute for it. 162-33 lands by mirroring the consumer's pattern again — one edit, one place.
- PR denial message reworded: the label must be bare, a per-repo qualifier is not resolvable yet (162-33) and may appear in addition without satisfying the requirement.
- `_story_details_field_labels` docstring corrected. The "by construction one finish can read" claim was false in the qualified direction; it is now true, because the pattern is the consumer's.
- Tests: the two cases that asserted qualified-only passes now assert it is DENIED (parametrized, including the previously untested status-style qualifier); a new case pins that qualified lines beside a bare line stay allowed; `test_consumer_parses_every_shape_the_hook_accepts` asserts the hook's pattern equals the consumer's, which is the invariant both directions depend on and the drift alarm for 162-33.
- Round-trip guard widened: its extraction regex embedded the consumer's label class, so a suggestion the consumer could not parse was invisible to it by construction — exactly why the bad message passed review-less. It now matches any backticked bold field and asserts each parses under the consumer's regex.

**Verification:** story suite 50/50 (was 46 — 4 net new cases). Full dist suite: see below. `ruff check` clean. Also confirmed by hand that the reviewer's exact session shape now denies, and that bare-plus-qualified still returns no errors.

**Deviation retracted:** the round-1 deviation ("field-line regex not reused from the consumer") no longer describes the code — the hook now uses the consumer's pattern verbatim, pinned by test. Left in the record below with a retraction note rather than deleted, since the reviewer's finding is only legible against it. The corresponding Delivery Finding about two divergent regexes is likewise resolved in the code and reduced to a drift note for 162-33.

**Not touched** (deferred MED/LOW per coordinator, follow-up stories): archive-path denial nuance, trailing-colon heading over-block, HTML-comment bypass, fenced-code gap.

## Subagent Results

| # | Specialist | Received | Status | Findings | Decision |
|---|------------|----------|--------|----------|----------|
| 1 | reviewer-preflight | Yes | clean | 5800 passed / 0 failed / 4 skipped / 7 xfailed, exit 0; ruff clean; 0 smells, 0 TODOs, 0 test skips; 3 files, +720/-3 | N/A — matches my independent re-run (zero XPASS confirmed with `-rX`) |
| 2 | reviewer-test-analyzer | Yes | findings | (a) `**PR (status):**` passes the hook but is untested — intent unpinned; (b) only 2 deny variants go through `main()`; (c) the narrowed `tests/python/` assertion is now unfalsifiable for the new behavior; (d) tautological `sys.modules` assertion | (a) CONFIRMED — folded into the High; (b) CONFIRMED, Low; (c) CONFIRMED, Low — the narrowing itself is legitimate, the replacement is weak; (d) CONFIRMED, Low |
| 3 | reviewer-edge-hunter | Yes | findings | (a) fenced code blocks in Story Details satisfy the check; (b) qualified-only PR lines pass the hook but finish reads nothing; (c) `## Story Details:` over-blocks | (a) CONFIRMED but the consumer has the identical gap — no divergence introduced, Low; (b) CONFIRMED — this is the High; (c) CONFIRMED by probe (finish parses it via the global fallback), Medium |
| 4 | reviewer-comment-analyzer | Yes | findings | (a) `_story_details_field_labels` docstring's "by construction one finish can read" is false for the qualifier shape; (b) "Edit operations validated post-hoc" describes validation that does not exist | (a) CONFIRMED — part of the High; (b) CONFIRMED, pre-existing string, logged as a Delivery Finding. Its non-findings (the "deliberately looser" comment, the backticked example shapes) match my own checks |
| 5 | reviewer-security | Yes | findings | (a) content-shaping bypass: `"<session" not in content` is a whole-body substring test, so smuggling the XML structural tags into a markdown body skips field validation — probed and CONFIRMED (a session with the tags inside an HTML comment is allowed with no `Branch`/`PR`); (b) no size guard before `splitlines()`; regexes ReDoS-free; no leakage | (a) CONFIRMED as behavior, severity DOWNGRADED to Medium/deferred — TEA logged this evasion path before implementation and pinned it in `TestScopeBoundaries`; the trust boundary here is the agent itself and the hook is an accident guardrail, not an adversarial control. The genuinely wide part is the substring test, worth narrowing when 162-33 touches this. (b) Low — I probed `content: null` and the hook prints to stderr, exits 0, emits no decision, i.e. fails open; that is the pre-existing broad `except` and is the correct direction for a PreToolUse gate |
| 6 | reviewer-type-design | Yes | findings | (a) `SESSION_REQUIRED_FIELDS` keys are raw strings with nothing tying them to the normalized label set; (b) two regexes for one concept with no shared type or cross-module test; (c) `dict[str, str]` leaves no room for per-field rules | (a) DOWNGRADED to Low — a bad key would block every session write on the first run, so it cannot ship silently; (b) CONFIRMED, and it is exactly Dev's own finding #1 plus the inverted-direction correction in my deviation audit — hand to 162-33; (c) DISMISSED for a 2-pointer with two fields; a dataclass here is speculative generality, and the dict is trivially widened when a third field arrives |

| 7 | reviewer-test-analyzer (round-2 delta) | Yes | findings | (a) the equality pin compares pattern strings, not behavior, and does not pin the `.match`/`.search` invocation method the rework changed; (b) `"pr" in _flagged(...)` where the sibling class uses set equality; (c) the round-trip guard joins both messages, masking a per-field regression | All three CONFIRMED and all Low/deferred — see the round-2 findings table. (a)'s "the test would pass if `_validate_session_fields` were deleted" is true but inert: 40+ other tests in the file exercise that function |

**All received: Yes** — 6 of 6 spawned specialists returned in round 1; 1 of 1 in the round-2 delta review.

**Round-2 specialist scope (stated for the record):** I re-spawned only `reviewer-test-analyzer` for the delta. The rework is 145 lines, two-thirds of it test changes, and the highest-risk element is Dev inverting assertions TEA had set as binding — precisely a test-analyst question. The implementation delta I verified myself and more directly than a specialist would: pattern identity asserted in-process, plus 16 fresh end-to-end probes through the real hook dispatch, plus an `importtime` measurement of the residual's stated cost. Security, type-design and rule surfaces are unchanged or strictly narrowed by this delta (the label class got tighter, two constructs were deleted, no new inputs or dependencies), so round-1 coverage still holds. Config (`.pennyfarthing/config.local.yaml`) disables `edge_hunter`, `silent_failure_hunter`, `comment_analyzer` and `simplifier`; I ran the first three anyway because a parser-heavy diff is exactly what path enumeration and comment-accuracy catch, and all three produced confirmed findings. `reviewer-simplifier` and `reviewer-rule-checker` were not spawned: the diff is 65 lines with no reuse or complexity question worth a specialist, and the project rules that bear on it (result objects not exceptions, single source of truth, `.pennyfarthing/` runtime paths) I checked directly — see the security row for the fail-open probe.

## Reviewer Assessment

**Verdict:** REJECTED (one High). Everything else is deferred, non-blocking.

**End-to-end dispatch verified (not unit-only).** The installed `pf` is an editable install resolving to this branch's tree (`pf.__file__` → `pennyfarthing-dist/src/pf/__init__.py`), so `pf hooks schema-validation` fed real PreToolUse Write payloads on stdin exercises the branch code. 25 probes, all stdin-only (no filesystem mutation, tree clean):

- DENY: missing both / missing `Branch` only / missing `PR` only / blank value (incl. whitespace-only) / prose mention of the tokens / field lines only in a later section / no `Story Details` heading. Messages name only the field actually missing and point at the section.
- ALLOW: both present, placeholders, unbulleted lines, non-session paths, `sprint/archive/...`, `Edit` tool, XML-shaped session, `## story details` case/whitespace variants, CRLF.
- Lookalikes correctly refused: `**PR Status:**`, `**PR-Status:**`, `**Branch Strategy:**`.

AC-1, AC-2, AC-4 hold. AC-3 holds for placeholders; the forward-compat half is where the High sits.

**Suite re-run independently:** `pytest pennyfarthing-dist/src/pf/tests/ -q -rX` → 5800 passed, 4 skipped, 7 xfailed, exit 0, **zero XPASS**. `ruff check` clean on both changed files. Head `353ab07c1` GPG-signed, good signature, key 7B37E56D8E241397. Working tree clean.

| Severity | Issue | Location | Fix Required |
|----------|-------|----------|--------------|
| [HIGH] | The `pr` remediation text tells the agent that a per-repo qualifier "also counts", and the hook does accept a session whose only PR-ish line is qualified. `story_finish._parse_session` reads **nothing** from that shape — verified: a Story Details block with `Branch` plus only a qualified per-repo PR line parses to `{'branch': ...}`, no `pr` key. So an agent that follows the hook's own fix instruction produces a session that passes the backstop and then lands in the arm this story exists to close. The round-trip guard cannot see it: its extraction regex reuses the consumer's own label class (`\w[\w\s]*`) and only looks inside backticks, so the qualified suggestion is invisible to it by construction. | `schema_validation.py:49-52` (message), `:98` (docstring), `test_162_11_...py:380` (guard blind spot) | Stop advertising the unreadable shape: drop the qualifier sentence from the `pr` message, or say plainly that per-repo lines are not yet resolvable and a bare `PR` line is still required until 162-33 ships. Correct the `_story_details_field_labels` docstring — "by construction one finish can read" is false in exactly this direction. Optionally add the negative test (`**PR (status):**` currently passes) so intent is pinned either way. Tolerance itself may stay; SM asked for it. |
| [MEDIUM] | `.session/archive/` is a real archive location in this codebase (`migration/session.py:368` globs it), and writes there are **denied** — the archive exemption is incidental to `_is_session_file`'s `.session/` substring test, not a deliberate archive check. AC-2's "archives pass" is only proven for `sprint/archive/...`, which is the one path the test uses. No live producer writes archives through the Write tool, so this is latent. | `schema_validation.py:59`, test `ARCHIVE_PATH` | Exempt an `archive/` path segment explicitly rather than relying on where archives happen to live. Deferred. |
| [MEDIUM] | `## Story Details:` (trailing colon) makes the hook deny both fields even though `_parse_session` reads that session fine via its global fallback — verified. Over-blocking fails safe, but the message tells the agent to add lines it already added, which is a loop. Dev logged the neighbouring case (renamed/dropped heading); this is the same class. | `schema_validation.py:107` | Normalize trailing punctuation on the heading, or detect an absent `Story Details` section and say so. Deferred. |
| [LOW] | Field lines inside a fenced code block in Story Details satisfy the hook. The consumer has the identical gap, so the hook faithfully mirrors finish — no divergence introduced. | `schema_validation.py:105` | Deferred; fix both parsers together if ever. |
| [LOW] | The narrowed `tests/python/` assertion is a **legitimate** narrowing (the old `errors == []` asserted the exact opposite of AC-1, and the rename plus docstring make the change auditable), but the replacement is purely negative: it would still pass if field validation vanished entirely. It lives in the pre-existing-red suite, so it is not a gate either way. | `tests/python/test_hooks_subpackage.py:653` | Add `assert errors` (that fixture is missing both fields). Deferred. |
| [LOW] | End-to-end `main()` coverage reaches only 2 of the deny variants; the rest are helper-level. Plus one tautological assertion (`"pf.hooks.schema_validation" in sys.modules` is guaranteed by the module-level import). | `test_162_11_...py:561`, `:641` | Deferred. |

**Specialist findings incorporated:**
- **[TEST]** — the untested `**PR (status):**` acceptance is folded into the High; thin end-to-end deny coverage, the weak narrowed assertion, and the tautological `sys.modules` check are the Low rows above. The suite does drive `main()` with real stdin payloads, so it is not unit-only.
- **[SEC]** — the `"<session"` substring branch is a content-shaping bypass I reproduced (XML tags inside an HTML comment in a markdown body → allowed with no `Branch`/`PR`). Downgraded to Medium/deferred: TEA logged and pinned it before implementation, and the agent is the trust boundary, not an adversary. Regexes are ReDoS-free (negated classes, no nested quantifiers); no leakage beyond the caller's own path; `content: null` fails open (stderr, exit 0, no decision emitted) via the pre-existing broad `except`, which is the right direction for a PreToolUse gate. No size guard before `splitlines()` — Low.
- **[TYPE]** — two regexes for one concept with nothing pinning their relationship: confirmed, and it is the structural half of the High. Hand the consolidation to 162-33. Stringly-typed field keys downgraded to Low (a bad key blocks every session write immediately, so it cannot ship quietly); the `dict[str, str]` → dataclass suggestion dismissed as speculative generality for two fields.
- **[RULE]** — checked directly rather than via a specialist. CLAUDE.md rule 6 (result objects, don't throw): the new helpers return `list[str]` and raise nothing on well-formed input. Rule 4 (single source of truth in `pennyfarthing-dist/`): the only source change is there; no symlinked `.pennyfarthing/` path was touched. Rule 8 (runtime scripts use `.pennyfarthing/` paths): no path literals added. Rule 1: no `.pennyfarthing/` edits — tree clean. Rule 5 (`.js` extensions) is TypeScript-only, not applicable. The one rule-shaped tension is the guardrail-bypassability expectation, handled in **[SEC]** above.

**Data flow traced:** agent Write payload → `main()` → `_get_file_type` (path is a session only when it ends `-session.md` **and** contains `.session/`) → `_validate_session` → markdown arm → `_validate_session_fields` → `_story_details_field_labels` (section-scoped, line-anchored, blank-dropping, qualifier-normalizing) → deny with per-field message, or allow. Verified at every branch above.

**Pattern observed (good):** enforcement deliberately mirrors the consumer's own resolution order rather than inventing a rule — section authority and line anchoring match `story_finish._parse_session` (`story_finish.py:164-178`), so the two cannot drift on the parts 155-40 made load-bearing. The High finding is the one place the mirror is broken *and* claimed to be intact.

**Error handling:** malformed stdin never blocks (pinned, `TestScopeBoundaries::test_malformed_stdin_never_blocked`); every non-matching arm allows with a stated reason; the hook fails open on anything it does not recognize, which is the right direction for a PreToolUse gate.

**Security:** no attack surface — no shell, no path traversal, no interpolation of content into commands. The regexes are linear with no nested quantifiers, so no ReDoS. Error text echoes only the file path, which the caller already supplied.

**Coverage boundary the exempt paths leave open (deliberate and logged, confirmed not accidental):** `Edit` is exempted in code with a stated reason and pinned by a test; the XML arm is untouched and pinned. Both are in TEA's Delivery Findings. Two things worth SM's attention beyond those: the `main()` allow-reason string "Edit operations validated post-hoc" is **false** — nothing validates post-hoc — and `sm-setup`, the subagent that actually writes the session from the template (the 155-32 producer), carries no `PreToolUse` frontmatter, unlike the eleven top-level agents. The template does now carry both lines (155-33), so this is a regression-coverage gap rather than a live hole, but the backstop does not currently sit on the producer.

**Deviation audit:**
- Dev, "field-line regex not reused from the consumer" — **ACCEPTED as an implementation choice, rationale AMENDED.** The joint-satisfiability argument is correct and I verified it: the consumer's label class cannot express a qualified label, so importing it would fail TEA's forward-compat requirement. But the deviation's safety justification is directionally wrong. A strict superset means hook-pass does **not** imply finish-readable; it implies the opposite. That inverted claim is the root of the High, and it should not be carried into 162-33 as written.
- TEA, suite location — **ACCEPTED.** New reds inside a 287-failure suite would make RED/GREEN unverifiable; I confirmed the base breakage is unrelated (missing modules, renamed helpers).
- TEA, narrowed assertion — **ACCEPTED**, with the Low above on the replacement's strength.
- TEA, blank values treated as missing — **ACCEPTED.** Verified a blank line and an absent line both reach finish as `None`; accepting the former would ship a hook that green-lights 155-32.
- TEA, Story Details location required — **ACCEPTED.** Matches 155-40 authority; the fallback exists for repair, not for authoring.
- No undocumented deviations found.

**Handoff:** Back to Dev for the High (text-and-docstring change plus optional pinning test). Nothing else blocks.

---

## Reviewer Assessment — Round 2 (delta review of e6a645a21)

**Verdict:** APPROVED. The round-1 High is fixed, and fixed better than I prescribed.

I asked for a text change. Dev instead went after the premise and found that the whole qualifier apparatus was unnecessary: a line the consumer cannot parse contributes no label, so it is *already* tolerated as an extra without being counted. That reframing is correct and I verified it independently — it means the round-1 forward-compat requirement and the round-1 safety requirement were never actually in tension, and the looser label class bought nothing but the defect. `_QUALIFIER_RE` and the normalization step are gone; `_FIELD_LINE_RE` is now `SESSION_FIELD_RE`'s pattern byte-for-byte (confirmed: `_FIELD_LINE_RE.pattern == SESSION_FIELD_RE.pattern` → `True`), and the `.match` call became `.search` to mirror the consumer's call too. Net effect on the diff: it is now *smaller* than the version I rejected.

**Re-probed end-to-end through `pf hooks schema-validation`** (real stdin PreToolUse payloads against the editable install, stdin-only, tree clean):

- The exact shape I rejected on now **denies**: Story Details with a Branch line and only `- **PR (pennyfarthing):** #182`. Same for `- **PR [ui]:** #7` and the status-style qualifier I flagged as untested.
- Still allows: bare PR line; bare PR line **plus** per-repo extras (forward compat preserved — 162-33 is not blocked); placeholders; unbulleted lines; multi-word sibling labels (`Jira Key`, `Stack Parent`) — the tightened label class dropped no legitimate shape.
- Lookalikes still refused (`PR Status`, `Branch Strategy`); exempt paths unchanged (non-session, `sprint/archive/`, Edit tool).
- Consumer round-trip on every PR shape the hook now accepts: bare → `pr` resolves; bare-plus-extras → `pr` resolves to the bare line's value. The acceptance set is now a subset of the resolvable set, which is the invariant round 1 claimed falsely and round 2 actually has.

**Denial message** now says the label must be bare and that a qualified line may appear in addition but does not satisfy the requirement. It no longer points agents at an unresolvable shape. **Docstring at :98** is true as written rather than hedged — the pattern *is* the consumer's, so "by construction one finish can read" is now earned.

**Suite independently re-run:** story suite 50/50; full dist suite 5804 passed / 4 skipped / 7 xfailed, exit 0, zero XPASS (`-rX` empty). `ruff` clean on both files. Head `e6a645a21` GPG-signed, good signature, key 7B37E56D8E241397. Working tree clean.

**Residual assessed — literal duplication instead of an import: ACCEPTED.** I checked the stated cost rather than taking it: `python3 -X importtime` puts `pf.sprint.story_finish` at ~71ms cumulative, and it is **not** already resident on the hook path (verified — importing `pf.hooks.schema_validation` leaves `pf.sprint.story_finish` out of `sys.modules`). So the number is real and the dependency would be new, not free. The fail-open argument is the stronger half: a PreToolUse guardrail that imports a heavyweight sibling gains a way to stop guarding if that import ever breaks, and the broad `except` would turn that into a silent allow. Trading an import for a test-enforced equality pin is the right call for a backstop. The pin is a genuine drift alarm — it fails loudly the moment either pattern is edited, which is exactly what 162-33 needs to see.

**Record-keeping verified.** The round-1 deviation is retracted **in place** with the reasoning for why its premise was wrong, not silently deleted — that is the right way to do it. The two inverted `TestForwardCompatPrShape` assertions are logged as a moderate deviation naming TEA's binding tests explicitly. **I confirm the inversion:** those two assertions encoded the defect. TEA's forward-compat instinct was sound; only its expression was wrong, because it conflated "must not block the future shape" with "must count the future shape". The corrected boundary keeps the first and drops the second, and TEA's actual goal — 162-33 ships without redesigning the hook — is still met.

**Round-2 findings — all Low, none blocking, all deferred:**

| Severity | Issue | Location | Disposition |
|----------|-------|----------|-------------|
| [LOW] | The equality pin compares pattern **strings**, so it is a proxy for the behavioral claim its docstring makes. It fails spuriously on a semantically equivalent reformulation of the consumer regex, and it does not pin the *invocation method* — the hook moved `.match`→`.search` in this very commit and nothing guards that. Latent only: with a `^`-anchored pattern on a single line the two calls are equivalent. | `test_162_11_...py:522` | Add a behavioral round-trip beside the string pin (feed accepted lines through `SESSION_FIELD_RE` and compare the label group). Keep the string pin — it is the louder alarm for 162-33. Deferred. |
| [LOW] | `test_qualified_only_pr_line_is_error` asserts `"pr" in _flagged(errors)` where the sibling class uses `_flagged(errors) == {"pr"}`. The session under test supplies a valid Branch line, so a scanning defect that also flagged branch would pass unnoticed. Inconsistent precision with `TestMissingFieldsBlocked`. | `test_162_11_...py:492` | Tighten to set equality. Deferred. |
| [LOW] | The widened round-trip guard joins both error messages before checking, so one message losing its backticked example is masked by the other's. Also still blind to un-backticked suggestions — and the new PR message mentions the qualifier example without backticks (harmless now that it is explicitly disclaimed, but the guard would not catch a regression there). | `test_162_11_...py:385` | Drive per-field. Deferred. |
| [MEDIUM] | **New, pre-existing, now demonstrated with a live artifact.** The XML routing test is a whole-body substring check for the session open-tag, so a *markdown* session whose prose merely quotes that token routes to the XML arm and is **denied** for missing XML tags. This session file is now itself in that state: my round-1 assessment quotes the token twice (lines 124 and 154), and feeding this exact file to the hook as a Write payload denies with four XML-shape errors — while the field validation on it passes cleanly. Not a regression from this diff (the substring test predates it) and not reachable in practice because agents Edit sessions rather than Write them, but it is the same wide substring TEA logged as an evasion path, biting in the blocking direction. | `schema_validation.py:127` | Narrow the routing test to an anchored/structural check instead of a substring. Logged as a Delivery Finding. Deferred. |

Everything from round 1 that I deferred remains deferred and unchanged: `.session/archive/` denial, `## Story Details:` over-block, fenced-code-block acceptance, the false "Edit operations validated post-hoc" reason string, and `sm-setup` carrying no `PreToolUse` frontmatter. None were in scope for this rework.

**Handoff:** To SM for finish.

## Delivery Findings

The schema-validation hook (`pf hooks schema-validation`, dispatched via PreToolUse on Write) must enforce that `.session/*-session.md` files contain the Branch and PR field lines in the Story Details block. This is the mechanical backstop for the 155-33 template contract.

**Context from 155-33 review:**
- 155-32's false-done happened because sm-setup's session template omitted the Branch/PR lines from Story Details
- finish resolved nothing and took the no-PR arm (155-33 fixed the template)
- This story adds the automatic enforcement per SOUL principle 11: automatic beats instructional

**Scope considerations:**
- Placeholder values are acceptable (e.g., "(none yet ...)", "(trunk-based — work happens on the default branch)")
- The LINES must exist with their field names
- Hook must not false-positive on non-session files or archived sessions
- Since 162-6, multi-repo stories may need per-repo PR lines eventually (162-33 designs that) — hook should enforce the current single-line contract without blocking that future shape
- Path pattern to match: `.session/*-session.md`
- Error message must guide the agent to fix the missing fields

<!-- Agents: append findings below this line. Do not edit other agents' entries. -->

### TEA (test design)
- **Gap** (non-blocking): the `tests/python/` suite is broadly red at base commit e240f7564 — 287 failures, 22 collection errors, none related to this story (module `pf.hooks.reflector_check` absent, `cyclist_pretooluse` absent from `pf.hooks`, `session_start` helpers renamed, hook-command registry list stale). Affects `pennyfarthing/tests/python/` (either the suite is dead and should be deleted/merged into `pennyfarthing-dist/src/pf/tests/`, or it needs a repair story). It cannot function as a gate in its current state. *Found by TEA during test design.*
- **Gap** (non-blocking): the hook exempts Edit, and every agent edits session files far more often than it rewrites them. This story's backstop only fires on whole-file writes, so a session that already lacks the fields keeps them missing through the whole story. Affects `pennyfarthing-dist/src/pf/hooks/schema_validation.py` (a post-write or Stop-time session validator would close it). *Found by TEA during test design.*
- **Improvement** (non-blocking): an agent can bypass field enforcement by including an XML session tag, since that routes to the XML-only validation path. Affects `pennyfarthing-dist/src/pf/hooks/schema_validation.py`. Low risk today (nothing writes XML sessions) but it is a real escape hatch in a hook whose whole purpose is being unbypassable. *Found by TEA during test design.*
### Dev (implementation)
- **Improvement** (non-blocking): the hook and the consumer now hold two regexes for the same concept — `story_finish.SESSION_FIELD_RE` (strict label) and the hook's qualifier-tolerant one. They agree today only because the hook's is a strict superset. Affects `pennyfarthing-dist/src/pf/sprint/story_finish.py` and `pennyfarthing-dist/src/pf/hooks/schema_validation.py` (162-33 should promote one shared parser when it designs the per-repo shape, rather than adding a third). *Found by Dev during implementation.* — **ROUND 2:** this understated it; the divergence was the HIGH the reviewer found, not a tidiness note. The patterns are now identical and pinned equal by test, so the hook can never accept what finish cannot read. Still two literals rather than one import: the hook stays dependency-free because importing `story_finish` costs ~63ms on a PreToolUse path and would make the backstop fail open if that import ever breaks. 162-33 should keep the pin and change both literals together, or promote the pattern to a leaf module both import. *Updated by Dev after review.*
- **Gap** (non-blocking): enforcement is section-scoped to Story Details, so an agent that renames or drops that heading while keeping the field lines gets denied with a message that names the fields, not the heading. Affects `pennyfarthing-dist/src/pf/hooks/schema_validation.py` (the error could detect an absent Story Details section and say so). Not fixed here — no test requires it and the current message already tells the agent where the lines belong. *Found by Dev during implementation.*
### Reviewer (code review)
- **Gap** (non-blocking): `sm-setup` — the subagent that writes the session from the template, i.e. the 155-32 producer — has no `PreToolUse` frontmatter, unlike the eleven top-level agents. This story's backstop therefore does not sit on the write it exists to guard. Affects `pennyfarthing-dist/agents/sm-setup.md` (add the hook, or register schema-validation at settings level so subagent writes are covered too). Latent today because 155-33 fixed the template. *Found by Reviewer during code review.*
- **Gap** (non-blocking): the archive exemption is incidental. `_is_session_file` keys on the `.session/` substring, so `sprint/archive/...` is exempt but `.session/archive/...` — a real archive location, globbed by `migration/session.py:368` — is denied. Affects `pennyfarthing-dist/src/pf/hooks/schema_validation.py` (exempt an `archive/` path segment explicitly). *Found by Reviewer during code review.*
- **Gap** (non-blocking, round 2): the markdown-vs-XML routing test is a whole-body substring check for the session open-tag, so a markdown session that merely quotes that token in prose is routed to the XML arm and denied for missing XML tags. Demonstrated on this very session file (the token appears in the round-1 assessment text; a Write of it denies with four XML-shape errors while its field validation passes). Affects `pennyfarthing-dist/src/pf/hooks/schema_validation.py` (routing wants an anchored/structural check, not a substring — same wide test as TEA's logged evasion path, in the blocking direction). Pre-existing, not introduced by 162-11. *Found by Reviewer during round-2 delta review.*
- **Improvement** (non-blocking): the hook's `Edit` allow-reason reads "Edit operations validated post-hoc" and nothing does. Pre-existing string, but this story makes it load-bearing for the documented Edit gap. Affects `pennyfarthing-dist/src/pf/hooks/schema_validation.py` (say what is true: fragment writes are not validated). *Found by Reviewer during code review.*
- **Question** (non-blocking): the sprint YAML records no description and no acceptance criteria for this story — `sprint/context/context-story-162-11.md` is a title-only stub. ACs came from the SM assessment. Affects `sprint/` (story rows want real AC text so context generation is not a placeholder). *Found by TEA during test design.*

## Design Deviations

<!-- Agents: append deviations below this line. Do not edit other agents' entries. -->

### TEA (test design)
- **Test suite location:** SM said extend the hook's existing test suite. The existing schema-validation unit tests live in `tests/python/test_hooks_subpackage.py`, which is broadly red at base. Tests go in `pennyfarthing-dist/src/pf/tests/test_162_11_schema_hook_session_fields.py` — the suite that is actually green and gate-worthy, following its per-story file convention. Reason: putting new reds inside a suite with 287 pre-existing failures makes RED/GREEN unverifiable. The hook module itself is extended, not forked.
- **One pre-existing assertion narrowed:** `test_hooks_subpackage.py::test_validate_session_old_format_not_blocked` asserted markdown sessions produce zero errors, which directly contradicts this story. Rewritten to its real intent (no XML-shape complaints) and renamed. Reason: leaving a test that asserts the opposite of the AC would send Dev in circles.
- **Blank field values treated as missing:** SM's framing was "the LINES must exist, values may be placeholders." Tests additionally block a line with an empty value. Reason: an empty value and an absent line are indistinguishable to finish, so accepting it would ship a hook that passes the exact defect it exists to catch.
- **Story Details location required:** finish has a fallback that reads anchored field lines from any section. Tests require them in Story Details specifically. Reason: SM's scope says the fields must be in Story Details, and that is the section `_parse_session` treats as authoritative (155-40); the fallback exists for recovering already-broken sessions, not for writing new ones.

### Dev (implementation)
- **Field-line regex not reused from the consumer**
  - Spec source: .session/162-11-session.md, TEA assessment "Designed interface for Dev"
  - Spec text: "at least one line-anchored field line (the shape `story_finish.SESSION_FIELD_RE` parses)"
  - Implementation: the hook defines its own anchored line regex whose label class is `[^*:]+` rather than importing `SESSION_FIELD_RE`
  - Rationale: `SESSION_FIELD_RE`'s label class is word-and-space only, so it cannot parse the qualified per-repo shape the same TEA interface requires the hook to accept (forward compat, 162-33). Both requirements are satisfiable only with a looser label pattern plus a qualifier-stripping normalization. The anchoring and bullet-optionality — the parts 155-40 made load-bearing — are identical, and the round-trip test proves every shape the hook suggests still parses under the consumer's regex.
  - Severity: minor
  - Forward impact: minor — 162-33 inherits two regexes for one concept and should consolidate (logged as a Delivery Finding)
  - **RETRACTED in round 2 (review rejection).** The premise was wrong: qualifier tolerance never required a looser label class, because an unparseable line contributes no label and is therefore tolerated without being counted. The looser class instead made the hook accept PR lines finish cannot resolve. The hook now uses `SESSION_FIELD_RE`'s pattern verbatim, pinned equal by test. No deviation from TEA's interface remains except the one below.
- **Qualified-only PR line refused, against TEA's tests**
  - Spec source: pennyfarthing-dist/src/pf/tests/test_162_11_schema_hook_session_fields.py, `TestForwardCompatPrShape` as written in RED
  - Spec text: "test_per_repo_pr_lines_without_a_bare_pr_line_pass" / "test_bracketed_repo_qualifier_passes" — both asserted `_validate_session(...) == []` for a session whose only PR line carries a repo qualifier
  - Implementation: both cases inverted to assert denial; tolerance is now pinned as qualified-beside-bare instead
  - Rationale: those two assertions encoded the defect the reviewer found. The consumer cannot parse a qualified label (verified: parses to `None`), so a session satisfying them reproduces the 155-32 false-done while passing the backstop. Forward compat for 162-33 is preserved by tolerating the shape as an extra rather than counting it, which needs no hook redesign.
  - Severity: moderate — changes a test contract TEA set as binding
  - Forward impact: 162-33 must teach the consumer to parse qualified labels first; the hook then follows by mirroring the pattern, and the equality pin fails loudly until it does
  - **Reviewer (audit, round 1 — applied to the RETRACTED deviation above, not to this one):** accepted as an implementation choice; rationale amended. The superset relation runs the other way from the claimed guarantee — hook-pass does not imply finish-readable — which was the High. Superseded by the retraction: the patterns are now identical, so there is no superset and nothing for 162-33 to inherit.
  - **Reviewer (audit, round 2 — on this deviation):** **ACCEPTED.** Inverting a binding TEA assertion is the right call when the assertion encodes the defect, and Dev logged it as moderate rather than burying it. Verified: TEA's forward-compat goal (162-33 ships without a hook redesign) is still met by tolerating the qualified shape as an extra. The severity rating is honest and the forward-impact note correctly identifies that the consumer must learn the shape first.