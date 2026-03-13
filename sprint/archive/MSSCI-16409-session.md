---
story_id: "146-4"
jira_key: "MSSCI-16409"
epic: "MSSCI-16405"
workflow: "trivial"
---
# Story 146-4: demo.yaml configuration — branding, format prefs, classification rules

## Story Details
- **ID:** 146-4
- **Jira Key:** MSSCI-16409
- **Epic:** MSSCI-16405
- **Points:** 2
- **Workflow:** trivial
- **Stack Parent:** none

## Workflow Tracking
**Workflow:** trivial
**Phase:** finish
**Phase Started:** 2026-03-13T15:41:25Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-03-13T15:17:37Z | 2026-03-13T15:19:09Z | 1m 32s |
| implement | 2026-03-13T15:19:09Z | 2026-03-13T15:23:01Z | 3m 52s |
| review | 2026-03-13T15:23:01Z | 2026-03-13T15:29:42Z | 6m 41s |
| implement | 2026-03-13T15:29:42Z | 2026-03-13T15:36:04Z | 6m 22s |
| review | 2026-03-13T15:36:04Z | 2026-03-13T15:41:25Z | 5m 21s |
| finish | 2026-03-13T15:41:25Z | - | - |

## Story Context

### Task
Create and configure a `demo.yaml` file with:
1. **Branding information** — use https://1898andco.burnsmcd.com/ for branding details
2. **Format preferences** — styling and presentation configuration
3. **Classification rules** — rules for demo generation system classification

### Implementation Notes
- File location: `pennyfarthing-dist/demo.yaml`
- Configuration structure must align with demo generation system expectations
- Branding should pull from the provided Burns McDonnell URL

**Repos:** pennyfarthing (branch: `feat/146-4-demo-yaml-config-branding`)

## SM Assessment

**Setup complete.** Story 146-4 session initialized, Jira MSSCI-16409 claimed and moved to In Progress, feature branch `feat/146-4-demo-yaml-config-branding` created in pennyfarthing repo.

**Routing:** Trivial workflow → Dev (White Rabbit) for implementation.

**Key context for Dev:** User specified branding source URL: https://1898andco.burnsmcd.com/. Dev should fetch branding details from that URL to populate demo.yaml configuration.

## Delivery Findings

Agents record upstream observations discovered during their phase.
Each finding is one list item. Use "No upstream findings" if none.

**Types:** Gap, Conflict, Question, Improvement
**Urgency:** blocking, non-blocking

<!-- Agents: append findings below this line. Do not edit other agents' entries. -->

### Dev (implementation)
- No upstream findings during implementation.

### Reviewer (code review)
- **Gap** (blocking): Orchestrator calls `classify_story(signals)` without `config_path` — demo.yaml classification rules are never loaded at runtime. Affects `pennyfarthing-dist/src/pf/demo/orchestrator.py:56` (must locate and pass demo.yaml path). *Found by Reviewer during code review.*
- **Improvement** (non-blocking): `_try_config_classification` swallows config load errors by returning None. Should propagate errors so users know their config is broken. Affects `pennyfarthing-dist/src/pf/demo/classifier.py:198-199` (return error result instead of None). *Found by Reviewer during code review.*
- **Improvement** (non-blocking): No defensive validation on config YAML structure — empty patterns match everything, non-list rules cause AttributeError, invalid regex crashes. Affects `pennyfarthing-dist/src/pf/demo/classifier.py:202-206` (add type checks and try/except). *Found by Reviewer during code review.*
- **Improvement** (non-blocking): Add inline documentation to demo.yaml classification section explaining rule schema (pattern, type, artifacts, valid values). Affects `pennyfarthing-dist/demo.yaml:62` (add comment block). *Found by Reviewer during code review.*

### Reviewer (code review — round 2)
- **Improvement** (non-blocking): `artifacts` field in config rules lacks isinstance check — if string instead of list, iteration over characters produces confusing error. Affects `pennyfarthing-dist/src/pf/demo/classifier.py:241` (add `isinstance(artifact_names, list)` guard). *Found by Reviewer during round 2 code review.*

## Impact Summary

**Upstream Effects:** 4 findings (1 Gap, 0 Conflict, 0 Question, 3 Improvement)
**Blocking:** 1 BLOCKING items — see below

**BLOCKING:**
- **Gap:** Orchestrator calls `classify_story(signals)` without `config_path` — demo.yaml classification rules are never loaded at runtime. Affects `pennyfarthing-dist/src/pf/demo/orchestrator.py:56`.

