---
story_id: "155-40"
jira_key: "none"
epic: "155"
workflow: "tdd"
---
# Story 155-40: Session field parsing: anchor SESSION_FIELD_RE to line start and scope Branch/PR resolution to Story Details

## Story Details
- **ID:** 155-40
- **Jira Key:** none (Jira: skipped — local-only sprint)
- **Workflow:** tdd
- **Stack Parent:** none
- **Branch:** fix/155-40-session-field-parse
- **PR:** #166 - fix(155-40): anchor SESSION_FIELD_RE and give Story Details authority over Branch/PR resolution

## Workflow Tracking
**Workflow:** tdd
**Phase:** finish
**Phase Started:** 2026-08-01T13:38:32Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-08-01T13:10:23Z | 2026-08-01T13:11:47Z | 1m 24s |
| red | 2026-08-01T13:11:47Z | 2026-08-01T13:24:35Z | 12m 48s |
| green | 2026-08-01T13:24:35Z | 2026-08-01T13:28:38Z | 4m 3s |
| review | 2026-08-01T13:28:38Z | 2026-08-01T13:38:32Z | 9m 54s |
| finish | 2026-08-01T13:38:32Z | - | - |

## Delivery Findings

Root cause, proven during the 155-33 finish incident (2026-08-01): the finish flow's session parser (SESSION_FIELD_RE + _parse_session, in the pennyfarthing Python package under pennyfarthing-dist/src/pf/ — sprint/finish area; TEA locates exact file) uses an UNANCHORED `re.search` per field and last-match-wins accumulation. Any later prose in agent assessments/deviations/findings that merely mentions the field tokens overrides the real Story Details fields. On 155-33 this parsed `Branch:` as the prose fragment "field like the gitflow arm" and `PR:` as None, so finish took the silent no-PR arm and marked the story done while PR #165 was open.

No upstream findings

