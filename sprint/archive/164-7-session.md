---
story_id: "164-7"
jira_key: ""
epic: "164"
workflow: "tdd"
---
# Story 164-7: Add --description/body option to pf sprint story add so minted follow-ups carry provenance in the story body (155-13 review)

## Story Details
- **ID:** 164-7
- **Jira Key:** (none — Jira not enabled for this project)
- **Workflow:** tdd
- **Stack Parent:** none
- **Branch:** feat/164-7-story-add-description-option
- **PR:** (none yet — recorded when the PR is created)

## Workflow Tracking
**Workflow:** tdd
**Phase:** finish
**Phase Started:** 2026-08-10T17:12:41Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-08-10T16:46:50Z | - | - |

## Technical Discovery

### Command Implementation Location
- **Source file:** `/Users/keithavery/Projects/op-1/pennyfarthing/pennyfarthing-dist/src/pf/sprint/story_add.py`
- **Primary entry point:** `story_add_command()` (lines 297–427) — Click CLI handler
- **Core logic:** `add_story()` (lines 61–171) — programmatic story creation

### YAML Schema
- **Canonical key order:** `STORY_KEY_ORDER` in `yaml_io.py` (lines 51–73)
- **Description field:** Already defined at position 55 in STORY_KEY_ORDER
- **Field name:** `description` (confirmed in sprint YAML shards, e.g., epic-162.yaml, epic-163.yaml, epic-164.yaml)
- **Value format:** Block scalar (multiline safe via `LiteralScalarString` in `_ensure_block_scalars()`)

### Current `story_add_command()` Options
- `--type`, `--priority`, `--workflow`, `--jira`, `--sprint-file`, `--initiative`, `--repos`, `--depends-on`, `--epic`, `--dry-run`
- **No description/body option exists** — must be added

### Implementation Strategy

#### AC 1: Add CLI option
- **Add to `story_add_command()` signature** (line 297):
  ```python
  @click.option("--description", type=str, default=None, help="Story description (provenance text)")
  @click.option("--body", "description", type=str, default=None, help="Alias for --description")
  ```
  **Note:** Click supports aliasing via identical parameter names with different option names. The `description` parameter will receive either `--description TEXT` or `--body TEXT`.
  
  **Alternative approach:** Use explicit parameter-name alias:
  ```python
  def story_add_command(..., description: str | None = None, ...):
  ```
  Then pass to `add_story(description=description)`.

- **Pass to `add_story()` and `add_initiative_story()`** — both need the new parameter

#### AC 2: Update `add_story()` function signature
- **Add parameter** (line 61):
  ```python
  def add_story(
      sprint_path: Path,
      epic_id: str,
      title: str,
      points: int,
      *,
      story_type: str | None = None,
      priority: str = "P1",
      workflow: str = "tdd",
      jira: str | None = None,
      repos: str | None = None,
      depends_on: str | None = None,
      plan_ref: str | None = None,
      description: str | None = None,  # NEW
  ) -> dict[str, Any]:
  ```

- **Add to story fields dict** (lines 120–137):
  ```python
  if description is not None:
      fields["description"] = description
  ```

- **Insert into STORY_KEY_ORDER** — already at position 55, so proper ordering is automatic

#### AC 3: Update `add_initiative_story()` function
- **Same pattern:** add `description: str | None = None` parameter, insert into story dict if not None

#### AC 4: Test round-trip
- **Create new test** (e.g., `test_164_7_story_add_description_field.py`):
  1. Call `add_story(..., description="My provenance text")` 
  2. Re-read sprint YAML via `read_sprint()`
  3. Assert story["description"] == "My provenance text"
  4. Test multiline text: `description="Line 1\nLine 2\nLine 3"`
  5. Test special YAML chars: `description="Key: value, [array], {object}"`
  6. Test empty/None: omit description, verify field is absent or null

#### AC 5: Backward compatibility
- **Default to None** — omitting `--description` produces no field in the story dict
- **YAML serialization:** `_ensure_block_scalars()` already handles multiline safety
- **Existing stories unaffected** — no description field, no change to existing round-trip

### Acceptance Criteria Mapping

