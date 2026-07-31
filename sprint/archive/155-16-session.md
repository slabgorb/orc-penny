---
story_id: "155-16"
jira_key: ""
epic: "155"
workflow: "tdd"
---
# Story 155-16: Wrap remaining read_sprint calls in finish path (SOUL #10) + 155-6 LOW test-polish deferrals

## Story Details
- **ID:** 155-16
- **Jira Key:** (none — Jira not configured for this story)
- **Workflow:** tdd
- **Stack Parent:** none
- **Branch:** feat/155-16-read-sprint-finish-wrap
- **Branch Strategy:** gitflow (feat/155-16-read-sprint-finish-wrap on pennyfarthing/develop)

## Workflow Tracking
**Workflow:** tdd
**Phase:** finish
**Phase Started:** 2026-07-31T14:32:45Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-07-31T14:09:11Z | 2026-07-31T14:11:18Z | 2m 7s |
| red | 2026-07-31T14:11:18Z | 2026-07-31T14:21:19Z | 10m 1s |
| green | 2026-07-31T14:21:19Z | 2026-07-31T14:24:15Z | 2m 56s |
| review | 2026-07-31T14:24:15Z | 2026-07-31T14:32:45Z | 8m 30s |
| finish | 2026-07-31T14:32:45Z | - | - |

## Delivery Findings

Agents record upstream observations discovered during their phase.
Each finding is one list item. Use "No upstream findings" if none.

**Types:** Gap, Conflict, Question, Improvement
**Urgency:** blocking, non-blocking

<!-- Agents: append findings below this line. Do not edit other agents' entries. -->

### TEA (test design)
- **Conflict** (non-blocking): AC-1 names the step-4b read, but 155-9 already guarded it with a deliberately opposite contract (graceful degrade, success True, recorded step failure) — the story context was authored from 155-6 deferrals without reconciling against 155-9's shipped work. Affects `sprint/context/context-story-155-16.md` (AC-1 should be read as status-transition-read-only; future follow-up stories should be diffed against sibling deliveries at authoring time). *Found by TEA during test design.*
- **Improvement** (non-blocking): Today an unreadable sprint index at the status-transition read lets the ENTIRE finish ceremony complete (done transition, session removed) with only a 4b bookkeeping note — the RED failure dumps in `test_155_16_finish_status_read_guard.py` capture this end-to-end. Affects `pennyfarthing-dist/src/pf/sprint/story_finish.py` (the exact defect this story fixes; noting here because the blast radius — a fully completed ceremony against a known-broken index — is worse than the story title suggests). *Found by TEA during test design.*

### Dev (implementation)
- No upstream findings during implementation.

### Reviewer (code review)
- **Improvement** (non-blocking): Post-merge aborts in `finish_story` are not cleanly retryable — after this story's status-read abort (or the pre-existing transition-failure abort at ~line 620), a re-run re-enters Step 2 where `gh pr merge` on the already-merged PR returns non-zero, so finish aborts with the misleading "refusing to mark the story done with unmerged code". Affects `pennyfarthing-dist/src/pf/sprint/story_finish.py` (short-circuit Step 2 when `_pr_is_merged(pr_number)` is already true, making every post-merge abort retryable). Pre-existing class shared with the transition-failure abort — this diff adds one more instance, it did not create the class. Note: could not live-probe `gh pr merge` on a merged PR (classifier-denied, correctly); based on documented gh behavior. *Found by Reviewer during code review.*
- **Improvement** (non-blocking): The failure-result tests for the new guard don't pin `jira_key`/`steps` key presence — test-analyzer empirically confirmed a mutation dropping both keys passes all 5 story tests. No caller consumes them on the failure path today (`cli.py:481` reads only `error`), so this is parity-polish, not a live defect. Affects `pennyfarthing-dist/src/pf/tests/test_155_16_finish_status_read_guard.py` (add two key-presence asserts to `test_status_read_failure_returns_loud_result`). *Found by Reviewer during code review.*

## Design Deviations

Agents log spec deviations as they happen — not after the fact.
Each entry: what was changed, what the spec said, and why.

<!-- Agents: append deviations below this line. Do not edit other agents' entries. -->

