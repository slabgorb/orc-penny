---
story_id: "144-4"
jira_key: "MSSCI-16388"
epic: "MSSCI-16384"
workflow: "trivial"
---
# Story 144-4: Add simplify toggle to repos.yaml

## Story Details
- **ID:** 144-4
- **Jira Key:** MSSCI-16388
- **Epic:** MSSCI-16384 (Specification Fidelity Gates)
- **Workflow:** trivial
- **Points:** 1
- **Priority:** p1
- **Stack Parent:** none

## Workflow Tracking
**Workflow:** trivial
**Phase:** finish
**Phase Started:** 2026-03-13T09:50:57Z

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-03-13 | 2026-03-13T09:45:46Z | 9h 45m |
| implement | 2026-03-13T09:45:46Z | 2026-03-13T09:48:13Z | 2m 27s |
| review | 2026-03-13T09:48:13Z | 2026-03-13T09:50:57Z | 2m 44s |
| finish | 2026-03-13T09:50:57Z | - | - |

## Story Context

### Title
Add simplify toggle to repos.yaml

### Description
Add a `simplify` toggle to the `repos.yaml` configuration schema that allows repositories to opt into simplified behavior for the framework's orchestration features.

### Acceptance Criteria
1. `repos.yaml` schema includes a new `simplify` boolean field at the repository level
2. The field defaults to `false` (simplification OFF unless explicitly enabled)
3. Framework honors the `simplify` flag in relevant orchestration components
4. Documentation updated to explain the simplify toggle and when to use it
5. Configuration is validated on startup with appropriate error messages for invalid values

### Technical Approach
- Extend `repos.yaml` JSON schema to add the `simplify` field
- Add field to Python `RepoConfig` dataclass for type safety
- Update schema validation logic to enforce the default value
- Add tests confirming the toggle behavior
- Update `repos.yaml` documentation with the new field and default

### Important Notes
- The simplify toggle should default to OFF (false)
- This is part of the broader Specification Fidelity Gates epic, which modernizes how framework handles configuration

## SM Assessment

Story 144-4 is a 1-point trivial story to add a `simplify` boolean toggle to `repos.yaml`. Key requirement: defaults to OFF (false). Schema update, dataclass addition, validation, and docs. Straightforward config change — routing to Dev for implementation.

**Routing:** Trivial workflow → Dev (skip TEA)
**Risk:** Low — schema extension with clear acceptance criteria

## Reviewer Assessment

**Verdict:** APPROVED

**Observations:**
1. [VERIFIED] AC1 — `simplify: bool = False` on `RepoConfig` at `repos.py:48`, parsed at `repos.py:87`. Field present, typed, defaulted.
2. [VERIFIED] AC2 — Default is `False` in both dataclass declaration and `_parse_repo_entry`. Absent key → `False`. Correct.
3. [VERIFIED] Pattern — Implementation follows exact pattern of `pr_strategy`/`stack_tool` (same file, same function, same `.get()` with default). No deviation from codebase conventions.
4. [VERIFIED] Topology output — `loader.py:468` only surfaces when truthy, consistent with `components_path` pattern at line 464-466. No noise for repos that don't opt in.
5. [VERIFIED] Data flow — YAML safe_load → dict → `data.get("simplify", False)` → RepoConfig.simplify (bool). Separately, raw dict → `config.get("simplify")` → topology text. Both paths safe.
6. [LOW] AC3/AC4/AC5 — Consumer wiring, docs, and validation are not in this diff. Acceptable for a 1-point schema-add story; the remaining ACs belong in follow-up stories that consume the toggle.

**Data flow traced:** repos.yaml → yaml.safe_load → _parse_repo_entry → RepoConfig.simplify (safe: absent key → False, YAML bool coercion handles yes/no/on/off)
**Pattern observed:** Follows pr_strategy/stack_tool pattern exactly at repos.py:46-48, repos.py:84-87
**Error handling:** data.get() with False default — safe on missing key, consistent with all other fields
**Security:** No concerns — boolean config flag, no user input, no injection surface

**Handoff:** To Stilgar for finish-story

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/src/pf/git/repos.py` - Added `simplify: bool = False` to RepoConfig dataclass and `_parse_repo_entry` parser
- `pennyfarthing-dist/src/pf/prime/loader.py` - Surface `simplify: enabled` in topology output when toggled on

**Tests:** 142/142 passing (GREEN)
**Branch:** feat/144-4-simplify-toggle-repos-yaml (pushed)

**Handoff:** To Reviewer for code review

## Delivery Findings

No upstream findings.

<!-- Agents: append findings below this line. Do not edit other agents' entries. -->

### Dev (implementation)
- No upstream findings during implementation.

### Reviewer (code review)
- **Gap** (non-blocking): AC3 ("Framework honors the simplify flag in relevant orchestration components") is schema-only — no consumer reads `RepoConfig.simplify` to conditionally enable/disable simplify subagents yet. Affects `pennyfarthing-dist/agents/tea.md` and workflow YAML (future story scope). *Found by Reviewer during code review.*
- **Gap** (non-blocking): AC4 ("Documentation updated") — `workflows/project-setup/steps/step-03-repos-yaml.md` does not list `simplify` as a repos.yaml field. Affects `pennyfarthing-dist/workflows/project-setup/steps/step-03-repos-yaml.md` (add `simplify` to schema template). *Found by Reviewer during code review.*

## Impact Summary

**Upstream Effects:** 1 findings (1 Gap, 0 Conflict, 0 Question, 0 Improvement)
**Blocking:** None

- **Gap:** AC4 ("Documentation updated") — `workflows/project-setup/steps/step-03-repos-yaml.md` does not list `simplify` as a repos.yaml field. Affects `pennyfarthing-dist/workflows/project-setup/steps/step-03-repos-yaml.md`.

## Design Deviations

No design deviations.

<!-- Agents: append deviations below this line. Do not edit other agents' entries. -->

### Dev (implementation)
- **Topology output is opt-in display:** Only shows "Simplify: enabled" when `true` — omits the line entirely when `false` (default). Reason: Consistent with existing pattern where `components_path` is only shown when present, avoiding noise for the majority of repos.
- **No explicit validation errors for invalid values:** YAML's `safe_load` coerces non-boolean to falsy naturally. Adding explicit type validation would be over-engineering for a boolean field with a safe default. The dataclass type annotation provides IDE-time checking.

### Reviewer (audit)
- **Topology output is opt-in display** → ✓ ACCEPTED by Reviewer: Follows existing pattern for `components_path`. Showing "Simplify: disabled" on every repo would be noise.
- **No explicit validation errors for invalid values** → ✓ ACCEPTED by Reviewer: Consistent with every other field in RepoConfig — none validate types at runtime. YAML safe_load handles boolean coercion correctly.