- **Improvement:** `_try_config_classification` swallows config load errors by returning None. Should propagate errors so users know their config is broken. Affects `pennyfarthing-dist/src/pf/demo/classifier.py:198-199`.
- **Improvement:** No defensive validation on config YAML structure — empty patterns match everything, non-list rules cause AttributeError, invalid regex crashes. Affects `pennyfarthing-dist/src/pf/demo/classifier.py:202-206`.
- **Improvement:** Add inline documentation to demo.yaml classification section explaining rule schema (pattern, type, artifacts, valid values). Affects `pennyfarthing-dist/demo.yaml:62`.

## Design Deviations

Agents log spec deviations as they happen — not after the fact.
Each entry: what was changed, what the spec said, and why.

<!-- Agents: append deviations below this line. Do not edit other agents' entries. -->

### Dev (implementation — round 2)
- No deviations from spec. All fixes directly address reviewer findings.

### Reviewer (audit)
- **Dev "No deviations"** → ✓ ACCEPTED by Reviewer: demo.yaml delivers all 3 AC sections (branding, format_preferences, classification) as specified. Structure aligns with classifier's expected config format.

### Reviewer (audit — round 2)
- **Dev "No deviations" (round 2)** → ✓ ACCEPTED by Reviewer: All 6 fixes directly address the original rejection findings. No spec deviations introduced.

## Subagent Results

| # | Specialist | Received | Status | Findings | Decision |
|---|-----------|----------|--------|----------|----------|
| 1 | reviewer-preflight | Yes | clean | none | N/A |
| 2 | reviewer-edge-hunter | Yes | findings | 12 | confirmed 3, dismissed 9 |
| 3 | reviewer-silent-failure-hunter | Yes | findings | 2 | confirmed 1, dismissed 1 |
| 4 | reviewer-test-analyzer | Yes | findings | 5 | confirmed 2, dismissed 3 |
| 5 | reviewer-comment-analyzer | Yes | findings | 2 | confirmed 1, dismissed 1 |
| 6 | reviewer-type-design | Yes | findings | 4 | confirmed 1, dismissed 3 |
| 7 | reviewer-security | Yes | clean | none | N/A |
| 8 | reviewer-simplifier | Yes | findings | 3 | dismissed 3 |

**All received:** Yes
**Total findings:** 8 confirmed, 20 dismissed, 0 deferred

### Finding Decisions

**Confirmed:**
1. [TEST] Orchestrator never passes config_path — classification rules are dead config (`orchestrator.py:56`)
2. [SILENT] _try_config_classification swallows config load errors, returns None instead of propagating (`classifier.py:198-199`)
3. [EDGE] Empty pattern string `rule.get("pattern", "")` matches everything — catch-all false positive (`classifier.py:205`)
4. [EDGE] No try/except around `re.search()` for invalid regex patterns from config (`classifier.py:206`)
5. [EDGE] No type validation on `rules` — non-list or non-dict items cause AttributeError (`classifier.py:202-204`)
6. [DOC] classification.rules section lacks inline schema documentation for rule structure
7. [TYPE] No structural validation of YAML after deserialization — malformed config silently falls through
8. [TEST] No integration test loading actual demo.yaml to verify the 6 specific regex patterns work

**Dismissed:**
- [EDGE] Regex word boundaries (9 findings): patterns run on short story titles via `re.IGNORECASE`; false positives are unlikely and acceptable for config-override rules that exist alongside built-in rules. The built-in `_title_has_keyword` uses `\b` but config rules intentionally use broader matching.
- [SIMPLE] Gold-plating on branding/format_preferences (2 findings): AC explicitly requested all 3 sections — spec-driven, not over-engineering.
- [SIMPLE] Duplicated artifact lists: 6 rules is manageable; YAML aliases would reduce readability.
- [DOC] "Stale comment" about Data Analytics: the header comment is a file description, not an enumeration of services — no mismatch.
- [TYPE] Schema validation for unused sections: no consumers exist yet; schema enforcement premature.
- [TYPE] `classification.rules` optionality: the `.get()` fallback to `[]` is correct defensive coding.
- [TEST] Missing tests for branding/format_preferences: no consumers, nothing to test.
- [TEST] Tautological config test: existing test verifies the config→enum mapping path, which is the right thing to test.
- [SILENT] Unvalidated regex crash: this is a crash (not silent), covered by finding #4 above.

