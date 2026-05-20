# Epic 40: Scale Adaptation and Brownfield Support

## Overview

Adopt BMAD's scale-adaptive approach and extend brownfield codebase discovery. This epic adds upward scaling for larger initiatives (Level 0-4) and enhances brownfield analysis for existing codebases.

**Epic ID:** epic-40
**Points:** 17
**Priority:** P2
**Marker:** infrastructure
**Repos:** pennyfarthing
**Status:** backlog

## Goals

1. **Scale Levels (0-4)** - Define project scale levels from quick tasks to enterprise initiatives
2. **PRD Workflow for Small Changes** - Lightweight PRD mode for small changes (Level 1)
3. **Enterprise Hooks** - Add extension points for large-scale enterprise workflows
4. **Brownfield Discovery** - Enhance existing `brownfield scan` command (already implemented)
5. **Convention Adoption** - Auto-detect and adopt project conventions from brownfield analysis
6. **PRD Import** - Support importing external PRD documents into Pennyfarthing workflows

## Background

### BMAD Scale-Adaptive Approach

BMAD uses project scale levels to adapt workflow complexity:

| Level | Name | Description | Typical Duration |
|-------|------|-------------|------------------|
| 0 | Quick Fix | Single file change, no spec needed | < 1 hour |
| 1 | Simple Task | Few files, minimal spec | < 1 day |
| 2 | Feature | Multi-file, requires spec | 1-5 days |
| 3 | Epic | Cross-cutting, full planning | 1-4 weeks |
| 4 | Initiative | Enterprise-scale, multiple epics | 1+ months |

### Current State

Pennyfarthing has foundational components:
- **PRD workflow** with tri-modal support at `pennyfarthing-dist/workflows/prd/`
- **Brownfield discovery** implemented in `pennyfarthing_scripts/brownfield/`
- **PRD workflow** with tri-modal support at `pennyfarthing-dist/workflows/prd/`

This epic extends these to form a cohesive scale-adaptive system.

## Technical Approach

### Story 40-1: Define Scale Levels (2 points)

**Goal:** Create a formal scale-level schema and detection heuristics.

**Files to Create:**
- `pennyfarthing-dist/guides/scale-levels.md` - Documentation of scale levels
- `packages/core/src/scale/levels.ts` - Scale level types and constants

**Files to Modify:**
- `pennyfarthing-dist/guides/workflow-schema.md` - Add scale-level trigger support
- `packages/core/src/workflow/loader.ts` - Support scale-level routing

**Technical Notes:**
```typescript
// packages/core/src/scale/levels.ts
export enum ScaleLevel {
  QuickFix = 0,    // < 1 hour, single file
  SimpleTask = 1,  // < 1 day, few files
  Feature = 2,     // 1-5 days, multi-file
  Epic = 3,        // 1-4 weeks, cross-cutting
  Initiative = 4,  // 1+ months, enterprise
}

export interface ScaleDetectionResult {
  level: ScaleLevel;
  confidence: number;
  evidence: string[];
}
```

**Acceptance Criteria:**
- [ ] ScaleLevel enum defined with 5 levels (0-4)
- [ ] Scale detection heuristics documented
- [ ] Workflow schema supports `scale` trigger

---

---

### Story 40-3: Enterprise Workflow Hooks (3 points)

**Goal:** Add extension points for enterprise-scale workflows (Level 3-4).

**Files to Create:**
- `pennyfarthing-dist/workflows/enterprise-init/workflow.yaml` - Enterprise initialization workflow
- `pennyfarthing-dist/workflows/enterprise-init/steps/` - Enterprise workflow steps
- `packages/core/src/workflow/hooks.ts` - Workflow extension hooks

**Files to Modify:**
- `pennyfarthing-dist/guides/workflow-schema.md` - Document hooks

**Technical Notes:**
```yaml
# Enterprise workflow hooks
workflow:
  name: enterprise-init
  type: stepped
  scale: [3, 4]

  hooks:
    pre_start: ./hooks/pre-start.md      # Governance check
    post_phase: ./hooks/post-phase.md    # Phase reporting
    on_gate: ./hooks/on-gate.md          # Approval routing
    on_error: ./hooks/on-error.md        # Escalation
```

**Acceptance Criteria:**
- [ ] Hook system implemented (pre_start, post_phase, on_gate, on_error)
- [ ] Enterprise-init workflow created
- [ ] Hooks documented in workflow-schema.md

---

### Story 40-4: Brownfield Discovery Command Enhancement (5 points)

**Goal:** Enhance existing brownfield discovery with convention detection.

**Current Implementation:**
- `pennyfarthing_scripts/brownfield/discover.py` - Core discovery logic
- `pennyfarthing_scripts/brownfield/cli.py` - CLI entry point
- Tests at `pennyfarthing_scripts/tests/test_brownfield.py`

**Files to Modify:**
- `pennyfarthing_scripts/brownfield/discover.py` - Add convention detection
- `pennyfarthing_scripts/brownfield/cli.py` - Add new subcommands

**Files to Create:**
- `pennyfarthing_scripts/brownfield/conventions.py` - Convention extraction
- `pennyfarthing_scripts/brownfield/recommendations.py` - Adoption recommendations

**Technical Notes:**
```python
# conventions.py - Extract from existing code
@dataclass
class ConventionSet:
    naming: NamingConventions      # camelCase, snake_case, etc.
    structure: StructureConventions # src/, lib/, etc.
    testing: TestingConventions    # jest, pytest, vitest
    linting: LintingConventions    # eslint, ruff, etc.

async def detect_conventions(path: Path) -> ConventionSet:
    """Detect coding conventions from existing codebase."""
```

