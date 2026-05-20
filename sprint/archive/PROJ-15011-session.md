# Story 107-3: Gate authoring guide and validation command

## Story Details
- **ID:** 107-3
- **Jira Key:** PROJ-15011
- **Workflow:** agent-docs
- **Points:** 2
- **Epic:** 107 (Gate Validation & Authoring)
- **Repos:** pennyfarthing

## Acceptance Criteria
- [x] Create `pennyfarthing-dist/guides/gate-schema.md` with:
  - Complete schema documentation
  - Working example(s)
  - Authoring best practices
- [x] Add validation command that:
  - Checks schema compliance
  - Validates acyclic (no cycles)
  - Enforces depth limit
  - Checks mandatory pass/fail
  - Reports ALL errors at once (not fail-fast)
- [x] Valid gates get confirmation with structure summary
- [x] Documentation follows existing guide conventions

## Workflow Tracking
**Workflow:** agent-docs
**Phase:** finish
**Phase Started:** 2026-02-15 16:30 UTC

### Phase History
| Phase | Started | Ended | Duration |
|-------|---------|-------|----------|
| setup | 2026-02-15 16:02 UTC | 2026-02-15 16:04 UTC | 2m |
| analyze | 2026-02-15 16:04 UTC | 2026-02-15 16:12 UTC | 8m |
| implement | 2026-02-15 16:12 UTC | 2026-02-15 16:20 UTC | 8m |
| review | 2026-02-15 16:20 UTC | 2026-02-15 16:30 UTC | 10m |
| finish | 2026-02-15 16:30 UTC | - | - |

## Context
This story completes the Gate Validation & Authoring epic (107). Previous stories (107-1, 107-2) implemented:
- Schema validation at parse time (PROJ-15009)
- Acyclic validation and depth limit enforcement (PROJ-15010)

This story (107-3) adds:
1. Comprehensive authoring guide at `pennyfarthing-dist/guides/gate-schema.md`
2. CLI validation command with full error reporting

The workflow is phased: SM → Orchestrator (analyze & implement) → Tech Writer (review) → SM (finish)

## Notes
- Orchestrator will analyze existing gate definitions and propose complete schema documentation
- Tech Writer will review for clarity, structure, and accuracy
- Focus on practical guidance for authors working with gate definitions

---
## Orchestrator Assessment

**PR:** https://github.com/slabgorb/pennyfarthing/pull/919

### Files Created
| File | Purpose |
|------|---------|
| `pennyfarthing-dist/guides/gate-schema.md` | Complete gate authoring guide |
| `pennyfarthing_scripts/gate/__init__.py` | Gate CLI package |
| `pennyfarthing_scripts/gate/cli.py` | `pf gate validate` command |
| `pennyfarthing_scripts/gate/validate.py` | Validation logic (schema, depth, cycles) |

### Files Modified
| File | Change |
|------|--------|
| `pennyfarthing_scripts/cli.py` | Register `gate` command group |

### Validation Tested
| Scenario | Result |
|----------|--------|
| Valid gate (tests-pass.md) | PASS — structure summary shown |
| Valid gate (confidence-sm.md) | PASS — structure summary shown |
| Missing pass/fail elements | FAIL — both errors reported at once |
| Depth limit (level 4) | FAIL — depth exceeded error |
| Duplicate gate names | FAIL — cycle detection error |
| Multiple errors (empty, unnamed, missing) | FAIL — all 4 errors in one pass |
| Nested gate (parent + child) | PASS — depth 1, 1 child |

**Handoff:** To Corporal LeBeau (Tech Writer) for documentation review

---
## Tech Writer Review

**Verdict:** APPROVED

### Guide Review (`pennyfarthing-dist/guides/gate-schema.md`)

| Criterion | Status | Notes |
|-----------|--------|-------|
| Clear structure | PASS | Logical flow: Location → Schema → Contract → Example → Integration → Validation → Best Practices |
| No stale references | PASS | Both `workflow-schema.md` and `patterns/approval-gates-pattern.md` resolve |
| Follows guide conventions | PASS | Uses `<info>` tag, `##` sections, tables, code blocks — matches `bikelane.md` and `workflow-schema.md` |
| XML tags properly nested | PASS | All examples have matching open/close tags |
| Examples are accurate | PASS | Schema matches `gate_runner.py` parser, discovery matches `gate_file.py` |
| Audience appropriate | PASS | Written for workflow authors — the right audience for gate authoring |

### Accuracy Checks

| Claim in Guide | Verified Against | Match |
|----------------|-----------------|-------|
| Discovery: `.pennyfarthing/gates/` → `pennyfarthing-dist/gates/` | `gate_file.py:45-48` | Exact |
| `model` defaults to `haiku` | `gate_runner.py:76` | Exact |
| Max depth 3 | `validate.py:20` (`MAX_DEPTH = 3`) | Exact |
| `status: pass \| fail` strict enum | `gate_runner.py:117` | Exact |
| Default-deny on missing GATE_RESULT | `gate_runner.py:21-25` | Exact |

### CLI Review (`pf gate validate`)

| Check | Status |
|-------|--------|
| `pf gate --help` renders cleanly | PASS |
| `pf gate validate` on valid gate → structure summary | PASS |
| `pf gate validate` on invalid gate → all errors at once | PASS |
| Exit code 1 on failure | PASS |
| Lazy import pattern matches other CLI commands | PASS |

### Minor Observations (non-blocking)

1. **Output format cosmetic:** Guide shows `Gate 'tests-pass' is valid` but actual output includes `[OK]` prefix. Acceptable — guide shows semantic content, prefix is terminal formatting.
2. **`GateInfo` dataclass** in `validate.py` is defined but unused. Dead code, but harmless.

**Handoff:** To Colonel Hogan (SM) for finish