### TEA (test design)
- **AC-1's step-4b half not re-pinned — green-on-arrival via 155-9, and its literal wording conflicts with the shipped contract**
  - Spec source: context-story-155-16.md, AC-1
  - Spec text: "Step-4b read and status-transition read in finish_story return {success: False, story_id, error} on FileNotFoundError/ValueError instead of raising"
  - Implementation: Only the status-transition read is RED-tested. The step-4b read was already guarded by 155-9 with a deliberate broad catch whose pinned contract is the OPPOSITE shape: success stays True (merge + done landed), the failure is recorded in the 4b step entry, and steps 4c-7 run (`test_155_9_finish_archive_epic_hardening.py::TestStep4bReadSprintGuard`).
  - Rationale: The story context was written from 155-6 deferrals before 155-9 shipped. Making 4b return {success: False} would regress 155-9's graceful-degrade contract and break its tests. Spec authority: shipped sibling tests + in-code rationale comment beat the trailing AC wording.
  - Severity: minor
  - Forward impact: Dev must NOT touch the step-4b guard; Reviewer should read AC-1 as status-read-only.
- **No-escape backstop pinned beyond the AC letter (PermissionError at the status read must not raise)**
  - Spec source: context-story-155-16.md, AC-2
  - Spec text: "New guards use narrow (FileNotFoundError, ValueError) catch, not broad except Exception"
  - Implementation: `test_status_read_other_exception_must_not_escape` (green-on-arrival) forbids a pure-narrow fix that deletes the existing fallback: a non-(FNF/VE) exception at this post-merge read must not escape finish_story as a raw traceback.
  - Rationale: SOUL #10 — the read runs AFTER the irreversible merge; an escape strands a merged story mid-ceremony, strictly worse than today. Expected fix shape: narrow guard returns the loud result, pre-existing broad fallback (unchanged scope) or equivalent no-raise shape retained for exotic exceptions. Reviewer may override the shape; the no-raise property is the pin.
  - Severity: minor
  - Forward impact: The AST test pins only the narrow handler's PRESENCE; whether the retained broad fallback passes AC-2's "0 rule-checker violations" is the rule-checker's/Reviewer's call.
- **Sibling harness edited: test_155_9's boom fake now passes through call 2**
  - Spec source: test_155_9_finish_archive_epic_hardening.py, `_read_sprint_then_boom`
  - Spec text: (155-9 harness) "First call passes through... every later call raises"
  - Implementation: Boom moved from calls 2+ to calls 3+ so the fake targets the step-4b read specifically instead of incidentally booming the status-transition read first.
  - Rationale: Once Dev guards the status read, a call-2 boom would abort finish before ever reaching 4b, breaking 155-9's tests for the wrong reason. The edit is fix-agnostic: green on HEAD today and green post-fix. Verified: 24 sibling tests pass after the edit.
  - Severity: minor
  - Forward impact: none
- **Green-on-arrival pins logged as intentional**
  - Spec source: context-story-155-16.md, AC-4
  - Spec text: "Demo-hook 4b test asserts the epic value; positive jira-key finish path has coverage"
  - Implementation: Both AC-4 items are regression pins that pass on HEAD: the strengthened epic-value assert in `test_demo_finish_hook.py` (PROJ-99990) and `TestJiraKeyedFinishPositivePath` (jira_done step key, jira-named archive, 4b jira-keyed epic). The PermissionError no-escape backstop is also intentionally green.
  - Rationale: Test-polish ACs pin existing behavior; forcing a spurious RED would misrepresent the spec.
  - Severity: minor
  - Forward impact: Gate/Reviewer must not read the 2 green tests + 2 sibling-file edits as spurious; genuine RED count is 3.

### Dev (implementation)
- No deviations from spec. Implemented TEA's designed interface verbatim: narrow `(FileNotFoundError, ValueError)` guard at the status-transition read returning `{"success": False, "story_id", "jira_key", "error", "steps"}` before any transition (message mirrors the 155-6 primary-read guard and carries `str(exc)`); pre-existing broad fallback retained unchanged for exotic exception types (rationale documented in-code, per TEA's no-escape pin). Step-4b and primary-read guards untouched.

