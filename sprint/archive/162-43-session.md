---
story_id: "162-43"
jira_key: ""
epic: ""
workflow: "tdd"
---
# Story 162-43: Schema-hook hardening tail (162-11 review): allow .session/archive/ writes (real archive location globbed by migration/session.py:368 — currently denied); accept the trailing-colon Story Details heading variant (finish reads it via fallback, hook over-blocks with a misleading message); fix XML routing's whole-body substring test (a markdown session QUOTING the session tag in prose mis-routes to the XML arm and denies — live artifact in the 162-11 session); add a behavioral round-trip test beside the pattern-string equality pin; per-field round-trip guard (joined messages mask per-field regressions)

## Story Details
- **ID:** 162-43
- **Jira Key:** (none — Jira integration disabled)
- **Workflow:** tdd
- **Stack Parent:** none
- **Branch:** feat/162-43-schema-hook-hardening-tail
- **PR:** (none yet — recorded when the PR is created)

## SM Assessment

**Spec:** the title IS the full spec (162-11 review). FIVE deliverables in `pennyfarthing-dist/src/pf/hooks/schema_validation.py` (3 behavior fixes + 2 test strengthenings). I read the code; sites below are grounded.

**1. Allow `.session/archive/` writes (currently DENIED).**
- `_is_session_file` (line 69): `file_path.endswith("-session.md") and ".session/" in file_path`.
- The 162-11 suite's archive test (`ARCHIVE_PATH = "/project/sprint/archive/162-11-session.md"`) passes **by accident** — `sprint/archive/` contains no `.session/` substring, so `_is_session_file` returns False and the write is exempt.
- The REAL archive location is `.session/archive/` (`migration/session.py:363-370` globs `session_dir/"archive"/"*-session.md"`). A write there → `endswith("-session.md")` True AND `.session/` in path True → classified as a LIVE session → validated → an in-flight/complete archived session that doesn't meet the live field/XML contract is DENIED. `story_finish` rewrites archives and must not be blocked.
- **Fix:** exempt `.session/archive/` explicitly. Simplest: in `_is_session_file` (or a small `_is_archived_session` guard consulted by `_get_file_type`), return non-session (or short-circuit to allow) when `/archive/` appears in the `.session/` path segment. Keep `sprint/archive/` working. Do NOT weaken live-session detection.

**2. Accept the trailing-colon Story Details heading variant.**
- `_story_details_field_labels` (line 118): `in_details = line[3:].strip().lower() == STORY_DETAILS_SECTION` ("story details"). A heading `## Story Details:` → `"story details:"` ≠ `"story details"` → `in_details` never flips → zero fields found → hook denies with the misleading "Missing Branch/PR" message even though `story_finish` reads the block via its fallback.
- **Fix:** normalize the heading before comparison — strip a single trailing `:` (and surrounding whitespace) so both `## Story Details` and `## Story Details:` match. Don't broaden to arbitrary suffixes.

**3. Fix XML routing's whole-body substring test.**
- `_validate_session` (line 137): `if "<session" not in content: return _validate_session_fields(content)`. A **markdown** session that merely QUOTES the token `<session` in prose (documenting the XML shape — a live artifact in the 162-11 session file itself) trips the substring, routes to the XML arm, and is denied for missing `story=`/`workflow=`/`<meta>` it was never supposed to have.
- **Fix:** route to the XML arm only on a STRUCTURAL session tag, not a whole-body substring. Detect an actual opening tag — e.g. a line-anchored `^\s*<session[\s>]` (the real XML session root is written at line start with attributes), not a backticked/mid-prose mention. Preserve: genuine XML sessions still validate; genuine malformed XML sessions still get caught.

**4. Behavioral round-trip test beside the pattern-string equality pin.**
- The 162-11 suite pins `schema_validation._FIELD_LINE_RE.pattern == story_finish.SESSION_FIELD_RE.pattern` (string equality, test ~527). String equality is brittle-and-blind both ways: a cosmetic rewrite that preserves semantics breaks it, and (worse) it proves nothing about parse behavior. Add a **behavioral** round-trip: feed a representative corpus of field lines (bulleted/unbulleted, hyphenated repo labels, blank values, mid-prose non-fields, trailing-colon) through BOTH regexes and assert identical (label, value) extraction. This is the guard that actually catches drift.

**5. Per-field round-trip guard.**
- `_validate_session_fields` returns a LIST joined into one message; a test asserting on the joined string can pass while an individual field's detection regresses (branch OK masks PR broken, or vice-versa). Add a guard that checks EACH required field independently — a session missing only branch denies for branch (and names it), missing only PR denies for PR, missing both names both. Pin per-field, not on the concatenation.

**TEA (RED):** failing tests, hook-level (construct `tool_data` dicts / call `_validate_content`/`_is_session_file` directly; NO real Write, NO network):
- (1) a Write to `.session/archive/<id>-session.md` whose body would fail live validation → ALLOWED (archived). Also pin `_is_session_file(".session/archive/x-session.md")` is False (or the archive guard exempts it). Keep the existing `sprint/archive/` case green.
- (2) a session whose heading is `## Story Details:` with valid branch/PR lines → PASSES (fields detected). Guard the non-colon form still works.
- (3) a MARKDOWN session (no real `<session ...>` root) that contains the literal token `` `<session>` `` in prose → routed to the markdown/field arm, PASSES on valid fields. Guard that a genuine XML session (line-anchored `<session story=...>`) still routes to XML and still catches a missing `story=`/`workflow=`.
- (4) behavioral round-trip corpus through `_FIELD_LINE_RE` and `SESSION_FIELD_RE` → identical extraction per line (keep the existing string-equality pin too; add this beside it).
- (5) per-field: missing-branch-only, missing-pr-only, missing-both → each denies naming exactly the missing field(s).

