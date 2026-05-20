# Story 87-1: Extend repos.yaml schema with ownership and boundaries

**Epic:** 87 — Repo Topology & Agent Spatial Awareness
**Jira:** PROJ-14785
**Points:** 2
**Priority:** P0
**Workflow:** tdd-tandem
**Phase:** finish
**Repos:** pennyfarthing
**Branch:** feat/87-1-repo-topology-schema
**Assigned:** Keith Avery

---

## Context

The #1 friction category (25 incidents) is agents targeting the wrong file or repo. This story extends `repos.yaml` with machine-readable topology fields so agents know ownership, boundaries, and rendering context at startup.

## Acceptance Criteria

- [ ] Each repo entry in repos.yaml has an `owns` field with glob patterns for directory ownership
- [ ] Each repo entry has a `never_edit` field listing off-limits paths (node_modules, symlinks, build output)
- [ ] Each repo entry has a `symlinks` mapping of symlink paths to their actual source locations
- [ ] Each repo entry has a `ui_layer` field (react|cli|none) identifying rendering context
- [ ] Optional `components_path` field for repos with UI components
- [ ] Schema is validated (tests confirm structure is correct)
- [ ] Existing repos.yaml data is preserved (backwards compatible extension)

## Technical Approach

Extend the existing `repos.yaml` at `pennyfarthing/pennyfarthing-dist/repos.yaml` (which symlinks to `.pennyfarthing/repos.yaml`) with new fields per repo entry. The schema should be self-documenting with comments.

## Files to Modify

- `pennyfarthing-dist/repos.yaml` — add new topology fields
- Tests for schema validation

## TEA Assessment

**Tests Required:** Yes
**Reason:** Schema validation requires tests for each topology field and backwards compatibility

**Test Files:**
- `packages/shared/src/repos-topology.test.ts` — 27 tests across 7 AC groups
- `packages/shared/src/repos-topology.ts` — stub with types and validation function signature

**Tests Written:** 27 tests covering 7 ACs
**Status:** RED (24 failing on assertion, 3 passing trivially — correct RED state)

**Test Breakdown by AC:**
| AC | Tests | Description |
|----|-------|-------------|
| AC1 | 3 | `owns` field — valid array, reject non-array, reject non-string entries |
| AC2 | 3 | `never_edit` field — valid array, reject non-array, reject non-string entries |
| AC3 | 4 | `symlinks` field — valid object, empty object, reject array, reject non-string values |
| AC4 | 4 | `ui_layer` field — react/cli/none valid, reject invalid value |
| AC5 | 3 | `components_path` — present, absent (optional), reject non-string |
| AC6 | 7 | Schema validation — null, missing repos, bad structure, missing required fields |
| AC7 | 3 | Backwards compatibility — legacy config, partial topology, field preservation |

**Implementation Notes for Dev:**
- Implement `validateReposTopology()` in `repos-topology.ts`
- Implement `loadReposConfig()` for file loading (uses `yaml` package already in deps)
- Update `.pennyfarthing/repos.yaml` with actual topology data for both repos
- Export from `index.ts` if needed by other packages

**Handoff:** To Dev for implementation (GREEN phase)

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `packages/shared/src/repos-topology.ts` — implemented `validateReposTopology()` and `loadReposConfig()`
- `.pennyfarthing/repos.yaml` — extended with topology data for both repos (orchestrator PR)

**Tests:** 27/27 passing (GREEN)
**PR:** #816 — feat(87-1): repos.yaml topology schema with ownership and boundaries (pennyfarthing)
**PR:** #13 — feat(87-1): add topology data to repos.yaml (orchestrator)
**Branch:** feat/87-1-repo-topology-schema (pennyfarthing), feat/87-1-repos-topology-data (orchestrator)

**Implementation Details:**
- `validateReposTopology()`: validates top-level structure, required fields (path, type, description), and optional topology fields
- `loadReposConfig()`: async file loader using dynamic imports for `fs` and `yaml`
- All topology fields optional for backwards compatibility
- Error messages include field path for easy debugging (e.g. `repos.orchestrator.owns must be an array`)

**Handoff:** To Reviewer for code review

## Reviewer Assessment

**Verdict:** APPROVED
**Data flow traced:** `unknown` config → `isRecord()` guard → `validateRepo()` per entry → field-level validation → `{ valid, errors }` (safe — no mutation, no I/O)
**Pattern observed:** Result-object pattern at `repos-topology.ts:111-127` — never throws, accumulates errors
**Error handling:** All errors accumulated with field paths (e.g. `repos.orchestrator.owns must be an array`) at `repos-topology.ts:49-55`
**Security:** Pure validation function, no I/O in synchronous path. No injection vectors.

**Observations:**
| Severity | Issue | Location |
|----------|-------|----------|
| [VERIFIED] | Result pattern compliance | `repos-topology.ts:111-127` |
| [VERIFIED] | All 7 ACs covered (27 tests) | `repos-topology.test.ts` |
| [VERIFIED] | Backwards compatibility tested | `repos-topology.test.ts:260-285` |
| [VERIFIED] | repos.yaml topology accuracy | `.pennyfarthing/repos.yaml` |
| [MEDIUM] | `loadReposConfig()` untested | `repos-topology.ts:133-147` |
| [LOW] | Async wrapper around sync I/O | `repos-topology.ts:135` |
| [VERIFIED] | Type narrowing correct | `repos-topology.ts:44-46` |

**PRs merged:** pennyfarthing#816, orchestrator#13
**Handoff:** To SM for finish-story

## Session Log

- **Setup:** Story claimed, branch created, session initialized
- **RED:** 27 failing tests written and committed (fafa513)
- **GREEN:** Implementation complete, 27/27 passing (336e5a6). PRs: pennyfarthing#816, orchestrator#13
- **Review:** APPROVED — 0 Critical, 0 High, 1 Medium, 1 Low. PRs merged.
