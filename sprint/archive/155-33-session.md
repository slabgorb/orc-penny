---
story_id: "155-33"
jira_key: ""
epic: "155"
workflow: "tdd"
---
# Story 155-33: sm-setup session template omits Branch/PR fields, so finish silently skips the merge and marks the story done (hit live on 155-32)

## Story Details
- **ID:** 155-33
- **Jira Key:** (none — local kanban)
- **Workflow:** tdd
- **Points:** 2
- **Priority:** p1
- **Repos:** pennyfarthing (framework)
- **Branch:** feat/155-33-session-template-branch-pr-fields
- **PR:** #165 - fix(155-33): session template carries Branch/PR fields; harden _extract_branch
- **Stack Parent:** none

## Story Context

**Title:** sm-setup session template omits Branch/PR fields, so finish silently skips the merge and marks the story done (hit live on 155-32)

**Type:** bugfix

**Description:** The sm-setup session template (consumed and emitted by sm-setup subagent in `pennyfarthing-dist/agents/sm-setup.md`) omits the `**Branch:**` and `**PR:**` fields in the session file output. When `pf sprint story finish` runs, it reads these session fields to resolve the PR to merge; their absence caused finish to silently skip the merge and mark stories done while their PRs remained open. This behavior was observed live on 155-32.

Related recent stories:
- 155-16: status-read guard in finish_story
- 155-29: already-merged short-circuit
- 155-31: dry-run already-merged preview
- 155-32: consolidated pre-merge gh pr view probes (where the bug surfaced)

All related stories have been merged to pennyfarthing develop.

**Acceptance Criteria:** (none specified)

**Technical Notes:**
- Root cause: sm-setup template missing required fields
- Impact: Finish silently skips merge; story marked done but PR left open
- Fix surface: Update sm-setup template to include **Branch:** and **PR:** in output
- Alternative: Harden finish_story to tolerate missing fields and auto-resolve from git history

## Workflow Tracking
**Workflow:** tdd
**Phase:** finish
**Phase Started:** 2026-08-01T11:07:28Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-08-01T10:31:35.558343+00:00 | 2026-08-01T10:33:33Z | 1m 57s |
| red | 2026-08-01T10:33:33Z | 2026-08-01T10:52:18Z | 18m 45s |
| green | 2026-08-01T10:52:18Z | 2026-08-01T10:57:17Z | 4m 59s |
| review | 2026-08-01T10:57:17Z | 2026-08-01T11:07:28Z | 10m 11s |
| finish | 2026-08-01T11:07:28Z | - | - |

## Sm Assessment

**Routing:** 2-pt p1 bugfix, workflow `tdd` (phased) per story YAML — routes setup → red (TEA) → green (Dev) → review → finish. TEA owns the red phase next.