**Dev (GREEN):** three minimal behavior fixes in `schema_validation.py` (archive exemption, trailing-colon heading normalize, structural XML routing). Deliverables 4 & 5 are tests — no prod code beyond what makes them pass. Don't touch `_FIELD_LINE_RE`'s pattern (162-11 invariant: it stays byte-identical to the consumer's `SESSION_FIELD_RE`).

**Constraints (binding):** edit **source** at `pennyfarthing-dist/src/pf/hooks/schema_validation.py` — never `.pennyfarthing/`. SCOPED runs: `cd pennyfarthing/pennyfarthing-dist && uv run pytest src/pf/tests/test_162_11_schema_hook_session_fields.py src/pf/tests/<new file>.py -q` + `test_init_frontmatter_integration.py`. NEVER full suite. Preserve ALL 162-11 invariants (the `_FIELD_LINE_RE == SESSION_FIELD_RE` pin, qualified-PR-label rejection, anchoring, 155-32 field contract). Result objects, not throws (the hook already swallows exceptions to a stderr note + allow — keep that). `ruff check`.

## Workflow Tracking
**Workflow:** tdd
**Phase:** finish
**Phase Started:** 2026-08-12T16:20:34Z
**Round-Trip Count:** 1

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-08-12T15:29:58Z | 2026-08-12T15:32:24Z | 2m 26s |
| red | 2026-08-12T15:32:24Z | 2026-08-12T15:38:47Z | 6m 23s |
| green | 2026-08-12T15:38:47Z | 2026-08-12T15:41:58Z | 3m 11s |
| review | 2026-08-12T15:41:58Z | 2026-08-12T15:53:32Z | 11m 34s |
| green | 2026-08-12T15:53:32Z | 2026-08-12T16:13:37Z | 20m 5s |
| review | 2026-08-12T16:13:37Z | 2026-08-12T16:20:34Z | 6m 57s |
| finish | 2026-08-12T16:20:34Z | - | - |

## Delivery Findings

Agents record upstream observations discovered during their phase.
Each finding is one list item. Use "No upstream findings" if none.

**Types:** Gap, Conflict, Question, Improvement
**Urgency:** blocking, non-blocking

<!-- Agents: append findings below this line. Do not edit other agents' entries. -->

### TEA (test design)
- **Gap** (non-blocking): the hook's `_story_details_field_labels` is NOT fence-aware, but the consumer's `session_parse._parse_session_lines` skips triple-backtick fenced lines. A session whose only `- **PR:**` line sits inside a fenced example block inside Story Details SATISFIES the hook and resolves to NOTHING at finish — the same 155-32 failure class as the qualified-PR label that 162-11's review caught. Affects `pennyfarthing-dist/src/pf/hooks/schema_validation.py` (`_story_details_field_labels` needs the same fence skip as the consumer). Not in 162-43's five deliverables; no test written for it here. *Found by TEA during test design.*
- **Gap** (non-blocking): deliverable 3's specified fix (line-anchored `^\s*<session[\s>]`) still mis-routes a MARKDOWN session that contains a fenced XML example whose `<session ...>` line starts at column 0 inside the fence. The prose/backtick case (the live artifact) is fixed; the fenced-example case is not. Deliberately NOT pinned by a test, so as not to over-constrain the GREEN fix beyond spec. Affects `_validate_session` routing if it ever bites. *Found by TEA during test design.*
- **Improvement** (non-blocking): `_validate_session_fields` returning a `list[str]` of prose messages forces every per-field test to string-match the message to know which field failed (the `_flagged()` helper, duplicated across both suites). A structured return (`list[tuple[field, message]]` or a dict keyed by field) would let tests assert on the field identity directly. Affects `schema_validation.py` + both test suites. *Found by TEA during test design.*

## Design Deviations

Agents log spec deviations as they happen — not after the fact.
Each entry: what was changed, what the spec said, and why.

<!-- Agents: append deviations below this line. Do not edit other agents' entries. -->

### Dev (implementation, round 2)
- **Improvement** (non-blocking): `pf.sprint.__init__` eagerly imports `cli`, `loader`, `status`, `work`, so no hook can import a helper from `pf.sprint.*` without pulling the sprint CLI into every PreToolUse invocation. That is why the hook/consumer parity contract is enforced by DUPLICATION + a parity test in two places now (`_FIELD_LINE_RE`/`SESSION_FIELD_RE` and `_normalize_section_heading`/`normalize_section_heading`). Affects `pennyfarthing-dist/src/pf/sprint/__init__.py` (a lazy `__getattr__` re-export would let hooks share one implementation and delete the duplication class of bug entirely). *Found by Dev during implementation.*

### Dev (implementation)
- **Archive exemption placed in `_is_session_file`, not `_get_file_type`:** TEA left the location free. Implemented as an early return in `_is_session_file` via `_ARCHIVE_SEGMENT_RE = (?:^|/)archive/`, so `_get_file_type` returns None and the hook allows. Reason: one guard covers both the classifier and the decision path with no branching in `_get_file_type`. Side effect: the segment match is not `.session/`-specific, so ANY `-session.md` under an `archive/` segment is exempt — which is the intent (`sprint/archive/` was already exempt for an unrelated reason and stays exempt for a principled one).
- **No changes for deliverables 4 & 5:** tests only, green on the three behavior fixes.

#### Round 2 (REJECTED fix loop)
- **Scope extended to a SECOND prod file:** the story scoped Dev to `schema_validation.py` only. HIGH #1's symmetric fix required editing `src/pf/sprint/session_parse.py`. Reason: Keith approved the symmetric fix over the revert-D2 alternative; the hook must never be looser than the consumer it protects.
- **Retracted the round-1 archive deviation:** round 1 documented "the segment match is not `.session/`-specific… which is the intent." That was wrong — SM's constraint was "exempt `.session/archive/` explicitly… do NOT weaken live-session detection." Narrowed to `(?:^|/)\.session/archive/`; `sprint/archive/` still exempt via the absent `.session/` clause.
- **Normalization duplicated, not imported:** the reviewer preferred a shared helper. `pf.sprint.__init__` imports `cli`, `loader`, `status`, `work`, so `from pf.sprint.session_parse import …` would load the sprint CLI on every PreToolUse Write. Kept two byte-identical functions (`normalize_section_heading` / `_normalize_section_heading`) pinned by a behavioral parity test over a 10-heading corpus — the same trade-off already made for `_FIELD_LINE_RE` vs `SESSION_FIELD_RE`.
- **Perf finding pinned behaviorally, not by pattern string:** a time bound (<1.0s on 128KB of blank indented lines; 5.2s before, sub-ms after) instead of asserting the pattern text, so a future equivalent-but-linear rewrite does not break the test.

### TEA (test design)
- **Deliverable 1 pinned at `_get_file_type`, not `_is_session_file`:** SM offered either ("or the archive guard exempts it"). Tests assert `_get_file_type(".session/archive/x-session.md") is None` plus hook-level ALLOW, mirroring 162-11's own archive test. Reason: leaves Dev free to place the guard in `_is_session_file` or in `_get_file_type` without a test rewrite; the contract that matters is classification + decision, not the helper.
- **Deliverables 4 and 5 are partly green-on-arrival:** both are test strengthenings, not behavior changes, so a corpus round-trip over two byte-identical patterns cannot fail on HEAD. Deliverable 4 is committed as a pure regression pin (plus an anti-vacuity check on the corpus itself). Deliverable 5 was made genuinely RED by parametrizing the per-field guard over BOTH heading spellings — the trailing-colon cases fail today (no field detected → both fields reported), the plain-heading cases are the pin.
- **Fence-aware parity NOT tested:** see Delivery Findings — the hook/consumer disagree on fenced field lines. Out of scope for the five deliverables; testing it would drag prod code changes Dev was not scoped for.

## TEA Assessment

**Tests Required:** Yes
**Reason:** n/a

**Test Files:**
- `pennyfarthing/pennyfarthing-dist/src/pf/tests/test_162_43_schema_hook_hardening.py` - all five deliverables; hook-level only (`_validate_session`, `_story_details_field_labels`, `_get_file_type`, and `main()` via patched stdin/stdout). No real Write, no network.

**Tests Written:** 64 tests (16 failing) covering 5 deliverables
**Status:** RED — `16 failed, 48 passed` (3 archive, 5 trailing-colon heading, 4 XML routing, 4 per-field-under-colon-heading; all assertion failures). 162-11 suite fully green (`50 passed`). `ruff check` + `ruff format` clean on the new file.

**Handoff:** To Dev for implementation

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing/pennyfarthing-dist/src/pf/hooks/schema_validation.py` — three minimal behavior fixes: (1) `_ARCHIVE_SEGMENT_RE` early return in `_is_session_file` exempts `archive/` path segments; (2) `_story_details_field_labels` strips exactly one trailing colon from the `## ` heading before comparing to `STORY_DETAILS_SECTION`; (3) `_validate_session` routes to the XML arm on `_SESSION_ROOT_RE = ^\s*<session[\s>]` (MULTILINE) instead of a whole-body `"<session" in content` substring test.

**Tests:** GREEN
- 162-43 suite: 64/64 passing (was 16 failed / 48 passed)
- 162-11 suite: 50/50 passing (all invariants intact, `_FIELD_LINE_RE` pattern untouched)
- `test_init_frontmatter_integration.py`: passing (127 passed across the three scoped files)
- Extra regression sweep of the other two suites importing the hook (`test_agent_schema_validation_hooks.py`, `test_159_12_advisory_never_edit_zone.py`): 47 passed
- `ruff check` + `ruff format --check`: clean

**Not done (deliberate):** the three non-blocking TEA findings (fence-awareness, column-0 fenced `<session>`, prose-list message shape) are out of scope — no speculative fixes.

**Branch:** feat/162-43-schema-hook-hardening-tail (pushed)

**Handoff:** To Reviewer

---

## Dev Assessment (round 2 — REJECTED fix loop)

**Implementation Complete:** Yes

**Files Changed:**
- `pennyfarthing/pennyfarthing-dist/src/pf/sprint/session_parse.py` — **HIGH #1 (symmetric fix, Keith-approved):** new public `normalize_section_heading()` (strips exactly ONE trailing colon) + `STORY_DETAILS_SECTION` constant; the `## ` heading branch of `_parse_session_lines` now normalizes before the `== "story details"` comparison, so `## Story Details:` gets the 155-40 authority override. `section` is set to the NORMALIZED value, so the downstream `section == STORY_DETAILS_SECTION` check fires. First-wins and the duplicate-section (`seen_story_details`) semantics are untouched.
- `pennyfarthing/pennyfarthing-dist/src/pf/hooks/schema_validation.py` — **HIGH #2:** `_ARCHIVE_SEGMENT_RE` narrowed to `(?:^|/)\.session/archive/` (ancestor `archive/` dirs no longer disable the gate for a whole checkout). **MEDIUM:** `_SESSION_ROOT_RE` → `^[ \t]*<session[\s>]` (5.2s → sub-ms on 128KB of blank indented lines). **HIGH #1 consumer parity:** heading normalization extracted to `_normalize_section_heading()`, the byte-twin of the consumer's `normalize_section_heading` (duplicated for the same reason `_FIELD_LINE_RE` duplicates `SESSION_FIELD_RE` — a PreToolUse hook must not import `pf.sprint`, whose `__init__` pulls in the whole CLI). **LOW:** stale docstring updated — it now claims section-authority parity too, which is again true.
- `pennyfarthing/pennyfarthing-dist/src/pf/tests/test_162_43_schema_hook_hardening.py` — 3 new classes, 22 new tests: `TestStoryDetailsAuthorityParity` (the HIGH #1 repro + hook-accept ⇒ consumer-grants-authority implication + a 10-heading behavioral parity corpus), `TestArchiveExemptionIsScoped` (ancestor-`archive/` regressions), `TestSessionRootRegexIsLinear` (128KB time bound + indented-root guard).

**RED first (HIGH #1 proven):** 10 failed / 76 passed before the fix. The decisive failure — `test_story_details_authority_overrides_earlier_placeholders[## Story Details:]`: placeholder `- **PR:** (none yet…)` under `## SM Assessment`, real `- **PR:** #227` under `## Story Details:` → consumer resolved `pr` to the placeholder. Now `#227`.

**Tests:** GREEN — every scoped run:
- 162-43 + 162-11 suites: **136 passed** (162-43 was 64 tests, now 86)
- session_parse/finish seam (`155-40`, `164-11`, `164-13`, `162-33`, `155-32`): **59 passed**
- remaining `session_parse`/`parse_session` consumers (`143-10`, `143-9`, `155-33`, `164-12`, `164-8`, `test_prime`, `158-4`): **235 passed**
- other hook consumers + integration (`agent_schema_validation_hooks`, `159-12`, `init_frontmatter_integration`): **60 passed**
- `ruff check` + `ruff format --check`: clean on all 3 changed files

**Not done (deliberate):** the two remaining LOWs — `<session/>`/truncated-tag routing and the D4 dormant-round-trip docstring reword — are cosmetic/doc-only and were left alone rather than churning a green suite. The three non-blocking TEA findings (fence-awareness et al.) remain out of scope.

**Branch:** feat/162-43-schema-hook-hardening-tail

**Handoff:** To Reviewer (round 2)

## Subagent Results

| # | Specialist | Received | Status | Findings | Decision |
|---|------------|----------|--------|----------|----------|
| 1 | reviewer-preflight | Yes | clean | 174 passed / 0 failed / 0 skipped across 5 scoped suites; `ruff check` + `ruff format --check` clean; 0 TODOs, 0 test skips; `_is_session_file`/`_get_file_type` have no callers outside the hook + its two test suites | N/A — corroborated by my own run |
| 2 | reviewer-edge-hunter | Yes | findings | 4: archive ancestor-dir over-exemption (high); `<session/>` no longer routes to XML (med); bare `<session` at EOF no longer routes to XML (low); fullwidth-colon heading miss (low) | 1 CONFIRMED → HIGH #2 (independently reproduced). 2+3 CONFIRMED → merged into LOW #4. 4 DISMISSED as a finding, kept as a note: pre-existing on `develop`, not a regression, and no agent emits U+FF1A |
| 3 | reviewer-security | Yes | findings | 2: O(N2) ReDoS on `_SESSION_ROOT_RE` with measured timings (high conf); archive bypass scope exceeds stated intent (med conf) | 1 CONFIRMED → MEDIUM #3. I re-measured independently (68s at 1.6MB) and verified the proposed `[ \t]*` fix (8.9ms). Severity set to MEDIUM not HIGH: reachable only via a session file with long contiguous whitespace runs. 2 CONFIRMED → duplicate of HIGH #2 |
| 4 | reviewer-test-analyzer | Yes | findings | 3: D4 round-trip vacuous (high conf); hyphenated repo-label not pinned in corpus (med); D5 hook-output variant asserts on the joined message (med). Plus a 5-mutation battery: all 3 prod fixes caught | 1 PARTIALLY CONFIRMED → **DOWNGRADED** to LOW #6. Its object-identity proof is correct (`_FIELD_LINE_RE is SESSION_FIELD_RE` is True — I verified) but its conclusion "no corpus crafting can make the round-trip non-vacuous" is WRONG: once the pattern strings diverge textually the objects separate and the corpus does real work, which is exactly the drift case. Dormant, not vacuous. 2 CONFIRMED → folded into LOW #6 fix. 3 CONFIRMED but not raised separately — `test_one_message_per_missing_field_naming_only_itself` already enforces the structural invariant (mutation-proven) |
| 5 | reviewer-simplifier | Yes | findings | 4: `_ARCHIVE_SEGMENT_RE` over-broad vs. stated requirement; redundant `.strip()` after `heading[:-1]`; 2 parametrize opportunities in the test file. Verified the `migration/session.py:363-370` citation is accurate | 1 CONFIRMED → reinforces HIGH #2 (third independent hit). 2 DISMISSED — the `.strip()` is what makes `## Story Details :` work, which I verified passes; harmless and mildly defensive. 3+4 DISMISSED — style-only, no correctness impact, not worth churning a green suite |
| 6 | reviewer-rule-checker | Yes | clean | 11 rules / 24 instances / 0 violations. Both files under `pennyfarthing-dist/` (source, not `.pennyfarthing/` symlinks); no sprint YAML, no `node_modules`, no runtime `pennyfarthing-dist/` path strings; fail-open `main()` honors the result-object rule | N/A — symlink and source-of-truth rules verified compliant |
| 7 | reviewer-type-design | Yes | findings | 3: `_is_session_file` name now lies for archived sessions (med); `_get_file_type` conflates "unknown type" with "exempt session" so `main()` emits a false allow reason (high conf); `str` path type forces hand-rolled segment matching (low) | 2 CONFIRMED → LOW #7 (new). 1 CONFIRMED, folded into LOW #7 as the same root cause. 3 noted in HIGH #2's fix guidance (`Path.parts` is a valid alternative) but not raised — refactoring the path type across four predicates is out of scope for this story |

**All received: Yes** — 7 of 7 specialists returned results; no timeouts, no errors, no skipped rows.

Two subagents (edge-hunter, security) independently reached HIGH #2, and the simplifier reached it a third time from a readability angle. My own decisive finding (HIGH #1, the hook/consumer Story Details divergence) was found by none of the seven — it required tracing the changed heading logic across the seam into `session_parse.py`, which sits outside the diff.

## Reviewer Assessment

**Verdict:** REJECTED

Preflight is green (174 passed across the 5 scoped suites, `ruff check` + `ruff format --check` clean), edits are in `pennyfarthing-dist/` source (symlink rule respected), and the `_FIELD_LINE_RE.pattern == SESSION_FIELD_RE.pattern` invariant holds. Two of the three fixes are correct. Deliverable 2 and Deliverable 1 both reintroduce the failure class this hook exists to prevent. All findings below were reproduced by running code, not by reading it.

| Severity | Issue | Location | Fix Required |
|----------|-------|----------|--------------|
| [HIGH] | **Colon-heading fix creates a hook/consumer divergence — the 155-32 class, reproduced.** The consumer `session_parse._parse_session_lines:48` matches `candidate == "story details"` EXACTLY, with no colon strip. The hook now accepts `## Story Details:` and reports both fields "in Story Details"; the consumer classifies that section as `"story details:"`, so the block never enters `detail_fields` and the 155-40 Story-Details authority override never fires. Proven: for a session with a placeholder `- **PR:** (none yet...)` in an earlier section and `- **PR:** #227` under `## Story Details:`, the hook PASSES and the consumer resolves `pr` to the placeholder. Same body with the plain heading resolves `#227`. That is a story going done pointing at no PR while the gate said OK. It also falsifies the docstring at `schema_validation.py:120-131` ("a session that passes is by construction one finish can read"). | `schema_validation.py:141-143` + `src/pf/sprint/session_parse.py:48` | Make the fix SYMMETRIC: apply the same single-trailing-colon normalization in `session_parse._parse_session_lines` heading branch so the consumer grants Story-Details authority to the same headings the hook accepts. Add a test asserting hook-accept ⇒ consumer-grants-authority for both spellings (the divergence case above is the test). Alternative if consumer changes are out of scope: revert D2 and instead fix only the misleading deny message. Do not leave the hook looser than the consumer. |
| [HIGH] | **Archive exemption silently disables the gate for whole projects.** `_ARCHIVE_SEGMENT_RE = (?:^|/)archive/` matches an `archive/` segment ANYWHERE in the path, including ancestors above the repo. Proven: `_is_session_file("/Users/k/archive/myproj/.session/162-1-session.md")` → `False`, `_get_file_type(...)` → `None` → every live session write in that checkout is allowed unvalidated, with no warning. Same for `archive/.session/x-session.md`. This is a behavior regression (those paths were validated on `develop`) and it contradicts the binding SM constraint "Do NOT weaken live-session detection." The stated requirement is only `.session/archive/` — the real glob at `migration/session.py:363-370` (citation verified accurate). | `schema_validation.py:81,85` | Narrow to the canonical location: `re.compile(r"(?:^|/)\.session/archive/")`, or drop the regex for `".session/archive/" in file_path`. `sprint/archive/` stays exempt either way via the absent `.session/` clause — verified. Add the ancestor-`archive/` path as a regression test (`/Users/k/archive/proj/.session/x-session.md` must remain a live session). |
| [MEDIUM] | **[SEC]** **`_SESSION_ROOT_RE` is O(N2) — measured 68s.** `\s*` matches newlines, so under `re.MULTILINE` each line-start anchor lets `\s*` consume every following whitespace char before failing on `<session`, then unwinds. Measured on this runtime: 2k whitespace lines → 264ms, 8k → 4.25s, 32k (1.6MB) → **67.96s**. A stall is NOT covered by `main()`'s fail-open handler — it does not raise, it blocks the PreToolUse hook synchronously. Reachable only via a session file with long contiguous whitespace runs, hence Medium not High. | `schema_validation.py:69` | `re.compile(r"^[ \t]*<session[\s>]", re.MULTILINE)` — horizontal-only indent is exactly the documented intent ("a re-indented file is still an XML session"), costs zero expressiveness, and measures 8.93ms on the 1.6MB input (7600x faster). |
| [LOW] | **Two XML shapes now escape XML validation.** `[\s>]` excludes `/`, so `<session/>` no longer routes to the XML arm (`develop`'s substring test did); likewise a bare `<session` at EOF. Both fall to the field arm and skip every tag check. Both are malformed input, so impact is low. | `schema_validation.py:69` | Either widen to `[\s>/]` or add a comment naming `<session/>` and truncated tags as intentional non-matches, alongside the fenced-block limitation TEA already logged. |
| [LOW] | **Stale docstring.** `_story_details_field_labels`' docstring still asserts consumer parity ("the line pattern here is the consumer's own — so a session that passes is by construction one finish can read"). True for the FIELD pattern, now false for SECTION detection (HIGH #1). | `schema_validation.py:120-131` | Update once HIGH #1 is resolved; if the symmetric fix lands, the claim becomes true again and should say so explicitly. |
| [LOW] | **[TEST]** **Deliverable 4 cannot fail at HEAD.** `re.compile` caches by (pattern, flags), so `_FIELD_LINE_RE is SESSION_FIELD_RE` is literally `True` (verified) — the round-trip is `x == x` for every corpus row. TEA's anti-vacuity check has real teeth for what it guards (corpus strength: ≥10 matches, ≥5 near-miss rejections, canonical branch value, blank-value row) but it cannot fix object identity. NOT dismissed as worthless: the moment the two pattern strings diverge textually the objects separate and the corpus does genuine behavioral work, which is precisely the drift scenario targeted. It is dormant, not vacuous — but the docstring at line 495-502 overstates ("asserts the two regexes make the same DECISION"). | `test_162_43_schema_hook_hardening.py:495-513` | Non-blocking. Reword the docstring to "dormant until the patterns diverge textually," and add `assert ("pr my-repo", "#227") in matched` to pin the 162-33 hyphenated-label extraction the corpus comment claims to cover but never asserts. |

| [LOW] | **[TYPE]** **`_get_file_type` conflates "not a governed file" with "exempt session", so the hook logs a false reason.** The archive guard lives inside `_is_session_file`, so an archived session makes `_get_file_type` return `None` and `main():298-306` emits the allow reason **"Not a session/skill/step file"** — which is untrue: `.session/archive/162-1-session.md` IS a session file, it is merely exempt. The predicate's name now lies too (False no longer means "not a session file"). Cosmetic today, but the hook's own audit trail is the thing that explains a skipped validation to whoever debugs the next 155-32. | `schema_validation.py:84,106` and `main():298-306` | Split the predicates — keep `_is_session_file` structural and add `_is_archived_session`, consulted by `_get_file_type`; return a distinct `"archived-session"` state (a `Literal` beats the existing magic strings) and give `main()` the honest reason "Archived session — exempt from schema validation". Naturally combines with HIGH #2's narrowing. |
| [RULE] | **No project-rule violations.** 11 rules / 24 instances / 0 violations. Both changed files are under `pennyfarthing-dist/` (source of truth, rule 4) with nothing written to `.pennyfarthing/` symlinked dirs (rule 1) — I confirmed `.pennyfarthing/` contains only symlinks to `pennyfarthing-dist/` and neither changed path resolves through one. No sprint YAML edited directly (rule 2), no `node_modules/` (rule 3), no runtime `pennyfarthing-dist/` path strings (rule 8). `main()`'s fail-open swallow-to-stderr-and-allow is preserved, honoring rule 6 (result objects, don't throw) at the hook boundary. | — | None. |

**Data flow traced:** agent `Write` → `main()` → `_get_file_type(file_path)` → `_validate_session(content)` → `_SESSION_ROOT_RE` routing → `_story_details_field_labels` → `_FIELD_LINE_RE` → deny/allow. Then the SAME session file → `session_parse.parse_session` → `story_finish` merge target. The divergence in HIGH #1 sits exactly at the seam between those two halves: the hook and the consumer disagree on what "Story Details" means.

**Verified good:**
- `_FIELD_LINE_RE.pattern == story_finish.SESSION_FIELD_RE.pattern` — holds, pattern byte-untouched (162-11 invariant intact, 50/50 green).
- Qualified-PR rejection, line anchoring, 155-32 field contract — all still enforced.
- Genuine XML sessions still route to XML and still get caught: indented root, `<session\n  story=...>` (attrs on next line), and `<session workflow="tdd">` missing `story=` all behave correctly (verified).
- The prose/backtick artifact that motivated D3 is genuinely fixed — both `` `<session>` `` in prose and `<session...>` mid-sentence now route to the field arm.
- Archive comment's citation of `migration/session.py:363-370` is factually accurate (verified by reading it).
- Mutation battery: all three prod fixes survive reversion mutations; `TestPerFieldGuard::test_one_message_per_missing_field_naming_only_itself` genuinely enforces per-field structure (catches a collapse-to-one-message mutation).

**Deviation audit:**
- *"Archive exemption placed in `_is_session_file`, not `_get_file_type`"* — **ACCEPTED** on placement (TEA left it free; one guard covers classifier and decision path). **FLAGGED** on the documented side effect: "the segment match is not `.session/`-specific... which is the intent." It is not the intent — SM's constraint was "exempt `.session/archive/` explicitly... Do NOT weaken live-session detection," and the widening does weaken it (HIGH #2). `sprint/archive/` needs no help from the widened match; it is already exempt via the absent `.session/` clause.
- *"No changes for deliverables 4 & 5"* — **ACCEPTED**, correct for test-only deliverables.
- *TEA: "Deliverable 1 pinned at `_get_file_type`"* — **ACCEPTED**, contract-level pinning was the right call.
- *TEA: "Deliverables 4 and 5 partly green-on-arrival"* — **ACCEPTED** and honestly disclosed; see LOW finding for the residual overstatement.
- *TEA: "Fence-aware parity NOT tested"* — **ACCEPTED** as scoped out.
- **UNDOCUMENTED:** the `<session/>` / truncated-tag routing change (LOW) is a behavior delta from `develop` that no deviation entry or test mentions.

**Handoff:** Back to Dev. HIGH #1 requires a change in `src/pf/sprint/session_parse.py` (outside the story's original single-file scope) — SM should confirm that scope extension or accept the revert-D2 alternative.

### Reviewer (audit)
- **Gap** (blocking): the hook and `session_parse` disagree on Story Details heading recognition after this change — hook strips one trailing colon, consumer requires an exact match. Affects `pennyfarthing-dist/src/pf/hooks/schema_validation.py` and `pennyfarthing-dist/src/pf/sprint/session_parse.py` (the normalization must live in both, or in neither). *Found by Reviewer during code review.*
- **Gap** (blocking): `_ARCHIVE_SEGMENT_RE` exempts any `archive/` path segment including ancestors above the repo root, silently disabling session validation for an entire checkout. Affects `pennyfarthing-dist/src/pf/hooks/schema_validation.py` (narrow to `.session/archive/`). *Found by Reviewer during code review.*
- **Improvement** (non-blocking): `^\s*` under `re.MULTILINE` is an O(N2) anti-pattern that will recur in this codebase. Affects any MULTILINE line-start regex — worth a grep sweep for `^\s*` + `re.MULTILINE` and a note in the hooks guide. *Found by Reviewer during code review.*
- **Question** (non-blocking): TEA's fence-awareness gap (a `- **PR:**` inside a fenced block inside Story Details satisfies the hook, resolves to nothing at finish) is the same seam as HIGH #1 and is still open. Affects `_story_details_field_labels` (needs the consumer's fence skip). Worth folding into one "hook/consumer parity" follow-up story rather than three separate tails. *Found by Reviewer during code review.*
## Reviewer Assessment

**Verdict:** APPROVED

_Round 2 (re-review after rework)._ Scoped to the round-2 diff only (`f3f649f01..ffd49662f`, 3 files, +238/-23) per coordinator instruction; the round-1 audit above is not repeated. **No round-2 subagents were spawned** — this was a targeted re-verification of five specific claims, and I ran every probe myself rather than delegating. The Subagent Results table above documents round 1.

Both blocking findings are genuinely fixed, verified end-to-end with my own adversarial probes and not by reading the tests.

**1. HIGH #1 (hook/consumer Story Details divergence) — FIXED, symmetric.**
- My exact round-1 repro (placeholder `- **PR:** (none yet…)` in an earlier section, real `#227` under Story Details) now resolves `pr='#227'` for `## Story Details`, `## Story Details:` **and** `## Story Details :`. Before round 2 the colon spelling resolved the placeholder. I could not construct a heading-spelling shadow that survives.
- Negatives reject on BOTH sides: `## Story Details::`, `## Story Details Extra`, `## Story  Details:` (double internal space), `## Story Details;`, and fullwidth `## Story Details：` all normalize identically in the two implementations and all correctly deny.
- Byte-twin parity over an 18-heading adversarial corpus of my own (empty string, bare `:`, bare `::`, tab-separated, leading tab, 200-char heading, unicode fullwidth colon, `## SM Assessment:`): **zero divergences** between `schema_validation._normalize_section_heading` and `session_parse.normalize_section_heading`.
- `seen_story_details` first-wins / duplicate-section semantics are unchanged — see the non-blocking finding below for the one residual (pre-existing) shape.
- The duplication decision (twin function, not an import) is correct and correctly justified: a PreToolUse hook importing `pf.sprint` would pull the eager CLI import chain into every Write. Same precedent as `_FIELD_LINE_RE`. Both docstrings cross-reference each other and name the parity test.

**2. HIGH #2 (archive over-exemption) — FIXED.** `(?:^|/)\.session/archive/`. All eight path cases behave: `.session/archive/x-session.md` and nested `.session/archive/deep/y-session.md` exempt; `/Users/k/archive/myproj/.session/162-1-session.md` and `archive/.session/x-session.md` are **live again** (ancestor bypass closed); `sprint/archive/162-11-session.md` still exempt via the absent `.session/` clause; `162-43-archive-session.md` and `.session/archives/` still live. The comment now records the ancestor-bypass rationale instead of asserting the widening was intentional.

**3. MEDIUM (O(N²)) — FIXED.** `^[ \t]*<session[\s>]`. Measured: 0.57ms / 2.20ms / 8.78ms / **35.97ms** at 2k / 8k / 32k / 128k blank indented lines (6.5MB) — linear, versus 68s at 1.6MB before. Routing semantics preserved: space-indented, tab-indented, column-0, blank-lines-then-root, and `<session\n  story=…>` all still route to XML; prose/backtick mentions still route to the field arm.

**4. Parity test HAS teeth — mutation-proven.** Unlike deliverable 4's regex pin (where `re.compile` caching made the two objects identical), these are two separately-defined functions, so the corpus does real work today. I ran four mutations against the hook's normalizer:

| Mutation | Result | Caught by |
|---|---|---|
| A: strip ALL trailing colons (hook looser than consumer) | **CAUGHT** | `## Story Details::` |
| B: no colon strip (hook stricter) | **CAUGHT** | 3 corpus cases + the implication test |
| C: strip any trailing `:;-` | **CAUGHT** | `## Story Details::`, `## Story Details -` |
| D: strip one colon but drop the re-`.strip()` | *SURVIVED* | — (see LOW below) |

`test_hook_accept_implies_consumer_grants_authority` is the right shape — stated as an implication, so it holds whichever way the normalization settles rather than hard-coding today's answer.

**5. No regression in the session_parse/finish seam.** 589 tests pass across the session_parse / story_finish / append_only / demo-collector / story_detail / findings-aggregate / frontmatter / schema-validation / never-edit-zone selection. I also confirmed the three modules whose docstrings claim "Story Details authority, first-wins" (`demo/collector.py`, `tui/story_detail_data.py`, `findings/aggregate.py`) all **delegate** to `session_parse.parse_session` rather than reimplementing it, so the fix propagates to every consumer rather than just finish.

**Tests:** 136 passed (162-43: 86, 162-11: 50). 589 passed on the seam selection. `ruff check` clean, `ruff format --check` clean on all three changed files. Full suite deliberately not run.

### Specialist dimension coverage (round 2)

No round-2 subagents were spawned — the re-review was scoped to five specific claims on a 3-file diff, so I ran each dimension myself. Recorded per dimension so the coverage is auditable rather than implied:

- **[SEC]** — Round-1's ReDoS finding is resolved and I re-measured it rather than trusting the fix: 35.97ms on 6.5MB (128k blank indented lines), linear scaling across 2k/8k/32k/128k, down from 68s at 1.6MB. No new injection, secret, or info-leak surface: the diff adds no I/O, no subprocess, no deserialization, and no new user-controlled data path — `normalize_section_heading` is pure string work on already-in-memory content. Re-audited the validation-BYPASS vector that produced round-1's HIGH #2: `(?:^|/)\.session/archive/` now anchors on the segment PAIR, and I confirmed no ancestor-directory, sibling (`archives/`), or filename-embedded (`162-43-archive-session.md`) path evades the gate. No new bypass introduced.
- **[TEST]** — Judged the new parity guard adversarially rather than counting tests. Mutation battery of 4 against the hook normalizer: 3 caught (strip-all-colons, no-strip, strip-any-punctuation), 1 survived (dropped re-`.strip()`) → filed as the LOW below with the one-line corpus fix. Confirmed these tests avoid round-1's vacuity trap: the two normalizers are separately-defined function objects, not `re.compile`-cached identities, so the corpus does real work today. `test_hook_accept_implies_consumer_grants_authority` is well-shaped as an implication. Independently reproduced the "failed-then-passed" claim by probing my own round-1 repro directly. 136 + 589 tests verified green by my own runs.
- **[TYPE]** — The diff improves type design on the axis round 1 flagged. `STORY_DETAILS_SECTION` is now a named constant in BOTH modules instead of the bare literal `"story details"` appearing twice inline in `_parse_session_lines`, and `section == STORY_DETAILS_SECTION` replaces the stringly-typed comparison. `normalize_section_heading(heading_text: str) -> str` is fully annotated in both copies. Round-1's `_get_file_type` → `str | None` conflation (archived session vs. unknown type, producing a false allow reason) is unchanged and remains a LOW; not a round-2 regression. The extraction of the inline heading logic into a named function is the right seam for the parity pin — it made the invariant testable, which is why the mutation battery was possible at all.
- **[RULE]** — Re-verified against project rules for the newly touched file. `pennyfarthing-dist/src/pf/sprint/session_parse.py` is SOURCE, not a `.pennyfarthing/` symlink target (rule 1) and sits under `pennyfarthing-dist/` (rule 4) — checked that `.pennyfarthing/` holds only symlinks and that neither changed path resolves through one. No sprint YAML edited directly (rule 2), no `node_modules/` (rule 3), no runtime `pennyfarthing-dist/` path strings (rule 8). Rule 6 (result objects, don't throw): both new functions return plain values and raise nothing; `main()`'s fail-open swallow-to-stderr-and-allow is untouched. The DRY deviation (twin function rather than shared import) is deliberate, documented on both sides, and justified by the hook's import-cost constraint — see the deviation audit. Zero violations.

### Non-blocking findings (round 2)

| Severity | Issue | Location | Recommendation |
|----------|-------|----------|----------------|
| [MEDIUM] | **Placeholder shadowing is still reachable via DUPLICATE Story Details sections** — a different mechanism from HIGH #1, and **pre-existing, not a round-2 regression** (I ran the identical probe against `develop`: same result, `pr='(placeholder)'`). Shape: a placeholder PR in an early section, `## Story Details` with only Branch, an intervening `## Notes`, then a second `## Story Details` carrying the real PR. The hook flips `in_details` on EVERY matching heading so it reports `{branch, pr}` present and PASSES; the consumer's `seen_story_details` denies authority to the second block, so first-wins hands `pr` to the placeholder. Gate says OK, finish points at no PR. | `session_parse.py:72-78` vs `schema_validation.py:163-166` | Follow-up story, not this one. The hook needs the consumer's first-block-only rule (or the consumer needs the hook's every-block rule). Fold into the parity story below. |
| [LOW] | **`session_parse.py:75-77`'s comment is false for ADJACENT duplicates.** It claims "Second (and later) occurrences: do NOT update section — those lines must never contribute to detail_fields." Because `section` is simply not reassigned, two *adjacent* Story Details headings leave `section` still equal to `"story details"` from the first, so the second block's fields DO reach `detail_fields` (verified: resolves `#227`). Pre-existing logic, but round 2 widened which heading spellings reach this branch. | `session_parse.py:75-77` | Correct the comment to describe what the code does, or set `section = None` on the duplicate to make the comment true. |
| [LOW] | **Parity corpus lacks the space-before-colon heading**, the one shape whose correctness depends on the second `.strip()` after `heading[:-1]`. Mutation D survived because of it. The existing `test_trailing_colon_heading_with_trailing_space_passes` covers space *after* the colon, not before. Direction of harm is the safe one (hook stricter → false deny, not a 155-32), hence Low. | `test_162_43_schema_hook_hardening.py:665-679` | Add `"## Story Details :"` to the `test_heading_recognition_is_identical_on_both_sides` corpus — one line, kills mutation D. |
| [LOW] | **Latent third heading-matching site.** `session/append_only.py:20` has `EXEMPT_SECTIONS = {"Workflow Tracking", "Story Details", "Phase History"}` matched exactly and **case-sensitively** at line 54, with no colon normalization. Its module docstring names "Story Details (PR field additions)" as a legitimate exempt edit — which would not apply under `## Story Details:`. Latent only: `validate_session_append_only` has **zero callers** anywhere in the package or in any yaml/toml/json config (I grepped both), i.e. it is unwired dead code from 150-10. | `session/append_only.py:20,54` | No action now. If append-only is ever wired up, it must adopt `normalize_section_heading` — note it in the parity follow-up so it is not rediscovered as a bug. |
| [LOW] | Two round-1 Lows remain open and were **not** in round-2's scope: `<session/>` and truncated `<session` at EOF still skip the XML arm; and the archive guard living inside `_is_session_file` still makes `main()` log the false allow reason "Not a session/skill/step file" for archived sessions. | `schema_validation.py:69,84,106` | Optional cleanup; neither is a correctness risk. |

**Round-2 deviation audit:** the twin-function duplication instead of a shared import is a deliberate, documented deviation from DRY. **ACCEPTED** — the import-cost rationale is real (PreToolUse runs on every Write), it follows the established `_FIELD_LINE_RE`/`SESSION_FIELD_RE` precedent, both sides cross-reference each other, and the drift risk is pinned by a mutation-proven behavioral test. No undocumented deviations found in the round-2 diff.

**Handoff:** To SM for finish-story.

### Reviewer (round-2 audit)
- **Gap** (non-blocking): placeholder shadowing remains reachable through duplicate `## Story Details` sections — the hook treats every Story Details block as authoritative, the consumer only the first. Pre-existing (verified identical on `develop`), not introduced here. Affects `pennyfarthing-dist/src/pf/sprint/session_parse.py:72-78` and `pennyfarthing-dist/src/pf/hooks/schema_validation.py:163-166` (the two need the same first-block rule). *Found by Reviewer during round-2 code review.*
- **Improvement** (non-blocking): there are now FOUR sites that recognize the `## Story Details` heading — `session_parse` (normalized), `schema_validation` (normalized twin), and `session/append_only.py:20` (exact, case-sensitive, unwired). The parity follow-up story should enumerate all of them and pin them with one shared corpus. Affects `pennyfarthing-dist/src/pf/session/append_only.py`. *Found by Reviewer during round-2 code review.*
- **Question** (non-blocking): `session/append_only.py` (150-10) has no callers in code or config. Is it abandoned, or wiring that got dropped? If abandoned it should be deleted rather than left as a trap that silently disagrees with the parser. Affects `pennyfarthing-dist/src/pf/session/append_only.py`. *Found by Reviewer during round-2 code review.*
- **Improvement** (non-blocking): the recommended single "hook/consumer parity" follow-up story now has four members — TEA's fence-awareness gap, TEA's fenced-col-0 `<session>` gap, the duplicate-Story-Details gap above, and the `append_only` heading site. All four are the same seam. *Found by Reviewer during round-2 code review.*