**Acceptance Criteria:**
- [ ] Convention detection for naming (camelCase, snake_case, etc.)
- [ ] Test framework detection (jest, pytest, vitest, etc.)
- [ ] Linting/formatting detection (eslint, prettier, ruff, etc.)
- [ ] Structure convention detection (src/, lib/, tests/, etc.)
- [ ] New tests in test_brownfield.py

---

### Story 40-5: Brownfield Convention Adoption (2 points)

**Goal:** Generate CLAUDE.md sections from brownfield analysis.

**Files to Create:**
- `pennyfarthing_scripts/brownfield/adopt.py` - Convention adoption logic
- `pennyfarthing-dist/templates/claude-md-conventions.md` - Template for conventions section

**Files to Modify:**
- `pennyfarthing_scripts/brownfield/cli.py` - Add `adopt` subcommand
- `pennyfarthing-dist/workflows/project-setup/steps/step-01-discover.md` - Integrate brownfield

**Technical Notes:**
```python
# adopt.py
async def generate_claude_md_section(conventions: ConventionSet) -> str:
    """Generate CLAUDE.md conventions section from detected conventions."""

async def adopt_conventions(
    project_path: Path,
    conventions: ConventionSet,
    claude_md_path: Path,
) -> AdoptionResult:
    """Apply detected conventions to CLAUDE.md."""
```

**Acceptance Criteria:**
- [ ] `brownfield adopt` command generates CLAUDE.md section
- [ ] Conventions integrated into project-setup workflow
- [ ] User confirmation before modifications

---

### Story 40-6: PRD Import Support (2 points)

**Goal:** Import external PRD documents into Pennyfarthing's PRD workflow.

**Files to Create:**
- `pennyfarthing_scripts/prd/__init__.py` - PRD import module
- `pennyfarthing_scripts/prd/import.py` - Import logic
- `pennyfarthing_scripts/prd/cli.py` - CLI commands

**Files to Modify:**
- `pennyfarthing-dist/workflows/prd/workflow.yaml` - Add import mode
- `pennyfarthing-dist/commands/prd.md` - Document import command

**Technical Notes:**
```python
# import.py
@dataclass
class ImportedPRD:
    title: str
    description: str
    requirements: list[Requirement]
    source_format: str  # confluence, notion, markdown, gdoc

async def import_prd(
    source: Path | str,
    format: str = "auto",
) -> ImportedPRD:
    """Import PRD from external source."""
```

**Acceptance Criteria:**
- [ ] Import from Markdown files
- [ ] Basic Confluence page import (via URL)
- [ ] PRD workflow has `import` mode alongside create/validate/edit
- [ ] Imported PRD maps to Pennyfarthing's internal format

## Key Files Summary

### New Files
| Path | Purpose |
|------|---------|
| `pennyfarthing-dist/guides/scale-levels.md` | Scale level documentation |
| `packages/core/src/scale/levels.ts` | Scale level types |
| `packages/core/src/workflow/hooks.ts` | Workflow extension hooks |
| `pennyfarthing-dist/workflows/enterprise-init/` | Enterprise workflow |
| `pennyfarthing_scripts/brownfield/conventions.py` | Convention detection |
| `pennyfarthing_scripts/brownfield/recommendations.py` | Adoption recommendations |
| `pennyfarthing_scripts/brownfield/adopt.py` | Convention adoption |
| `pennyfarthing_scripts/prd/` | PRD import module |

### Modified Files
| Path | Changes |
|------|---------|
| `pennyfarthing-dist/guides/workflow-schema.md` | Scale triggers, hooks |
| `pennyfarthing_scripts/brownfield/discover.py` | Convention detection |
| `pennyfarthing_scripts/brownfield/cli.py` | New subcommands |
| `pennyfarthing-dist/workflows/prd/workflow.yaml` | Import mode |
| `packages/core/src/workflow/loader.ts` | Scale routing |

## Dependencies

### Internal Dependencies
- **Epic 50** (Stepped Workflow Support) - Foundation for stepped workflows (COMPLETE)
- **Epic 54** (BMAD Workflow Imports) - PRD workflow already imported (COMPLETE)
- **PROJ-12419** (Brownfield Discovery) - Initial implementation (COMPLETE)

### External Dependencies
- None - all foundations are in place

## Blockers

- None identified - existing brownfield and workflow infrastructure provides solid foundation

## Success Criteria

1. **Scale Detection** - Projects automatically routed to appropriate workflow based on detected scale
2. **Quick Tasks Fast** - Level 0-1 tasks complete with minimal ceremony (< 5 workflow steps)
3. **Enterprise Ready** - Level 3-4 tasks have hooks for governance, approvals, and reporting
4. **Convention Adoption** - Brownfield analysis generates actionable CLAUDE.md sections
5. **PRD Import** - External PRDs can be imported and continue in Pennyfarthing's workflow
6. **Test Coverage** - All new code has corresponding tests

## Testing Strategy

### Unit Tests
- Scale level detection heuristics
- Convention detection accuracy
- PRD import parsing

### Integration Tests
- Workflow routing by scale level
- Brownfield → CLAUDE.md generation
- PRD import → workflow continuation

### E2E Tests
- Full PRD workflow for Level 1 task
- Full enterprise workflow for Level 4 initiative
- Brownfield scan → adopt → project setup

## References

- BMAD Scale-Adaptive Approach: `~/Projects/BMAD-METHOD/docs/scale-adaptation.md`
- Existing brownfield: `pennyfarthing_scripts/brownfield/`
- PRD workflow: `pennyfarthing-dist/workflows/prd/`
- Workflow schema: `pennyfarthing-dist/guides/workflow-schema.md`
