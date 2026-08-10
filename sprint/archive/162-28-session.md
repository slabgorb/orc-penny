---
story_id: "162-28"
jira_key: ""
epic: ""
workflow: "tdd"
---
# Story 162-28: B1: phase-approval gate FAILS OPEN on rework sessions

## Story Details
- **ID:** 162-28
- **Jira Key:** (none)
- **Workflow:** tdd
- **Stack Parent:** none
- **Branch:** feat/162-28-phase-approval-gate-fails-open
- **PR:** #188

## Workflow Tracking
**Workflow:** tdd
**Phase:** finish
**Phase Started:** 2026-08-06T20:19:37Z
**Round-Trip Count:** 2

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-08-06T18:20:40.523814+00:00 | 2026-08-06T18:21:49Z | 1m 8s |
| red | 2026-08-06T18:21:49Z | 2026-08-06T18:33:14Z | 11m 25s |
| green | 2026-08-06T18:33:14Z | 2026-08-06T18:45:51Z | 12m 37s |
| review | 2026-08-06T18:45:51Z | 2026-08-06T19:06:22Z | 20m 31s |
| green | 2026-08-06T19:06:22Z | 2026-08-06T19:25:31Z | 19m 9s |
| review | 2026-08-06T19:25:31Z | 2026-08-06T19:47:27Z | 21m 56s |
| green | 2026-08-06T19:47:27Z | 2026-08-06T19:59:05Z | 11m 38s |
| review | 2026-08-06T19:59:05Z | 2026-08-06T20:19:37Z | 20m 32s |
| finish | 2026-08-06T20:19:37Z | - | - |

## Sm Assessment

**Verdict:** READY

