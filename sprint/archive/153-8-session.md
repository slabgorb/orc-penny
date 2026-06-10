---
story_id: "153-8"
jira_key: ""
epic: ""
workflow: "tdd"
---
# Story 153-8: DX bundle — pf sprint story update --title, error messages list candidate IDs on not-found, --brief agent activation mode, document auto-PR behavior on git push

## Story Details
- **ID:** 153-8
- **Jira Key:** (none — local sprint)
- **Workflow:** tdd
- **Stack Parent:** none

## Workflow Tracking
**Workflow:** tdd
**Phase:** finish
**Phase Started:** 2026-06-10T17:14:41Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-06-10T16:57:38+00:00 | 2026-06-10T16:59:13Z | 1m 35s |
| red | 2026-06-10T16:59:13Z | 2026-06-10T17:05:32Z | 6m 19s |
| green | 2026-06-10T17:05:32Z | 2026-06-10T17:09:13Z | 3m 41s |
| review | 2026-06-10T17:09:13Z | 2026-06-10T17:14:41Z | 5m 28s |
| finish | 2026-06-10T17:14:41Z | - | - |

## Sm Assessment

**Setup complete; routing to TEA for red phase.**

- Session and story context created; feature branch `feat/153-8-dx-bundle` off `develop` in `pennyfarthing/`, checked out.
- Jira intentionally skipped — local-only sprint.
- Scope: four bundled DX improvements — (1) `pf sprint story update --title`, (2) not-found errors list candidate story IDs, (3) `pf agent start --brief` condensed activation, (4) document auto-PR-on-push behavior (docs-only). Items 1–3 need tests; default behaviors must remain unchanged.
- Mode: peloton-inline — SM drives TEA → Dev → Reviewer as subagents (Opus); SM owns PR create/merge and finish ceremony.

## Tea Assessment

**Tests Required:** Yes (items 1–3). Item 4 is docs-only — spec below, no tests.

**Test Files (RED, failing on HEAD):**
- `pennyfarthing-dist/src/pf/tests/test_153_8_story_update_title.py` — item 1
- `pennyfarthing-dist/src/pf/tests/test_153_8_not_found_candidates.py` — item 2
- `pennyfarthing-dist/src/pf/tests/test_153_8_agent_start_brief.py` — item 3

**Status:** RED — 27 failed, 3 passed. The 3 passers are intentional
default-unchanged / no-op guards (already-correct behavior on HEAD):
- `TestTitleDefaultUnchanged::test_other_field_update_preserves_title`
- `TestUpdateNotFoundListsCandidates::test_error_names_the_missing_id`
- `TestDefaultUnchanged::test_default_still_includes_everything`

Failures are all clean feature-absence (`TypeError: unexpected keyword 'title'`,
`ImportError: format_story_not_found_error`, `prime() must accept 'brief'`,
`--brief`/`--title` "No such option"). Related existing suites green:
`test_156_1_story_update_shards.py`, `test_story_update.py`, `test_tiers.py`
(87 passed) — fixtures/expectations match real code paths.

Commit: `6e1d68d74` on `feat/153-8-dx-bundle`.

---

### Designed Interface (Dev implements this verbatim)

#### Item 1 — `story update --title`
`pf/sprint/story_update.py`:
- Add keyword to `update_story(...)`: `title: str | None = None` (place
  alongside the other optional scalar params).
- Apply: `if title is not None: story["title"] = title` (in the field-update
  block, before `validate_sprint_document`). No special validation needed —
  `title` is already a REQUIRED, validated story field
  (`validator.REQUIRED_STORY_FIELDS` / `REQUIRED_SHARD_STORY_FIELDS`); the
  existing post-mutation validate + `write_sprint` shard-aware persist covers it.
- Add Click option: `@click.option("--title", default=None, help="New story title")`
  and thread `title=title` into the `update_story(...)` call.
- Default (no `--title`) must be a no-op: title defaults to None → untouched.

