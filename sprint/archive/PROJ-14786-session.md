# Story 87-2: Wire topology into agent prime context

**Epic:** 87 — Repo Topology & Agent Spatial Awareness
**Jira:** PROJ-14786
**Points:** 2
**Priority:** P0
**Workflow:** tdd-tandem
**Phase:** finish
**Repos:** pennyfarthing
**Branch:** feat/87-2-wire-topology-prime-context
**Assigned:** Keith Avery

---

## Phase History

| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-02-11T17:14:00Z | 2026-02-11T17:15:30Z | 1m 30s |
| red | 2026-02-11T17:15:30Z | 2026-02-11T17:45:00Z | 29m 30s |
| green | 2026-02-11T17:45:00Z | 2026-02-11T18:15:00Z | 30m 0s |
| review | 2026-02-11T18:15:00Z | 2026-02-11T18:27:28Z | 12m 28s |
| finish | 2026-02-11T18:27:28Z | - | - |

## Handoff History

| From | To | Gate | Status | Timestamp |
|------|-----|------|--------|-----------|
| setup (sm) | red (tea) | manual | PASSED | 2026-02-11T17:15:30Z |
| red (tea) | green (dev) | tests_fail | PASSED | 2026-02-11T17:45:00Z |
| green (dev) | review (reviewer) | tests_pass | PASSED | 2026-02-11T18:15:00Z |
| review (reviewer) | finish (sm) | approval | PASSED | 2026-02-11T18:27:28Z |

---

## Context

Story 87-1 created the repos.yaml topology schema with ownership boundaries, never-edit zones, symlink mappings, and UI layer identification. This story wires that topology data into the agent prime context system so agents receive the spatial awareness manifest at startup. Agents will now know which repo owns which paths, what's off-limits, and where UI components live before their first action.

The prime system (in `pennyfarthing_scripts.prime`) bootstraps agents with tiered context. The loader modules (`loader.py`) currently load agent definitions, behavior guides, sprint context, session context, and sidecars. Story 87-2 adds topology context so `getPrimeContextJson()` in Cyclist and the prime CLI include repos topology as a new component alongside existing components.

## Acceptance Criteria

- [ ] **AC1:** Topology context is loaded from repos.yaml and integrated into the prime context system
  - `load_repos_topology()` function added to `pennyfarthing_scripts/prime/loader.py`
  - Validates and loads repos.yaml using `validateReposTopology()` from `@pennyfarthing/shared`
  - Handles missing or invalid topology gracefully (returns empty context if repos.yaml unavailable)

- [ ] **AC2:** Agents receive repos topology in their prime context (FULL tier)
  - Topology is included in all FULL tier context loads (new session startup)
  - Formatted as a readable manifest (repo name, owns[], never_edit[], ui_layer)
  - Positioned after sprint context, before session context (mid-priority in context stack)

- [ ] **AC3:** Cyclist's `getPrimeContextJson()` includes topology in JSON output
  - Topology appears as a `components` list item (name, tokens, source)
  - Returns parsed repos topology structure (not just text)
  - Source path: `.pennyfarthing/repos.yaml`

- [ ] **AC4:** Topology context is available to reduced tiers (REFRESH, HANDOFF, MINIMAL)
  - REFRESH tier: topology included (spatial awareness is session-independent)
  - HANDOFF tier: topology included (new agent needs full orientation)
  - MINIMAL tier: topology skipped (deep conversation context)

- [ ] **AC5:** Unit tests cover topology loading and integration
  - Test happy path: valid repos.yaml with topology fields loads correctly
  - Test error handling: missing repos.yaml, invalid YAML, validation errors
  - Test token counting: topology component reports realistic token count
  - Test backwards compatibility: repos.yaml without topology fields works fine

## Technical Approach

### Phase 1: Add Loader Function
Create `load_repos_topology()` in `pennyfarthing_scripts/prime/loader.py` that:
1. Loads `.pennyfarthing/repos.yaml` using `loadReposConfig()` from shared
2. Validates structure with `validateReposTopology()`
3. Formats topology as readable context (markdown-style manifest)
4. Returns formatted text or None if unavailable

### Phase 2: Integrate into Prime Context
Update `pennyfarthing_scripts/prime/cli.py`:
1. In `prime()` function's FULL tier path, call `load_repos_topology()` after sprint context
2. Add section header "Repos Topology" and print formatted topology
3. In `_build_json_result()`, include topology as a component with token count estimate
4. Update `_component_header()` and `_component_source()` mappings for topology

### Phase 3: Integrate into Tiered Tiers
Update `pennyfarthing_scripts/prime/tiers.py`:
1. Include topology in FULL, REFRESH, and HANDOFF tier components
2. Estimate token count (typically 200-300 tokens for both repos)
3. Exclude from MINIMAL tier (keep minimal)