## Dev Assessment (Round 1)

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/demo.yaml` - New demo configuration with 1898 & Co. branding, format preferences, and 6 classification rules

**Tests:** 71/71 passing (GREEN)
**Branch:** feat/146-4-demo-yaml-config-branding

**Handoff:** To next phase (review)

## Dev Assessment (Round 2 — post-rejection fixes)

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/src/pf/demo/orchestrator.py` - Wire config_path to classify_story() by locating demo.yaml relative to project_root
- `pennyfarthing-dist/src/pf/demo/classifier.py` - Propagate config load errors, validate config structure types, guard empty patterns, catch invalid regex
- `pennyfarthing-dist/demo.yaml` - Add inline schema documentation for classification rules section

**Reviewer Findings Addressed:**
| # | Severity | Fix |
|---|----------|-----|
| 1 | [HIGH] | Orchestrator now locates demo.yaml and passes config_path to classify_story() |
| 2 | [MEDIUM] | _try_config_classification returns error result instead of None on config load failure |
| 3 | [MEDIUM] | Empty pattern guard: `if not pattern: continue` |
| 4 | [MEDIUM] | re.search wrapped in try/except re.error with descriptive error result |
| 5 | [MEDIUM] | isinstance checks on classification (dict), rules (list), and each rule (dict) |
| 6 | [LOW] | Inline comment block documenting rule schema, valid types, and valid artifacts |

**Tests:** 92/92 passing (GREEN)
**Branch:** feat/146-4-demo-yaml-config-branding (pushed)

**Handoff:** To Reviewer (Queen of Hearts) for re-review

## Reviewer Assessment

**Verdict:** REJECTED

| Severity | Issue | Location | Fix Required |
|----------|-------|----------|--------------|
| [HIGH] | Orchestrator never passes config_path to classify_story — classification rules in demo.yaml are dead config, never loaded at runtime | `orchestrator.py:56` | Locate demo.yaml (relative to project root or pennyfarthing-dist/) and pass as config_path to classify_story() |
| [MEDIUM] | _try_config_classification swallows config load errors — returns None instead of error result, masking broken configs | `classifier.py:198-199` | Return the error result instead of None so callers see config failures |
| [MEDIUM] | Empty pattern default matches everything — `rule.get("pattern", "")` is a catch-all | `classifier.py:205` | Guard: `if not pattern: continue` |
| [MEDIUM] | No try/except around re.search for config regex — invalid patterns crash the pipeline | `classifier.py:206` | Wrap in try/except re.error, return error result |
| [MEDIUM] | No type validation on config structure — non-list rules or non-dict items cause AttributeError | `classifier.py:202-204` | Validate isinstance checks after .get() |
| [LOW] | classification.rules section lacks inline schema documentation | `demo.yaml:62` | Add comment explaining rule format, valid types, valid artifacts |

**Data flow traced:** demo.yaml → yaml.safe_load → config dict → classification.rules → re.search on title → StoryType enum → ArtifactType list. **Gap at orchestrator.py:56** — config_path never passed, so the flow never starts.

**Pattern observed:** [VERIFIED] All enum values in demo.yaml are correct (3 StoryType values, 5 ArtifactType values). Branding data matches source URL. YAML structure is clean.

**Error handling:** Config load errors are swallowed at classifier.py:198-199. Invalid regex patterns at classifier.py:206 would crash (uncaught re.error). Empty patterns at classifier.py:205 silently match everything.

**Security:** [VERIFIED] No secrets, safe_load used, no ReDoS risk, no injection vectors.

**Handoff:** Back to Dev for fixes — primarily wiring orchestrator config_path and hardening classifier input validation.

## Subagent Results (Round 2)

| # | Specialist | Received | Status | Findings | Decision |
|---|-----------|----------|--------|----------|----------|
| 1 | reviewer-preflight | Yes | clean | none | N/A |
| 2 | reviewer-edge-hunter | Yes | findings | 1 | confirmed 1 (MEDIUM) |
| 3 | reviewer-silent-failure-hunter | Yes | clean | none | N/A |
| 4 | reviewer-test-analyzer | Yes | findings | 7 | confirmed 3 (LOW), dismissed 4 |
| 5 | reviewer-comment-analyzer | Yes | findings | 1 | confirmed 1 (LOW) |
| 6 | reviewer-type-design | Yes | findings | 3 | dismissed 3 |
| 7 | reviewer-security | Yes | clean | none | N/A |
| 8 | reviewer-simplifier | Yes | findings | 3 | dismissed 3 |