#### Item 2 — not-found errors list candidate IDs (shared helper)
`pf/sprint/loader.py` — add ONE helper, called by every lookup-fail site so the
behavior never drifts:
```
def format_story_not_found_error(sprint_data, story_id: str) -> str: ...
```
Required behavior (asserted by tests; exact prose is Dev's choice):
- Names the missing `story_id`.
- Lists available story IDs gathered from epics + standalone_stories + stories
  (walk the merged data; reuse the same sections `find_story_in_data` searches).
- **Near-misses first:** rank candidates by closeness to `story_id` (e.g.
  difflib / shared epic-prefix / edit distance) so a near miss like `153-7`
  is listed *before* a distant `999-1` when the user typed `153-9`.
- The bare legacy string alone is no longer acceptable (must be augmented).

Call sites to switch to the helper (build `data` is already in scope at each):
- `story_update.py` line ~96 (`if story is None:` branch).
- `story_remove.py` line ~41 (`if story is None:` branch).
- `story finish` shares `find_story_in_data` — if/where it emits the bare
  not-found message, route it through the same helper (verify during GREEN).

#### Item 3 — `pf agent start --brief`
DESIGN DECISION: `--brief` == the existing **HANDOFF** tier. Do NOT invent a
second code path. `prime(..., brief=True)` short-circuits to the same path as
`tier="HANDOFF"`.
- `pf/prime/cli.py`:
  - Add `brief: bool = False` to `prime(...)`. Near the top (after `minimal`
    handling, before tier parsing), do: `if brief and not tier: tier = "HANDOFF"`
    (or set `context_tier = ContextTier.HANDOFF`). Must occur before the
    `if context_tier and context_tier != FULL:` dispatch so it routes to
    `_prime_tiered`.
  - `brief` MUST default to False; default activation byte-identical to today.
  - Add `@click.option("--brief", is_flag=True, help="Condensed activation (agent essentials only)")`
    to BOTH `prime_cmd` (in this file) and thread `brief=brief` through.
- `pf/cli.py`:
  - Add `@click.option("--brief", is_flag=True, help="Condensed activation (agent essentials only)")`
    to `agent_start`, add `brief: bool` param, pass `brief=brief` into `prime(...)`.
- KEEP in brief: workflow state, agent definition, compressed persona, repos topology.
- DROP in brief: SOUL.md, output style, full persona, behavior guide, sprint
  context, session header/assessment, sidecars (this is exactly HANDOFF today).
- Tests pin `brief_out == handoff_out` (byte-identical) to enforce single path.

#### Item 4 — document auto-PR-on-push (DOCS ONLY, no tests)
**INVESTIGATION FINDING (see Delivery Findings):** there is **no** auto-PR-on-push
hook in the framework. The only push hook is
`pennyfarthing-dist/scripts/hooks/pre-push.sh`, which merely *reminds* about
Jira sync when `sprint/current-sprint.yaml` changed — it does **not** run
`gh pr create`. PR creation actually happens during `sm-finish` /
`pf sprint story finish` / `pf sprint standalone`, NOT on push. The story's
premise ("pushing a feature branch auto-creates a PR") does not match the code.

**Doc spec for Dev/Tech-Writer (truthful version):**
- Location: new section in `pennyfarthing-dist/guides/hooks.md` under
  "Git Hooks" (expand the existing `pre-push.sh` bullet, line ~123), OR a short
  dedicated `guides/git-push-and-pr.md` cross-linked from hooks.md. Prefer
  expanding hooks.md to avoid guide sprawl.
- Required content:
  1. **What pre-push actually does:** location
     (`.pennyfarthing/scripts/hooks/pre-push.sh`), trigger (git `pre-push`,
     installed via `pf git install-hooks` dispatcher `.d/`), behavior (warns on
     uncommitted/changed `sprint/current-sprint.yaml`, reminds to sync Jira).
     It is advisory only — `exit 0` always; never blocks, never opens a PR.
  2. **Where PRs are actually created:** `sm-finish` /
     `pf sprint story finish` / `pf sprint standalone` (via `gh pr create`),
     i.e. at story-finish time, not on push.
  3. **How to disable the reminder:** remove/disable the `pre-push` entry in
     `.git/hooks/pre-push.d/` (or skip with `git push --no-verify`).
- The guide must NOT claim auto-PR-on-push exists.

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/src/pf/sprint/story_update.py` — added `title` kwarg to `update_story` + `--title` Click option; routed not-found through shared helper.
- `pennyfarthing-dist/src/pf/sprint/loader.py` — added `format_story_not_found_error` (+ `_collect_story_ids`); near-misses ranked first via difflib.
- `pennyfarthing-dist/src/pf/sprint/story_remove.py` — routed not-found through shared helper.
- `pennyfarthing-dist/src/pf/prime/cli.py` — added `brief` param to `prime()` (defaults False, short-circuits to HANDOFF tier) + `--brief` option on `prime_cmd`.
- `pennyfarthing-dist/src/pf/cli.py` — added `--brief` option to `agent start`, threaded `brief=` into `prime()`.
- `pennyfarthing-dist/guides/hooks.md` — documented real pre-push behavior (Jira-sync reminder, exit 0, no PR); explicit "no auto-PR-on-push"; PRs created at story-finish; how to disable.

**Tests:** 30/30 new passing; 87 existing (test_156_1_story_update_shards, test_story_update, test_tiers) still green — 117 total passing (GREEN). Ruff clean on changed files.
**Branch:** feat/153-8-dx-bundle (committed)

**Handoff:** To review phase.

## Subagent Results

Inline peloton mode — specialist analyses run directly by Reviewer (not spawned as subagents).

| # | Specialist | Received | Status | Findings | Decision |
| 1 | reviewer-preflight | Yes | mostly clean | 117 targeted tests pass; ruff I001 in 1 new test file (Low) | CONFIRMED (Low) |
| 2 | reviewer-edge-hunter | Yes | findings | empty-string title accepted+persisted (Low); YAML-special chars round-trip safely (good); `--brief`/`--tier` precedence sane | CONFIRMED empty-title (Low); dismissed special-char (ruamel quotes) |
| 3 | reviewer-silent-failure-hunter | Yes | finding | `story_finish` silently proceeds on unknown story id — no not-found error surfaced (Medium, AC gap) | CONFIRMED (Medium) |
| 4 | reviewer-test-analyzer | Yes | clean | 30 new tests pin shard persistence, byte-identical brief↔handoff, near-miss ordering; no vacuous assertions; no finish test (mirrors the wiring gap) | CONFIRMED |
| 5 | reviewer-comment-analyzer | Yes | finding | item-4 doc overstates `pf sprint story finish` as a `gh pr create` site (Medium); TEA docstring claim re: finish coverage inaccurate | CONFIRMED (Medium) |
| 6 | reviewer-security | Yes | clean | no security surface — title strings round-trip via ruamel (quoted, no YAML injection); no auth/network/eval/subprocess-with-user-input added; difflib over local ids only | N/A |

All received: Yes

## Reviewer Assessment

**Verdict:** APPROVED (with deferred findings)

**Data flow traced:** `pf sprint story update 153-8 --title "X"` → `story_update_command` → `update_story(title=...)` → `find_story_in_data` (locates story dict in merged shard data) → `story["title"]="X"` → `validate_sprint_document` → `write_sprint` (shard-aware: re-writes `epic-153.yaml`, not raw index). Verified by `test_title_update_persists_to_shard` + manual run: title lands in the correct shard, siblings untouched, default (no `--title`) is a no-op. **Shard-write landmine avoided** — write goes through `write_sprint`, never a raw-YAML write.

**Pattern observed:** Single shared helper `format_story_not_found_error` in `loader.py:455` consumed by both `story_update.py:100` and `story_remove.py:44` — correct one-truth pattern, no drift between the two wired call sites. Near-miss ranking via `difflib.SequenceMatcher` is sane (verified `153-7` precedes `999-1` for input `153-9`).

**Error handling:** `--brief` precedence is unambiguous — `prime/cli.py:424` `if brief and not tier` means explicit `--tier` wins; `tier_from_string` is case-insensitive so `"HANDOFF"` resolves cleanly. `test_brief_output_matches_handoff_tier` proves byte-identical single code path; `test_default_still_includes_everything` guards the unchanged default. YAML-special chars in titles round-trip safely (ruamel quotes them) — no injection.

**Observations (verified good):** (1) write path is shard-aware end-to-end; (2) helper is genuinely shared update↔remove; (3) `--brief` is a true single path, not a forked formatter; (4) item-4 doc correctly states pre-push.sh is advisory-only / `exit 0` / no auto-PR — matches the actual script.

**[SEC] Security:** No new security surface. Title input round-trips through ruamel (special chars quoted — no YAML injection, verified manually with `weird: "value" #now [list] {map}`). No auth/network/`eval`/user-input-subprocess added; `difflib.SequenceMatcher` operates only over local sprint story ids. Clean.

| Severity | Issue | Location | Fix Required |
|----------|-------|----------|--------------|
| [MEDIUM] | AC says "not-found errors from update/**remove/finish** list candidate IDs," but the helper is NOT wired into `story_finish`. `story_finish` uses `find_story_in_data` only for jira-key lookup and **silently proceeds** on an unknown id (no not-found error surfaced at all). AC partially unmet; TEA's claim that finish is "covered via the same resolver" conflates resolver-sharing with error-formatting and is backed by no finish test. | `story_finish.py:190,332,402` | Follow-up: add a not-found guard in `story_finish` that returns `format_story_not_found_error(...)`. Low-traffic path (finish runs on real in-flight stories), so deferred, not blocking. |
| [MEDIUM] | Item-4 doc replaces a false premise with a subtler inaccuracy: it lists `pf sprint story finish <id>` as a place where "PR creation happens" and says "each of these invokes `gh pr create`." `story_finish.py` only **merges** an existing PR (`gh pr merge`), it never runs `gh pr create`. Real PR-create sites are `sm-finish` (agent md) and the standalone flow. | `guides/hooks.md` (pre-push section) | Follow-up: correct the doc to say `pf sprint story finish` merges a pre-existing PR; PR creation is `sm-finish` / `standalone` only. |
| [LOW] | `--title ""` (empty string) is accepted and persists a blank title on a REQUIRED field — validator does not reject it. Consistent with existing `--description`/other string fields (same no-empty guard), so not a regression. | `story_update.py:106` | Optional: reject empty `title`. Deferred. |
| [LOW] | Ruff I001 (import-block sort) in new test file; auto-fixable. Dev reported "ruff clean" — minor miss. | `tests/test_153_8_agent_start_brief.py:30` | `ruff check --fix`. |

**Deviation audit:** Both TEA deviations ACCEPTED — (a) `--brief`→HANDOFF reuse is the correct no-drift design and is byte-identical-tested; (b) item-4 documenting actual no-auto-PR behavior is the right call (the premise was false). No undocumented deviations found in the diff beyond the finish-wiring gap noted above.

**Tests:** 117 passed (30 new + 87 existing: test_156_1_story_update_shards, test_story_update, test_tiers) on targeted run. No vacuous assertions — title tests pin shard persistence + sibling isolation, brief tests pin byte-identical equivalence, not-found tests pin near-miss ordering.

**Handoff:** To SM for finish-story. None of the findings are Critical/High; the two Mediums are AC/doc-accuracy gaps suitable for a follow-up story.

## Delivery Findings

### TEA (test design)
- **Conflict** (non-blocking): Story item 4 assumes "pushing a feature branch
  auto-creates a PR." No such automation exists. `pre-push.sh` only prints a
  Jira-sync reminder (`exit 0`, no `gh pr create`); PRs are created at
  story-finish (`sm-finish` / `story finish` / `standalone`). Affects the item-4
  doc — it should document the *real* push/PR flow and explicitly note auto-PR
  is not a thing. *Found by TEA during investigation.*

### Reviewer (code review)
- **Gap** (non-blocking): AC names update/remove/**finish** for candidate-ID
  not-found errors, but the shared helper is only wired into update + remove.
  `story_finish` uses `find_story_in_data` for jira-key lookup only and silently
  proceeds on an unknown id — no not-found error is surfaced there at all.
  Affects `story_finish.py` (add a not-found guard returning
  `format_story_not_found_error`). Low-traffic path; deferred to follow-up.
  *Found by Reviewer during code review.*
- **Gap** (non-blocking): item-4 doc (`guides/hooks.md`) overstates — it lists
  `pf sprint story finish <id>` as a `gh pr create` site, but that command only
  *merges* a pre-existing PR (`gh pr merge`). Real create-sites are `sm-finish`
  and the standalone flow. Affects the hooks.md pre-push section (correct the
  finish claim). *Found by Reviewer during code review.*

## Impact Summary

**Upstream Effects:** No upstream effects noted
**Blocking:** None

## Design Deviations

### TEA (test design)
- **--brief implementation:** Story said "design what --brief keeps vs drops."
  Tests pin `--brief` to the **existing HANDOFF tier** (byte-identical) rather
  than a bespoke section set. Reason: HANDOFF already keeps exactly the brief
  essentials (workflow/agent-def/compressed-persona/topology) and drops the
  heavyweight sections; reusing it avoids a second drifting code path.
- **Item 4 doc content:** Spec documents the *actual* (no-auto-PR) behavior
  rather than the premise in the story title. Reason: the auto-PR-on-push
  automation does not exist in the codebase (see Delivery Findings).

## Story Description

DX bundle — four small developer experience improvements:

1. `pf sprint story update <id> --title <new title>` — title is currently not updatable via CLI
2. Story-not-found error messages should list candidate/near-miss story IDs (e.g. all IDs in the sprint, or fuzzy matches) instead of the bare "Story 'X' not found in epics, standalone_stories, or stories"
3. `--brief` agent activation mode — `pf agent start <name> --brief` emitting a condensed activation (skip or trim heavyweight sections) for quick activations
4. Document the auto-PR behavior on git push (there is hook/automation behavior where pushing a feature branch auto-creates a PR — document where it lives, how it triggers, how to disable; this is docs-only)

## Acceptance Criteria

- `pf sprint story update X-Y --title "New"` updates the story title in the correct shard, validated
- Not-found errors from story update/remove/finish list available story IDs to help the user self-correct
- `pf agent start <name> --brief` produces condensed activation output; default behavior unchanged
- Auto-PR-on-push behavior documented in the appropriate guide under pennyfarthing-dist/guides/
- Tests cover items 1-3 (item 4 is docs-only)

## Delivery Findings

No upstream findings.

## Design Deviations

No deviations at setup time.