| AC | Implementation | Test Location |
|----|----|---|
| `pf sprint story add` accepts `--description TEXT` | Add option + parameter to `story_add_command()` + `add_story()` | `test_164_7_story_add_description_field.py` |
| `--body` alias works (if review intends) | Click alias support or explicit parameter mapping | Same test |
| Value written to `description` field in YAML | Insert into `fields` dict in `add_story()`, positioned via `STORY_KEY_ORDER` | Test: read back from YAML |
| Omitting option preserves current behavior | Default `description=None`, conditional insertion | Test: add story without flag |
| Round-trip: add, read, assert | Programmatic test: `add_story(..., description=TEXT)` → `read_sprint()` → verify | `test_164_7_story_add_description_field.py` |
| Multiline / special chars safe (no YAML corruption) | `LiteralScalarString` in `_ensure_block_scalars()` already handles this | Test: multiline + YAML special chars |

### Notes
- **Jira Integration:** Disabled for this project (`is_jira_enabled() == False`) — no Jira claim required
- **Branch Strategy:** Gitflow (pennyfarthing repo) — PR targets `develop`
- **Story Type:** No type field set (defaults to `feature` in CLI)
- **Related Story:** 155-13 is the review that surfaced this feature request (follow-up minting flow likely calls `add_story()` programmatically and could pass description text)

## TEA Assessment

**Tests Required:** Yes
**Reason:** New CLI option and programmatic parameter both need round-trip coverage.

**Test Files:**
- `pennyfarthing/pennyfarthing-dist/src/pf/tests/test_164_7_story_add_description.py` — 23 tests covering all 4 ACs

**Tests Written:** 23 tests covering 4 ACs
**Status:** RED (19 failing, 4 passing — correct)

**--body alias decision:** BOTH `--description` and `--body` tested. The session's implementation strategy explicitly includes `--body` as a Click alias binding to the same `description` parameter. Tests enforce that `--body` writes to `description` field (not a separate `body` key).

**RED failure one-liners:**
- Programmatic (14 tests): `TypeError: add_story() got an unexpected keyword argument 'description'`
- CLI `--description` (3 tests): `No such option: --description` (exit_code 2)
- CLI `--body` (3 tests): `No such option: --body` (exit_code 2)
- Compat `test_none_description_not_stored` (1 test): same TypeError

**4 passing (correct):** backward-compat tests that call `add_story()` without `description=` and invoke CLI without `--description` — these pass today and must keep passing after implementation.

**Commit:** ae494d509 on `feat/164-7-story-add-description-option`