**Why this story now:** Highest-priority available work (p1, epic 155 finish-truthfulness). The gap bit live on 155-32: finish marked the story done while its PR stayed open because the session lacked Branch/PR fields. Fixing the template (and/or finish's tolerance) protects every subsequent story's finish ceremony.

**Scope guidance for TEA/Dev:**
- Primary fix surface: sm-setup agent/template source in `pennyfarthing/pennyfarthing-dist/` (edit source, never `.pennyfarthing/` symlinks) so every generated session carries `**Branch:**` and `**PR:**` fields.
- Secondary surface worth a failing test: `finish_story`'s behavior when those fields are absent — it must not silently skip the merge (aligns with 155-1/155-16/155-29 guarantees). Loud abort or git-derived resolution are both acceptable; silent done is not.
- Note: this very session needed the Branch field explicitly instructed into the spawn prompt — the template gap is reproducible as of today.

**Anomalies to carry:** `pf sprint work next` recommended 155-17 (p3) despite six available p1 stories — picker appears to ignore priority; candidate follow-up story (do not fix in this story).

## TEA Assessment

**Tests Required:** Yes
**Test Files:**
- `pennyfarthing-dist/src/pf/tests/test_155_33_session_template_branch_pr_fields.py` (new) — template structure guards, template→`_parse_session` round trip, `_extract_branch` hardening, and three end-to-end finish tests driven by the REAL template shape

**Tests Written:** 29 total — 18 failing (RED) + 11 green-on-arrival guards, 0 errored
**Status:** RED (all 18 fail on assertions with designed messages — verified by direct scoped run, not testing-runner prose)
**Commit:** `e0782cbf4` on `feat/155-33-session-template-branch-pr-fields`

**ACs (defined by TEA per context file instruction — the authoritative record lives in the test-file docstring):**
- AC-1: Step 4 session template carries `- **Branch:**` and `- **PR:**` lines; the document instructs (outside the fence) recording the real branch into the field
- AC-2: template round-trips through `_parse_session` — branch fillable/resolvable, PR placeholder yields no phantom number
- AC-3: `_extract_branch` strips markdown backticks (live 155-32 Dev shape) and maps none-sentinels (`none`/`N/A`/`na`/`null`/`-`/`—`, any case) to None so `gh pr list --head none` never fires
- AC-4: end-to-end, a template-shaped session leads `finish_story` to resolve the PR from the branch and INVOKE the merge
- AC-5: guards — plain values, annotation strip, `#N - title` PR shapes preserved

**Designed interface for Dev (tests bind only to essentials):**
1. Template Story Details gains `- **Branch:** (created in Step 5)` and `- **PR:** (none yet — recorded when the PR is created)` (any parenthesized placeholder extracts safely to None)
2. Step 5 gitflow arm instructs updating `**Branch:**` to the real branch, plain text, NO backticks; trunk-based arm keeps a parenthesized note
3. `story_finish._extract_branch`: after the existing annotation strip, strip surrounding backticks, then map the case-insensitive sentinel set to None

**Green-simulated:** exactly that fix shape → 29/29 pass; sim reverted (working tree clean, verified). Sibling finish-family suites (155-1/9/12/15/16/29/31/32): 89 passed, no pre-adjustments needed.

### Rule Coverage

| Rule | Test(s) | Status |
|------|---------|--------|
| #1 silent swallowing | `test_sentinel_branch_never_probes_gh`, `test_template_session_resolves_branch_and_merges` (silent merge-skip is the story's bug class) | failing |
| #5 path handling | all template reads use `encoding="utf-8"`; fixtures write with explicit encoding | enforced in suite |
| #6 test quality | every test asserts concrete values (exact branch, exact probe list, `is None`); no `let _`/truthy-only asserts; self-checked | self-check clean |
| #11 boundary validation | `test_backticked_value_strips_to_branch`, `test_none_sentinels_resolve_to_none` (session fields are agent-written input at a trust boundary) | failing |

**Rules checked:** 4 of 13 applicable to a test-only RED phase; remaining rules bind on Dev's implementation diff
**Self-check:** 0 vacuous tests found

**Handoff:** To Dev (the White Rabbit) for GREEN implementation

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/agents/sm-setup.md` — Story Details template gains `- **Branch:** (created in Step 5)` and `- **PR:** (none yet — recorded when the PR is created)`; Step 5 gitflow arm gains a blocking instruction to record the real branch into the `**Branch:**` field (plain text, no backticks) with the finish-ceremony rationale inline; trunk-based arm keeps the field a parenthesized note (bare `none` would be probed as a literal branch); stacked arm updates the field like gitflow
- `pennyfarthing-dist/src/pf/sprint/story_finish.py` — `_extract_branch` now strips markdown backticks after the existing annotation strip and maps the case-insensitive no-branch sentinel set (`none`/`n/a`/`na`/`null`/`-`/`—`, module constant `_BRANCH_SENTINELS`) to None

**Tests:** 29/29 story suite passing (GREEN) — verified by direct scoped run
**Regression sweep:** 316 tests across every `story_finish`/`_parse_session` consumer family (155-1/4/6/7/8/9/12/15/16/29/31/32, 147-12, 151-3, 153-2, 153-4, 160-3, tour, demo-finish, jira-sync) + 125 tests across suites that parse `sm-setup.md` (153-1, 158-3, 158-4, 159-4, wrapper-removal, resolve-gate) — all passing, zero pre-adjustments
**Lint:** ruff clean on changed source
**Branch:** feat/155-33-session-template-branch-pr-fields (pushed, commits e0782cbf4 test + 3a902abe8 impl)

**Implementation matches the TEA designed interface exactly** (template placeholder shape, Step 5 field-update instruction, extraction normalization order: annotation strip → backtick strip → sentinel map).

**Handoff:** To Reviewer (the Queen of Hearts) for review phase

## Subagent Results

| # | Specialist | Received | Status | Findings | Decision |
|---|-----------|----------|--------|----------|----------|
| 1 | reviewer-preflight | Yes | clean | none | N/A — 107 tests pass (29 story + 78 consumer), lint clean, 0 smells, tree clean |
| 2 | reviewer-edge-hunter | Skipped | disabled | N/A | Disabled via settings — domain covered by me (see [EDGE] items) |
| 3 | reviewer-silent-failure-hunter | Skipped | disabled | N/A | Disabled via settings — domain covered by me (see [SILENT] items) |
| 4 | reviewer-test-analyzer | Skipped | disabled | N/A | Disabled via settings — domain covered by me (see [TEST] items) |
| 5 | reviewer-comment-analyzer | Skipped | disabled | N/A | Disabled via settings — domain covered by me (see [DOC] items) |
| 6 | reviewer-type-design | Skipped | disabled | N/A | Disabled via settings — domain covered by me (see [TYPE] items) |
| 7 | reviewer-security | Yes | findings | 4 | confirmed 4 (1 medium, 2 low, 1 informational-verified), dismissed 0, deferred 0 |
| 8 | reviewer-simplifier | Skipped | disabled | N/A | Disabled via settings — domain covered by me (see [SIMPLE] items) |
| 9 | reviewer-rule-checker | Skipped | disabled | N/A | Disabled via settings — Rule Compliance section below is my exhaustive pass |

**All received:** Yes (2 enabled returned; 7 disabled via settings)
**Total findings:** 4 confirmed, 0 dismissed, 0 deferred

## Reviewer Assessment

**Verdict:** APPROVED

No Critical or High issues. The template now carries the two load-bearing fields, the extraction layer handles the value shapes agents actually write, and the end-to-end tests exercise the REAL template — closing the fixtures-hand-write-everything gap that let 155-32 ship. One Medium residual (annotation-inside-backticks) is confirmed, reproduced, and routed as a follow-up; it does not undermine the primary fix because the template now instructs plain-text values and the observed live shapes are covered.

**Data flow traced:** session `**Branch:**` value → `_parse_session` (line-regex, last-wins) → `_extract_branch` (annotation strip → backtick strip → sentinel map, `story_finish.py:175-186`) → `gh pr list --head <branch>` (list-form argv, single execve token — no shell, no re-tokenization) → `pr_number` (regex `#(\d+)` / gh stdout digits) → consolidated `_pr_view` probe → conflict gate → `gh pr merge` → `_pr_is_merged` verification → done transition. Safe at each hop: garbage values cannot change command meaning (argv), cannot fake a PR number (digit regex), and cannot skip the 155-1 post-merge verification once a PR resolves.

**Findings (all confirmed, none blocking):**

| Severity | Tag | Issue | Location | Disposition |
|----------|-----|-------|----------|-------------|
| [MEDIUM] | [SEC][EDGE] | Order-of-operations residual: annotation INSIDE backticks (`` `feat/x (pushed)` ``) survives normalization as `feat/x (pushed)` — garbage head, PR resolution silently fails for that (unobserved) hand-written shape. Reproduced first-hand. | `story_finish.py:180-181` | Follow-up story: iterate strip pair to fixed point + test case. Not blocking: template now mandates plain text; both OBSERVED live shapes covered; 155-34 will convert any residual no-resolution into a loud abort. |
| [LOW] | [SEC] | Sentinel false-positive: a real branch literally named `none`/`na`/`null`/`-`/`—` coerces to None, disabling the fallback for that branch. | `story_finish.py:172` | Accepted risk under enforced `feat/{id}-{slug}` naming; fold tradeoff note into the same follow-up. |
| [LOW] | [SEC][TEST] | Test-isolation gap (PRE-EXISTING, whole finish family): `finish_story` Step 4c imports and calls `pf.demo.orchestrator.generate` unpatched — real `git`/`gh` subprocesses run against tmp_path and fail fast (non-fatal by design). Introduced by neither this diff nor this suite; shared by 155-1/12/15/16/29/31/32 harnesses. | `story_finish.py:789-803` | Follow-up: one autouse patch in the finish-test conftest. |
| [LOW] | [SEC] | Informational-verified: crafted Branch values (leading `-`, spaces, metacharacters) cannot become injection — list-form argv lands the whole value as one token; `--repo evil/x` shapes stay inert. Protection is the argv form itself. | `story_finish.py:380-385, 543` | No action; noted so nobody "simplifies" to `shell=True`. |

**Observations (beyond findings):**
1. `[VERIFIED]` Template placeholders extract safely — `agents/sm-setup.md:209-210` new lines are fully parenthesized; `_extract_branch` paren-strip → None, `_extract_pr_number` finds no `#\d` (proven by `test_instantiated_branch_value_never_garbage` and `test_pr_placeholder_yields_no_phantom_number`). Complies with lang-review #11 boundary normalization.
2. `[VERIFIED]` The gitflow-arm instruction is a blocking admonition ("Do not proceed to Step 6 until...") with the finish-ceremony rationale inline — `agents/sm-setup.md:316-326`. Complies with the gate-admonition pattern (preconditions, not suggestions).
3. `[VERIFIED]` `[SILENT]` No new exception paths: `_extract_branch` is a pure transform, no try/except added or removed; the sentinel→None mapping is documented at the constant (`story_finish.py:169-172`) and pinned by 9 parametrized tests. Complies with lang-review #1 / SOUL #10.
4. `[VERIFIED]` `[TEST]` Mutation resistance spot-checks: deleting any sentinel → its parametrized case fails; removing the backtick strip → 4 tests fail; removing either template line → 3 static + round-trip + e2e fail; `seen["list_heads"] == [BRANCH]` pins both probe count and cleanliness in one assert. No vacuous assertions found in the 584-line suite.
5. `[VERIFIED]` `[SIMPLE]` Minimal diff discipline: 16 lines of source change, no new abstractions beyond one module constant; template edits are instruction-only. Nothing to simplify without losing the tested contract.
6. `[EDGE]` `gh pr list --head <branch> --jq .[0].number` picks the FIRST PR when multiple PRs share a head branch (pre-existing, `story_finish.py:381`); with squash-and-delete-branch hygiene this is theoretical — noted, no action.
7. `[DOC]` The new template comment text and the `_BRANCH_SENTINELS` docstring both cite 155-33 and state the constraint the code can't show (why sentinels must map to None) — accurate, not stale. `[TYPE]` No new types warranted; `str | None` signature unchanged and correct.

### Rule Compliance

Python lang-review checklist vs the `story_finish.py` diff (the only Python source change) and the new test file:

| # | Rule | Instances in diff | Verdict |
|---|------|-------------------|---------|
| 1 | Silent exception swallowing | 0 new except blocks; sentinel mapping documented + tested | Compliant |
| 2 | Mutable default arguments | none in diff | N/A |
| 3 | Type annotation gaps | `_extract_branch(fields: dict[str, str]) -> str \| None` unchanged; constant matches file idiom (`_PR_VIEW_FIELDS` precedent) | Compliant |
| 4 | Logging coverage/correctness | pure function, no logging surface | N/A |
| 5 | Path handling | no file I/O in source diff; test file uses `encoding="utf-8"` on every read/write | Compliant |
| 6 | Test quality | 29 tests, all value-pinning asserts; green-on-arrival guards documented as intentional | Compliant |
| 7 | Resource leaks | none (no handles opened) | N/A |
| 8 | Unsafe deserialization | none | N/A |
| 9 | Async/await pitfalls | none | N/A |
| 10 | Import hygiene | zero new imports | Compliant |
| 11 | Input validation at boundaries | the diff IS the boundary normalization; residual: [MEDIUM] order-of-ops above | Compliant with confirmed follow-up |
| 12 | Dependency hygiene | zero new dependencies | Compliant |
| 13 | Fix-introduced regressions | swept: sentinel false-positive ([LOW], accepted) and order-of-ops residual ([MEDIUM], filed); 316 consumer + 125 template-family tests green | Compliant with findings recorded |

Tenant-isolation audit: no tenant-bearing types or trait-equivalent surfaces in this diff (session fields are single-user local files); the trust boundary audited is session-value → subprocess argv, traced above.

### Devil's Advocate

Assume this diff is a lie and 155-32 happens again next week — how? The strongest attack is that both halves of the fix are INSTRUCTIONS to a haiku subagent, not code. The template now contains the field lines, but sm-setup could still emit a session without them (it writes the file with the Write tool from prose instructions; nothing mechanical rejects a session missing `**Branch:**` — the schema-validation hook doesn't check it, which Dev filed as a finding). If the subagent drops the field, we are exactly where 155-32 was: extraction finds nothing, `gh pr list` never fires, Step 2 records skipped, done-with-open-PR. The honest defense is layered, not airtight: the static tests pin the TEMPLATE, the SM runbook pre-creates PRs and verifies merge state before bookkeeping, and 155-34 will make the no-resolution arm abort loudly — but until 155-34 lands, a dropped field still finishes silently. Second attack: a confused agent writes `**Branch:** `feat/x (pushed)`` — backticks around the whole annotated value — and the new normalization provably fails to clean it (reproduced). Third: the sentinel set is a blunt instrument; it can only be wrong in one direction (real branch named `none` → treated as no-branch → silent skip), and that direction is the epic's own failure mode — mitigated only by naming convention. Fourth: `_parse_session` is last-wins, so any later section's stray `**Branch:**` line silently overrides Story Details; a Dev assessment typo becomes the merge target resolver's input. None of these rise to blocking — each is either guarded by a shipped test, unobserved in practice, pre-existing, or explicitly owned by 155-34 — but the honest verdict is: this story fixes the DEFAULT path and the observed shapes, and the loud-abort backstop that makes the whole class un-lieable is the sibling story. The first attack (subagent drops the field) produced Dev's schema-validation-hook finding; I endorse promoting it.

**Error handling:** no new failure paths; garbage/absent branch degrades to None → no-PR arm (155-34's scope to harden); sentinel and backtick handling proven by parametrized tests. **Wiring:** template instructions → session file → finish extraction verified end-to-end by `TestFinishFromTemplateSession` (the suite's whole point). **Pattern observed:** designed-interface RED → verbatim GREEN (TEA docstring spec at `test_155_33_session_template_branch_pr_fields.py:44-58`, implemented 1:1) — good pattern, keeps review to spec-vs-code instead of archaeology.

**Handoff:** To SM for finish-story

## Delivery Findings

Agents record upstream observations discovered during their phase.
Each finding is one list item. Use "No upstream findings" if none.

**Types:** Gap, Conflict, Question, Improvement
**Urgency:** blocking, non-blocking

### TEA (test design)
- **Gap** (non-blocking): `_parse_session` is last-wins on duplicate field names — a hand-written `**Branch:**` in a later assessment section silently overwrites the Story Details field. Affects `pennyfarthing-dist/src/pf/sprint/story_finish.py` (`_parse_session`; consider first-wins or section-scoped parsing in a follow-up). *Found by TEA during test design.*
- **Question** (non-blocking): who records the `**PR:**` field when SM pre-creates the PR at finish time? sm-setup.md can only instruct its own template; the SM agent definition may need a matching "record the PR number in the session" instruction. Affects `pennyfarthing-dist/agents/sm.md` (out of this story's file scope). *Found by TEA during test design.*
- **Improvement** (non-blocking): after this fix a sentinel/absent branch extracts to None, which routes finish into the no-PR arm — sibling 155-34 (no-PR + unmerged commits must not mark done) is the story that makes that arm safe; the two compose but do not collide (verified: this suite pins nothing on the no-resolution outcome). Affects `pennyfarthing-dist/src/pf/sprint/story_finish.py`. *Found by TEA during test design.*

### Dev (implementation)
- **Improvement** (non-blocking): the session-schema validation hook (`pf hooks schema-validation`, PreToolUse:Write) does not require the `**Branch:**`/`**PR:**` fields it could now enforce mechanically — promoting the template contract into the hook would catch a subagent that drops the fields despite the template (SOUL #11). Affects `pennyfarthing-dist/src/pf/hooks/` (schema-validation session rules). *Found by Dev during implementation.*
- No other upstream findings during implementation.

### Reviewer (code review)
- **Improvement** (non-blocking): `_extract_branch` normalization is single-pass ordered (parens then backticks), so annotation-INSIDE-backticks (`` `feat/x (pushed)` ``) survives as garbage and silently defeats PR resolution ([MEDIUM], reproduced); fold with the sentinel-set tradeoff (real branch named `none` coerces to None, [LOW]) into one follow-up: iterate the strip pair to a fixed point + document the sentinel risk + two test cases. Affects `pennyfarthing-dist/src/pf/sprint/story_finish.py` (`_extract_branch`). *Found by Reviewer during code review.*
- **Improvement** (non-blocking): every finish-family test harness (155-1/12/15/16/29/31/32/33) leaves `finish_story` Step 4c demo generation unpatched — `pf.demo.orchestrator.generate` spawns real `git`/`gh` subprocesses against tmp_path that fail fast (non-fatal, pre-existing). One autouse patch in a shared conftest closes it for the whole family. Affects `pennyfarthing-dist/src/pf/tests/` (finish-family harnesses). *Found by Reviewer during code review.*
- **Improvement** (non-blocking): endorsing Dev's hook finding with review evidence — the Devil's Advocate's strongest attack (subagent emits a session without the fields despite the template) is only closed mechanically by promoting `**Branch:**`/`**PR:**` presence into `pf hooks schema-validation` for session writes. Affects `pennyfarthing-dist/src/pf/hooks/` (same follow-up as Dev's entry). *Found by Reviewer during code review.*

## Design Deviations

Agents log spec deviations as they happen — not after the fact.
Each entry: what was changed, what the spec said, and why.

### TEA (test design)
- **ACs authored by TEA into the test-file docstring** → ✓ ACCEPTED by Reviewer: established 155-10/155-13 precedent; docstring spec verified present and complete (AC-1..AC-5).
  - Spec source: context-story-155-33.md, Acceptance Criteria section
  - Spec text: "No acceptance criteria recorded in the sprint YAML — TEA to define during the RED phase."
  - Implementation: AC-1..AC-5 defined and recorded in the docstring of `test_155_33_session_template_branch_pr_fields.py`; that docstring is the authoritative AC record (155-10/155-13 precedent)
  - Rationale: the context file delegates AC authorship to TEA; the docstring keeps spec and enforcement in one place
  - Severity: minor
  - Forward impact: Reviewer judges AC coverage against the docstring, not the context file
- **Extraction hardening included beyond the title's template framing** → ✓ ACCEPTED by Reviewer: archived 155-32 session proves the backticked hand-written field shape live; same silent-skip mechanism, correctly kept inside this story; 155-34 boundary verified respected (no test pins the no-resolution outcome).
  - Spec source: story title (session file) + filing commit e0f2747
  - Spec text: "sm-setup session template omits Branch/PR fields, so finish silently skips the merge"
  - Implementation: suite also pins `_extract_branch` backtick-stripping and none-sentinel mapping (AC-3), not just the template fields
  - Rationale: the archived 155-32 session PROVES the second live failure mode — Dev hand-wrote a backticked `**Branch:**` field that could never resolve; fixing the template alone leaves the same silent skip reachable through the exact value shapes agents write. Same mechanism, same story (SOUL #1)
  - Severity: minor (scope extension within the same defect class)
  - Forward impact: Dev's diff touches `story_finish.py` as well as `agents/sm-setup.md`; 155-34's no-resolution behavior is explicitly NOT pinned
- **Green-on-arrival guards are intentional** → ✓ ACCEPTED by Reviewer: all 11 verified as preservation pins that fail under over-application; not spurious.
  - Spec source: AC-2/AC-5 (test-file docstring)
  - Spec text: preservation requirements ("plain fields keep working", "placeholder yields no phantom number")
  - Implementation: 11 tests pass on HEAD by design (round-trip garbage-free, PR-placeholder None, existing extraction shapes, PR-number shapes)
  - Rationale: `ac-as-green-regression-guard` — they go red only if the fix over-applies (e.g. normalization breaking plain values)
  - Severity: minor
  - Forward impact: gate/Reviewer must not read the 11 passes as spurious
- **Static outside-fence instruction test constrains fix shape** → ✓ ACCEPTED by Reviewer: cheapest mechanical proxy for un-testable subagent runtime behavior (SOUL #11); wording left free, verified non-brittle against the shipped fix.
  - Spec source: AC-1 (test-file docstring)
  - Spec text: "the document instructs (outside the template fence) how the real branch is recorded into the **Branch:** field"
  - Implementation: `test_branch_field_instruction_outside_template` requires the literal token `**Branch:**` somewhere outside the Step 4 fence
  - Rationale: a field that nothing ever fills stays a placeholder forever; any correct instruction must name the field, so the token test is the cheapest mechanical proxy (a haiku subagent's runtime behavior is otherwise untestable — SOUL #11)
  - Severity: minor
  - Forward impact: Dev must reference the field in prose (Step 5 arm or equivalent); wording is free

### Dev (implementation)
- **Stacked-arm Branch-field instruction added beyond test coverage** → ✓ ACCEPTED by Reviewer: stacked repos create real branches; omitting the arm would reproduce the exact defect on stacked stories; instruction-only, zero behavioral risk.
  - Spec source: TEA designed interface (session file) / AC-1 (test-file docstring)
  - Spec text: "Step 5 gitflow arm instructs updating `**Branch:**` to the real branch ... trunk-based arm keeps a parenthesized note" — the stacked-PR arm is not mentioned and no test pins it
  - Implementation: the stacked arm (`gt create feat/{STORY_ID}-{SLUG}`) also instructs updating the `**Branch:**` field like the gitflow arm
  - Rationale: stacked repos create a real branch too; leaving the field a placeholder there would reproduce the exact 155-33 silent-skip on stacked stories
  - Severity: minor
  - Forward impact: none — instruction-only; behavior identical to the gitflow arm the tests do pin
- No other deviations: implementation follows the TEA designed interface verbatim.
## SM Finish Addendum — Incident Record (2026-08-01)

**The finish ceremony's Step 2 record above is untruthful.** `pf sprint story finish 155-33` reported `merge_pr` and completed the full done ceremony, but PR #165 was still OPEN — the no-PR skipped arm ran, not a merge.

**Root cause (proven against this exact file):** `SESSION_FIELD_RE` is an unanchored `search` and `_parse_session` is last-wins, so later PROSE in this session that merely mentions the field tokens overrode the real Story Details fields. Finish parsed `branch` = `'field like the gitflow arm'` (a fragment of the Dev deviation entry) and `pr` = a fragment of TEA's Question finding (no digits → None). The garbage head probe returned nothing, pr resolved to None, and the skipped arm completed the ceremony — done-while-PR-open, the epic's own bug class, one layer deeper than 155-33 fixed.

**Recovery:** PR #165 merged manually and VERIFIED (state=MERGED, mergedAt=2026-08-01T11:14:02Z, develop=1bbf64004); local branch cleaned up. Follow-up **155-40** (p1) filed: anchor the field regex to line start and scope Branch/PR resolution to the Story Details block. TEA's last-wins Gap finding above is superseded by this live evidence.

**Truth state:** story code IS merged; the `done` status is now accurate. Only the Step 2 record in the ceremony output was false.
