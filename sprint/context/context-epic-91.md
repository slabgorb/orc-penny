# Epic 91: Cross-File Reference & Schema Validation Pipeline

## Overview

Layered CI validation pipeline for `pennyfarthing-dist/` source files. Pennyfarthing distributes interconnected agents, commands, skills, workflows, and scripts across 469+ files with 1,685+ cross-references. When files are renamed, moved, or deleted, references from other files silently break and are only caught by users at runtime — typically when a BikeLane handoff fails or an agent can't find a script.

This epic ports a proven validation pipeline from [BMAD-METHOD](https://github.com/bmad-code-org/BMAD-METHOD) (PRs #1494, #1529, #1573) to Pennyfarthing, adapted for its specific structure (BikeLane workflows, agent handoffs, skill registry, command cross-refs, etc.).

**Value:** On first run against current `develop`, the validator found 6 genuine issues with zero false positives — after eliminating 7 initial false positives by adding runtime variable and template exclusions. Historical analysis of BMAD-METHOD showed broken file references accounted for 25% of all reported bugs (59 closed issues, 289 broken refs across 26 release tags).

## Validation Pyramid

```
    Layer 3: Graph Validation
        Step transitions, reachability (placeholder)

      Layer 2: Schema Validation
        YAML fields, required props, enums (adapted from BMAD PR #1529)

    Layer 1: File Reference Validation
      Cross-file refs, path resolution (17 checks, prototype complete)

  Layer 0: Formatting & Linting
    ESLint, Ruff, markdownlint, yamllint (partially configured)
```

## Current State (as of 2026-02-07)

### Layer 1 Validator — `scripts/validate-refs.js`

- **Branch:** `feat/validate-file-refs` (PR #721)
- **Status:** In progress, 17 check types implemented, 29 tests passing
- **Coverage:** 457 files scanned, 1,980 references checked, 0 false positives

#### 17 Check Types

| # | Check | Source files | Target |
|---|-------|-------------|--------|
| 1 | Workflow YAML `agent:` fields | `workflows/*.yaml` | `agents/*.md` |
| 2 | Stepped workflow `steps.path` | `workflows/*/workflow.yaml` | Step directories |
| 3 | Workflow YAML `template:` fields | `workflows/*.yaml` | Template files |
| 4 | YAML relative path values | All `.yaml` | Target files |
| 5 | Agent `<helpers>` subagent names | `agents/*.md` | `agents/*.md` |
| 6 | `.pennyfarthing/scripts/` paths | All `.md` | `scripts/` |
| 7 | `python3` script paths | All `.md` | `scripts/` |
| 8 | Command `<related>` cross-refs | `commands/*.md` | `commands/*.md` |
| 9 | Skill registry `related_skills` | `skill-registry.yaml` | `skills/*/` |
| 10 | Markdown `[text](./path)` links | All `.md` | Target files |
| 11 | Shell `source`/dot-source refs | All `.sh` | Target scripts |
| 12 | `handoff-marker.sh` targets | `agents/*.md` | Agent names |
| 13 | Absolute path leak detection | All files | N/A |
| 14 | Theme YAML agent keys | `personas/themes/*.yaml` | `agents/*.md` |
| 15 | Guide references in backticks | All `.md` | `guides/*.md` (with subdirectory support) |
| 16 | Skill `redirect:` targets | `skill-registry.yaml` | `skills/*/` |
| 17 | Python `import` statements | All `.py` | `pennyfarthing_scripts/` modules |

#### What it does NOT check (by design)

- Runtime variables (`{STORY_ID}`, `$CLAUDE_PROJECT_DIR`, `{{mustache}}`)
- Workflow `variables:` block values — runtime-substituted into step templates
- Template output files (`templates/`) — reference generated siblings
- Code blocks (triple-backtick fenced) — stripped before scanning
- OCEAN profile format in theme `additional_characters`
- Workflow trigger type taxonomy
- Template variable binding in workflow steps

### Lookup Builders

The validator builds lookup tables from the filesystem:

| Lookup | Count | Source |
|--------|-------|--------|
| Agent names | 10 | `pennyfarthing-dist/agents/*.md` |
| Guide names | 29 | `pennyfarthing-dist/guides/**/*.md` (recursive with subdirs) |
| Python modules | 106 | `pennyfarthing_scripts/` (dotted paths, respects `__init__.py`) |
| Skill names | ~22 | `pennyfarthing-dist/skills/*/` directories |
| Command names | ~49 | `pennyfarthing-dist/commands/*.md` |

### Testability Infrastructure

- `_isMain` guard wraps main execution block (prevents side effects on import)
- `_testing` export exposes check functions for unit tests
- Pattern matches `post-merge.sh` (`if [[ "${BASH_SOURCE[0]}" == "${0}" ]]`)

### Test Suite — `scripts/validate-refs.test.js`

29 tests across 7 suites using `node:test`:

| Suite | Tests | What |
|-------|-------|------|
| `getGuideNames` | 4 | Lookup builder incl. subdirectories |
| `getPythonModules` | 5 | Dotted module path discovery |
| `checkThemeAgentKeys` | 4 | Theme YAML agent keys vs `agents/*.md` |
| `checkGuideRefs` | 7 | Backtick guide refs, 3 prefix patterns, code block exclusion, subdirs |
| `checkSkillRegistry — redirect` | 3 | Deprecated skill redirect targets |
| `checkPythonImports` | 5 | Python import validation incl. package prefix fallback |
| `integration` | 1 | Full validator spawned as child process |

## Architecture Decisions

### ESM with YAML AST parsing

The validator uses ES modules and the `yaml` package's `parseDocument()` for AST-level YAML walking. This gives access to source ranges (byte offsets) for line number reporting, which is critical for GHA `::warning` annotations.

### Package-prefix fallback for Python imports

Python import validation uses a two-tier check: first tries exact dotted module match (e.g., `sprint.validate_cmd`), then falls back to checking if the first segment is a known package (e.g., `sprint`). This avoids false positives on deep module paths within known packages.

### Guide reference regex

Three prefix patterns are matched for guide references in backticks:

```
`guides/agent-behavior.md`
`.pennyfarthing/guides/agent-behavior.md`
`pennyfarthing-dist/guides/agent-behavior.md`
```

Regex: `` /`(?:\.pennyfarthing\/|pennyfarthing-dist\/|(?:\.\.?\/)*)?guides\/([a-zA-Z0-9_/-]+)\.md`/g ``

### Non-blocking by default

The validator runs in warning mode (exit 0) by default. `--strict` flag enables enforcement mode (exit 1). This allows gradual adoption — broken references appear in build logs without blocking builds.

## Prior Art

| Repo | PR | Status | What |
|------|-----|--------|------|
| BMAD-METHOD | [#1494](https://github.com/bmad-code-org/BMAD-METHOD/pull/1494) | Merged | Layer 1 file ref validator (original) |
| BMAD-METHOD | [#1529](https://github.com/bmad-code-org/BMAD-METHOD/pull/1529) | Closed | Layer 2 Zod schema validator (format migration) |
| BMAD-METHOD | [#1573](https://github.com/bmad-code-org/BMAD-METHOD/pull/1573) | Open | Layer 1 CSV extension |
| Pennyfarthing | [PR #721](https://github.com/slabgorb/pennyfarthing/pull/721) | Draft | Layer 1 adapted for Pennyfarthing |
| Pennyfarthing | `tests/check-references.sh` | Outdated | Legacy 328-line zsh checker (not maintained) |

## Broken References Found

### First run (6 genuine issues from 13 checks)

| File | Line | Reference | Fix PR | Jira |
|------|------|-----------|--------|------|
| `commands/run-ci.md` | 114 | `.pennyfarthing/scripts/run-ci.sh` | Merged (PR #722) | PROJ-14517 |
| `commands/setup.md` | 61 | `/theme` → `/set-theme` | Merged (PR #723) | PROJ-14518 |
| `skills/workflow/skill.md` | 343 | `../../docs/BIKELANE.md` | Merged (PR #724) | PROJ-14519 |
| `skills/workflow/skill.md` | 344 | ADR 0005 → 0013 | Merged (PR #726) | PROJ-14520 |
| `skills/workflow/skill.md` | 345 | `../workflows/` → `../../workflows/` | Merged (PR #725) | PROJ-14521 |
| `epics-and-stories/step-05` | 15 | `import-epic-to-future.sh` (never implemented) | Merged (PR #727) | PROJ-14522 |

### Second run (2 more from checks 14-17)

| File | Line | Reference | Jira |
|------|------|-----------|------|
| `skills/workflow/skill.md` | 344 | `../../docs/adr/0013-bmad-workflow-import.md` | PROJ-14552 |
| `guides/patterns/tdd-flow-pattern.md` | 397 | `guides/tactical-agent-behavior.md` → `agent-template-tactical.md` | PROJ-14553 |

### False positives eliminated (7 total)

- 5 BMAD-imported workflow variables (runtime-resolved, not static paths)
- 2 template artifacts (`OCEAN-ANALYSIS.md` generated at benchmark time)
- 1 regex fix: `[A-Z]:\\` matching sed `PR:**` — tightened to require `[A-Z]:\\[a-zA-Z]`

## Story Plan by Layer

### Ticket Status Summary

| Category | Stories | With Jira Ticket | Needs Ticket |
|----------|---------|-------------------|--------------|
| Layer 0 | 4 | 0 | **4** (91-7, 91-8, 91-9, 91-10) |
| Layer 1 | 2 | 2 | 0 |
| Layer 2 | 3 | 0 | **3** (91-11, 91-12, 91-13) |
| Layer 3 | 2 | 0 | **2** (91-14, 91-15) |
| Research | 4 | 4 | 0 |
| Bug fixes | 8 | 8 | 0 |
| **Total** | **23** | **14** | **9** |

Create Jira tickets for the 9 unlinked stories when they move from `planning` to `ready`.

### Layer 0: Formatting & Linting (8 pts, 4 stories)

| Story | Points | Jira | Depends On | Notes |
|-------|--------|------|-----------|-------|
| 91-7: Enforce ESLint | 3 | needs ticket | None | Remove `continue-on-error` from CI, add lint to shared + cyclist |
| 91-8: Add Ruff to CI | 1 | needs ticket | None | Wire existing `pyproject.toml` config, 107 Python files |
| 91-9: Add markdownlint | 2 | needs ticket | 91-3 (research) | Wire existing `.markdownlint.yaml`, 300 .md files |
| 91-10: Add yamllint | 2 | needs ticket | 91-3 (research) | Create `.yamllint.yaml` config, 55 YAML files |

### Layer 1: File Reference Validation (8 pts, 2 stories)

| Story | Points | Jira | Depends On | Notes |
|-------|--------|------|-----------|-------|
| 91-1: Productize validator | 3 | PROJ-14511 | None | **In progress** (PR #721) |
| 91-2: GHA workflow | 5 | PROJ-14512 | 91-1 | `::warning` annotations, `GITHUB_STEP_SUMMARY`, PR comment |

### Layer 2: Schema Validation (13 pts, 3 stories)

| Story | Points | Jira | Depends On | Notes |
|-------|--------|------|-----------|-------|
| 91-11: Workflow YAML schema | 5 | needs ticket | 91-5 (research) | 24 workflows, 3 variants (phased/stepped/procedural) |
| 91-12: Agent definition schema | 5 | needs ticket | 91-5 (research) | 19 agent files, required sections, helper model values |
| 91-13: Skill/command schema | 3 | needs ticket | 91-5 (research) | Enforce `skill-registry.schema.json`, 49 commands, 22 skills |

### Layer 3: Graph Validation (13 pts, 2 stories)

| Story | Points | Jira | Depends On | Notes |
|-------|--------|------|-----------|-------|
| 91-14: Workflow graph | 8 | needs ticket | 91-6 (research) | Step transitions, reachability, gate markers |
| 91-15: Cross-entity refs | 5 | needs ticket | 91-6 (research) | Bidirectional consistency across agents/workflows/commands/skills |

### Research (10 pts, 4 stories)

| Story | Points | Jira | Notes |
|-------|--------|------|-------|
| 91-3: Layer 0 R&D | 2 | PROJ-14513 | Linter selection and adoption plan |
| 91-4: Layer 1 R&D | 2 | PROJ-14514 | BMAD adaptation decisions doc |
| 91-5: Layer 2 R&D | 3 | PROJ-14515 | Schema approach and gap analysis |
| 91-6: Layer 3 R&D | 3 | PROJ-14516 | Graph validation feasibility study |

### Bug Fixes (8 pts, 8 stories)

| Story | Points | Jira | Status |
|-------|--------|------|--------|
| 91-16: run-ci.md wrong path | 1 | PROJ-14517 | done (PR #722) |
| 91-17: setup.md /theme ref | 1 | PROJ-14518 | done (PR #723) |
| 91-18: workflow BIKELANE link | 1 | PROJ-14519 | done (PR #724) |
| 91-19: workflow ADR 0005 link | 1 | PROJ-14520 | done (PR #726) |
| 91-20: workflow architecture.yaml path | 1 | PROJ-14521 | done (PR #725) |
| 91-21: step-05 missing script | 1 | PROJ-14522 | done (PR #727) |
| 91-22: broken ADR link | 1 | PROJ-14552 | planning |
| 91-23: stale guide ref | 1 | PROJ-14553 | planning |

## Key Files

| File | Purpose |
|------|---------|
| `pennyfarthing/scripts/validate-refs.js` | Layer 1 validator (~830 lines) |
| `pennyfarthing/scripts/validate-refs.test.js` | Test suite (29 tests, ~235 lines) |
| `pennyfarthing/package.json` | `validate:refs` and `test:validate-refs` scripts |
| `pennyfarthing/pennyfarthing-dist/` | Directory being validated (source of truth) |
| `pennyfarthing/pennyfarthing_scripts/` | Python package validated by check 17 |

## Usage

```bash
cd pennyfarthing
node scripts/validate-refs.js              # Warning mode (exit 0)
node scripts/validate-refs.js --verbose    # Show all 1,980 refs checked
node scripts/validate-refs.js --strict     # Enforcement mode (exit 1)
pnpm run test:validate-refs                # Run 29 unit + integration tests
```

## Out-of-Scope Gaps (future ticket)

Identified during gap analysis of checks 14-17 but classified as schema/format validation rather than file references:

- Workflow trigger type taxonomy validation
- Helper character name validation in themes
- OCEAN profile format validation in `additional_characters`
- Template variable binding validation in workflow steps