### TEA (test design)
- **Conflict** (non-blocking): the story title's "scope Branch/PR resolution to Story Details" applied strictly breaks the shipped 155-33 pin `test_backticked_branch_field_resolves_and_merges`, whose fixture's only branch field lives under a Dev Assessment heading (the live 155-32 recovery shape). Tests pin the compatible authority+fallback contract instead. Affects `pennyfarthing-dist/src/pf/sprint/story_finish.py` (`_parse_session` — Dev implements fallback-preserving resolution; Reviewer may override toward strict scoping, which then requires relocating the 155-33 fixture and a product call on hand-written recovery shapes). *Found by TEA during test design.*
- **Improvement** (non-blocking): `demo/collector.py:16` and `findings/aggregate.py:20` carry verbatim copies of the unanchored session-field regex plus the same last-wins loop — the identical poison class, unconsolidated (SOUL #2). Affects `pennyfarthing-dist/src/pf/demo/collector.py` and `pennyfarthing-dist/src/pf/findings/aggregate.py` (consolidate to one parser or sweep in a sibling story). *Found by TEA during test design.*

### Dev (implementation)
- No upstream findings during implementation.

### Reviewer (code review)
- **Improvement** (non-blocking): the new section tracker is fence-blind and lets a LATER literal Story Details heading fill keys the real section lacks (`detail_fields.setdefault` checks key presence, not section instance) — a fenced markdown example containing a column-0 heading replica plus a field line could steer resolution when the real section omits the field; exploit is far more contrived than the pre-fix attack (any prose mention) and the pr value stays digit-constrained, so MEDIUM non-blocking. Affects `pennyfarthing-dist/src/pf/sprint/story_finish.py` (`_parse_session` — skip fenced blocks by toggling on ``` lines, and let only the FIRST Story Details occurrence populate the overlay). *Found by Reviewer during code review.*
- **Improvement** (non-blocking): `_parse_session`'s now-deterministic utf-8 read can raise UnicodeDecodeError out of `finish_story` (call site is unwrapped, unlike the `read_sprint` guard directly above it at story_finish.py:384-391) — a session with pasted binary/mixed-encoding bytes crashes finish with a raw traceback instead of the result contract (SOUL #10); pre-existing on this platform (default codec was already utf-8), narrow trigger. Affects `pennyfarthing-dist/src/pf/sprint/story_finish.py` (wrap the `_parse_session` call site per the sibling `read_sprint` pattern). *Found by Reviewer during code review.*
- **Improvement** (non-blocking): endorsing TEA's parser-copy finding with security evidence — `demo/collector.py:16` and `findings/aggregate.py:20` keep the unanchored last-wins parse but neither feeds subprocess argv today (collector's branch comes from sprint YAML; aggregate is report-only), so consolidation is hygiene not exposure; note `tui/story_detail_data.py` and `bmad/sync.py` carry further independent session parsers for a full-family sweep. Affects `pennyfarthing-dist/src/pf/demo/collector.py`, `pennyfarthing-dist/src/pf/findings/aggregate.py` (consolidate onto the anchored parser, SOUL #2). *Found by Reviewer during code review.*
- **Question** (non-blocking): a placeholder or empty field value in Story Details now BLOCKS later-section fallback (probed live: empty detail value plus a hand-written later field line resolves to None) — this is the security-correct semantics (every fresh template session carries placeholders; deferring to fallback would reopen the later-section attack for the common case), but it means the placeholder-plus-hand-written-recovery shape resolves nothing and today completes via the accepted no-PR done path. The 155-34 loud-abort should explicitly cover this shape. Affects `pennyfarthing-dist/src/pf/sprint/story_finish.py` (155-34 scope note, no change in this story). *Found by Reviewer during code review.*

## Design Deviations

### TEA (test design)
- **Authority+fallback contract instead of strict Story-Details-only scoping**
  - Spec source: story title / context-story-155-40.md
  - Spec text: "scope Branch/PR resolution to Story Details"
  - Implementation: tests pin: Story Details value WINS when present; an anchored line-start field in a later section resolves ONLY when Story Details lacks the field; mid-prose mentions never match anywhere
  - Rationale: strict scoping breaks the shipped 155-33 sibling pin (live-incident recovery shape); the authority+fallback contract kills both 155-33 poisons while keeping all 376 finish-family sibling tests green (proven by green-sim)
  - Severity: minor
  - Forward impact: Dev must not implement strict section-only scoping; Reviewer invited to override with a product call
- **Behavior pinned, not mechanism**
  - Spec source: story title
  - Spec text: "anchor SESSION_FIELD_RE to line start"
  - Implementation: tests accept any implementation with the observable contract (anchored first-match scan or Story-Details overlay both pass); the regex object itself is not asserted on
  - Rationale: fix-agnostic RED per sidecar policy; no real session carries field lines above Story Details, so the variants are observationally equivalent
  - Severity: minor
  - Forward impact: none
- **Four green-on-arrival preservation guards are intentional**
  - Spec source: 155-33 shipped tests + sm-setup template contract
  - Spec text: bulleted/bare field shapes, hand-written fallback session, backtick/annotation/sentinel normalization must keep working
  - Implementation: `TestPreservedShapes` (4 tests) pass on HEAD and must stay green post-fix
  - Rationale: they stop an over-strict anchor (e.g. rejecting the `- ` bullet prefix) from blanking every template-written field — the failure mode that would be strictly worse than the bug
  - Severity: minor
  - Forward impact: gate/Reviewer must not read them as spurious
- **AC record lives in the test-file docstring; rule-#5 pin scoped to the parse function**
  - Spec source: context-story-155-40.md ("TEA to define ACs during RED") + lang-review python #5
  - Spec text: no ACs recorded in sprint YAML; CWE-838 encoding rule
  - Implementation: AC-1..AC-6 defined in `test_155_40_session_field_parse_anchor.py` docstring; the encoding pin walks only the parse function's AST, not the whole module
  - Rationale: docstring-as-AC-record is the 155-10/155-13 precedent; a module-wide encoding sweep is 160-12's pattern and out of this story's scope
  - Severity: minor
  - Forward impact: Reviewer reads the docstring as the spec of record

### Dev (implementation)
- **First-wins applies to all fields; the authority overlay only to branch/pr**
  - Spec source: session Technical Approach + TEA deviation "Authority+fallback contract"
  - Spec text: "scope Branch/PR resolution to Story Details" (title); TEA pinned authority+fallback for branch/pr only
  - Implementation: `setdefault` first-wins for every field key; the Story-Details overlay rewrites only the `branch`/`pr` keys; `jira` and other keys are not overlaid
  - Rationale: the title scopes authority to Branch/PR; widening the overlay to all keys would change jira/workflow resolution no test demands (minimalist discipline) — first-wins already favors Story Details in practice since it is the first section
  - Severity: minor
  - Forward impact: if a future story wants jira under the same authority, extend the overlay tuple

### Reviewer (audit)
- **Authority+fallback contract instead of strict Story-Details-only scoping** → ✓ ACCEPTED by Reviewer: strict scoping would break the shipped live-incident recovery pin and silently orphan hand-written recovery shapes; the fallback is anchored-only, the poison classes are dead (verified by incident-replay tests), and 155-34's loud abort is the systemic backstop for no-resolution worlds. The green-sim proof (376 sibling tests untouched) settles the product call — no override.
- **Behavior pinned, not mechanism** → ✓ ACCEPTED by Reviewer: agrees with author reasoning; the observable contract is what survives refactors.
- **Four green-on-arrival preservation guards are intentional** → ✓ ACCEPTED by Reviewer: the bullet-prefix guard in particular is what stopped a naive line-start anchor from blanking every template field — load-bearing, not spurious.
- **AC record lives in the test-file docstring; rule-#5 pin scoped to the parse function** → ✓ ACCEPTED by Reviewer: docstring-as-AC-record follows the 155-10/155-13 precedent; function-scoped encoding pin is correctly sized (the module-wide sweep belongs to the 160-12 pattern family).
- **First-wins applies to all fields; the authority overlay only to branch/pr** (Dev) → ✓ ACCEPTED by Reviewer: minimalist and title-faithful; first-wins already favors Story Details for unoverlaid keys since it is the first section, so jira behavior is unchanged in every archived-session shape checked.

## Technical Approach

**Acceptance criteria (derived from title + incident):**

1. `SESSION_FIELD_RE` (or its replacement) matches only at line start (anchored, e.g. `^` with MULTILINE) so mid-prose token mentions never match.
2. `Branch:` / `PR:` field resolution is scoped to the Story Details section of the session file only — assessment/deviation/finding prose cannot override fields.
3. Regression test reproducing the 155-33 poisoning: a session whose Story Details carry correct `Branch:` / `PR:` fields plus later prose mentioning the tokens (including the literal fragment "field like the gitflow arm") must parse the REAL fields.
4. First-match or section-scoped semantics replace last-wins, with tests covering: fields only in Story Details; prose-only mentions (no real fields → parse yields None, not prose garbage); fields plus prose mentions.
5. Existing finish-family tests stay green.

**Poison-token principle:** This story fixes the exact bug where unanchored field parsing allows prose mentions to poison the parsed result. Session writing must be careful to refer to these field names ONLY in code backticks (like `Branch:`, `SESSION_FIELD_RE`) in all prose sections. The Story Details section above uses the canonical bold field format; that is the ONLY place bold formatting is allowed for these tokens.

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/src/pf/sprint/story_finish.py` — anchored `SESSION_FIELD_RE` (line start, optional list-bullet prefix), rewrote the parse loop to first-wins accumulation with a section tracker and a Story-Details overlay for the branch/pr keys, added utf-8 encoding to the session read. 40 insertions / 7 deletions, no new imports, exactly TEA's designed interface (which the green-sim had already proven against the full sibling family).

**Tests:** 14/14 story tests passing; 376/376 across all 23 suites importing the module; independent testing-runner verification 198 passed / 0 failed; ruff clean on both changed files; post-runner `git status` confirmed only the intended source file dirty.
**Branch:** pushed to origin (see Story Details)

**Handoff:** To the Queen of Hearts (Reviewer) for review.

## Subagent Results

| # | Specialist | Received | Status | Findings | Decision |
|---|-----------|----------|--------|----------|----------|
| 1 | reviewer-preflight | Yes | clean | none | N/A — GREEN: 14/14 story tests, 376/376 dependent suites, ruff clean, tree clean, no smells |
| 2 | reviewer-edge-hunter | Yes | Skipped | disabled | Disabled via settings — covered personally: probed h3-subheading, closing-hash heading, empty detail value, duplicate/fenced heading edges live; see [EDGE] observations |
| 3 | reviewer-silent-failure-hunter | Yes | Skipped | disabled | Disabled via settings — covered personally: no new swallows in diff; found the unwrapped decode raise (deferred, see [SILENT]) |
| 4 | reviewer-test-analyzer | Yes | Skipped | disabled | Disabled via settings — covered personally: mutation-reasoned every new branch (anchor, overlay tuple, setdefault, bullet tolerance, encoding); no vacuous asserts; see [TEST] |
| 5 | reviewer-comment-analyzer | Yes | Skipped | disabled | Disabled via settings — covered personally: docstring/comments match implementation and cite the right stories; see [DOC] |
| 6 | reviewer-type-design | Yes | Skipped | disabled | Disabled via settings — covered personally: signatures/return contract unchanged, annotations present; see [TYPE] |
| 7 | reviewer-security | Yes | findings | 4 | confirmed 2 (both MEDIUM non-blocking, deferred as findings), corroborated 2 LOW (endorse TEA's consolidation deferral); 0 blocking |
| 8 | reviewer-simplifier | Yes | Skipped | disabled | Disabled via settings — covered personally: 40-line minimal diff, no dead code, no needless abstraction; see [SIMPLE] |
| 9 | reviewer-rule-checker | Yes | Skipped | disabled | Disabled via settings — covered personally: rule-by-rule sweep in Rule Compliance below; see [RULE] |

**All received:** Yes (2 spawned + 7 disabled-and-covered-directly)
**Total findings:** 4 confirmed (0 blocking), 0 dismissed, 4 deferred as non-blocking Delivery Findings

## Reviewer Assessment

**Verdict:** APPROVED

**Binding evidence (classifier-safe, commit-order):** test commit b1e6b7f6c precedes impl commit 21cba11ff; TEA verified 10-RED at the test commit, where the source was byte-identical to develop — the recorded 10-failed/4-passed split IS the inverse-binding probe result. The green-sim cycle (candidate fix applied, 376 green, restored, RED re-verified) is documented in the TEA assessment.

**Data flow traced:** agent-written session markdown → `_parse_session` (anchored regex; first-wins; Story Details overlay for branch/pr) → `_extract_branch` (annotation/backtick strip, sentinel map) / `_extract_pr_number` (digit-only `#(\d+)`) → `gh pr list --head <branch>` / `gh pr view <pr>` / `gh pr merge <pr>` — all list-form argv, no shell anywhere in the module (verified story_finish.py:220-222, 247, 336-340, 576). Extracted values can select a wrong target but can never change command meaning; the pr number reaching merge is always pure digits; the 155-1 post-merge `MERGED` verification still gates the done transition. Safe end-to-end.

**Observations:**
- [VERIFIED] The exact 155-33 incident is dead — evidence: `TestFinishEndToEnd::test_155_33_incident_replay_no_silent_skip` replays the archived poison lines verbatim and asserts the probe went to the real branch and the merge ran; on pre-fix source the RED run recorded the literal garbage probe (`gh pr list --head "field like the gitflow arm"`) and a fabricated `gh pr merge 999`. Complies with epic-155 truthfulness and lang-review #1.
- [EDGE] Probed live: an h3 subheading inside Story Details does NOT reset the section (correct — `###` fails the `## ` prefix test); a closing-hash heading variant degrades gracefully (first-wins still favors Story Details); an empty detail value blocks fallback (security-correct, filed as a 155-34 scope Question). Residual: fence-blindness + duplicate-heading gap-fill (MEDIUM, deferred — see Delivery Findings).
- [SILENT] No new swallows introduced; the diff's only raise-path change is the now-deterministic utf-8 decode, whose call site was already unwrapped pre-diff — deferred with the sibling `read_sprint` guard pattern as the prescribed fix (SOUL #10).
- [TEST] Mutation reasoning on every new branch: reverting the anchor kills 3 tests, dropping either overlay key kills its authority test, reverting to last-wins kills both authority tests, removing bullet tolerance kills the preservation guards, removing encoding kills the AST pin. No vacuous asserts; integration tests pin recorded argv, not just return values. One accepted gap: no pin that jira is NOT overlaid (equivalent-mutant territory, LOW).
- [DOC] Docstring and regex comment accurately state the anchored + authority-with-fallback semantics and cite 155-40/155-33/155-32 — verified against implementation line by line.
- [TYPE] `dict[str, str]` contract unchanged; consumers (`_extract_*`) untouched; annotations complete on the changed function.
- [SEC] Security specialist: 0 blocking. Confirmed MEDIUM fence/duplicate-heading hardening and MEDIUM decode-raise (both deferred, routed); corroborated the LOW parser-copy consolidation (endorsed with argv-safety evidence). Verified-safe list independently matches my own argv/ReDoS/heading analysis.
- [SIMPLE] 40-line diff, mostly documentation; no helper sprawl; the section tracker is a plain string compare. Minimal and readable.
- [RULE] See Rule Compliance below — one pre-existing SOUL #10 gap deferred; all rules newly touched by the diff are compliant.

### Rule Compliance

| Rule | Instances in diff | Verdict |
|------|-------------------|---------|
| #1 silent swallowing | no try/except added or removed | compliant — and the fix removes a silent wrong-value class |
| #2 mutable defaults | 0 new defs with defaults | compliant |
| #3 annotations at boundaries | `_parse_session` (private helper, annotated anyway) | compliant |
| #4 logging | no error paths added that warrant logging (value-level None contract) | compliant |
| #5 path/encoding (CWE-838) | 1 read: `read_text(encoding="utf-8")` | compliant (newly) — pinned by AST test |
| #6 test quality | 14 new tests | compliant — no vacuous asserts, mutation-resistant |
| #13 one-path validation | anchor applies to ALL fields uniformly; overlay deliberately scoped to branch/pr per title (Dev deviation, accepted); sibling parser copies out of file scope, deferred | compliant in-diff |
| SOUL #2 one truth | parser copies in collector/aggregate remain | deferred (TEA finding endorsed) |
| SOUL #10 result objects | unwrapped decode raise at the `_parse_session` call site | pre-existing, deferred with prescribed fix |

### Devil's Advocate

Assume this diff lies and 155-33 happens again next week — how? The strongest attack is the one the security specialist found: the overlay's authority is keyed on a heading STRING, not a section identity. A later fenced example that reproduces a Story Details heading at column 0, in a session whose real Story Details omits a field line, fills the gap — and this codebase's own agents write fenced markdown examples about this exact parser (this session's test file quotes field lines constantly). Mitigations that keep me approving: the template always writes both placeholder lines (so the omitted-field precondition requires a hand-mangled session), 155-43 will enforce their presence mechanically, the pr path stays digit-only, and the pre-fix parser fell to a strictly weaker attack (any mid-line mention, no heading replica needed). Second attack: feed finish a session with undecodable bytes — finish crashes raw instead of returning a result object; ugly, but it cannot produce a false done (a crash before Step 2 leaves session and YAML untouched), and it predates this diff. Third attack: rely on the fallback — write your branch only in an assessment section and hope; anchored fallback resolves it (the shipped recovery contract), and if nothing resolves, today's accepted no-PR path marks done — that residual is 155-34's charter, not this story's, and I filed the placeholder-shape Question so it doesn't slip. Fourth: unicode homoglyph bold-asterisk tricks — the regex requires literal ASCII `**`, so a homoglyph line simply fails to parse, which degrades toward None, never toward garbage. The honest verdict: this diff monotonically shrinks the attack surface, replays the real incident as a permanent regression test, and leaves two well-routed hardening residuals — none of which can mark a story done while its PR stays open.

**Pattern observed:** incident-verbatim regression fixtures (archived-session poison lines reproduced exactly) at `test_155_40_session_field_parse_anchor.py:107-127` — worth repeating for every truthfulness-epic story.
**Error handling:** parse failures degrade to None (extractors), never to captured prose; no-resolution worlds fall through to the accepted no-PR path pending 155-34's loud abort; the merge itself stays gated by the 155-1 post-merge verification.
**Handoff:** To The Mad Hatter (SM) for finish-story.

## TEA Assessment

**Tests Required:** Yes
**Test Files:**
- `pennyfarthing-dist/src/pf/tests/test_155_40_session_field_parse_anchor.py` — anchoring, Story Details authority, no-fabrication, end-to-end incident replays, encoding rule pin

**Tests Written:** 14 total — 10 failing (RED) + 4 intentional green preservation guards, 0 errored
**Status:** RED (failing on assertions for the right reasons — verified directly, per-failure values inspected)

**RED inventory (all assertion-level):**
- `TestAnchoring` (3): mid-prose mentions in a deviation, a finding, and inside Story Details itself each override the real field today (branch parses to the literal prose fragment "field like the gitflow arm" — the live incident value)
- `TestNoFabrication` (2): prose-only mentions yield captured garbage today; a digit-bearing prose tail FABRICATES pr 999 — the RED run reproduced a literal `gh pr merge 999` invocation
- `TestStoryDetailsAuthority` (2): line-start hand-written fields in a later section override Story Details today (last-wins)
- `TestFinishEndToEnd` (2): full verbatim-shaped incident replicas through `finish_story` with the 155-29-style stateful gh fake — wrong-PR merge (999 instead of 288) and the exact 155-33 silent no-PR skip (probes head "field like the gitflow arm", merges nothing, marks done)
- `TestEncodingRule` (1): the parse function's `read_text()` lacks an encoding argument (lang-review python #5, CWE-838)

**Green-sim evidence:** a candidate fix (anchored regex tolerating the list-bullet prefix + first-wins scan + Story Details overlay for branch/pr + utf-8 encoding) applied in place turns all 14 green AND keeps every suite importing `story_finish` green — 376 passed across 23 files. Source restored after; tree clean; RED re-verified.

### Rule Coverage

| Rule | Test(s) | Status |
|------|---------|--------|
| #1 silent swallowing (epic class) | both `TestFinishEndToEnd` replays pin that the silent no-PR skip and wrong-target merge die | failing |
| #5 encoding / CWE-838 | `test_parse_session_read_text_has_encoding` | failing |
| #6 test quality | self-check done: no vacuous asserts, every assert pins a concrete value with a message; own file ruff-clean | n/a |

**Rules checked:** 3 of 3 applicable lang-review rules have coverage (others — mutable defaults, annotations, logging, subprocess hygiene — not touched by this story's surface)
**Self-check:** 0 vacuous tests found

**Designed interface (recommendation, not a pin):** anchor the regex with `^\s*(?:[-*]\s+)?` so template bullets survive; resolve branch/pr from a Story-Details-first overlay; keep the fallback scan for sessions whose only field line is hand-written in a later section; add utf-8 encoding to the read.

**Handoff:** To Dev (the White Rabbit) for implementation. Scoped run command: `cd pennyfarthing/pennyfarthing-dist && uv run pytest src/pf/tests/test_155_40_session_field_parse_anchor.py -q`. The 22 sibling files listed by `grep -ln story_finish src/pf/tests/*.py` must stay green.

## Sm Assessment

Setup complete for 155-40 (p1, 2 pts, tdd, type: bug). Selected manually as top priority: it is the designated fix for the critical finish-parser poisoning that produced a live false-done on 155-33 (done-while-PR-open), and it de-risks every future finish ceremony in the sprint. Jira skipped — local-only sprint. Branch `fix/155-40-session-field-parse` created off up-to-date `develop` in pennyfarthing/ (gitflow). Technical approach and five acceptance criteria are recorded above; the regression fixture must reproduce the 155-33 incident verbatim. Routing: phased tdd → TEA (The Caterpillar) owns the red phase next. One session-hygiene constraint for every downstream agent: keep the poison-token principle — no bold-asterisk field tokens in prose, backticks only.