### Reviewer (audit)
- **TEA: AC-1's step-4b half not re-pinned** → ✓ ACCEPTED by Reviewer: verified against `test_155_9::TestStep4bReadSprintGuard` and the in-code rationale comment at story_finish.py:604-610 — the 155-9 graceful-degrade contract is shipped and pinned; re-pinning AC-1's literal wording would regress it. Spec-authority reasoning sound.
- **TEA: No-escape backstop pinned beyond the AC letter** → ✓ ACCEPTED by Reviewer: the read is post-merge; a raw escape is strictly worse than either allowed outcome. Rule-checker independently judged the retained fallback not a rule-#1 violation of this diff (unchanged pre-existing lines, confirmed via `git diff -U0`).
- **TEA: Sibling harness edited (boom fake calls 3+)** → ✓ ACCEPTED by Reviewer: test-analyzer traced all read_sprint call sites (299/549/640) and confirmed the pass-through count is necessary and does not weaken 155-9's 4b pins — the parametrized boom still lands exactly on the step-4b read pre- and post-fix.
- **TEA: Green-on-arrival pins logged as intentional** → ✓ ACCEPTED by Reviewer: test-analyzer's guard-deleted revert reproduced exactly the documented 3-RED/2-green split; the green pins are genuine regression guards, not spurious.
- **Dev: No deviations from spec** → ✓ ACCEPTED by Reviewer: diffed the implementation against TEA's designed interface — verbatim match including message shape, key parity with the five sibling abort paths, and untouched sibling guards.

## Sm Assessment

Setup complete and verified. Story 155-16 (2 pts, p2, tdd) is the top-priority backlog item in epic 155 (finish/merge/archive truthfulness). Session file created with bare name, story context written with ACs and technical approach from the epic-155 shard, branch `feat/155-16-read-sprint-finish-wrap` created off `pennyfarthing/develop` per repos.yaml gitflow. Jira claim explicitly skipped — no Jira key exists for this story. Merge gate clear (no open PRs). Routing to TEA for the red phase: TEA should write failing tests covering the four ACs, with mutation-verification (AC3) as the bar for each new guard. Scope is contained to `story_finish.py` read_sprint wrapping plus 155-6 LOW test-polish deferrals — no design phase needed.

## TEA Assessment

**Tests Required:** Yes

**Test Files:**
- `pennyfarthing-dist/src/pf/tests/test_155_16_finish_status_read_guard.py` (new) — status-read guard REDs, guard-shape pins, positive jira-key path
- `pennyfarthing-dist/src/pf/tests/test_155_9_finish_archive_epic_hardening.py` (edited) — boom fake decoupled from the status read (passes through call 2)
- `pennyfarthing-dist/src/pf/tests/test_demo_finish_hook.py` (edited) — 4b step now asserts the resolved epic value (PROJ-99990)

**Tests Written:** 5 new (3 RED + 2 green-on-arrival guards) + 2 sibling-file strengthenings, covering all 4 ACs
**Status:** RED (verified twice: direct scoped run + testing-runner RUN_ID 155-16-tea-red — exactly 3 failures, all AssertionError, no collection errors; 26 sibling tests green)

**RED tests (fail on HEAD, self-mutation-verifying per AC-3 — HEAD is the guard-deleted mutant):**
1. `test_status_read_failure_returns_loud_result[filenotfound]` — success False + story_id + error text, no done-transition, session kept
2. `test_status_read_failure_returns_loud_result[valueerror]` — same contract, parse-error taxonomy
3. `test_status_read_guard_catch_is_narrow` — AST pin: the status-read try must gain a (FileNotFoundError, ValueError) handler (today: broad Exception only)

**Green guards (intentional, see Design Deviations):**
4. `test_status_read_other_exception_must_not_escape` — PermissionError must not raise past finish_story (forbids over-narrow fix deleting the fallback)
5. `test_jira_keyed_finish_records_jira_done_step_and_archive` — jira_done step carries the key, archive named PROJ-91616-session.md, 4b epic PROJ-91600 (AC-4)

### Rule Coverage

| Rule | Test(s) | Status |
|------|---------|--------|
| #1 silent exception swallowing | `TestStatusReadGuard` (both params), `test_status_read_guard_catch_is_narrow` | failing (RED) |
| #1 no new raw-raise hole | `test_status_read_other_exception_must_not_escape` | passing (guard) |
| #6 test quality (error-absence-only asserts) | demo-hook epic-value assert, `TestJiraKeyedFinishPositivePath` | passing (polish) |