Setup complete for 162-28 (p1, 2 pts, tdd). Branch `feat/162-28-phase-approval-gate-fails-open` cut from the develop tip that includes 162-21 (PR #186) and 162-25 (PR #187). Peloton mode active (team peloton-162-28, subagent orchestration). Key routing note: the story predates 162-21, whose d3a4bdaad moved both approval subchecks to select_last_section — the pinned xfails in test_143_12 were reported retired. TEA's red phase starts by re-running those xfails and characterizing any residue; any remaining gap closes within 162-21's last-match-plus-ambiguity-guard design, not by reverting to cycle-scoping.

## Context Notes

**Story Background:** Filed from 162-5 triage BEFORE 162-21 landed (PR #186, plus 162-25's PR #187 — branch from current origin/develop tip).

**Key Update:** 162-21's commit d3a4bdaad already moved `_check_subagent_dispatch` and `_check_subagent_completion` to a shared `select_last_section` helper (exact-heading, last-match, near-miss ambiguity guard, fence masking). Reviewer reported that the two quarantined xfails in `test_143_12_subagent_dispatch.py` were genuinely retired (suite xfail count dropped 7→5).

**Critical Finding:** 162-28's premise may be partly or fully overtaken by 162-21's landing. The story's prescribed fix direction ("scope by rework cycle, not last-match") CONFLICTS with the last-match-plus-ambiguity-guard design 162-21 shipped.

**TEA Red Phase Task:** Run the pinned xfail(s) in `test_143_12` and determine what residue of the defect remains. Any remaining gap should be closed within 162-21's design (last-match + ambiguity guard), not by reverting it.

## Tea Assessment

**Verdict:** RED

**Tests Required:** Yes

162-21 closed two thirds of B1. It did NOT close the third. `_check_subagent_dispatch` and `_check_subagent_completion` now go through `gate_recovery.select_last_section` (exact heading, last match, near-miss ambiguity guard, fence masking) and the two pinned xfails are genuinely retired. `_check_rework_freshness` — the approval subcheck whose entire job is detecting staleness on rework sessions — was left on a bare `re.search` for `^## Subagent Results` (FIRST match) with a `^## (?!Subagent Results)` truncation lookahead that deliberately skips same-named headings and therefore concatenates consecutive cycles. That is the original 162-5 reader, verbatim, in the one function the story's fail-open scenario runs through. Plus B4 (an explicit AC): the guard gates on `**Rework Cycle:** N`, which nothing in the framework writes outside test fixtures, while `complete_phase` writes `**Round-Trip Count:** N` — so `_parse_rework_cycle` returns 0 on every real session and the whole guard short-circuits to "initial review".

**Test File:**
- `pennyfarthing-dist/src/pf/tests/test_143_12_subagent_dispatch.py` — 8 new failing tests, 1 new passing compat pin, 1 xfail un-quarantined

**Tests Written:** 9 (8 RED, 1 green compat pin) covering the story title's defect plus the B4 AC
**Status:** RED

**Counts:** file 8 failed / 10 passed / 0 xfailed. Suite 12 failed / 5981 passed / 4 skipped / 4 xfailed. Baseline on the same tip: 4 failed / 5980 passed / 4 skipped / 5 xfailed. Delta = +8 RED, +1 pass, xfail 5→4. The 4 `test_frame_routes.py` failures are pre-existing and unrelated.

Every one of the 8 fails in the fail-open direction — `pass: True` or `status: "success"` where the gate must block. None fails on a missing import or a fixture error.

| Test | Current behaviour |
|------|-------------------|
| `test_freshness_reads_the_last_results_section_not_the_first` | fresh cycle-2 table above a stale cycle-1 one → `pass: True` |
| `test_consecutive_results_sections_are_not_merged` | lookahead concatenates; cycle 1's tag answers for an untagged current section → `pass: True` |
| `test_suffixed_results_heading_after_last_exact_blocks` | `## Subagent Results (Cycle 4)` read straight past → `pass: True` |
| `test_illustrative_cycle_tag_does_not_satisfy_the_guard` | fenced `**Cycle: 2**` vouches for an untagged table → `pass: True` |
| `test_illustrative_rework_counter_is_not_read` | fenced `**Rework Cycle:** 7` fabricates cycle 7 |
| `test_freshness_guard_sees_the_counter_complete_phase_writes` | `**Round-Trip Count:** 2` → `current_cycle: 0` |
| `test_stale_last_cycle_table_is_approved` | `complete_phase(gate_type="approval")` → `status: "success"` |
| `test_stale_results_on_a_real_round_trip_session_is_approved` | same, on a real round-trip session → `status: "success"` |

**Design constraint for Dev:** close this inside 162-21's design. `_check_rework_freshness` should read its section via `select_last_section("Subagent Results")` and surface `ambiguous` as a block; `_parse_rework_cycle` should mask illustrative regions and read the counter that is actually written **while keeping `Rework Cycle` working** — `test_150_8_rework_pipeline.py`'s fixtures use it, and `test_rework_cycle_field_is_still_honoured` pins it. Do NOT introduce the cycle-scoping the original story text prescribed; that reverts 162-21.

**Handoff:** To Dev for GREEN.

## Delivery Findings

No upstream findings at setup.

<!-- Agents: append findings below this line. Do not edit other agents' entries. -->

### TEA (test design)
- **Gap** (non-blocking): 162-21 moved two of three approval subchecks onto `select_last_section` but left `_check_rework_freshness` (and `_parse_rework_cycle`) on the old bare-`re.search` reader — the fix was applied per-callsite instead of swept across every section reader in the approval path. Affects `pennyfarthing-dist/src/pf/handoff/complete_phase.py:583,595,600,556` (route all four through the shared helper). *Found by TEA during test design.*
- **Gap** (non-blocking): once B4 is fixed the freshness guard becomes live for the first time, which makes `**Cycle: N**` in `## Subagent Results` a hard requirement on every rework session. Nothing instructs the Reviewer to write it and no gate file documents it, so live-fixing B4 alone could hard-block real rework approvals. Affects `pennyfarthing-dist/agents/reviewer.md` and the reviewer gate files (document the cycle tag alongside the results table). *Found by TEA during test design.*
- **Improvement** (non-blocking): `complete_phase` writes the round-trip counter with a bare `re.search` + un-counted `re.sub` (`complete_phase.py:199-206`), so a counter quoted in a code fence can be found and every occurrence gets rewritten. Same illustrative-region blind spot as the readers, on the writer side. Affects `pennyfarthing-dist/src/pf/handoff/complete_phase.py:197-214`. *Found by TEA during test design.*
- **Question** (non-blocking): 4 tests in `pennyfarthing-dist/src/pf/tests/test_frame_routes.py` (`TestPersonaRoute` ×3, `TestBackwardCompatibility::test_error_responses_have_error_field`) fail on the current develop tip, unrelated to this story. Affects `pennyfarthing-dist/src/pf/frame/` — needs its own story. *Found by TEA during test design.*

### Dev (implementation)
- **Improvement** (non-blocking): the round-trip counter WRITER is still on a bare `re.search` + un-counted `re.sub` (`complete_phase.py:197-214`), so a counter quoted in a code fence can be found and every occurrence rewritten — TEA's third finding, left untouched here because no test covers it and it is the writer half of a reader story. Affects `pennyfarthing-dist/src/pf/handoff/complete_phase.py:197-214` (mask before searching, pass `count=1` to the sub). *Found by Dev during implementation.*
- **Gap** (non-blocking): the freshness guard is now live, so any in-flight session that already recorded a `**Round-Trip Count:**` and an untagged `## Subagent Results` table will hard-block on its next approval until the Reviewer appends a tagged section. Doc-level guidance now exists (`agents/reviewer.md`, `gates/approval.md`) and the error message names the exact tag, but no migration or one-time amnesty was added. Affects live `.session/*.md` files mid-rework. *Found by Dev during implementation.*
- **Improvement** (non-blocking): `mask_illustrative_regions`' docstring claims it blanks "fenced and indented code regions" but the implementation only handles fences (`gate_recovery.py:195-229`), so an indented (4-space) example verdict or cycle tag is still read as operative. Affects `pennyfarthing-dist/src/pf/handoff/gate_recovery.py:195-229` (either mask indented blocks or correct the docstring). *Found by Dev during implementation.*

### Reviewer (code review)
- **Gap** (blocking): `mask_illustrative_regions` masks fenced blocks ONLY, so three other illustrative forms are read as operative — 4-space-indented blocks, inline backtick spans, and HTML comments. Dev's finding #3 filed the indented half as a docstring nit; it is not, because the freshness guard's central anti-forgery claim now rests on this primitive. Affects `pennyfarthing-dist/src/pf/handoff/gate_recovery.py:195-229` (mask indented blocks, inline code spans and HTML comment spans; the same hardening also protects 162-21's verdict and dispatch readers). *Found by Reviewer during code review.*
- **Gap** (blocking): `select_last_section` terminates its slice at `^##[ \t]+` only, so any `###`/`####` subsection appended after the last exact heading bleeds into the section body. Affects `pennyfarthing-dist/src/pf/handoff/gate_recovery.py:284` (terminate on `^#{1,6}[ \t]+`). Shared with 162-21's readers. *Found by Reviewer during code review.*
- **Gap** (non-blocking): `gate_recovery.parse_round_trip_count:381` is a second, divergent reader of the same counter, and its docstring still claims "Same pattern complete_phase writes with, so the two agree" — no longer true now that `_parse_rework_cycle` masks, reads two fields, and takes `max()`. TEA's finding #1 asked for a sweep across every reader; the sweep covered the section reader but forked the counter reader. Affects `pennyfarthing-dist/src/pf/handoff/gate_recovery.py:381-387` and `complete_phase.py:550` (one shared counter reader, or an accurate docstring). *Found by Reviewer during code review.*
- **Question** (non-blocking): the "4 pre-existing `test_frame_routes.py` failures" cited as baseline by TEA, Dev and the sprint lead do NOT reproduce — full suite on this branch is 5993 passed / 0 failed / 4 skipped / 4 xfailed, and the file passes 70/70 in isolation. `pytest-randomly` is not installed, so ordering is deterministic; the failures appear to be environment-dependent (likely a live Frame server or config state during the earlier runs). Affects story 162-49's premise — it may be chasing an environmental flake rather than a code defect. *Found by Reviewer during code review.*
- **Improvement** (non-blocking): the freshness guard treats a missing `**Round-Trip Count:**` line as cycle 0 and short-circuits to pass, so deleting the counter disarms the check entirely. This is a self-attesting control — the agent being gated writes the file it is gated on. Architectural, pre-existing, and out of this story's scope. Affects `pennyfarthing-dist/src/pf/handoff/complete_phase.py:592` (consider a sidecar counter agents cannot edit, or treat a missing counter on a post-rework phase as fail-closed). *Found by Reviewer during code review.*

### Dev (rework cycle 1)
- **Gap** (non-blocking): the counter WRITER steered the reader into a fail-open on this story's own session. `complete_phase`'s increment located `**Round-Trip Count:**` with an unmasked `re.search` and rewrote it with an un-counted `re.sub`, so on the review->green rework transition the FIRST match was a counter quoted in TEA's backticked prose: the quotation was incremented (2 -> 3), every other quoted mention was rewritten to match, and no operative counter line was ever recorded — the freshness guard then read cycle 0 and disarmed itself. Fixed in this cycle (masked search, single-occurrence rewrite) and the session's counter and corrupted prose were restored by hand. Affects any session already damaged this way: the counter must be re-added manually. *Found by Dev during rework.*
- **Question** (non-blocking): the 4 `test_frame_routes.py` failures fail on the untouched develop tip in this environment (verified by stashing the branch) and pass in the Reviewer's, so they are environment-dependent rather than pre-existing-everywhere. Whatever 162-49 fixes should also record what differs between the two environments. Affects `pennyfarthing-dist/src/pf/frame/`. *Found by Dev during rework.*

### Reviewer (re-review, cycle 1)
- **Gap** (blocking): the cycle-0 short-circuit cannot distinguish "never reworked" from "counter unreadable", so HIDING the counter disarms the guard exactly as deleting it does. Wrapping the operative counter line in an HTML comment, a fence, or backticks makes the reader return 0 and the guard answer "No rework cycle — initial review" on a stale table. The HTML-comment form is invisible in rendered Markdown, so it is strictly worse than deletion. I scoped counter-deletion out in cycle 1 as architectural; that ruling was wrong, because masking is in-scope machinery this commit extends and it reaches the same bypass. Affects `pennyfarthing-dist/src/pf/handoff/gate_recovery.py:496-515` and `complete_phase.py:616-623` (make the counter reader tri-state — absent vs present-but-masked — and block on unreadable, the same rule the unterminated-fence case already follows). *Found by Reviewer during re-review.*
- **Gap** (blocking): widening the shared masker made `_check_subagent_dispatch` blank tags that are plainly present, hard-blocking legitimate approvals in two shapes — tags written inside backticks, which is the form `agents/reviewer.md:253` and `:473` and `gates/approval.md:219-226` all model, and tags on a 4-space-indented line after a blank line under a `###` subsection, which the `list_context` guard does not cover because a heading is neither a list nor a table. Affects `pennyfarthing-dist/src/pf/handoff/gate_recovery.py:304-316` and the dispatch-tag search (search dispatch tags on unmasked content, or treat headings as opening a non-code context, or stop rendering the tags in backticks in the docs). *Found by Reviewer during re-review.*
- **Improvement** (non-blocking): `**Round-Trip Count:** 1 (was 0)` and other annotated forms fail the end-anchored counter pattern and read 0, disarming the guard. Hand-annotation is a live practice in this workflow — this session's own counter was restored by hand this cycle. Affects `pennyfarthing-dist/src/pf/handoff/gate_recovery.py:493` (tolerate a trailing comment, or block on a counter line that is present but unparseable). *Found by Reviewer during re-review.*
- **Improvement** (non-blocking): `gates/approval.md:143` says the results section "ends at the next heading of any level", which is not what the code does — `select_last_section` ends it at the next `##` and the `###` exclusion comes from the separate `section_preamble()` call. The behavioural guidance is right but the mechanism described is wrong, which will mislead the next person changing it. Affects `pennyfarthing-dist/gates/approval.md:143`. *Found by Reviewer during re-review.*
- **Improvement** (non-blocking): two error messages overstate their constraints — the stale-tag message says "leave exactly one" tag when the code accepts any number so long as all match, and the no-tag message says "under a later `###` subsection" when the blocking subsection may be the section's first line. Affects `pennyfarthing-dist/src/pf/handoff/complete_phase.py:668-690`. *Found by Reviewer during re-review.*

### Dev (rework cycle 2)
- **Improvement** (non-blocking): `mask_quoted_blocks` vs `mask_illustrative_regions` is now a policy choice each caller makes, and nothing stops a future reader from picking the wrong one — the fail-open and fail-closed directions are only documented in docstrings. Affects `pennyfarthing-dist/src/pf/handoff/gate_recovery.py` (consider naming them by intent, e.g. `masker_for_presence_search` / `masker_for_operative_statement`, or wrapping the two search kinds in named helpers so the choice cannot be made by accident). *Found by Dev during rework.*
- **Improvement** (non-blocking): deleting the `**Round-Trip Count:**` line still disarms the freshness guard (cycle 0 = initial review). Hiding it now blocks, so deletion is the last remaining shape of the self-attestation problem, and it is the one a counter in the session file cannot solve. Affects `pennyfarthing-dist/src/pf/handoff/complete_phase.py` (the counter needs a store the reviewed agent does not write — sidecar, or derive the count from Phase History rows, which are appended by the workflow). *Found by Dev during rework, carried from the Reviewer's cycle-1 finding.*

### Reviewer (re-review, cycle 2)
- **Gap** (non-blocking, follow-up): the counter reader still cannot distinguish "no counter" from "text I do not recognise as a counter", and that residue is wider than counter DELETION alone. All of these read `absent` and pass: the line deleted; a near-miss label (`**Round-Trip Count**: 3`, `**Round-Trip Count** 3`, `*Round-Trip Count:* 3`, unbolded); a lowercase label (`**round-trip count:** 3`); and the field name broken across a newline (`**Round-Trip` / `Count:** 3`). The HTML comment is incidental to that last one — the same input with no comment also reads `absent` — so it is not a defect in the raw-vs-masked comparison, it is the recognition gap. Every one of these behaved identically before this cycle, so nothing regressed, and no regex widening can close the set because the space of "text a human meant as a counter" is unbounded. The fix is the one already proposed: derive the count from something the gated agent does not author — the mechanically written Phase History rows, or a sidecar. Affects `pennyfarthing-dist/src/pf/handoff/gate_recovery.py:537-593`. *Found by Reviewer during re-review.*
- **Improvement** (non-blocking): the counter WRITER collapses `absent` and `unreadable` where the reader now separates them. It runs its own masked `finditer` instead of calling `read_round_trip_count`, so on a hidden counter it takes the insert branch and writes a fresh count of 1 — silently resetting a session that was at 2. The approval path blocks on `unreadable` so no stale approval follows, but `get_rework_recovery`'s `max_attempts` ceiling is computed from the reset value, so the round-trip budget can be under-counted. Pre-existing behaviour, now inconsistent with the tri-state reader — the same reader/writer divergence class this story has been closing. Affects `pennyfarthing-dist/src/pf/handoff/complete_phase.py:208-228` (call `read_round_trip_count` and error on `unreadable`). *Found by Reviewer during re-review.*
- **Gap** (non-blocking): two behaviours are correct but unpinned, so they can be regressed silently. Nothing covers "real counter unreadable AND a readable legacy `**Rework Cycle:**` present" — the exact condition the `status != "absent"` short-circuit exists for — and no end-to-end test blocks a FENCED cycle tag through `_check_rework_freshness`, so removing fence masking from the aggressive masker would fail no test in that file. I verified both behave correctly today. Affects `pennyfarthing-dist/src/pf/tests/test_162_28_freshness_tag_predicate.py:76,412`. *Found by Reviewer during re-review.*
- **Improvement** (non-blocking): `guides/handoff-cli.md:67` is stale after the masker split — it says fenced text "is masked before both scans", which now describes neither policy accurately: HTML comments are masked by both and go unmentioned, the aggressive policy also masks indented blocks and inline spans, and "both scans" asserts a single shared policy where the whole point of this cycle was two policies with opposite failure directions. Separately, neither `agents/reviewer.md` nor `gates/approval.md` warns that a hidden or unparseable counter line blocks the approval — the error message is precise when it fires, but there is no forewarning. Affects `pennyfarthing-dist/guides/handoff-cli.md:67`, `agents/reviewer.md:208-226`, `gates/approval.md:137-147`. *Found by Reviewer during re-review.*
- **Improvement** (non-blocking): five pre-existing doc inaccuracies survive in the files this story touches — `gates/approval.md:123,160,192` say "8 subagents" where the code requires 9, `agents/reviewer.md:271` says "All 8 rows", and `gates/approval.md:260`'s recovery message lists 7 dispatch tags, omitting `[RULE]`. None introduced here; all cheap to sweep. Affects `pennyfarthing-dist/gates/approval.md` and `agents/reviewer.md`. *Found by Reviewer during re-review.*

## Impact Summary

**Upstream Effects:** 9 findings (2 Gap, 0 Conflict, 0 Question, 7 Improvement)
**Blocking:** 1 BLOCKING items — see below

**BLOCKING:**
- **Gap:** `mask_illustrative_regions` masks fenced blocks ONLY, so three other illustrative forms are read as operative — 4-space-indented blocks, inline backtick spans, and HTML comments. Dev's finding #3 filed the indented half as a docstring nit; it is not, because the freshness guard's central anti-forgery claim now rests on this primitive. Affects `pennyfarthing-dist/src/pf/handoff/gate_recovery.py:195-229`.

- **Gap:** 162-21 moved two of three approval subchecks onto `select_last_section` but left `_check_rework_freshness` (and `_parse_rework_cycle`) on the old bare-`re.search` reader — the fix was applied per-callsite instead of swept across every section reader in the approval path. Affects `pennyfarthing-dist/src/pf/handoff/complete_phase.py:583,595,600,556`.
- **Improvement:** the round-trip counter WRITER is still on a bare `re.search` + un-counted `re.sub` (`complete_phase.py:197-214`), so a counter quoted in a code fence can be found and every occurrence rewritten — TEA's third finding, left untouched here because no test covers it and it is the writer half of a reader story. Affects `pennyfarthing-dist/src/pf/handoff/complete_phase.py:197-214`.
- **Improvement:** `mask_illustrative_regions`' docstring claims it blanks "fenced and indented code regions" but the implementation only handles fences (`gate_recovery.py:195-229`), so an indented (4-space) example verdict or cycle tag is still read as operative. Affects `pennyfarthing-dist/src/pf/handoff/gate_recovery.py:195-229`.
- **Improvement:** the freshness guard treats a missing `**Round-Trip Count:**` line as cycle 0 and short-circuits to pass, so deleting the counter disarms the check entirely. This is a self-attesting control — the agent being gated writes the file it is gated on. Architectural, pre-existing, and out of this story's scope. Affects `pennyfarthing-dist/src/pf/handoff/complete_phase.py:592`.
- **Improvement:** `**Round-Trip Count:** 1 (was 0)` and other annotated forms fail the end-anchored counter pattern and read 0, disarming the guard. Hand-annotation is a live practice in this workflow — this session's own counter was restored by hand this cycle. Affects `pennyfarthing-dist/src/pf/handoff/gate_recovery.py:493`.
- **Improvement:** `mask_quoted_blocks` vs `mask_illustrative_regions` is now a policy choice each caller makes, and nothing stops a future reader from picking the wrong one — the fail-open and fail-closed directions are only documented in docstrings. Affects `pennyfarthing-dist/src/pf/handoff/gate_recovery.py`.
- **Improvement:** deleting the `**Round-Trip Count:**` line still disarms the freshness guard (cycle 0 = initial review). Hiding it now blocks, so deletion is the last remaining shape of the self-attestation problem, and it is the one a counter in the session file cannot solve. Affects `pennyfarthing-dist/src/pf/handoff/complete_phase.py`.
- **Improvement:** the counter WRITER collapses `absent` and `unreadable` where the reader now separates them. It runs its own masked `finditer` instead of calling `read_round_trip_count`, so on a hidden counter it takes the insert branch and writes a fresh count of 1 — silently resetting a session that was at 2. The approval path blocks on `unreadable` so no stale approval follows, but `get_rework_recovery`'s `max_attempts` ceiling is computed from the reset value, so the round-trip budget can be under-counted. Pre-existing behaviour, now inconsistent with the tri-state reader — the same reader/writer divergence class this story has been closing. Affects `pennyfarthing-dist/src/pf/handoff/complete_phase.py:208-228`.

### Downstream Effects

- **`pennyfarthing-dist/src/pf/handoff`** — 9 findings

## Design Deviations

No deviations recorded at setup.

<!-- Agents: append deviations below this line. Do not edit other agents' entries. -->

### TEA (test design)
- **Selection rule:** Story title said "Fix must scope by rework cycle, not last-match". Tests instead pin last-exact-match + near-miss ambiguity guard + fence masking. Reason: the story was filed before 162-21 landed; cycle-scoping would revert d3a4bdaad's shared `select_last_section` and re-open the ambiguity direction three review cycles established cannot be guessed at.
- **Scope:** Story framed B1 as covering `_check_subagent_dispatch`/`_check_subagent_completion`; those are closed. Tests target `_check_rework_freshness` and `_parse_rework_cycle` instead — the same defect, in the subchecks 162-21 did not touch, plus the B4 AC.

### Dev (implementation)
- **Activation half done in-story:** TEA flagged that fixing B4 makes the freshness guard live for the first time. Implemented the ecosystem half: `agents/reviewer.md` gains a BLOCKING "Rework re-reviews: tag the cycle" subsection (append a NEW *exact* `## Subagent Results` heading — no suffix — and tag the body `**Cycle: N**` where N is the session's `**Round-Trip Count:**`), and `gates/approval.md`'s subagent-completion gate documents the same requirement as pass criterion 5. Reason: doc-only was insufficient on its own but doc + clearer error text is — the no-tag message also had a real bug (`'**Cycle: {cycle}**'` in a non-f-string printed `{cycle}` literally), so the guard was going to name the wrong tag to the agent it blocks.
- **Existing fixture updated:** `test_143_10_reviewer_dev_roundtrip.py::test_full_rework_then_approval` began failing once the guard woke up — it drives a real rework round trip (`**Round-Trip Count:** 1`) and then approves with an untagged results table. Added `**Cycle: 1**` to that fixture rather than weakening the guard. Reason: this is the activation risk landing in the suite, and the fixture now matches the contract reviewer.md documents. No assertion was changed.
- **Both counter fields honoured, highest wins:** `_parse_rework_cycle` reads `Round-Trip Count` and `Rework Cycle` and takes `max()` when several values appear. Reason: the compat pin requires the legacy field keep working, and preferring the higher cycle is the fail-safe direction (a higher current cycle can only make results *more* stale).

### Reviewer (audit)
- **TEA — selection rule (last-exact + ambiguity instead of cycle-scoping): ACCEPTED.** Cycle-scoping would have reverted d3a4bdaad and re-opened the ambiguity direction. Deviating from the story text was the correct call; the story predated 162-21.
- **TEA — scope shifted to `_check_rework_freshness`/`_parse_rework_cycle`: ACCEPTED.** Verified the two subchecks the story named are genuinely on the shared reader already; the residue was where TEA said it was.
- **Dev — activation half done in-story (reviewer.md + approval.md): ACCEPTED.** Arming a never-live guard without documenting its new requirement would have been the worse outcome, and the literal-`{cycle}` non-f-string bug was a real defect that would have named the wrong tag to the agent it blocks.
- **Dev — existing fixture updated with `**Cycle: 1**`: ACCEPTED.** Independently verified this is an activation fix, not a weakened assertion. Pre-fix the guard was unreachable, so the untagged fixture asserted nothing about freshness; the terminal `assert r["status"] == "success"` now has to pass through a live guard, making the test strictly stronger. No assertion was altered, and the fail-open direction stays pinned separately.
- **Dev — both counter fields honoured, highest wins: FLAGGED.** The direction is fail-safe for staleness as claimed, and I am not asking for it to be reverted. But it forks a second reader of a counter that `gate_recovery.parse_round_trip_count` already reads, and `agents/reviewer.md` documents N as the `Round-Trip Count` alone — so in the one shape the legacy field exists for (150-8's hand-written fixtures), a doc-compliant tag is rejected by the code. See findings 5 and 6.
- **Dev — blast-radius claim asserted without measurement: FLAGGED (non-blocking).** Delivery Finding #2 judges the no-migration risk acceptable without counting affected sessions. I counted: exactly one live session file exists in this workspace and it parses to cycle 0, so the real blast radius is zero. The conclusion was right; the method was assertion, not evidence.

## Dev Assessment

**Verdict:** GREEN

`_check_rework_freshness` and `_parse_rework_cycle` are now on the shared readers 162-21 introduced, and B4's dead field is fixed — which woke the guard up, so the ecosystem half (reviewer.md + approval.md + one existing rework fixture) landed with it.

**Implementation Complete:** Yes

**Files Changed:**
- `pennyfarthing-dist/src/pf/handoff/complete_phase.py` — `_check_rework_freshness` selects its section via `gate_recovery.select_last_section("Subagent Results")` (exact heading, LAST match, fence-masked) and returns a block on `ambiguous` naming the heading to repeat; `_parse_rework_cycle` masks illustrative regions and reads `**Round-Trip Count:** N` (the counter actually written) while still honouring the legacy `**Rework Cycle:** N`, highest value winning; the no-cycle-tag message no longer prints `{cycle}` literally and states that a fenced tag does not count.
- `pennyfarthing-dist/agents/reviewer.md` — new BLOCKING "Rework re-reviews: tag the cycle" subsection in `<subagent-completion-gate>`: append a NEW *exact* `## Subagent Results` heading (suffixed headings block as ambiguous) and tag its body `**Cycle: N**` from the session's `**Round-Trip Count:**`, after re-running all enabled subagents.
- `pennyfarthing-dist/gates/approval.md` — subagent-completion gate pass criteria gain #5, the cycle tag + last-exact-heading rule, so the gate doc and the code agree.
- `pennyfarthing-dist/src/pf/tests/test_143_10_reviewer_dev_roundtrip.py` — `**Cycle: 1**` added to the rework fixture in `test_full_rework_then_approval` (fixture only; no assertion changed) — the activation risk landing in the suite.

**Tests:** 18/18 in `test_143_12_subagent_dispatch.py` (8 RED closed, 10 existing green incl. the `Rework Cycle` compat pin). `test_150_8_rework_pipeline.py` and `test_162_21_resolve_gate_rejected_verdict.py` fully green, no regressions.

**Suite:** 4 failed / 5989 passed / 4 skipped / 4 xfailed. Baseline: 4 failed / 5980 passed / 4 skipped / 5 xfailed. Delta = +9 passing (8 RED + 1 pin), xfail 5→4 (B4's xfail un-quarantined by TEA). The 4 failures are the pre-existing `test_frame_routes.py` ones tracked as 162-49 — unchanged, same 4.

**Lint:** ruff clean on all changed Python files. `pf validate agent` passes (38 passed, 2 pre-existing warnings on other agents).

**Branch:** `feat/162-28-phase-approval-gate-fails-open` — commit `30958f80c`, GPG-signed (verified), pushed.

**Handoff:** To Reviewer.

## Subagent Results

Initial review (no rework recorded, round-trip count 0), so no cycle tag applies. Four specialists are disabled in `config.local.yaml` (`edge_hunter`, `silent_failure_hunter`, `comment_analyzer`, `simplifier`); all five enabled specialists were dispatched up front, in parallel, before any of my own analysis, and all five returned.

| # | Specialist | Received | Status | Findings | Decision |
|---|-----------|----------|--------|----------|----------|
| 1 | reviewer-preflight | Yes | unreliable | suite + lint + signing data; self-contradictory on suite numbers | confirmed 0, dismissed 1, deferred 0 — re-ran the suite myself; see [TEST] note |
| 2 | reviewer-test-analyzer | Yes | clean | 5 (revert experiment + fixture judgment + 5 coverage gaps) | confirmed 5, dismissed 0, deferred 0 |
| 3 | reviewer-type-design | Yes | clean | 5 (unanchored tag regex, negative/underscore parse, max() conflation, first-match, stringly-typed status) | confirmed 4, dismissed 0, deferred 1 |
| 4 | reviewer-security | Yes | clean | 5 (indented block, HTML comment, H3 bleed, counter deletion, `(\S+)` parse) | confirmed 5, dismissed 0, deferred 0 |
| 5 | reviewer-rule-checker | Yes | clean | 1 (doc/code divergence on max()) — 14 rules, 31 instances checked | confirmed 1, dismissed 0, deferred 0 |
| — | reviewer-edge-hunter | N/A | disabled in config | — | N/A |
| — | reviewer-silent-failure-hunter | N/A | disabled in config | — | N/A |
| — | reviewer-comment-analyzer | N/A | disabled in config | — | N/A |
| — | reviewer-simplifier | N/A | disabled in config | — | N/A |

**All received:** Yes

**Dismissal rationale (1).** reviewer-preflight reported "4 failed on the branch, 70 passed on develop — introduced by this commit." Dismissed as a measurement error: it reported a 0-failure full suite in the same breath, which cannot coexist with 4 deterministic failures in the same tree. I reproduced both runs — full suite 5993 passed / 0 failed, and `test_frame_routes.py` 70/70 in isolation. No regression exists, and nothing in this diff touches `pf/frame/`.

**Deferral rationale (1).** reviewer-type-design's `TypedDict`/`Literal` recommendation for `select_last_section`'s status vocabulary is sound but is a refactor of a 162-21 primitive with four callers. Deferred to its own story; the current caller does handle all three statuses.

## Reviewer Assessment

**Verdict:** REJECTED

The story's premise and TEA's diagnosis were right, the section-reader half of the fix is right, and B4 is genuinely closed — `_parse_rework_cycle` now reads the counter the framework actually writes, so the guard is reachable for the first time. But the assertion the guard now makes is not enforceable as written. I can satisfy the `**Cycle: N**` freshness tag six different ways on a session whose subagents were never re-run. A guard that was dead is now merely decorative, and the story exists to arm it.

| Severity | Issue | Location | Fix Required |
|----------|-------|----------|--------------|
| [CRITICAL] | [SEC] The cycle-tag regex `\*{0,2}Cycle:\s*(\d+)\*{0,2}` is unanchored and asterisk-optional, so any prose substring ending in `Cycle: N` satisfies it. Confirmed passing on a never-re-run table: `Re-ran for Rework Cycle: 2`, `Round-Trip Cycle: 2`, and a table cell `\| notes \| Rework Cycle: 2 \|`. The guard can be satisfied by text that is not a tag at all — and by the very field name the same function reads. | `complete_phase.py:633` | Anchor to a standalone column-0 tag, e.g. `(?m)^[ \t]*\*\*Cycle:[ \t]*(\d+)\*\*[ \t]*$`, and add the negative tests for the three strings above. |
| [HIGH] | [SEC] `mask_illustrative_regions` masks fenced regions ONLY, so three further illustrative forms forge the tag — a 4-space-indented example, an inline backtick span in prose, and an HTML comment. All three confirmed returning `pass: True` against a stale table. The docstring claims indented blocks are masked, and both `agents/reviewer.md` and the guard's own error text tell the agent only that "a tag inside a code fence does not count", so an honest reviewer writing prose about the tag inside its own section will pass a stale approval. This is the accidental case, not the adversarial one. | `gate_recovery.py:195-229`, relied on at `complete_phase.py:630-633` | Mask indented code blocks, inline code spans and HTML comment spans (or drop the indented claim from the docstring and anchor the tag per the [CRITICAL] row). Hardening here also protects 162-21's verdict and dispatch readers. |
| [HIGH] | [SEC] `select_last_section` ends its slice at `^##[ \t]+`, so a `###` subsection appended after the last exact heading bleeds into the section body — a tag under `### Reviewer Notes` vouches for the table above it. Confirmed `pass: True`. | `gate_recovery.py:284` | Terminate on `^#{1,6}[ \t]+`. |
| [MEDIUM] | [TYPE] `_REWORK_COUNTER_RE` captures `(\S+)`, so `int()` accepts values `gate_recovery.parse_round_trip_count`'s `(\d+)` rejects. `-3` parses to a negative cycle that clears the `== 0` sentinel, arms the guard, then demands a tag `(\d+)` can never match — permanently unapprovable with a misleading "no cycle tag" message. `1_000` parses to 1000 (PEP 515). Conversely `2.0` and `0x10` are silently dropped to cycle 0, which disarms the guard entirely — a fail-open on a malformed counter. | `complete_phase.py:550,574-579` | Use `(\d+)` to match the sibling parser, and skip non-positive values. |
| [MEDIUM] | [RULE] Doc/code divergence on `max()`. `reviewer.md:212` and `approval.md:137` both say N is the session's `**Round-Trip Count:**`; the code uses `max(Round-Trip Count, legacy Rework Cycle)`. Confirmed: a session with count 1 and a legacy field of 4 rejects the doc-compliant tag with "results are from cycle 1 but current rework cycle is 4". This bites precisely in the shape the legacy field exists for — 150-8's hand-written fixtures. | `agents/reviewer.md:212`, `gates/approval.md:137`, `complete_phase.py:550` | Prefer `Round-Trip Count` when present and fall back to the legacy field, or document the max-wins rule in both files. |
| [MEDIUM] | [RULE] `gate_recovery.parse_round_trip_count` is a second reader of the same counter whose docstring asserts "Same pattern complete_phase writes with, so the two agree" — now false. Two readers of one concept that provably disagree (masked vs unmasked, one field vs two, `(\d+)` vs `(\S+)`) is the exact failure class 162-21 set out to eliminate, and TEA's finding #1 asked for the sweep. | `gate_recovery.py:381-387` | One shared counter reader, or correct the stale docstring. |
| [MEDIUM] | [TEST] Coverage gaps on the new code: no test for `max()` with both fields present at differing values, for a higher stale legacy field, for a tag N greater than the current cycle, for the `ambiguous` branch end-to-end through `complete_phase(gate_type="approval")`, or for any of the six forge vectors above. `test_illustrative_cycle_tag_does_not_satisfy_the_guard` pins only the fenced form, so the suite's own stated intent — illustrative tags must not vouch — is unmet in four of five forms. | `test_143_12_subagent_dispatch.py:255,399,430` | Add the negative cases alongside the [CRITICAL]/[HIGH] fixes. |
| [LOW] | [TYPE] The tag match is case-sensitive while `select_last_section`'s heading match is `IGNORECASE`. `**cycle: 2**` and `**CYCLE: 2**` hard-block a compliant-looking session. | `complete_phase.py:633` | Add `re.IGNORECASE` for consistency with the heading rule. |

**Data flow traced.** Reviewer-authored session markdown → `complete_phase(gate_type="approval")` at `complete_phase.py:166` → `_check_rework_freshness` → `_parse_rework_cycle` (masked, both counter fields, max) → `select_last_section("Subagent Results")` (masked, last exact, ambiguity-blocking) → `cycle_tag` search → equality against the parsed cycle → `{"status": "error"}` on failure. The selection half of this chain is sound and correctly reuses 162-21's primitive; the terminal predicate is where it fails open. The input is attacker-controlled in the meaningful sense — the agent being gated writes the file it is gated on.

**Pattern observed.** Good: `_check_rework_freshness` now handles all three `select_last_section` statuses explicitly, including the `ambiguous` block with the heading named in the message (`complete_phase.py:605-624`) — that matches the sibling subchecks and the "report ambiguity, never guess" doctrine documented at `gate_recovery.py:290-296`. Bad: the terminal `cycle_tag` regex at `complete_phase.py:633` abandons that doctrine — unanchored, first-match-wins, asterisk-optional. The rigour applied to selecting the section was not applied to reading the tag inside it.

**Error handling.** `_parse_rework_cycle` swallows `ValueError` per match and continues (`complete_phase.py:576-578`), which is correct for multi-field scanning but means a malformed counter degrades to cycle 0 — silently disarming the guard rather than blocking. Null/empty input is safe: empty content yields no counter, cycle 0, "initial review". Every failure path returns a `{pass, message, current_cycle}` dict rather than raising, consistent with the surrounding gate-check convention.

**Verified good (not defects).** The 8 RED tests are genuine — reverting `complete_phase.py` to develop fails all 8 in the fail-open direction. The `test_143_10` fixture edit is a legitimate activation fix, not a weakened assertion: pre-fix the guard was unreachable so the untagged fixture asserted nothing about freshness, and the terminal success assertion now has to clear a live guard. The writer half at `complete_phase.py:197-214` stays correctly out of scope — I traced its interaction with the newly-masked reader and the divergence is fail-CLOSED (an unmasked fenced counter found first gets incremented and the un-counted `re.sub` rewrites every occurrence upward, after which the masked reader demands a higher tag), so it cannot combine into a fail-open. `max()` is directionally fail-safe for staleness as Dev argued; its problems are the unsatisfiable-instruction case and the duplicated reader, not fail-open. Both commits are GPG-signed (status G) with conventional messages, only `pennyfarthing-dist/` sources were touched, no `never_edit` or symlink zone was entered, and no sibling agent/gate/guide doc was left contradicting the new rule.

**Blast radius, weighed explicitly.** Dev's Delivery Finding #2 flags that in-flight rework sessions with untagged tables hard-block with no amnesty. I measured rather than assumed: exactly one live session file exists in this workspace, it is this story's own, and it parses to cycle 0 — so the actual blast radius is zero and the missing migration is acceptable. This is not a fail-closed-too-hard trap, and hard-blocking is the correct default for a staleness guard. The irony worth recording: the guard is currently so easy to satisfy that an in-flight session would likely be waved through by incidental prose, which is the defect, not the mitigation.

**Suite (re-verified independently, not taken from Dev).** 5993 passed / 0 failed / 4 skipped / 4 xfailed on `30958f80c`, clean tree. The "4 pre-existing failures" cited as baseline by TEA, Dev and the lead do not reproduce: `test_frame_routes.py` passes 70/70 both in isolation and in the full suite, `pytest-randomly` is not installed so ordering is deterministic, and the totals reconcile (5989 + 4 = 5993). Those failures are environment-dependent, which is a live question for story 162-49. Targeted files: `test_143_12` 34 passed, `test_143_10` 54 passed, `test_150_8` 27 passed, `test_162_21` 86 passed. Ruff: 2 pre-existing E501s, both present on develop, neither in this diff. `pf validate agent`: 38 passed, 2 pre-existing warnings.

**Observations:** 8 findings (1 critical, 2 high, 4 medium, 1 low), 5 verified-good notes, 5 upstream Delivery Findings, 6 deviations audited (4 accepted, 2 flagged).

**Handoff:** Back to Dev. The section-reader work and the B4 fix are sound and should be kept — the required changes are the tag predicate at `complete_phase.py:633`, the masking and slice-termination gaps in `gate_recovery.py`, and the counter regex, plus negative tests for the six forge vectors.

### Dev (rework cycle 1)
- **Subsection scope, not slice termination:** the reviewer's HIGH finding asked for `select_last_section` to terminate on `^#{1,6}[ \t]+`. Implemented it, and `test_150_13_reviewer_template` immediately went red — the reviewer template files its specialist tags under `### Specialist Findings`, so ending the slice at `###` hides the content `_check_subagent_dispatch` looks for and fails CLOSED on every review. Kept the slice at `^##`, added `gate_recovery.section_preamble()`, and scoped only the freshness tag to the preamble. Both halves of the trade-off are pinned, including the template regression at its source.
- **Indented-code masking is conditional:** masks a 4-space/tab-indented run only when it OPENS after a blank line outside a list or table context. Reason: unconditional masking would blank indented sub-bullets, and the dispatch check searches free-form prose for `[SEC]`-style tags — fail-closed in exchange for fail-open is not a fix.
- **Counter value must be the whole line:** `(\d+)` alone still read `2.0` as 2 and `1_000` as 1, so the pattern is anchored to end-of-line. A malformed counter therefore reads 0 (guard disarmed) rather than a plausible-but-wrong cycle; that residual disarm is the architectural self-attestation finding already filed, not something this predicate can fix.
- **Real field wins, `max()` dropped:** `_parse_rework_cycle` now prefers `**Round-Trip Count:**` and falls back to the legacy `**Rework Cycle:**` only when the real field is absent, per the reviewer's first option. Reason: it makes the documented instruction always satisfiable, which `max()` did not.
- **Writer fixed despite being scoped out:** the reviewer traced the writer as fail-CLOSED and left it out of scope. It reproduced as a fail-OPEN on this very session (see Delivery Findings), so it is fixed here with two pinning tests. Logged rather than silently expanded.
- **Vector 6 not pinned:** deleting the counter still disarms the guard (cycle 0 short-circuit). Left as the Reviewer filed it — architectural, needs a store agents cannot edit — and it stays in Delivery Findings.

## Dev Assessment (rework cycle 1)

**Verdict:** GREEN

All eight review findings are addressed, the six forge vectors are pinned as tests that were RED before the fix, and one finding was implemented as specified, proven wrong by the suite, and re-implemented a narrower way.

**Implementation Complete:** Yes

**Files Changed:**
- `pennyfarthing-dist/src/pf/handoff/complete_phase.py` — anchored `_CYCLE_TAG_RE` (standalone column-0 `**Cycle: N**`, IGNORECASE); every tag in the section must match the current cycle; tag search scoped to `section_preamble`; `_parse_rework_cycle` delegates to the shared counter reader with the legacy field as fallback; the rework counter WRITER masks before searching and rewrites only the operative occurrence.
- `pennyfarthing-dist/src/pf/handoff/gate_recovery.py` — `mask_illustrative_regions` also masks HTML comments (multi-line; unterminated masks the rest), conditional indented code blocks, and inline backtick spans, with a docstring that no longer overclaims; new `section_preamble()`; `parse_round_trip_count` is the single counter reader (masked, digits-only, whole-line value) and its "the two agree" claim is true again.
- `pennyfarthing-dist/agents/reviewer.md` — the tag rule states the column-0 line form, that quoted/prose/table-cell/subsection tags do not count, the legacy fallback, and that a leftover old tag blocks.
- `pennyfarthing-dist/gates/approval.md` — pass criterion 5 restated to match the code exactly.
- `pennyfarthing-dist/src/pf/tests/test_162_28_freshness_tag_predicate.py` — new, 33 tests.

**Tests:** 33 new (18 RED when written, including all six forge vectors, the `###` vector, the counter-value cases, the two-reader agreement check, and the two writer cases). Targeted suites all green: `test_162_28` 33, `test_143_12` 34, `test_143_10` 54, `test_150_8` 27, `test_162_21` 86, `test_150_13` 26.

**Suite:** 4 failed / 6022 passed / 4 skipped / 4 xfailed. The 4 are `test_frame_routes.py`; I verified they also fail with this branch stashed on the untouched develop tip in this environment, while the Reviewer measured 0 failures — environment-dependent, tracked as 162-49. Reported both readings rather than picking one.

**Lint:** ruff clean on `pennyfarthing-dist/src/pf/handoff/` and the new test file. `pf validate agent`: 38 passed, 2 pre-existing warnings on other agents.

**Live check:** on the real session file the new masking still reads the Reviewer's operative `REJECTED` verdict and the completion table, so the hardening did not fail closed on a genuine document.

**Branch:** `feat/162-28-phase-approval-gate-fails-open` — commit `13f26043c`, GPG-signed (verified), pushed.

**Handoff:** To Reviewer for cycle 2.

### Reviewer (audit, cycle 1)
- **Dev — subsection scope instead of slice termination: ACCEPTED, and my prescription was wrong.** I asked for `select_last_section` to end at a heading of any level. Dev implemented it, `test_150_13_reviewer_template` went red because the template files its specialist tags under a `### Specialist Findings` subsection, and he reverted to `^##` plus a narrowly-scoped `section_preamble()`. I verified the narrowing independently: a tag under any `###`-or-deeper subsection is excluded, a tag in the preamble passes, and the degenerate shape where a section opens directly with `###` yields an empty preamble and blocks. That is the correct resolution and it is better than what I asked for. Evidence-backed divergence from a reviewer instruction is exactly what I want to see.
- **Dev — indented masking made conditional on a blank line outside list/table context: ACCEPTED in intent, INCOMPLETE in coverage.** The reasoning is right — unconditional masking would blank dispatch tags and trade fail-open for fail-closed. But the guard only covers lists and tables, not headings, so an indented tag under a `###` subsection is still masked, and the same fail-closed risk in inline backticks was not guarded at all. See the blocking findings.
- **Dev — counter value anchored to end-of-line: ACCEPTED with a caveat.** Rejecting `2.0` and `1_000` is right. Dev correctly noted the residual disarm and attributed it to my architectural filing; the caveat is that annotated forms now also read 0, which matters because hand-editing the counter is a live practice.
- **Dev — real field wins, max() dropped: ACCEPTED.** Verified there is now exactly one counter-parsing implementation, that the freshness reader and the max-attempts reader agree, and that the previously stale "so the two agree" docstring is now true. My cycle-1 findings on both the divergence and the doc mismatch are fully closed.
- **Dev — writer fixed despite being scoped out: ACCEPTED, and my cycle-1 analysis was wrong.** I traced the writer as fail-closed and left it out of scope. It was fail-OPEN, and it had already fired on this very session. I confirmed Dev's account against my own cycle-1 transcript: TEA's prose counter read 2 in my first read of this file, read 3 immediately after my `complete-phase` call, and reads 2 again now. Expanding scope here was correct, and it was logged rather than done quietly.
- **Dev — vector 6 (counter deletion) not pinned, citing my filing: ACCEPTED AS REASONABLE, BUT MY SCOPING WAS WRONG.** Dev deferred exactly as I instructed, and twice flagged the residual disarm rather than burying it. The defect is nonetheless live and now reachable by masking rather than deletion, so it blocks — as my error to correct, not his to answer for.
- **Dev — session file hand-edited to restore the counter: ACCEPTED, integrity verified.** A Dev editing the file that gates his own work is precisely the self-attestation risk I filed, so I audited every number. The restored counter is the honest value (one rework transition occurred), TEA's prose is back to its original reading per my transcript, no residual corrupted value remains, and the edit ARMS the guard against Dev's own approval rather than relaxing it. Correct value, correct direction, disclosed in Delivery Findings.

## Subagent Results

**Cycle: 1**

Re-review after rework. All five enabled specialists were re-dispatched up front against the full diff for this cycle, in parallel, before my own analysis; all five returned. Four specialists remain disabled in `config.local.yaml`.

| # | Specialist | Received | Status | Findings | Decision |
|---|-----------|----------|--------|----------|----------|
| 1 | reviewer-preflight | Yes | clean | suite 6026 passed / 0 failed, 33 new tests, ruff clean, GPG good, 34 call sites mapped | confirmed 0, dismissed 0, deferred 0 — internally consistent this cycle, and I reproduced the suite independently |
| 2 | reviewer-test-analyzer | Yes | clean | 5 (revert oracle 19 failed on old code, 2 tests green pre-fix, writer-test gaps, untested masking branches, one weak invariant assertion) | confirmed 5, dismissed 0, deferred 0 |
| 3 | reviewer-type-design | Yes | clean | 5 (annotated counter reads 0, stale-tag message, preamble message wording, stringly-typed status, absent-assessment message) | confirmed 4, dismissed 0, deferred 1 |
| 4 | reviewer-security | Yes | clean | 4 (counter masking disarms guard, counter deletion unchanged, indented dispatch tag over-masked, regex co-location) | confirmed 3, dismissed 0, deferred 1 |
| 5 | reviewer-rule-checker | Yes | clean | 3 (approval.md mechanism claim, case-insensitivity undocumented, stale-tag message) — 18 rules, 47 instances | confirmed 3, dismissed 0, deferred 0 |
| — | reviewer-edge-hunter | N/A | disabled in config | — | N/A |
| — | reviewer-silent-failure-hunter | N/A | disabled in config | — | N/A |
| — | reviewer-comment-analyzer | N/A | disabled in config | — | N/A |
| — | reviewer-simplifier | N/A | disabled in config | — | N/A |

**All received:** Yes

**Deferral rationale (2).** Type-design's Literal/TypedDict refactor of the section status is carried forward from cycle 1 — still sound, still a four-caller refactor of a 162-21 primitive, still its own story. Security's suggestion to co-locate the tag regex with the masker is a structural preference with no live defect behind it.

**No dismissals this cycle.** Every specialist finding was reproduced before being accepted; the two blocking ones I verified by executing the guard, not by reading it.

## Reviewer Assessment

**Verdict:** REJECTED

This is a strong rework and it closes what I asked for. All six forgery vectors are genuinely dead — I re-ran every one and each now blocks while a legitimate column-0 tag passes. The counter has one reader again, the docs match the code on every substantive claim, and Dev overturned two of my own cycle-1 conclusions with evidence, which is the pipeline working as intended. It still cannot ship, because the guard remains disarmable — by hiding the counter rather than forging the tag — and because widening the shared masker now hard-blocks legitimate approvals in a different gate.

| Severity | Issue | Location | Fix Required |
|----------|-------|----------|--------------|
| [CRITICAL] | [SEC] The cycle-0 short-circuit treats "counter unreadable" as "never reworked", so hiding the counter disarms the guard exactly as deleting it does. Verified: wrapping the operative counter line in an HTML comment, a fence, or backticks yields cycle 0 and "No rework cycle — initial review" with a stale table and no tag. The HTML-comment form renders as nothing, so a human reading the session sees an intact document — strictly worse than deletion, which at least leaves a visible hole. The masker is in-scope machinery this commit deliberately widened, and widening it widened this hole. I scoped the deletion variant out in cycle 1 and that was my error, not Dev's. | `gate_recovery.py:496-515`, `complete_phase.py:616-623` | Make the counter read tri-state — absent, present-and-parsed, present-but-unreadable — and block on unreadable. Compare a raw search against the masked search: found raw but not masked means hidden, which must fail closed exactly as an unterminated fence already does. Pin the comment, fence and backtick shapes. |
| [HIGH] | [SEC] Over-masking hard-blocks legitimate approvals. `_check_subagent_dispatch` now loses tags that are plainly in the file, in two shapes I reproduced: tags inside backticks, which is the form `agents/reviewer.md:253`, `:473` and `gates/approval.md:219-226` all model, and tags on an indented line after a blank line under a `###` subsection, which the `list_context` guard misses because a heading is neither list nor table. The gate then reports the tags missing while they are visibly present, which is close to undiagnosable from the message alone. Dev applied exactly the right reasoning to indented lists and wrote a test for it; the same reasoning was never extended to headings or to inline spans. Confirmed a new regression: the pre-rework masker had no inline handling, so these assessments passed before this commit. | `gate_recovery.py:304-316`, dispatch-tag search | Search dispatch tags on unmasked content, or treat a heading as opening non-code context, or stop rendering the tags in backticks in the docs — and pin a backticked and an indented-under-`###` assessment as passing. |
| [MEDIUM] | [TYPE] An annotated counter such as a value followed by a parenthetical fails the end-anchored pattern and reads 0, disarming the guard. This is not hypothetical: the counter on this session was restored by hand this cycle, so hand-editing is live practice. | `gate_recovery.py:493` | Tolerate a trailing comment, or block when a counter line is present but its value will not parse. |
| [MEDIUM] | [TEST] The commit says all six vectors reproduce as RED tests first; two do not. Against the pre-rework code the stale-tag-alongside-fresh and tag-ahead-of-counter tests were already green — the old first-match regex blocked those by coincidence. So the new all-tags-must-match rule has no test that would catch its removal. The case that distinguishes the rules is a stale tag placed AFTER a matching one, which is untested. | `test_162_28_freshness_tag_predicate.py:121,132` | Add the stale-after-matching case, and correct the claim. |
| [MEDIUM] | [RULE] `gates/approval.md:143` says the section "ends at the next heading of any level". It ends at the next `##`; the `###` exclusion comes from `section_preamble()`. The agent-facing outcome is stated correctly but the mechanism is not, and this is the precise sentence someone will rely on when next changing the slice — the same trap that produced the failed `^#{1,6}` attempt this cycle. | `gates/approval.md:143` | Describe the two mechanisms separately. |
| [LOW] | [TEST] Untested masker branches: indented content with no preceding blank line, table-context continuations, a counter inside a fence for the writer, and two bare counter lines. All four behave correctly today — I verified them — but none is pinned, so the conditions can be deleted without failing a test. | `test_162_28_freshness_tag_predicate.py:209,299` | Pin the branches. |
| [LOW] | [RULE] Two error messages overstate their constraints: the stale-tag message demands "exactly one" tag when any number of matching tags passes, and the no-tag message blames "a later `###` subsection" when the offending subsection can be the section's first line. `reviewer.md:213` also says "spelled exactly" without noting the match is case-insensitive — harmless, since the doc is stricter than the code. | `complete_phase.py:668-690`, `agents/reviewer.md:213` | Align the wording. |

**Data flow traced.** Session markdown → `complete_phase(gate_type="approval")` → `_check_rework_freshness` → `_parse_rework_cycle` → `gate_recovery.parse_round_trip_count` (masked, last match, digits-to-end) with the legacy field as fallback → cycle-0 short-circuit → `select_last_section("Subagent Results")` → `section_preamble()` → all-tags-must-match. The tag predicate at the end of that chain is now sound; the failure moved to the front of it, where an unreadable counter is silently equated with no counter. The same masked reader feeds the writer, and I verified reader and writer now agree on which occurrence is operative.

**Pattern observed.** Good: the writer at `complete_phase.py:199-220` computes offsets against the masked copy and splices into the unmasked original, which is only safe because masking is byte-exact. I verified that invariant holds across fences, HTML comments, indented blocks, inline spans, unterminated openers and CRLF — length preserved and newline positions identical in every case. That is a real invariant, correctly relied upon, and pinned. Bad: the same masker is now load-bearing for two readers with opposite failure directions — the freshness tag wants aggressive masking, the dispatch tag search wants none — and one shared function cannot serve both. That tension is the root of the HIGH, and it will keep producing bugs until the two searches stop sharing a masker.

**Error handling.** All three `select_last_section` statuses are handled explicitly in the freshness path, and the ambiguous branch names the offending heading. Unterminated fences and comments mask to end of input, which blocks — the safe direction, deliberately chosen and documented. The gap is that the counter reader has no unreadable state at all, so it cannot block on one.

**Verified good (not defects).** All six cycle-1 forgery vectors now block and a legitimate column-0 tag passes — re-run individually, not taken on trust. The writer fix is correct in all four shapes I tested, including the exact corruption that hit this session: when the only occurrence is masked it now inserts a fresh operative line, when several exist only the operative one is incremented, and quoted mentions are left alone. Masking preserves byte offsets exactly. There is now one counter-parsing implementation and the previously false "the two agree" docstring is true. `section_preamble` is total across every section shape I probed and fails closed on the degenerate ones. `reviewer.md:214` is a genuinely precise statement of the contract and closes my cycle-1 doc divergence completely. The reviewer-template regression is pinned at its source. No test was deleted, weakened or xfailed. Both commits are GPG-signed with conventional messages, only `pennyfarthing-dist/` sources were touched, and no stale sibling doc survives. The session hand-edit is honest in value and direction.

**Two of my cycle-1 conclusions were wrong, and Dev caught both.** My prescribed slice termination would have failed closed on every review — `test_150_13` proves it, and his `section_preamble` narrowing is the better fix. My reading of the writer as fail-closed was wrong in the other direction: it was fail-open, it had already corrupted this session, and I had separately observed all three ingredients — inline spans unmasked, the trailing-backtick quirk making the value unparseable, the insert branch being skipped — without composing them. Recording that plainly because the third cycle's CRITICAL is the same mistake compounding: I scoped the counter-disarm out as architectural when the in-scope masker reaches it.

**Suite (re-verified independently).** 6026 passed / 0 failed / 4 skipped / 4 xfailed on `13f26043c`, clean tree, matching preflight exactly. Totals reconcile against Dev's 4 failed / 6022 passed, so the 4 environment-dependent `test_frame_routes.py` failures again did not occur here; both environments are now recorded on 162-49. Targeted files 184 passed, including 33 new. Ruff clean on all changed files, no new findings versus develop. `pf validate agent`: 38 passed, 2 pre-existing warnings.

**Observations:** 7 findings (1 critical, 1 high, 3 medium, 2 low), 11 verified-good notes, 5 upstream Delivery Findings, 7 deviations audited (all accepted, 2 with caveats), 2 self-corrections.

**Handoff:** Back to Dev. Keep everything in this commit — the tag predicate, the masker hardening, the preamble scoping, the single counter reader, the writer fix and the docs are all correct and should not be touched. Two changes are required: give the counter read an unreadable state that blocks, and stop the shared masker from eating dispatch tags.

### Dev (rework cycle 2)
- **Counter anchored to column 0:** beyond the tri-state the reviewer asked for, `**Round-Trip Count:**` must now start at column 0 to be operative. Reason: an indented counter was the one hidden shape that still parsed — the raw/masked comparison cannot see it, since an indented line with no blank line before it is not code. Column 0 is the doctrine the verdict and cycle tag already follow, and any indented mention now reports unreadable rather than arming a cycle nobody can see.
- **Legacy field gets the same tri-state:** a hidden or unparseable `**Rework Cycle:**` line also blocks, and the legacy fallback is consulted only when the real counter is genuinely absent (not when it is unreadable). Reason: otherwise a quoted legacy line could paper over an unreadable real counter.
- **Engine shared, policy split:** rather than duplicating the masker, `_mask(content, *, code_blocks, inline)` backs both public functions and `select_last_section` takes the masker as an argument. Reason: the two searches must disagree about policy but must not drift on byte-offset preservation, which the writer's splice depends on.
- **Annotated counter blocks rather than tolerating the annotation:** the reviewer offered either. Chose blocking — a value that will not parse is exactly the state the tri-state exists to surface, and tolerating trailing text would reopen the `2.0`/`1_000` class.
- **Residual MEDIUMs and LOWs closed too:** the stale-after-matching pin, the corrected RED claim, the four unpinned masker branches, the `approval.md` mechanism wording, and both overstated error messages. Reason: round-trip 2 of 3 — leaving cheap wording defects for a fourth pass spends the ceiling on nothing.

## Dev Assessment (rework cycle 2)

**Verdict:** GREEN

Both required changes are in, with the five residual findings closed alongside them. Nothing from the previous commit was touched except where a finding named it.

**Implementation Complete:** Yes

**Files Changed:**
- `pennyfarthing-dist/src/pf/handoff/gate_recovery.py` — new `read_round_trip_count()` tri-state (absent / found / unreadable, detecting hidden by comparing raw against masked) with `parse_round_trip_count()` now a thin wrapper; counter pattern anchored to column 0; new `mask_quoted_blocks()` for presence searches; `_mask(code_blocks=, inline=)` engine behind both maskers; `select_last_section(..., masker=)`.
- `pennyfarthing-dist/src/pf/handoff/complete_phase.py` — `_read_rework_cycle()` tri-state including the legacy field; the freshness guard blocks on `unreadable` with a message naming the line to un-hide; the dispatch check, the completion check and the approval-gate ambiguity precheck all read through `mask_quoted_blocks`; two error messages reworded.
- `pennyfarthing-dist/gates/approval.md` — the two slice mechanisms described separately (section runs to the next `##`; the tag is read from the preamble).
- `pennyfarthing-dist/agents/reviewer.md` — notes the tag match is case-insensitive.
- `pennyfarthing-dist/src/pf/tests/test_162_28_freshness_tag_predicate.py` — 16 new tests; the module docstring's RED claim corrected.

**Tests:** 16 new, 9 RED before the fix — four hidden-counter shapes (HTML comment, fence, backticks, indented), the unparseable annotated value, the tri-state reader, backticked dispatch tags, tags indented under a `###` subsection, and a backticked completion row. Plus the stale-after-matching pin and four masker branches that were correct but unpinned. File total 49. Targeted suites all green.

**Suite:** 4 failed / 6038 passed / 4 skipped / 4 xfailed. The 4 are `test_frame_routes.py`, environment-dependent (the Reviewer's environment reports 0; verified here against the untouched develop tip last cycle) — 162-49.

**Lint:** ruff clean on `pennyfarthing-dist/src/pf/handoff/` and the new test file. `pf validate agent`: 38 passed, 2 pre-existing warnings on other agents.

**Live check:** on this session file the counter now reads `found / 2`, and the guard correctly reports the cycle-1 tag as stale — the dogfood case for the Reviewer's next approval. The verdict reader, dispatch check and completion check all still pass on the real document, so neither masker change failed closed on it.

**Branch:** `feat/162-28-phase-approval-gate-fails-open` — commit `3dc27fe6e`, GPG-signed (verified), pushed.

**Handoff:** To Reviewer for cycle 3.

### Reviewer (audit, cycle 2)
- **Dev — tri-state counter read: ACCEPTED.** Verified all eight hiding and malformation shapes now block (HTML comment, fence, inline backticks, 4-space indent, 1-3 space indent, annotated value, table cell, and the legacy field's equivalents), and that a legitimate column-0 counter still reads `found`. This is exactly the change I asked for.
- **Dev — legacy field gets the same tri-state and is consulted only on genuine absence: ACCEPTED.** Verified the downgrade path is closed: an unreadable real counter blocks and does NOT fall through to a readable legacy field. That was the specific hole I was worried about and it is shut.
- **Dev — masker split into two policies over a shared engine: ACCEPTED, and the safety property holds.** The concern with splitting a security primitive is that two callers could disagree about which section is current. They cannot: a `## heading` match requires column 0 and no quoting, and the only constructs that can hide a column-0 line are fences and HTML comments, which BOTH policies mask identically. I verified heading-position agreement across seven adversarial shapes including unterminated fences and comments, nested quoting, and indented and backticked heading lookalikes — identical in every case. The intentional content-level asymmetry is the fix I asked for and 162-21 stays closed: fenced dispatch tags are still all reported missing, and fenced and backticked cycle tags still block.
- **Dev — presence searches made more lenient: ACCEPTED as the correct trade-off.** This is a fail-open direction on presence checks, so I probed its limits: a quoted `**All received:** Yes` alone cannot clear the completion check because the enabled specialist names must also appear, and a fenced full template clears neither. Relative to the shipped baseline (162-21, fences-only masking) this is unchanged, not a new hole — cycle 2's extra strictness was itself the defect I rejected.
- **Dev — closed all five residual wording and pin items rather than deferring: ACCEPTED.** Verified each independently: the "ends at the next heading of any level" claim is gone, "exactly one" and "later `###`" are gone from the error messages, case-insensitivity is now documented, and all five previously unpinned masker/writer branches have tests.
- **Dev — two architectural items filed and deliberately not fixed here: I AGREE both belong in a follow-up.** Counter deletion (and, as I found, every other unrecognisable-label shape) cannot be closed inside this diff: the recognition space is unbounded, so regex widening is an arms race with no completion condition, and the real fix — deriving the count from mechanically written Phase History or a sidecar the agent cannot author — is a design change with its own questions. Masker-choice-as-policy is a real smell with no live defect; note the `select_last_section` default is the aggressive policy, which fails CLOSED for either kind of caller, so the risky direction requires an explicit argument. That is the right default and it makes the follow-up genuinely optional rather than urgent.
- **Dev — suite numbers differ from mine again: ACCEPTED, disclosed.** Dev reports 4 failed / 6038 passed; I get 6042 passed / 0 failed. Totals reconcile, the delta is the four environment-dependent `test_frame_routes.py` tests, and both environments are recorded on 162-49.

## Subagent Results

**Cycle: 2**

Ceiling-round re-review. All five enabled specialists were re-dispatched up front against the full diff for this cycle, in parallel, before my own analysis; all five returned. Four specialists remain disabled in `config.local.yaml`.

| # | Specialist | Received | Status | Findings | Decision |
|---|-----------|----------|--------|----------|----------|
| 1 | reviewer-preflight | Yes | clean | 6042 passed / 0 failed, 49 tests in the new file, ruff clean, GPG good, full masker-policy map per call site | confirmed 0, dismissed 0, deferred 0 — flagged its own conflict with Dev's numbers instead of reconciling, which is what I asked for; I reproduced the suite independently |
| 2 | reviewer-test-analyzer | Yes | clean | 2 (untested legacy-vs-unreadable combination, fenced cycle tag not pinned end-to-end) plus confirmation that 9 of 16 were RED and nothing was weakened | confirmed 2, dismissed 0, deferred 0 |
| 3 | reviewer-type-design | Yes | clean | 5 (writer collapses absent/unreadable, near-miss labels read absent, stringly-typed tri-state, masker policy untyped, dispatch ambiguity message) | confirmed 4, dismissed 0, deferred 1 |
| 4 | reviewer-security | Yes | clean | 1 (field name split across a newline reads absent) plus confirmation that the masker split has no section-selection asymmetry | confirmed 1 as reclassified, dismissed 0, deferred 0 |
| 5 | reviewer-rule-checker | Yes | clean | 7 (hidden-counter consequence undocumented, stale handoff-cli masking table, five pre-existing 8-vs-9 and missing-tag items) | confirmed 7, dismissed 0, deferred 0 |
| — | reviewer-edge-hunter | N/A | disabled in config | — | N/A |
| — | reviewer-silent-failure-hunter | N/A | disabled in config | — | N/A |
| — | reviewer-comment-analyzer | N/A | disabled in config | — | N/A |
| — | reviewer-simplifier | N/A | disabled in config | — | N/A |

**All received:** Yes

**Reclassification, not dismissal (1).** Security reported the split-field-name shape as a NEW fail-open in this cycle's raw-vs-masked comparison. The behaviour is real and I reproduced it, but I reclassified its cause: the HTML comment is incidental — the same input without a comment also reads `absent` — and the shape failed open identically on `13f26043c`. It is therefore an instance of the deferred recognition gap, not a defect in the new mechanism and not a regression. Folded into the architectural finding with the shape enumerated so the follow-up is scoped correctly.

**Deferral rationale (1).** Type-design's Literal/TypedDict modelling of the tri-state and the section status is carried forward for the third cycle — still correct, still a multi-caller refactor of a 162-21 primitive, and it now overlaps the masker-policy-typing item Dev filed, so both belong to one typed-contracts story.

## Reviewer Assessment

**Verdict:** APPROVED

Both required changes are correctly implemented, and I could not find a new fail-open. The tri-state counter closes every hiding and malformation shape I could construct, the legacy downgrade path is shut, and the masker split — the risky part, because splitting a security primitive invites two callers disagreeing about which section is current — turns out to be structurally safe rather than accidentally safe: a `## heading` match requires column 0 and no quoting, and the only constructs that can hide such a line are fences and HTML comments, which both policies mask identically. I verified heading-position agreement across seven adversarial shapes and found no divergence. 162-21 stays closed and my two reported over-masking shapes now pass. Dev also closed all five residual wording and pin items instead of deferring them.

What remains is one architectural gap and a set of consistency and coverage items, none of which is a regression and none of which this diff could reasonably close.

| Severity | Issue | Location | Fix Required |
|----------|-------|----------|--------------|
| [MEDIUM] | [SEC] The counter reader still equates "no counter" with "text I do not recognise as a counter", and the residue is wider than deletion: near-miss labels, a lowercase label, and a field name broken across a newline all read absent and pass. The comment wrapper is incidental to the last of these — the same input unwrapped behaves the same — so this is recognition, not masking. All shapes behaved identically before this cycle, so nothing regressed, and no regex can close an unbounded set. | `gate_recovery.py:537-593` | Follow-up story: derive the count from something the gated agent does not author — the mechanically written Phase History rows, or a sidecar. That closes deletion, near-miss labels, case variants and line breaks together. |
| [MEDIUM] | [TYPE] The counter WRITER collapses absent and unreadable where the reader now separates them, because it re-implements the masked search instead of calling `read_round_trip_count`. On a hidden counter it inserts a fresh count of 1, resetting a session that was at 2. No stale approval follows — the approval path blocks on unreadable — but `max_attempts` is computed from the reset value, so the round-trip budget can be under-counted. Pre-existing, now inconsistent with the tri-state. | `complete_phase.py:208-228` | Call `read_round_trip_count` and error on unreadable, so the insert branch runs only on genuine absence. |
| [MEDIUM] | [TEST] Two correct behaviours are unpinned: nothing covers an unreadable real counter alongside a readable legacy field — the exact condition the short-circuit exists for — and no end-to-end test blocks a fenced cycle tag through the guard, so fence masking could be removed from the aggressive policy without failing a test in that file. | `test_162_28_freshness_tag_predicate.py:76,412` | Add both cases. |
| [MEDIUM] | [RULE] `guides/handoff-cli.md:67` is stale after the split: it says fenced text is masked "before both scans", which understates both policies and asserts a single shared one where this cycle's entire point was two with opposite failure directions. Neither `reviewer.md` nor `approval.md` warns that a hidden or unparseable counter blocks — the message is precise when it fires, but there is no forewarning. | `guides/handoff-cli.md:67`, `agents/reviewer.md:208-226`, `gates/approval.md:137-147` | Describe the two policies and their callers; add the counter-line requirement to the reviewer-facing docs. |
| [LOW] | [RULE] Five pre-existing doc inaccuracies in the touched files: three "8 subagents" where the code needs 9, one "All 8 rows", and a recovery message listing 7 dispatch tags with `[RULE]` missing. Not introduced here. | `gates/approval.md:123,160,192,260`, `agents/reviewer.md:271` | Sweep in the follow-up. |

**Data flow traced.** Session markdown → `complete_phase(gate_type="approval")` → ambiguity precheck on Reviewer Assessment (lenient masker) → completion table on Subagent Results (lenient) → dispatch tags on Reviewer Assessment (lenient) → `_check_rework_freshness` → `_read_rework_cycle` → `read_round_trip_count` (aggressive masker, tri-state) with the legacy field consulted only on genuine absence → block on unreadable, short-circuit on absent → `select_last_section` on Subagent Results (aggressive) → `section_preamble` → all-tags-must-match. I traced the aggressive/lenient boundary at every one of the five production call sites and confirmed the policy assignment matches the failure direction each check needs.

**Pattern observed.** The good pattern is the one that makes the split defensible: every operative statement in this system — verdict, cycle tag, counter — must be a single unquoted line at column 0. Because all three readers share that doctrine, widening or narrowing a masker cannot change which *section* is selected, only what the section's body contains. That is why a security primitive could be split in two without opening a seam, and it is worth preserving deliberately rather than by luck. The residual weakness is the flip side of the same doctrine: anything that is not a recognised single line is invisible, and invisible currently means absent, which for the counter means "no rework". Turning invisible into "block" for the counter is what the follow-up must do.

**Error handling.** All three counter states are handled explicitly and the unreadable branch names both the reason and the exact remedy. All three section statuses are handled in the freshness path. Fenced and comment openers that are never closed mask to end of input, which blocks. The one asymmetry is the writer, which has no unreadable branch — noted above. A CRLF-edited counter reads unreadable and blocks, which is fail-closed and acceptable.

**Verified good (not defects).** Eight counter hiding and malformation shapes block; the legacy downgrade path is shut; both maskers agree on heading positions across seven adversarial inputs; both preserve byte offsets and newline positions exactly, which the writer's splice depends on; fenced dispatch tags are still all reported missing and fenced and backticked cycle tags still block, so 162-21 is intact; backticked tags and tags indented under a `###` subsection now pass, closing my cycle-2 high; a quoted `All received` line alone cannot clear the completion check; 9 of 16 new tests were RED pre-fix as claimed; no test was deleted, renamed, xfailed or weakened; all five residual items from cycle 2 are closed; commit GPG-signed and conventional; only `pennyfarthing-dist/` sources touched; ruff clean.

**Ceiling-round judgment.** I held this to the stated bar — approve unless there is a genuine new fail-open or a botched implementation — and I checked the fail-open question three ways before concluding: I re-ran every previously closed vector, I attacked the split for a section-selection seam, and when security reported a new bypass I reproduced it and then tested whether it predated the diff. It did, in identical form, along with three sibling shapes. So this diff strictly reduces the fail-open surface and adds none. The remaining hole is real and I am not minimising it — the guard can still be disarmed by making the counter unrecognisable — but it is one architectural problem with one correct fix, it is filed, and three cycles of regex hardening have demonstrated that it cannot be closed by more of the same.

**Suite (re-verified independently).** 6042 passed / 0 failed / 4 skipped / 4 xfailed on `3dc27fe6e`, clean tree, matching preflight exactly. Dev's 4 failed / 6038 passed reconciles to the same total; the delta is the four environment-dependent `test_frame_routes.py` tests, recorded on 162-49 from both environments. Targeted files 151 passed; the new predicate file holds 49 tests. Ruff clean with no new findings versus develop. `pf validate agent`: 38 passed, 2 pre-existing warnings.

**Observations:** 5 findings (0 critical, 0 high, 4 medium, 1 low), 15 verified-good notes, 5 upstream Delivery Findings, 7 deviations audited and all accepted, 1 specialist finding reclassified with rationale.

**Handoff:** To SM for finish-story. The two architectural items — deriving the counter from a source the gated agent does not author, and typing the masker policy and the tri-state contracts — belong in a follow-up story together with the writer's missing unreadable branch, the two test pins, and the doc sweep.