**All received:** Yes
**Total findings:** 5 confirmed (1 MEDIUM, 4 LOW), 10 dismissed, 0 deferred

### Finding Decisions (Round 2)

**Confirmed:**
1. [EDGE] Missing isinstance check on `artifacts` field in config rules — if artifacts is a string instead of list, iteration over characters produces confusing error (`classifier.py:241`). **MEDIUM** — inconsistent with other type guards, fails safely but with bad error message.
2. [TEST] New isinstance validation guards (classification dict, rules list, rule dict) have no direct test coverage. **LOW** — straightforward checks, fix round prioritized correctness.
3. [TEST] Invalid regex error path (`try/except re.error`) untested. **LOW** — trivial error handling path.
4. [TEST] Empty pattern skip (`if not pattern: continue`) untested. **LOW** — trivial guard.
5. [DOC] Docstring at `classifier.py:196` says "Returns None if no rule matches" but function now also returns error dicts on validation failures. Return type `dict | None` still correct. **LOW** — incomplete but not misleading.

**Dismissed:**
- [TYPE] Return type contract concern (is not None conflates error with match): Error dicts ARE not None, so they propagate correctly through `if config_result is not None: return config_result`. The code works as intended.
- [TYPE] Caller check concern: Same — the `is not None` check correctly passes error dicts through.
- [TYPE] project_root type validation: Internal code called from CLI with typed parameter. Runtime type enforcement is over-engineering.
- [SIMPLE] Repeated isinstance pattern: 3 checks is not enough to justify a helper. Clear and readable.
- [SIMPLE] Empty pattern skip contradicts validation: Silently skipping empty patterns is the correct behavior per original finding #3.
- [SIMPLE] Redundant `.exists()` in orchestrator: `classify_story` also checks, but redundant safety is harmless.
- [TEST] Tautological assertion: Explicit success checks are a readability convention.
- [TEST] Regression risk in config precedence test: "Fix auth" matches BUGFIX built-in; if config broke, test would get BUGFIX not BACKEND. Test logic is correct.
- [TEST] Config load error propagation: Existing test infra covers load path indirectly.
- [TEST] Orchestrator config_path integration: Orchestrator uses mocks; simple path wiring beyond scope.

## Reviewer Assessment (Round 2)

**Verdict:** APPROVED

**Original findings verified:**
| # | Original Issue | Fix Verified |
|---|---------------|-------------|
| 1 | [HIGH] config_path never passed | ✓ `orchestrator.py:57-61` locates demo.yaml, passes to `classify_story()` |
| 2 | [MEDIUM] swallowed config errors | ✓ `classifier.py:199` returns `config_result` instead of None |
| 3 | [MEDIUM] empty pattern catch-all | ✓ `classifier.py:222-223` `if not pattern: continue` |
| 4 | [MEDIUM] uncaught re.error | ✓ `classifier.py:224-230` try/except with descriptive error |
| 5 | [MEDIUM] no type validation | ✓ `classifier.py:202-220` isinstance on classification, rules, each rule |
| 6 | [LOW] missing schema docs | ✓ `demo.yaml:62-69` 8-line comment block |

**Data flow traced:** demo.yaml → `yaml.safe_load` → config dict → `classification.rules` → isinstance guards → `re.search` on title (try/except) → StoryType enum → ArtifactType list → `_build_result`. **Gap at orchestrator.py:56 is now closed** — `config_path` resolved from `project_root/pennyfarthing-dist/demo.yaml` with `.exists()` guard.

**Pattern observed:** [VERIFIED] All 6 fixes are minimal and targeted. No scope creep. Error results follow `{success, error}` ADR-0008 pattern consistently.

**Error handling:** [VERIFIED] Config load errors now propagate. Invalid regex caught and reported. Empty patterns skipped. Type mismatches caught with descriptive messages.

**Security:** [VERIFIED] No new vectors. Config patterns from committed source, not user input. `safe_load` used. No ReDoS risk in patterns.

**Remaining notes (non-blocking):**
- MEDIUM: `artifacts` field lacks isinstance guard (inconsistent with other checks, but fails safely)
- LOW: New validation paths lack dedicated tests (fix round prioritized correctness)
- LOW: Docstring slightly stale (return type still correct)

**Handoff:** To The Mad Hatter (SM) for finish-story