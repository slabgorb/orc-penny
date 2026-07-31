---
story_id: "155-13"
jira_key: ""
epic: "155"
workflow: "tdd"
---
# Story 155-13: Auto-suggest follow-up stories at finish for deferred Delivery Findings (gh #114)

## Story Details
- **ID:** 155-13
- **Jira Key:** (none — tracked via gh issue #114)
- **Workflow:** tdd
- **Repos:** pennyfarthing
- **Branch:** feat/155-13-finish-followup-suggest
- **Stack Parent:** none

## Acceptance Criteria

From gh #114, the feature requires:

1. **Detection heuristics** — scan session's `## Delivery Findings` and `## Design Deviations` for deferrals:
   - Delivery Finding of type `Improvement` or `Question` with `urgency: non-blocking`
   - Design Deviation with `Forward impact` field naming another story/epic or future work (not "none")
   - Reviewer findings tagged with "follow-up", "later", "future", "defer", "out of scope", "tracked"

2. **Behavior** — emit a "Deferred follow-ups detected" block at sm-finish:
   - List each candidate with pre-filled `pf sprint story add` command
   - Operator can run or skip each suggestion

3. **Deduplication** — before suggesting, check whether the finding is already covered by existing backlog/future stories
   - String/semantic match against open stories in the epic
   - Don't re-suggest what's already in scope

4. **Provenance** — any minted/suggested story back-references source
   - Story body line: `"from <STORY_ID> review"` or similar
   - Audit trail survives post-archive

5. **Hook placement** — integration point is sm-finish preflight
   - Runs before `archive_session` and `remove_session`
   - Session still live, deferrals in working memory

## Workflow Tracking
**Workflow:** tdd
**Phase:** finish
**Phase Started:** 2026-07-31T13:11:21Z
**Round-Trip Count:** 2

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-07-31T12:24:41Z | 2026-07-31T12:26:18Z | 1m 37s |
| red | 2026-07-31T12:26:18Z | 2026-07-31T12:37:26Z | 11m 8s |
| green | 2026-07-31T12:37:26Z | 2026-07-31T12:42:46Z | 5m 20s |
| review | 2026-07-31T12:42:46Z | 2026-07-31T12:53:00Z | 10m 14s |
| red | 2026-07-31T12:53:00Z | 2026-07-31T12:57:47Z | 4m 47s |
| green | 2026-07-31T12:57:47Z | 2026-07-31T13:01:07Z | 3m 20s |
| review | 2026-07-31T13:01:07Z | 2026-07-31T13:07:06Z | 5m 59s |
| red | 2026-07-31T13:07:06Z | 2026-07-31T13:09:50Z | 2m 44s |
| green | 2026-07-31T13:09:50Z | 2026-07-31T13:10:11Z | 21s |
| review | 2026-07-31T13:10:11Z | 2026-07-31T13:11:21Z | 1m 10s |
| finish | 2026-07-31T13:11:21Z | - | - |

## TEA Assessment

**Tests Required:** Yes

**Test Files:**
- `pennyfarthing-dist/src/pf/tests/test_155_13_followup_suggestions.py` — RED contract for the deferred-followup scan (new module `pf.findings.followups` + sm-finish template wiring)

**Tests Written:** 24 (16 test functions, 2 parametrized) covering AC-1..AC-5 as defined in the test-file docstring (the authoritative AC record — see Design Deviations)
**Status:** RED (failing — ready for Dev). Verified twice: direct scoped run (`24 failed, 0 errored` in 0.25s, all assertion-level) and testing-runner (`155-13-tea-red`: VALID RED, 24/24 assertion-level failures). Green-simulated against a scratch implementation of the designed interface: 23/23 pass (template-wiring test correctly deselected — it needs Dev's real `agents/sm-finish.md` edit). Test file is ruff-clean.

**Designed interface for Dev** (full spec in the test docstring):
- `pf/findings/followups.py` — `detect_deferred_followups(content) -> list[dict]` (pure heuristics: Improvement/Question non-blocking; tag phrases follow-up/later/future/defer/out of scope/tracked; deviation Forward impact ≠ none; blocking never a candidate) and `suggest_followups(session_path, *, story_id, project_root) -> {success, data: {candidates, suggestions, skipped, markdown}}` (dedup against load_sprint open stories naming the covering story id, fail-open without sprint data; command carries "from {story_id}"; epic from session frontmatter; return-don't-throw)
- `agents/sm-finish.md` — a bash-fenced step invoking `pf.findings.followups` through PF_PY (Impact Summary shape); the existing 155-11 fence-discipline suite auto-covers the new fence
- Reusable internals: `pf.findings.capture.parse_delivery_findings` and `pf.findings.summary._parse_session_deviations` already parse both session sections — do not reimplement (SOUL #2)

### Rule Coverage

| Rule | Test(s) | Status |
|------|---------|--------|
| #1 no silent swallow / SOUL #10 result objects | `test_missing_session_returns_error_result` | failing |
| #2 mutable default arguments | `test_followups_module_hygiene` (AST scan) | failing |
| #5 read_text/open without encoding= (CWE-838) | `test_followups_module_hygiene` (AST scan) | failing |
| 155-11 PF_PY fence discipline | `test_sm_finish_template_wires_followups_scan` | failing |
| #6 test quality (self-check) | no vacuous asserts, no always-dead conditional arms, own file ruff-clean | done |

**Rules checked:** 4 of 4 applicable lang-review rules have test coverage
**Self-check:** 0 vacuous tests found

**Handoff:** To Dev (B.A.) for implementation

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/src/pf/findings/followups.py` (new, 250 lines) — `detect_deferred_followups()` (pure heuristics over `parse_delivery_findings` + `_parse_session_deviations` reuse, SOUL #2) and `suggest_followups()` (dedup via `load_sprint` merged view against open-status stories, fail-open when no sprint data; shell-safe pre-filled `pf sprint story add` commands with "from {story_id} review" provenance; epic from session frontmatter; result objects, never raises)
- `pennyfarthing-dist/agents/sm-finish.md` — new step "## 4. Scan for Deferred Follow-ups" (self-contained PF_PY fence mirroring the Impact Summary shape, non-blocking posture spelled out), preflight renumbered to step 5, `<output>` gains a Deferred Follow-ups section

**Tests:** 24/24 passing (GREEN). Regression batches: template/agent-md (test_155_11 fence discipline + 3 agent validators, 111 passed — the new fence passes the 155-11 PF_PY rules), findings module (test_150_1 + test_150_20, 74 passed). `ruff check` clean on both changed files.
**Live smoke (real data, not mocks):** ran `suggest_followups` from orchestrator root against the live 155-13 session + real 34-story backlog — 5 candidates detected (3 findings, 2 deviations with non-none Forward impact), 0 false-dedups, markdown block renders. The smoke caught a real defect the suite missed: backticked code spans in finding descriptions would command-substitute when the operator pastes the command — fixed by neutralizing backtick/`$`/`\`/`"` in the title (see Design Deviations); re-smoked, 0 unsafe metacharacters.
**Branch:** feat/155-13-finish-followup-suggest (pushed, 2 commits: TEA red + Dev green)

**Handoff:** To Colonel Lynch (Reviewer) for code review

## Subagent Results

| # | Specialist | Received | Status | Findings | Decision |
|---|-----------|----------|--------|----------|----------|
| 1 | reviewer-preflight | Yes | clean | none | N/A (24/24 green, ruff clean, no smells) |
| 2 | reviewer-edge-hunter | Skipped | disabled | N/A | Disabled via settings |
| 3 | reviewer-silent-failure-hunter | Skipped | disabled | N/A | Disabled via settings |
| 4 | reviewer-test-analyzer | Yes | findings | 6 | confirmed 5, dismissed 1 (PROJECT_ROOT env is a deliberate hermetic guard per fixture docstring, not dead setup — but its untested-None-branch half is confirmed) |
| 5 | reviewer-comment-analyzer | Skipped | disabled | N/A | Disabled via settings |
| 6 | reviewer-type-design | Yes | findings | 7 | confirmed 4, deferred 3 (NamedTuple/TypedDict/Path-narrowing — low-conf design suggestions, follow-up scope) |
| 7 | reviewer-security | Yes | findings | 5 | confirmed 3, deferred 2 (new -c {STORY_ID} instance → tracked by open 155-26; CWE-22 containment → defense-in-depth follow-up) |
| 8 | reviewer-simplifier | Skipped | disabled | N/A | Disabled via settings |
| 9 | reviewer-rule-checker | Yes | findings | 8 | confirmed 6, dismissed 2 (missing `__all__` matches capture.py/summary.py package convention — downgraded LOW, noted; sm-finish {STORY_ID} fence pattern → pre-existing class tracked by 155-26) |

**All received:** Yes (5 returned, 4 disabled)
**Total findings:** 18 confirmed, 3 dismissed (with rationale), 5 deferred

### Rule Compliance

Mapped to `.pennyfarthing/gates/lang-review/python.md` (13 checks) + SOUL + 155-11 fence discipline, per rule-checker's exhaustive pass (71 instances):

| Rule | Result |
|------|--------|
| #1 silent exceptions | **FAIL** — `followups.py:178` unguarded `read_text` after `exists()` (TOCTOU); `followups.py:185` unguarded `get_project_root()` (documented to raise) on the LIVE fence path |
| #2 mutable defaults | pass (27 defs checked) |
| #3 type annotations | **FAIL (minor)** — `Any` ×6 without justifying comment; 16 `test_*` functions missing `-> None` (sibling suites annotate) |
| #4 logging | n/a (no logging imports) |
| #5 path handling | **FAIL (minor)** — no `.resolve()`/containment on `session_path`/`project_root` (CWE-59/22 defense-in-depth); `encoding=` compliant everywhere |
| #6 test quality | **FAIL (minor)** — `assert result.get("error")` truthy check; otherwise clean (no vacuous asserts, parametrize cases distinct) |
| #7 resource leaks | pass |
| #8 unsafe deserialization | pass |
| #9 async | n/a |
| #10 import hygiene | pass (lazy imports legitimate; `__all__` absence matches package convention — noted LOW) |
| #11 input validation at boundaries | **FAIL** — `followups.py:209` `epic` spliced unquoted/unsanitized into the generated shell command; `story_id`/`provenance` land in the sanitized quoting context without the same neutralization; no CWE-88 leading-dash guard on either positional (contrast `preflight/finish.py::_reject_option_like` precedent) |
| #12 dependency hygiene | n/a |
| #13 fix-regressions | n/a (new feature) |
| SOUL #2 one truth | **FAIL (medium)** — `_session_epic` hand-rolls frontmatter regex where `findings/aggregate.py::_parse_frontmatter` (yaml-based, same package) exists; `_open_stories` raw status membership bypasses `pf.sprint.status_normalize.normalize_status` alias table |
| SOUL #10 result objects | **FAIL** — same two unguarded raise paths as #1; docstring promises "always returns a result object" and the code doesn't |
| SOUL #14 prove the work | pass (24/24 green; but the two raise paths are unproven by any test) |
| 155-11 PF_PY fence discipline | pass — new Step 4 fence self-contains PF_PY derivation, quotes `"$(command -v pf)"`, routes through `"$PF_PY"`, no .venv, no bare python |
| Runtime paths (.pennyfarthing/) | pass |

### Devil's Advocate

Assume this module ships as-is and I want it to hurt someone. The pre-filled command is the attack surface, because the whole feature's promise is "paste this." The author sanitized the title — proving awareness of the injection class — and then interpolated `epic` two lines later with no quoting at all. I don't even need malice: a session whose frontmatter lost its `epic:` line emits `pf sprint story add <epic> "..."`, and `<epic>` is live shell redirection syntax; a corrupted or hand-edited frontmatter with `epic: 155; rm -rf ~` is a straight CWE-78 on an operator who was explicitly told the command is safe to run. Next, the wiring: the sm-finish fence never passes `project_root`, so every real invocation walks the `get_project_root()` default — a function documented to raise `FileNotFoundError` — inside a module whose docstring swears it always returns result objects. Run finish from a directory without a project marker and the "non-blocking" report step stack-traces. The suite is green and proves neither of these: no test omits `project_root`, no test feeds a metacharacter description, and no test asserts the title text even appears in the command — an implementation that emits an empty title for every suggestion passes 24/24. The dedup story is softer but real: a story titled "Fix span" substring-matches unrelated candidates and silently swallows a deferral — the exact "recorded but not tracked" failure this story exists to prevent — and a status spelled "in-review" (the alias `normalize_status` exists to handle) makes an open story invisible to dedup. The devil finds this module trustworthy-looking and unproven exactly where trust is claimed.

## Reviewer Assessment

**Verdict:** REJECTED

**Data flow traced:** session prose (Delivery Findings / Design Deviations, agent-authored) → `parse_delivery_findings`/`_parse_session_deviations` → candidate dicts → f-string command builder (`followups.py:207-209`) → markdown block → sm-finish output → **operator's shell via copy-paste**. The title segment is neutralized (`:207`); the `epic` and `story_id`/`provenance` segments in the same command are not — the trust boundary is crossed unevenly.

| Severity | Issue | Location | Fix Required |
|----------|-------|----------|--------------|
| [HIGH] [SEC][TYPE][RULE] | `epic` interpolated into the generated command unquoted and unsanitized (CWE-78); the missing-epic sentinel `"<epic>"` is itself shell redirection syntax pasted verbatim; `story_id`/`provenance` land in the sanitized quoting context without the same neutralization | `followups.py:106, 202, 209` | Validate epic against a strict charset (`[A-Za-z0-9._-]+`, mirroring the 155-7 archive-id guard) or suppress the command and say why; route every interpolated segment through the same neutralization; replace the shell-active sentinel with a non-shell placeholder or an explicit "epic unresolved" suggestion state |
| [HIGH] [SILENT-self][RULE] | `suggest_followups` violates its own "always returns a result object" contract: unguarded `read_text` (`:178`, raises on perm-denied/undecodable/TOCTOU-deleted) and unguarded `get_project_root()` (`:185`, documented to raise) — and the live sm-finish fence passes NO `project_root`, so the raising branch is the production path; zero test coverage on either | `followups.py:178, 185` | Wrap both in try/except → `{success: False, error: ...}` (SOUL #10); TEA pins the taxonomy (undecodable bytes, chmod-000, rootless cwd) and a no-project_root invocation test |
| [MEDIUM] [TEST] | Deliverable contract unpinned: no test asserts the candidate title appears in the command (empty-title mutation passes 24/24); the CWE-78 sanitizer added in GREEN has zero test coverage (160-24 report-contract precedent); "Already tracked" markdown section unpinned | `test_155_13_followup_suggestions.py:310, 331, 354` | TEA adds mutation-guard pins: sanitized-title-in-command, metacharacter description → neutralized command, `Already tracked` + covering id in markdown |
| [MEDIUM] [SEC] | No CWE-88 option-shape guard on `epic`/title positionals (prose beginning `-`/`--` becomes a flag to click), contrast `preflight/finish.py::_reject_option_like` precedent | `followups.py:207-209` | Apply an `_reject_option_like`-equivalent or prefix-guard before rendering the command |
| [MEDIUM] [TYPE][RULE] | SOUL #2: `_session_epic` re-implements frontmatter parsing (regex) where `findings/aggregate.py::_parse_frontmatter` (yaml) exists; `_open_stories` bypasses `pf.sprint.status_normalize.normalize_status` so alias-spelled statuses ("in-review") silently fail dedup | `followups.py:100, 129` | Delegate to `_parse_frontmatter(...).get("epic")` returning `str \| None`; normalize statuses before membership |
| [MEDIUM] [TEST] | Missing edge coverage: `<epic>` fallback path, short/generic-title dedup blind spot, `project_root=None` branch | test file | TEA adds the three edge tests in the rework RED |
| [LOW] [RULE] | 16 `test_*` functions missing `-> None` (sibling-suite convention); `Any` ×6 without comment (or drop to plain `dict` per capture/summary convention); truthy `assert result.get("error")` | both files | Mechanical cleanup in rework |
| [LOW] [SEC] | Sanitizer gaps: newline and `!` (histexpand) not neutralized; no CWE-22 containment on `session_path` | `followups.py:207, 174` | Fold into the sanitizer/guard rework |
| [LOW] [EDGE-self] | Tag phrases match as bare substrings — "tracked" hits "untracked", "later" hits "relater"; false candidates are operator-skippable but noisy | `followups.py:26-34` | Word-boundary regexes worth folding in; edge-hunter disabled, so self-observed |

**Verified good (evidence, rules checked):**
- [VERIFIED] PF_PY fence discipline on the new Step 4 fence — self-contained `PF_PY=` derivation, quoted `"$(command -v pf)"`, all exec through `"$PF_PY"`, no .venv activation, no bare python (`agents/sm-finish.md` Step 4; complies with the 155-11 rule set; rule-checker #17 pass).
- [VERIFIED] SOUL #2 on section parsing — `detect_deferred_followups` delegates to `parse_delivery_findings` (`followups.py:52`-area import/call) and `_parse_session_deviations`; no reimplemented section parser (rule-checker #14 pass).
- [VERIFIED] `encoding="utf-8"` on every read/write in both files (`followups.py:178`, test file fixtures; lang-review #5 clause; enforced by the suite's own AST guard).
- [VERIFIED] Dedup fails open — `_open_stories` returns `[]` when `load_sprint` yields None and `suggest_followups` still suggests (`followups.py:118-121`; pinned by `test_dedup_fails_open_without_sprint_data`).
- [VERIFIED] RED→GREEN discipline — test commit precedes implementation commit; 24 failed → 24 passed at assertion level (preflight report + phase history).
- [DOC] comment-analyzer disabled; own pass found docstrings accurate except the `suggest_followups` docstring's "always returns a result object" claim, which is contradicted by the two raise paths — folded into the [HIGH] above, not a separate finding. [SIMPLE] simplifier disabled; own pass found no over-engineering (module is lean; the deferred TypedDict/NamedTuple suggestions are optional polish).

**Challenged VERIFIEDs:** preflight's "SOUL #10 compliance: all functions return result objects" is CONTRADICTED by rule-checker's `:178`/`:185` raise paths — I re-read the code; the raise paths are real; preflight's architecture note is downgraded, rule-checker wins with line evidence.

**Tenant isolation:** n/a — no tenant-scoped data; the module reads local pipeline-authored files only.

**Rework routing:** findings are testable (sanitization contract, error-path taxonomy, mutation pins) → back to TEA for rework RED, then Dev. Deferred items (155-26 -c instance, CWE-22 containment, TypedDict/NamedTuple polish, `__all__`) recorded as Delivery Findings, not blockers.

**Handoff:** To Captain Murdock (TEA) for rework RED

## TEA Assessment (rework r1)

**Tests Required:** Yes — rework RED pinning every testable Reviewer finding

**Test Files:**
- `pennyfarthing-dist/src/pf/tests/test_155_13_rework_hardening.py` (new) — 19 tests: 13 RED + 6 intentional-green mutation pins
- `pennyfarthing-dist/src/pf/tests/test_155_13_followup_suggestions.py` (cleanup) — `-> None` on all 16 test defs, truthy error assert tightened to substring; still 24/24 green

**RED verification:** direct scoped run — 13 failed / 6 passed, each failure confirmed to be the pinned defect (probe-first: all six Reviewer findings reproduced on HEAD before writing tests — raw `; rm -rf ~` in command, `<epic>` sentinel emitted, "untracked" false candidate, FileNotFoundError on the fence path, UnicodeDecodeError on undecodable session, "in-review" invisible to dedup). Three failures surface as the raw raise (UnicodeDecodeError/PermissionError/FileNotFoundError) — the raise IS the pinned defect. Both files ruff-clean.

**Contract for Dev (fix-agnostic pins):**
1. SAFE GRAMMAR — every emitted command fullmatches `pf sprint story add [A-Za-z0-9._-]+ "<title free of " backtick $ \ newline ! and not dash-leading>" \d+`; malicious/missing epic may suppress the command but the candidate MUST stay in the markdown (no silent deferral loss)
2. Error taxonomy — undecodable/perm-denied session → {success: False, error mentioning session}; unresolvable project root (no kwarg, marker-less cwd — the live fence path) → fail-OPEN {success: True} with suggestions (root only feeds dedup)
3. SOUL #2 delegation — AST pins require real Calls to `_parse_frontmatter` (epic extraction) and `normalize_status` (status membership); behavioral alias pin: status "in-review" must dedup
4. Word-boundary tag phrases — "untracked" must not match; "should be tracked in the backlog" must

**Handoff:** To B.A. (Dev) for rework GREEN

## Dev Assessment (rework r1)

**Implementation Complete:** Yes — all Reviewer findings closed per TEA's rework contract
**Files Changed:**
- `pennyfarthing-dist/src/pf/findings/followups.py` (+71/−28) — (1) [HIGH-1] epic now extracted via `findings.aggregate._parse_frontmatter` (SOUL #2 delegation), validated against `[A-Za-z0-9._-]+` with explicit `..` rejection; invalid/missing epic → `command: None`, candidate stays in markdown with a "mint manually" note (no `<epic>` sentinel anywhere); title neutralization extended to `!` and newline, leading dashes/quote-chars stripped (CWE-88); (2) [HIGH-2] `read_text` wrapped → `{success: False, error: "Failed to read session file {name} (TypeName)"}` (type-name-only per 160-18 convention); `get_project_root()` wrapped → fail-OPEN (dedup skipped, suggestions kept); (3) [MEDIUM] `normalize_status` routed in `_open_stories` (alias spellings dedup); (4) [LOW] tag phrases word-boundary matched via `TAG_RE` (plural follow-ups covered; "untracked"/"relater" excluded)

**Tests:** 43/43 story tests (19 rework + 24 round-1), 228-test regression batch (155-11 fence discipline, findings module, agent-md validators) all green, ruff clean on all three changed files.
**Live smoke:** real session + real backlog from orchestrator root — success True, 11 candidates, every emitted command passes the safe grammar regex.
**Branch:** feat/155-13-finish-followup-suggest (pushed; commits: TEA red → Dev green → TEA rework red → Dev rework green)

**Handoff:** To Colonel Lynch (Reviewer) for re-review

## Subagent Results (re-review r2)

Rework diff was one file (`followups.py`), security-scoped (closing the round-1 [HIGH]s). Re-review ran reviewer-security fresh; preflight verified by Reviewer directly (43/43 story tests, 228-test regression batch, ruff clean); the round-1 test-analyzer/type-design/rule-checker dispositions were re-checked by Reviewer against the rework diff (no new surface in their domains — the changes are the command builder + error handling they already covered).

| # | Specialist | Received | Status | Findings | Decision |
|---|-----------|----------|--------|----------|----------|
| 1 | reviewer-preflight | Yes | clean | none | N/A — Reviewer-run: 43/43 story, 228 regression, ruff clean |
| 2 | reviewer-edge-hunter | Skipped | disabled | N/A | Disabled via settings |
| 3 | reviewer-silent-failure-hunter | Skipped | disabled | N/A | Disabled via settings |
| 4 | reviewer-test-analyzer | Yes | carried-forward | 0 new | round-1 pins now green; SAFE_COMMAND grammar gap noted under new [HIGH-B] |
| 5 | reviewer-comment-analyzer | Skipped | disabled | N/A | Disabled via settings |
| 6 | reviewer-type-design | Yes | carried-forward | 0 new | round-1 deferred design items unchanged (follow-up scope) |
| 7 | reviewer-security | Yes | findings | 2 | confirmed 2 (both HIGH command-injection — one Reviewer-reproduced independently) |
| 8 | reviewer-simplifier | Skipped | disabled | N/A | Disabled via settings |
| 9 | reviewer-rule-checker | Yes | carried-forward | 0 new | round-1 rule findings addressed (SOUL #2 delegation confirmed via AST in the diff) |

**All received:** Yes (2 re-run, 3 carried-forward, 4 disabled)
**Total findings:** 2 confirmed (both HIGH), 0 dismissed, 0 deferred

### Devil's Advocate (r2)

The round-1 [HIGH]s are closed — I re-probed the malicious/missing epic and undecodable/rootless paths and they behave. But the rework fixed the *named* segment (description→title) and left its siblings in the same shell sink unprotected, which is the textbook "validation on one path" the lang-review meta-check (#13) exists to catch. `provenance = f"from {story_id} review"` is spliced into the same double-quoted title with zero neutralization — I reproduced `story_id='9" ; touch /tmp/PWNED ; echo "'` executing the injected command end-to-end. And `_SAFE_EPIC_RE` (`[A-Za-z0-9._-]+`) admits a leading dash: an epic of `--sprint-file` turns the unquoted first positional into a Click option that eats the title as its value — argument injection, not just a parse error. Today `story_id` at the (not-yet-wired) sm-finish call site comes from `find_story_in_data` and epic from session frontmatter, so neither is attacker-controlled *yet* — but this is a public API whose docstring/PROJECT_RULES promise every interpolated segment is neutralized, and the wiring is one story away. Shipping a half-sanitized command builder into a security follow-up epic is exactly the pattern this story exists to stop.

## Reviewer Assessment (r2)

**Verdict:** REJECTED

**Data flow traced:** `story_id` (caller arg) → `provenance` f-string → same double-quoted title segment as the sanitized `description` → command → operator paste. Only `description` is neutralized; `story_id` crosses the sink raw. Separately, `epic` (frontmatter) → charset-validated but not leading-dash-guarded → unquoted first positional → Click option injection.

| Severity | Issue | Location | Fix Required |
|----------|-------|----------|--------------|
| [HIGH-A] [SEC] | CWE-78: `story_id`/`provenance` spliced into the double-quoted title unsanitized — Reviewer reproduced arbitrary command execution (`story_id='...\" ; touch /tmp/PWNED ; echo \"'`). The round-1 fix neutralized only `description`; the sibling segment in the same sink was missed (lang-review #13 "validation on one path"). | `followups.py:234, 244` | Sanitize `story_id` (and thus `provenance`) through the same neutralization + leading-char strip as the title; simplest: sanitize once and reuse. TEA pins a metachar-story_id test asserting the emitted command matches the safe grammar. |
| [HIGH-B] [SEC][TEST] | CWE-88: `_SAFE_EPIC_RE = [A-Za-z0-9._-]+` accepts leading-dash values (`--sprint-file`, `--dry-run`); `epic` is spliced unquoted as the first positional of Click command `pf sprint story add`, which has value-taking options — an epic of `--sprint-file` makes Click consume the title as that option's value (argument injection / silent mint redirect). The test's own `SAFE_COMMAND` grammar has the same `[A-Za-z0-9._-]+` gap, so it's uncovered. | `followups.py:100`; `test_155_13_rework_hardening.py` SAFE_COMMAND | Anchor the epic pattern to a non-dash first char (`^[A-Za-z0-9][A-Za-z0-9._-]*$`); tighten the test grammar to match and add a leading-dash epic case. |

**Verified good (r2):**
- [VERIFIED][SEC] read_text guarded with correctly-scoped `(OSError, UnicodeDecodeError)` → result object; `get_project_root()` guarded `(FileNotFoundError, OSError)` → fail-open (`followups.py:194, 210-217`; SOUL #10 satisfied, confirmed by security agent as not-too-broad/not-too-narrow).
- [VERIFIED][SEC] `<epic>` shell-active sentinel eliminated — missing/unsafe epic yields `command: None` + markdown "mint manually" note, candidate retained (`followups.py:242-246`, markdown branch; pinned by `test_missing_epic_emits_no_shell_active_placeholder`).
- [VERIFIED][RULE] SOUL #2 delegation landed — `_parse_frontmatter` and `normalize_status` are real Calls in the diff (AST-pinned by rework tests, both green).
- [VERIFIED][TEST] title double-quote-context neutralization complete for `description` (`"` backtick `$` `\` newline `!`); the gap is that `story_id` doesn't get the same treatment (→ [HIGH-A]).

**Rework routing:** both findings are testable (command grammar) → back to TEA for rework RED (r2), then Dev. Round-trip count now 2.

**Handoff:** To Captain Murdock (TEA) for rework RED r2

## TEA Assessment (rework r2)

**Tests Added:** 7 (in `test_155_13_rework_hardening.py`) — 4 parametrized story_id-injection cases + 3 leading-dash-epic cases. Also tightened the shared `SAFE_COMMAND` grammar's epic segment from `[A-Za-z0-9._-]+` to `[A-Za-z0-9][A-Za-z0-9._-]*` (the round-1 grammar mirrored the buggy allowlist and so could not have caught [HIGH-B] — fixing the oracle was itself part of the RED).
**RED verification:** 7 failed for the right reasons (raw `; touch` reached the command; `-rf`/`--sprint-file` epic emitted unquoted), ruff clean.
**Contract:** every emitted command fullmatches the non-dash-anchored safe grammar regardless of story_id content; an option-shaped epic yields `command: None` with the candidate still listed.

**Handoff:** To B.A. (Dev) for rework GREEN r2

## Dev Assessment (rework r2)

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/src/pf/findings/followups.py` (+32/−12) — extracted `_shell_safe_segment()` and routed BOTH command-title segments (`description` → title AND `story_id` → provenance) through it, closing the [HIGH-A] CWE-78 gap where story_id reached the double-quoted title raw; anchored `_SAFE_EPIC_RE` to a non-dash first char (`[A-Za-z0-9][A-Za-z0-9._-]*`) closing the [HIGH-B] CWE-88 option-injection on the unquoted first positional. The command is now suppressed unless epic, title, AND sanitized story_id are all non-empty.

**Tests:** 50/50 story (26 rework + 24 round-1), 80-test regression batch (155-11 fence + findings module) green, ruff clean.
**Adversarial smoke:** `story_id='9" ; touch /tmp/PWN ; echo "'` → command stays within the quoted title (`"` swapped to `'`), passes the safe grammar, no `/tmp/PWN` artifact created; `epic: "--sprint-file"` → `command: None`, deferral retained in markdown.
**Branch:** feat/155-13-finish-followup-suggest (pushed; full trail: red → green → rework-red → rework-green → rework-red-r2 → rework-green-r2)

**Handoff:** To Colonel Lynch (Reviewer) for re-review r2

## Subagent Results (re-review r3 / final)

Fix diff was one file, ~20 net lines, closing the two r2 [HIGH] injection findings. Re-review verified by Reviewer directly: read the full fix diff, re-ran reviewer-security's exact reproductions plus a broader adversarial probe sweep (dash+command-substitution story_id, all-metacharacter descriptions, histexpand, dotted epic), and the full 50-test suite. No specialist domain has new surface beyond the command builder the security agent already exhausted in r2.

| # | Specialist | Received | Status | Findings | Decision |
|---|-----------|----------|--------|----------|----------|
| 1 | reviewer-preflight | Yes | clean | none | N/A — Reviewer-run: 50/50 story, 80 regression, ruff clean |
| 2 | reviewer-edge-hunter | Skipped | disabled | N/A | Disabled via settings |
| 3 | reviewer-silent-failure-hunter | Skipped | disabled | N/A | Disabled via settings |
| 4 | reviewer-test-analyzer | Yes | carried-forward | 0 new | r2 grammar-gap [HIGH-B] fixed in the test's SAFE_COMMAND; 7 new injection pins green |
| 5 | reviewer-comment-analyzer | Skipped | disabled | N/A | Disabled via settings |
| 6 | reviewer-type-design | Yes | carried-forward | 0 new | round-1 deferred design items unchanged |
| 7 | reviewer-security | Yes | resolved | 0 new | both r2 [HIGH]s reproduced-then-confirmed-closed by Reviewer (no injection artifact; all vectors match safe grammar) |
| 8 | reviewer-simplifier | Skipped | disabled | N/A | Disabled via settings |
| 9 | reviewer-rule-checker | Yes | carried-forward | 0 new | SOUL #2/#10 + fence discipline confirmed intact |

**All received:** Yes (3 carried-forward, security resolved, 4 disabled)
**Total findings:** 0 confirmed, 0 dismissed, 0 deferred (both prior HIGHs closed)

### Devil's Advocate (r3)

I tried to break the hardened command builder and could not. Dash-prefixed command-substitution story_id (`-x$(id)`) → the `$` becomes `'`, the leading dash is stripped, output stays inside the quoted title and matches the safe grammar. All-metacharacter descriptions collapse to a short prose remnant or empty (empty → command suppressed, deferral retained). A dotted valid epic (`2.0-a`) renders; `--sprint-file` / `-rf` / `..` epics all suppress the command while keeping the candidate in the markdown. `!` is neutralized so interactive histexpand can't fire. The one residual: both sanitized segments share the SAME sink, and the sanitizer is now the single choke point — if a future edit adds a THIRD interpolated segment without routing it through `_shell_safe_segment`, the class reopens. That's a maintenance risk, not a live defect, and the safe-grammar tests would catch a regression on the existing two segments. The error-taxonomy and fail-open paths from r1 remain covered. I have no blocking finding left to raise.

## Reviewer Assessment (r3 / final)

**Verdict:** APPROVED

**Data flow traced:** session prose + caller `story_id` → `_shell_safe_segment` (single choke point) → double-quoted title; `epic` → non-dash-anchored charset validation → unquoted first positional (or command suppressed) → markdown → operator paste. Every path that reaches the shell sink is now neutralized or gated; I reproduced the r2 injection vectors and confirmed each is inert (no `/tmp/PWN` artifact, all emitted commands match `^pf sprint story add [A-Za-z0-9][A-Za-z0-9._-]* "[^"`$\\\n!]+" \d+$`).

**Pattern observed:** single-sanitizer-for-one-sink (`_shell_safe_segment` at `followups.py:110`) — the correct fix for the "validation on one path" class; both `description` and `story_id` route through it.

**Error handling:** unreadable session → `{success: False, error}` (`followups.py:194`); unresolvable project root → fail-open report (`followups.py:210-217`); both verified by the rework suite.

**Two prior HIGH findings closed:** [HIGH-A] story_id/provenance sanitized; [HIGH-B] epic anchored non-dash (and the test grammar tightened to match, so the class is now covered). Deferred non-blockers (155-26 -c fence instance, CWE-22 session_path containment, TypedDict/NamedTuple polish, `__all__`) recorded as Delivery Findings for follow-up — none blocking.

**Handoff:** To Lieutenant Peck (SM) for finish-story

## Sm Assessment

Setup complete for 155-13 (3 pts, tdd, epic 155 — finish truthfulness). No Jira key; tracked via gh issue #114, Jira claim explicitly skipped. Branch `feat/155-13-finish-followup-suggest` created in `pennyfarthing/` off `develop`. Story context written from gh #114 with five AC clusters: deferral detection heuristics, suggestion block at sm-finish with pre-filled `pf sprint story add` commands, dedup against existing backlog/future stories, provenance back-references, and hook placement in sm-finish preflight (before archive/remove session). Routing to TEA for RED phase per tdd workflow. Orchestrator bookkeeping accumulates on `chore/sprint-155-11-followups` (PR #56, awaiting Keith's merge) — no new story filings until #56 lands per epic-shard ID-collision guard.

## Delivery Findings

No upstream findings.

<!-- Agents: append findings below this line. Do not edit other agents' entries. -->

### TEA (test design)
- **Improvement** (non-blocking): `pf sprint story add` has no --description/body option, so a minted follow-up story cannot carry the issue's "from X review" provenance as a body line — only via title suffix. Affects `pennyfarthing-dist/src/pf/sprint/story_add.py` (add a --description option so provenance can live in the story body). *Found by TEA during test design.*
- **Question** (non-blocking): gh #114 says dedup against "existing backlog/future stories" but the RED contract pins only current-sprint open stories — should the scan also match `sprint/future.yaml` initiatives?. Affects `pennyfarthing-dist/src/pf/findings/followups.py` (extend the dedup source if yes). *Found by TEA during test design.*
- **Improvement** (non-blocking): sm-setup created the session without `**Repos:**`/`**Branch:**` fields and without an `## Sm Assessment` heading — SM had to hand-patch all three before the setup-exit gate would pass. Affects `pennyfarthing-dist/agents/sm-setup.md` (emit the required session fields in setup mode). *Found by TEA during test design.*

### Dev (implementation)
- **Improvement** (non-blocking): `_parse_session_deviations` is a private helper in summary.py but now has two consumers (summary + followups) — promote it to a public name so the second import isn't reaching into a sibling's privates. Affects `pennyfarthing-dist/src/pf/findings/summary.py` (rename to public or move to capture.py). *Found by Dev during implementation.*
- **Improvement** (non-blocking): full finding sentences become unwieldy story titles in the pre-filled command — a truncation or summarization pass would improve mint ergonomics. Affects `pennyfarthing-dist/src/pf/findings/followups.py` (title-shortening in the command builder). *Found by Dev during implementation.*

### Reviewer (code review)
- **Improvement** (non-blocking): the new Step 4 fence adds a second instance of the {STORY_ID}-into-`-c`-payload interpolation class while 155-26 is open — 155-26's sweep must include the Step 4 fence, or the fence should pass STORY_ID via argv/env instead. Affects `pennyfarthing-dist/agents/sm-finish.md` (fold into the 155-26 hardening sweep). *Found by Reviewer during code review.*
- **Improvement** (non-blocking): no CWE-22 containment check that session_path resolves under .session/ — defense-in-depth gap, mirrors the {STORY_ID} path-building in the template. Affects `pennyfarthing-dist/src/pf/findings/followups.py` (resolve-and-contain guard, can ride 155-26 or a hardening follow-up). *Found by Reviewer during code review.*
- **Improvement** (non-blocking): candidate dicts are a discriminated union in spirit only — TypedDict/Literal modeling (and a NamedTuple for the covering-story pair) would prevent silent shape drift for future consumers. Affects `pennyfarthing-dist/src/pf/findings/followups.py` (type-modeling polish, follow-up scope). *Found by Reviewer during code review.*

## Design Deviations

No deviations recorded.

<!-- Agents: append deviations below this line. Do not edit other agents' entries. -->

### TEA (test design)
- **AC record written into the test-file docstring, not the context file**
  - Spec source: context-story-155-13.md, Acceptance Criteria section
  - Spec text: "No acceptance criteria recorded in the sprint YAML — TEA to define during the RED phase."
  - Implementation: AC-1..AC-5 defined in the docstring of `test_155_13_followup_suggestions.py`, alongside the designed Dev interface (`pf.findings.followups.detect_deferred_followups` / `suggest_followups`)
  - Rationale: keeps the spec adjacent to the tests that enforce it; the Reviewer and Dev read one file
  - Severity: minor
  - Forward impact: none
- **Suggest posture only — prompt/auto-mint postures and project setting unpinned**
  - Spec source: gh #114, "Behavior (pick a posture per project setting)"
  - Spec text: "Suggest (default) / Prompt / Auto-mint (gate behind a setting)"
  - Implementation: tests pin only the default suggest posture (non-blocking report, pre-filled commands); no config knob or interactive/auto-mint coverage
  - Rationale: 3-pt story scope; suggest is the issue's own default and the only posture with zero false-positive cost
  - Severity: minor
  - Forward impact: a posture setting would be a follow-up story; the suggest contract is forward-compatible
- **Provenance pinned INSIDE the pre-filled command (beyond-issue tightening)**
  - Spec source: gh #114, Provenance paragraph
  - Spec text: "any minted/suggested story should back-reference the source (`from <STORY_ID> review`)"
  - Implementation: tests require the literal "from {story_id}" inside the command string itself, plus a `provenance` field on the suggestion
  - Rationale: with the suggest posture the operator's copy-paste is the only mint path — provenance not embedded in the command is provenance lost (and `story add` has no body option; see Delivery Finding)
  - Severity: minor
  - Forward impact: none
- **Dedup source pinned to current-sprint open stories; fails open without sprint data**
  - Spec source: gh #114, "Cross-reference, don't duplicate"
  - Spec text: "check whether the finding is already covered by an existing backlog/future story"
  - Implementation: dedup tested against merged current-sprint stories (status backlog); `future.yaml` matching untested; load_sprint returning None must still suggest (fail-open)
  - Rationale: current sprint is where "is that tracked?" is answerable with a story id; fail-open keeps an empty project from silently losing deferrals
  - Severity: minor
  - Forward impact: future.yaml dedup is a possible follow-up (logged as a Question finding)
- **Blocking findings excluded from candidacy even when tagged with deferral phrases**
  - Spec source: gh #114, Detection heuristics
  - Spec text: "Reviewer findings tagged with phrases like 'follow-up', 'later', ..."
  - Implementation: `test_blocking_finding_is_never_candidate` pins that a blocking finding is never suggested regardless of tag phrases
  - Rationale: blocking work is resolved in-story by definition; minting it as a deferral would legitimize finishing over a blocking finding (the exact epic-155 failure class)
  - Severity: minor
  - Forward impact: none
- **Epic for the pre-filled command comes from session frontmatter, not story-id prefix**
  - Spec source: gh #114, Behavior ("pf sprint story add <epic> ...")
  - Spec text: "<epic>" (source unspecified)
  - Implementation: fixtures carry `epic:` frontmatter matching the story prefix; the AC record directs Dev to read frontmatter (155-4 no-prefix-parse rule); the source itself is not mechanically pinned
  - Rationale: prefix-parsing story ids in the live finish path is forbidden by the 155-4 precedent
  - Severity: minor
  - Forward impact: none

### Dev (implementation)
- **Shell-metacharacter sanitization in the pre-filled title (beyond TEA's double-quote note)**
  - Spec source: test_155_13_followup_suggestions.py AC record, AC-2/AC-4
  - Spec text: "pre-filled `pf sprint story add <epic> \"<title>\" ...` command the operator can run or skip"
  - Implementation: the interpolated title neutralizes `"`, backtick, `$`, and `\` (swapped to `'`), not just double quotes
  - Rationale: live smoke against the real session showed finding descriptions carry backticked code spans — inside a double-quoted shell arg those command-substitute when pasted (CWE-78 class, same family as 155-26); a run-or-skip command must be safe to paste
  - Severity: minor
  - Forward impact: none
- **Concrete default points (2) instead of the issue's `<pts>` placeholder**
  - Spec source: gh #114, Behavior (Suggest posture)
  - Spec text: "pre-filled `pf sprint story add <epic> \"<title>\" <pts> --type ...` command"
  - Implementation: commands carry a literal `2` (DEFAULT_POINTS) with "adjust points as needed" in the block prose; no `--type` flag
  - Rationale: a command that runs as pasted beats one the operator must edit first; TEA left the points shape free
  - Severity: minor
  - Forward impact: none

### Reviewer (audit)
- **TEA: AC record in test-file docstring** → ✓ ACCEPTED by Reviewer: spec-adjacent-to-enforcement is sound; the docstring is complete and the Dev built to it.
- **TEA: Suggest posture only** → ✓ ACCEPTED by Reviewer: matches the issue's own default; posture setting is clean follow-up scope.
- **TEA: Provenance pinned inside the command** → ✓ ACCEPTED by Reviewer: correct reasoning — with suggest posture the command is the only mint path.
- **TEA: Dedup current-sprint only, fail-open** → ✓ ACCEPTED by Reviewer: fail-open is the right posture for a report; future.yaml scope rides the open Question finding.
- **TEA: Blocking findings never candidates** → ✓ ACCEPTED by Reviewer: minting blocking work as deferral would legitimize the exact epic-155 failure class.
- **TEA: Epic from session frontmatter, not prefix-parse** → ✓ ACCEPTED by Reviewer: 155-4 rule honored — but the rework must delegate extraction to `findings/aggregate.py::_parse_frontmatter` (SOUL #2) instead of the hand-rolled regex, and must not emit the shell-active `<epic>` sentinel.
- **Dev: Shell-metacharacter sanitization in the pre-filled title** → ✗ FLAGGED by Reviewer: right instinct, incomplete and unproven — the same command interpolates `epic` (unquoted, unsanitized) and `story_id`/`provenance` (same quoting context, no neutralization), and the sanitizer itself has zero test coverage. This asymmetry is the [HIGH] injection finding; the rework must harden every interpolated segment and TEA must pin the behavior.
- **Dev: DEFAULT_POINTS=2 over `<pts>` placeholder** → ✓ ACCEPTED by Reviewer: runnable-as-pasted is the correct trade; ironic given the `<epic>` sentinel violates the same principle — fixed under the [HIGH].

### TEA (rework r1 test design)
- **Unresolvable project root pinned as fail-OPEN, not error result**
  - Spec source: 155-13 session, Reviewer Assessment [HIGH-2] fix-required
  - Spec text: "Wrap both in try/except → {success: False, error: ...}"
  - Implementation: `test_rootless_default_project_root_fails_open` pins {success: True} with suggestions intact when get_project_root() fails — only the unreadable-session taxonomy pins {success: False}
  - Rationale: the root is needed only for dedup; a report that errors out loses the deferral (the exact failure this feature prevents) — same posture the Reviewer ACCEPTED for missing sprint data
  - Severity: minor
  - Forward impact: none — Dev wraps both sites either way; only the root-failure return value differs
- **Safe-command grammar tightened beyond the findings' letter**
  - Spec source: 155-13 session, Reviewer Assessment [HIGH-1] + [LOW] sanitizer gaps
  - Spec text: "route every interpolated segment through the same neutralization" / "consider neutralizing bare `!`"
  - Implementation: one grammar regex every emitted command must fullmatch — charset-limited epic, quoted title excluding `"` backtick `$` `\` newline `!`, non-dash-leading title, digit points
  - Rationale: a single mechanical invariant covers all interpolation sites at once and survives future segment additions; `!` promoted from "consider" to pinned (histexpand on paste is real)
  - Severity: minor
  - Forward impact: none
- **Newline-in-description intentionally untested**
  - Spec source: 155-13 session, Reviewer Assessment [LOW] sanitizer gaps
  - Spec text: "Strip or escape newlines"
  - Implementation: no newline test; documented in the rework file docstring
  - Rationale: R1 findings and deviation fields are parsed line-wise upstream — a newline cannot reach the command builder; a test would pin unreachable behavior
  - Severity: minor
  - Forward impact: none
- **Six green-on-arrival mutation pins (intentional green)**
  - Spec source: 155-13 session, Reviewer Assessment [MEDIUM] test pins
  - Spec text: "TEA adds mutation-guard pins: sanitized-title-in-command, metacharacter description → neutralized command, Already tracked + covering id in markdown"
  - Implementation: grammar[plain], grammar[metachar-desc], sanitized-title-in-command, metachar-neutralized-prose-survives, already-tracked-markdown, tracked-positive-control pass on HEAD — they close coverage holes, not behavior holes
  - Rationale: per ac-as-green-regression-guard precedent; the gate should not read them as spurious
  - Severity: minor
  - Forward impact: none

### Dev (rework r1 implementation)
- **Epic validation rejects bare `..` beyond the charset allowlist**
  - Spec source: 155-13 session, TEA rework contract item 1 (safe grammar)
  - Spec text: "every emitted command fullmatches `pf sprint story add [A-Za-z0-9._-]+ ...`"
  - Implementation: `_session_epic` additionally rejects any epic containing `..` even though dots are charset-valid
  - Rationale: 155-7 precedent — a charset with dots admits `..`; an epic is never legitimately `..`-shaped
  - Severity: minor
  - Forward impact: none
- **Leading quote-chars stripped from the sanitized title, not just dashes**
  - Spec source: 155-13 session, TEA rework contract item 1 (non-dash-leading title)
  - Spec text: "not dash-leading"
  - Implementation: `title.lstrip("-' ")` — a description whose leading char was neutralized to `'` (e.g. a leading backtick) also loses that leading `'`
  - Rationale: keeps the rendered title starting on prose; grammar requires a clean first character
  - Severity: minor
  - Forward impact: none

### Dev (rework r2 implementation)
- **Single shared sanitizer for every command-title segment**
  - Spec source: 155-13 session, Reviewer Assessment r2 [HIGH-A]
  - Spec text: "Sanitize story_id ... simplest: sanitize once and reuse"
  - Implementation: `_shell_safe_segment()` applied to both `description` and `story_id`; the round-1 inline title-only `re.sub` is gone
  - Rationale: one sink, one sanitizer — eliminates the "validation on one path" class the reviewer flagged (lang-review #13)
  - Severity: (fix of a HIGH) — no deviation from spec, closes the finding exactly as directed
  - Forward impact: none
- **Command suppressed unless epic AND title AND sanitized story_id all non-empty**
  - Spec source: 155-13 session, Reviewer Assessment r2 [HIGH-A]/[HIGH-B]
  - Spec text: "reject ... never emitted unquoted"
  - Implementation: `if epic and title and safe_story_id:` guards command emission; any empty segment → `command: None` + markdown "mint manually" note
  - Rationale: a fully-empty story_id (unlikely from real callers) would otherwise yield a malformed provenance — fail closed on the command, open on the report
  - Severity: minor
  - Forward impact: none