**Rules checked:** 2 of 2 applicable lang-review rules have test coverage (#5 encoding n/a — no file-read sites added)
**Self-check:** 0 vacuous tests; every assert pins a concrete value; ruff clean on all three files

**Designed interface for Dev** (docstring of the new test file has the full spec): mirror the 155-6 primary-read guard at story_finish.py:531-537 — narrow `(FileNotFoundError, ValueError)` catch returning `{"success": False, "story_id": story_id, "error": f"...: {exc}", "steps": steps}` BEFORE any transition, keeping the pre-existing broad fallback (unchanged scope) for exotic exceptions. Do NOT touch the step-4b guard (155-9 contract) or the primary-read guard.

**Commit:** 784d649f5 on `feat/155-16-read-sprint-finish-wrap`

**Handoff:** To Dev (B.A.) for implementation

## Dev Assessment

**Implementation Complete:** Yes

**Files Changed:**
- `pennyfarthing-dist/src/pf/sprint/story_finish.py` — status-transition read guard: narrow `(FileNotFoundError, ValueError)` catch returning a loud result dict before any transition; pre-existing broad fallback retained for exotic exceptions (28 insertions, mostly rationale comments matching the file's commenting convention)

**Tests:** 5/5 story tests passing; 128/128 finish-flow regression batch (test_155_1/3/4/6/9/12/15/16, test_demo_finish_hook, test_story_finish_no_jira, test_151_3, test_147_12, test_archive_epic); testing-runner GREEN confirmation (RUN_ID 155-16-dev-green, 66/66 scoped); ruff clean on source + test file; post-runner `git diff` verified only my change present (runner-mutation gotcha)

**AC status:**
- AC-1 (status read returns {success: False, story_id, error} on FNF/VE): implemented — the step-4b half is 155-9's shipped contract, untouched per TEA's deviation
- AC-2 (narrow catch): `(FileNotFoundError, ValueError)` handler; AST pin green; rule-checker's broad-fallback call deferred to Reviewer (retained fallback is pre-existing behavior with documented rationale)
- AC-3 (mutation-verified): the RED tests are the mutants' witnesses — reverting the guard re-fails them
- AC-4 (test polish): shipped by TEA in RED (demo-hook epic assert + jira-keyed positive path); all green

**Branch:** feat/155-16-read-sprint-finish-wrap (pushed, commits 784d649f5 test + c025da553 impl)

**Handoff:** To Reviewer (Colonel Lynch) for code review

## Subagent Results

| # | Specialist | Received | Status | Findings | Decision |
|---|-----------|----------|--------|----------|----------|
| 1 | reviewer-preflight | Yes | clean | none | N/A — 119 scoped tests green, ruff clean, 0 smells, tree clean |
| 2 | reviewer-edge-hunter | Skipped | disabled | N/A | Disabled via settings — domain covered directly: caller sweep (single caller handles success-False), retry-after-abort edge found and captured as Delivery Finding, dry-run/human-mode paths traced |
| 3 | reviewer-silent-failure-hunter | Skipped | disabled | N/A | Disabled via settings — domain covered directly: the diff's whole subject is a de-swallow; retained fallback traced to the loud 592 transition-failure path; no new swallows introduced |
| 4 | reviewer-test-analyzer | Yes | findings | 3 (+3 verified-correct) | confirmed 2 (jira_key/steps pin gap → non-blocking finding; near-vacuous trailing assert → noted, by-design), deferred 1 (AST split-handler brittleness → LOW note); AC-3 mutation-verified empirically |
| 5 | reviewer-comment-analyzer | Skipped | disabled | N/A | Disabled via settings — domain covered directly: all claims in the new 20-line comment block verified against code (592 abort parity, transition_story loud-fail routing); no stale/misleading comments |
| 6 | reviewer-type-design | Yes | clean | none | N/A — exception taxonomy verified against read_sprint's actual raise surface; result-shape parity with all 5 sibling aborts confirmed |
| 7 | reviewer-security | Yes | clean | none | N/A — sink traced to local ClickException stderr only; no network path; no new file I/O |
| 8 | reviewer-simplifier | Skipped | disabled | N/A | Disabled via settings — domain covered directly: 28-line diff, mostly rationale comments; no over-engineering, no dead code |
| 9 | reviewer-rule-checker | Yes | clean | none | N/A — 15 rules (13 python.md + 2 SOUL) × ~20 instances, 0 violations; explicit judgment: retained fallback is unchanged pre-existing code, not an AC-2 violation |

**All received:** Yes (5 returned, 4 disabled with domains covered directly)
**Total findings:** 3 confirmed (all non-blocking), 0 dismissed, 1 deferred

## Reviewer Assessment

**Verdict:** APPROVED

**Data flow traced:** `story_id` (CLI arg) → `finish_story` → `read_sprint(sprint_path)` raises FNF/VE → new guard returns `{success: False, story_id, jira_key, error, steps}` → `cli.py:481` `click.ClickException(result["error"])` → local stderr, non-zero exit. Safe: no network sink, error text carries only local self-authored paths (same as the 155-6 guard) [SEC].

**Pattern observed:** Good — the guard mirrors the 155-6 primary-read guard (story_finish.py:298-305) in taxonomy, message shape, and result-key parity with all five sibling abort paths (verified by type-design at story_finish.py:554-564) [TYPE].

**Error handling:** The narrow catch returns loud; the retained broad fallback (story_finish.py:565-566, byte-identical to develop per `git diff -U0`) degrades exotic exceptions to the pre-existing transition path, which fails loudly at the 592 abort on a genuinely broken index — no new swallow, no new raise hole [SILENT] [RULE].

**Observations:**
1. [VERIFIED] Guard binds to the fix — test-analyzer's guard-deleted revert (`git show HEAD^`) produced exactly the 3 documented REDs and kept both guards green, then restored clean; equivalently, TEA's RED runs this session executed against source byte-identical to origin/develop (guard landed one commit later, 784d649f5 → c025da553) [TEST].
2. [VERIFIED] Exception tuple matches the callee's real contract — `read_sprint` → `_read_yaml_file` raises exactly FileNotFoundError/ValueError (yaml_io.py:99-113); shard-level failures are swallowed inside `merge_epic_shards` and never propagate. Complies with lang-review #1 narrow-catch [TYPE] [RULE].
3. [VERIFIED] Single production caller handles the new early return — `cli.py:478-481` checks `result["success"]` generically; no caller regression (lang-review #13) [RULE].
4. [VERIFIED] AC-4 polish is genuine — demo-hook epic assert checks distinct fixture data (PROJ-99990 from the epic's jira key, exercising 155-9 priority), not a tautology; jira-keyed positive path pins the step-3 key + jira-named archive [TEST].
5. [MEDIUM→non-blocking] Failure-result tests don't pin `jira_key`/`steps` presence — mutation dropping them passes; no caller consumes them on the failure path today. Delivery Finding filed [TEST].
6. [LOW] `test_status_read_other_exception_must_not_escape`'s trailing assert is near-vacuous in isolation — the load-bearing assert is the pytest.fail-on-raise, documented by design [TEST].
7. [LOW] AST narrow-catch test would spuriously fail an equally-correct split-handler refactor — documented brittleness, acceptable as a combined pin with the behavioral tests [TEST].
8. [LOW→non-blocking] Post-merge aborts (this one and the pre-existing 592) are not cleanly retryable — Step 2 re-merge fails rc≠0 on a merged PR. Pre-existing class; Delivery Finding filed with the `_pr_is_merged` short-circuit suggestion [EDGE].
9. [VERIFIED] No stale comments — every claim in the new comment block checked against code [DOC]. No complexity added — 28 lines, mostly rationale [SIMPLE].

### Rule Compliance

Rule-checker ran all 13 python.md checks + SOUL #10/#14 across every changed hunk (~20 instances): **0 violations**. Key judgments, independently verified:
- **#1 silent swallowing:** the new guard de-swallows (loud result); the retained `except Exception: current_status = "in_progress"` is unchanged pre-existing code with in-code SOUL-#10 rationale and its own behavioral pin — not a violation of this diff. AC-2's "new guards use narrow catch" is satisfied: the only NEW guard is the narrow one.
- **#6 test quality:** no vacuous asserts in the three test files; the demo-hook edit strengthens an error-absence-only assert into a concrete value pin.
- **#13 fix-introduced regressions:** narrower catch (opposite of the anti-pattern), single guarded path, single caller verified.
- **SOUL #10:** result dict on both failure taxonomies; no-raise pinned for exotic types. **SOUL #14:** RED→GREEN provenance documented and empirically reproduced.

### Devil's Advocate

Suppose this guard is wrong. The worst realistic scenario: the sprint index becomes unreadable mid-finish, the guard fires, and the operator is left with a merged PR, an archived-session copy, a live `.session` file, and a story still `in_review` — then re-runs finish after fixing the YAML, and Step 2 tries `gh pr merge` on an already-merged PR, gets rc≠0, and aborts with "refusing to mark the story done with unmerged code" — a message that is now actively lying about the failure cause. That is a genuine wart, and I filed it — but it is not grounds to reject THIS diff: the identical retry dead-end already exists for the pre-existing transition-failure abort at 592, and the alternative behavior this diff removes (silently completing the entire done ceremony against a known-broken index, session deleted, only a 4b bookkeeping whisper) is categorically worse for the truthfulness epic. Could the narrow catch miss something? PermissionError (an OSError outside FNF) routes to the retained fallback → assumed in_progress → `transition_story` fails loudly against the same unreadable file at the 592 abort — degraded but loud, and pinned by test. Could `find_story_in_data` raise inside the try and produce a misleading "could not read" message? It operates on an already-parsed dict; a ValueError from it is implausible, and even then the abort semantics stay correct — only the message prefix would be imprecise. A malicious actor needs write access to local self-authored YAML on a single-user CLI — no trust boundary crossed. A stressed filesystem (ENOSPC, EACCES mid-flow) lands in either the narrow guard (loud) or the fallback → 592 (loud). The bias risk — TEA, Dev, and Reviewer sharing one session — is real; the countermeasure was empirical: independent subagents mutation-tested the suite and reproduced the RED/green split rather than trusting the session's own narrative. Nothing surfaced that changes the verdict.

**Handoff:** To SM (Faceman) for finish-story

## Story Context

### Summary
Wrap remaining read_sprint calls in the finish flow to return {success: False} dicts on error instead of raising raw tracebacks. From 155-6 reviewer findings (SOUL #10), which wrapped only the primary read_sprint call in finish_story; other reads on the finish path still throw. Also address LOW test-polish deferrals from 155-6 review.

### Acceptance Criteria
1. **Step-4b read and status-transition read in finish_story return {success: False, story_id, error} on FileNotFoundError/ValueError instead of raising**
   - Identifies: story_finish.py line ~282 (step-4b read) and status-transition read
   - Expected behavior: wrap in try/except, return result dict with success flag
   - Exception types: narrow catch for (FileNotFoundError, ValueError) only

2. **New guards use narrow (FileNotFoundError, ValueError) catch, not broad except Exception; 0 rule-checker violations**
   - Constraint: match 155-6 guard scope at story_finish.py:290-297
   - Lang-review rule #1: no broad except Exception patterns
   - Verify with linter/rule-checker before approval

3. **Each new guard is mutation-verified (deleting it fails a test)**
   - TEA must write RED tests that fail when guards are removed
   - Verify coverage with mutation test harness

4. **Demo-hook 4b test asserts the epic value; positive jira-key finish path has coverage**
   - Test must assert the epic field on the completed story (not just error-absence)
   - Add positive jira-key finish test if not already covered

### Technical Approach
- **File:** `pennyfarthing/pennyfarthing-dist/src/pf/story_finish.py`
- **Scope:**
  1. Locate step-4b read_sprint call (likely near line 282, in `add_completed_story` path)
  2. Locate status-transition read_sprint call (lookup/state-change operations)
  3. Wrap each with try/except(FileNotFoundError, ValueError) → {success: False, story_id, error}
  4. Ensure return-dict fields match 155-6 guard pattern
- **Tests:** `test_155_16_finish_wrap_reads` (or similar)
  - RED: verify both paths throw if guards removed
  - Test demo-hook step-4b: assert epic value in result
  - Test jira-key finish path: positive coverage for keyed epics

### Dependencies
- Depends on 155-6 (merged): which wrapped the primary read_sprint call and established the guard pattern

### Branch Strategy
gitflow (feat/155-16-read-sprint-finish-wrap on pennyfarthing/develop)