### Phase 4: Update TypeScript Integration
Verify `packages/cyclist/src/prime.ts`:
1. `getPrimeContextJson()` already calls Python prime with `--json` flag
2. `parsePrimeOutput()` extracts components list
3. No changes needed in Cyclist—output will automatically include topology

### Phase 5: Tests
Create tests in `pennyfarthing_scripts/tests/prime/test_topology_loader.py`:
- Happy path: valid topology file loads and formats correctly
- Error paths: missing file, invalid YAML, validation errors
- Token counting: estimates realistic token count
- Backwards compatibility: repos without topology fields

## Files to Modify

**Primary:**
- `pennyfarthing_scripts/prime/loader.py` — add `load_repos_topology()` function
- `pennyfarthing_scripts/prime/cli.py` — integrate topology into FULL tier and JSON output
- `pennyfarthing_scripts/prime/tiers.py` — include topology in tier component lists

**Testing:**
- `pennyfarthing_scripts/tests/prime/test_topology_loader.py` — new test file

**Verification (no changes, just usage):**
- `packages/cyclist/src/prime.ts` — already integrated via JSON output
- `packages/shared/src/repos-topology.ts` — validation used by loader

## TEA Assessment

**Tests Required:** Yes
**Reason:** Prime integration requires validation of loader, tier availability, JSON output, and backwards compatibility

**Test Files:**
- `pennyfarthing_scripts/tests/test_topology_loader.py` — 29 tests across 7 test classes
- `pennyfarthing_scripts/prime/loader.py` — stub `load_repos_topology()` added (returns None)

**Tests Written:** 29 tests covering 5 ACs
**Status:** RED (19 failing on assertions, 10 passing for error handling — correct RED state)

**Test Breakdown by AC:**
| AC | Tests | Description |
|----|-------|-------------|
| AC1 | 13 | `load_repos_topology()` — valid loading, formatting fields, error handling |
| AC2 | 3 | FULL tier includes topology, token count, text output |
| AC3 | 3 | JSON output — component in list, tokens, source path |
| AC4 | 4 | Tier availability — FULL/REFRESH/HANDOFF yes, MINIMAL no |
| AC5 | 6 | Token counting (realistic range), backwards compat, CLI integration |

**Implementation Notes for Dev:**
- Implement `load_repos_topology()` in `pennyfarthing_scripts/prime/loader.py` — read `.pennyfarthing/repos.yaml`, format as readable manifest
- Add `repos_topology` to `load_tier_components()` in `tiers.py` for FULL, REFRESH, HANDOFF tiers (not MINIMAL)
- Add `repos_topology` to `_component_header()` and `_component_source()` in `cli.py`
- Add topology to FULL tier text output path in `prime()` function (between sprint and session)
- The loader is pure Python — use `yaml` module, not the TypeScript `validateReposTopology()`
- Export `load_repos_topology` from `__init__.py` and import in `tiers.py`

**Handoff:** To Dev for implementation (GREEN phase)

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing_scripts/prime/loader.py` — implement `load_repos_topology()` to read repos.yaml and format as readable manifest
- `pennyfarthing_scripts/prime/tiers.py` — add `repos_topology` to FULL, REFRESH, HANDOFF tiers (not MINIMAL)
- `pennyfarthing_scripts/prime/cli.py` — add component header/source mappings + text output in FULL tier path
- `pennyfarthing_scripts/prime/__init__.py` — export `load_repos_topology`

**Tests:** 29/29 passing (GREEN)
**PR:** #818 — feat(87-2): wire repos topology into agent prime context
**Branch:** feat/87-2-wire-topology-prime-context (pushed)

**Handoff:** To Reviewer for code review

## Reviewer Assessment

**Verdict:** APPROVED
**Data flow traced:** repos.yaml (disk) → yaml.safe_load → dict → string formatting → prime context text (safe — no user input, controlled file)
**Pattern observed:** Follows existing loader pattern (load_X returns str|None, graceful degradation) at `loader.py:241`
**Error handling:** 5 error paths verified (missing file, missing dir, invalid YAML, no repos key, empty repos) at `loader.py:261-273`
**Security:** yaml.safe_load prevents deserialization attacks, no injection vectors
**Observations:** 2 LOW (inline import at cli.py:479, "PRIORITY 5.5" comment at cli.py:476) — non-blocking
**Regressions:** None — test_yaml_io failure is pre-existing on develop

**Handoff:** To SM for finish-story

## Session Log

- **Setup:** Story claimed, branch created, session initialized (2026-02-11)
- **RED:** 29 tests written and committed (b1ce96d) — 19 failing, 10 passing (error handling)
- **GREEN:** Implementation complete (5cd96e5) — 29/29 passing, PR #818 created
- **REVIEW:** APPROVED — no CRITICAL/HIGH issues, 2 LOW cosmetic observations