**Handoff:** To Dev for implementation

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/src/pf/sprint/story_add.py` - Added `description: str | None = None` kwarg to `add_story()`, conditional field insertion, `--description`/`--body` Click options, and wired through to `add_story()` call

**Tests:** 23/23 passing (GREEN) — plus 52 regression tests all green (75 total)
**Branch:** feat/164-7-story-add-description-option (pushed)

**Handoff:** To Reviewer

## Delivery Findings

No upstream findings at setup stage.

<!-- Agents: append findings below this line. Do not edit other agents' entries. -->

### Reviewer (code review)
- **Gap** (blocking): Initiative path silently drops `description`. `story_add_command` accepts `--description`/`--body` and passes `description=` to `add_story()` in the epic branch, but the initiative branch at line 381 calls `add_initiative_story()` — which has no `description` parameter — without passing the value. User gets exit code 0 and success output with the description silently discarded. Affects `pennyfarthing-dist/src/pf/sprint/story_add.py:381` (fix: either add `description` to `add_initiative_story()` or raise `click.BadParameter` when `--description` is used with `--initiative`). *Found by Reviewer during code review.*
- **Gap** (non-blocking): `description=""` (empty string) passes the `is not None` guard at line 140 and writes `description: ""` to YAML. Undocumented, untested. Affects `pennyfarthing-dist/src/pf/sprint/story_add.py:140`.
- **Gap** (non-blocking): Both `--description` and `--body` in one invocation — Click last-write-wins silently, no error. Untested contract. Affects `pennyfarthing-dist/src/pf/sprint/story_add.py:334`.
- **Gap** (non-blocking): `test_description_appears_in_result_dict` asserts only `result["success"] is True` — never verifies description is in result dict (test name is misleading). Affects `test_164_7_story_add_description.py:159`.
- **Gap** (non-blocking): `test_shard_not_corrupted_by_special_description` — `data is not None` check is vacuous (read_sprint raises on failure). Missing content assertions. Affects `test_164_7_story_add_description.py:516`.

## Subagent Results

| # | Specialist | Received | Status | Findings | Decision |
|---|-----------|---------|--------|----------|----------|
| 1 | reviewer-preflight | Yes | clean | 23/23 pass, 3108/3111 regression green (1 pre-existing fail on develop), no smells, no skips | N/A |
| 2 | reviewer-edge-hunter [EDGE] | Yes | findings | Initiative silent drop (HIGH); both-flags last-write-wins undocumented (MEDIUM); STORY_KEY_ORDER position correct | Confirmed HIGH + MEDIUM |
| 3 | reviewer-test-analyzer [TEST] | Yes | findings | `test_description_appears_in_result_dict` misleading (MED); shard-corruption near-vacuous (MED); no both-flags test; no empty-string test | Confirmed MEDs |
| 4 | reviewer-silent-failure-hunter [SILENT] | Yes | findings | Initiative silent drop confirmed; pre-existing open() without encoding= in yaml_io.py (not in diff) | Confirmed HIGH |
| 5 | reviewer-comment-analyzer [DOC] | Yes | findings | `test_description_appears_in_result_dict` method name stale (LOW); shard test string trimmed dropping `"quote"` char, docstring still says "complex" (LOW) | acknowledged — both LOW, non-blocking |
| 6 | reviewer-rule-checker [RULE] | Yes | clean | Result-object pattern preserved; no scope creep; no rule violations | none |
| 7 | reviewer-security [SEC] | Yes | clean | ruamel.yaml serialization prevents YAML injection; no path traversal; no credentials; no network calls | none |
| 8 | reviewer-simplifier [SIMPLE] | Yes | clean | Conditional insertion matches sibling pattern (jira, story_type); no over-engineering | none |
| 9 | reviewer-type-design [TYPE] | Yes | clean | `str | None = None` matches add_story() type; keyword-only placement correct; no invariants broken | none |

All received: Yes

## Reviewer Assessment

**Verdict:** REJECTED

R1 (commit 1a0887692): [HIGH] initiative silent drop [SILENT][EDGE] + [MED] misleading test [TEST] + [MED] vacuous shard-corruption assertion [TEST] + two LOWs. Dev addressed all in commit c36c1cfb3.

## Reviewer Assessment

**Verdict:** APPROVED

R2 scoped re-review of fix commit c36c1cfb3:

| Finding | Status |
|---------|--------|
| [HIGH] Initiative silent drop (`story_add.py:381`) [SILENT][EDGE] | ADDRESSED — `add_initiative_story()` gains `description: str | None = None` keyword param; initiative call site passes `description=description`; 2 new round-trip tests confirm persistence and backward compat |
| [MED] `test_description_appears_in_result_dict` misleading [TEST] | ADDRESSED — now reads back from YAML via `read_sprint()` and asserts exact value |
| [MED] Shard corruption test near-vacuous [TEST] | ADDRESSED — now asserts all fields of pre-existing story intact, no description leak, new story description exact |

[DOC] Two LOWs: `test_description_appears_in_result_dict` method name still says "result_dict" after body was refactored to YAML read-back (`test_164_7_story_add_description.py:160`); shard-corruption test string trimmed to drop `"quote"` char but docstring still says "complex description" (`test_164_7_story_add_description.py:542`). Neither is blocking. [RULE] no rule violations. [SEC] ruamel.yaml serialization prevents YAML injection; no path traversal; no credentials. [SIMPLE] conditional insertion matches jira/story_type sibling pattern. [TYPE] `str | None` matches add_story(); keyword-only, consistent.

**New breakage scan:** Zero other callers of `add_initiative_story` outside changed files. New param keyword-only with `None` default — all existing callers safe. No STORY_KEY_ORDER regression. 25/25 tests pass.

**Handoff:** To SM for finish-story.

## Design Deviations

### TEA (test design)
- **--body alias included:** Spec said decision pending, session strategy confirms `--body` as Click alias for `--description`. Tests cover both. If Dev determines `--body` should be omitted, drop `TestBodyAlias` and note the decision.

<!-- Agents: append deviations below this line. Do not edit other agents' entries. -->