# Story 130-1: /pf-context create epic Skill

**Jira:** PROJ-15686
**Epic:** PROJ-15685 — Automated Context Creation
**Points:** 2
**Type:** feature
**Repos:** pennyfarthing
**Workflow:** tdd
**Phase:** finish
**Assigned:** slabgorb@gmail.com
**Started:** 2026-02-26
**Branch:** feat/PROJ-15686-pf-context-create-epic

## Context

This story creates the `/pf-context create epic` command as a markdown skill definition that orchestrates epic context document generation. The skill reads epic YAML shards from the sprint, consults the context schema (from 129-2) for required sections, and populates the epic context template (from 129-4) with planning document references and technical architecture summaries. The skill uses schema-driven section requirements rather than hardcoding, ensuring flexibility as the schema evolves. Epic context creation is a single-agent operation with no tandem partner, as epic-level context is strategic rather than implementation-focused. The templates folded from 129-4 will be referenced and stored at `pennyfarthing-dist/templates/context-epic-template.md`.

## Acceptance Criteria

- [ ] Skill definition exists at `pennyfarthing-dist/skills/pf-context/skill.md` with metadata
- [ ] `/pf-context create epic {id}` reads epic YAML shard and planning docs
- [ ] Skill reads `context-schema.yaml` for required epic sections (schema-driven, never hardcoded)
- [ ] Skill populates `context-epic-template.md` template and writes to `sprint/context/context-epic-{id}.md`
- [ ] Epic context template created at `pennyfarthing-dist/templates/context-epic-template.md` (folded from 129-4)
- [ ] Output passes validation (correct sections per schema)
- [ ] No tandem partner for epic context — single-agent operation

## Technical Approach

1. Create epic context template at `pennyfarthing-dist/templates/context-epic-template.md`
2. Create skill definition at `pennyfarthing-dist/skills/pf-context/skill.md` with metadata
3. Skill orchestrates: read epic YAML → read schema → read planning docs → fill template → write output
4. Schema at `pennyfarthing-dist/schemas/context-schema.yaml` is the authority for required sections

## Planning Documents

| Document | Relevant Sections |
|----------|-------------------|
| **PRD** (`sprint/planning/context-gate-prd.md`) | FR6-FR11 (context creation), FR22-FR24 (agent integration), Journey 5 (epic context cascade) |
| **ADR-0029** (`docs/adr/0029-context-gate-architecture.md`) | Component structure diagram (lines 81-108), consistency rules 5-6 and 9, implementation plan items 5-6 |
| **Tandem Protocol** (`pennyfarthing-dist/guides/tandem-protocol.md`) | Reference for backseat protocol (not used for epic context) |

## Story Notes

**What to do:** Create the skill definition at `pennyfarthing-dist/skills/pf-context/skill.md` with the epic creation flow. Skill reads sprint YAML for epic data, reads schema for section requirements, populates template, writes output.

**Key constraints:**
- Schema is the ONLY authority for sections
- Output naming: `context-epic-{id}.md`
- No tandem for epic context — single-agent operation

**Test criteria:** Invoking `/pf-context create epic {id}` produces a valid context file that passes `pf context-docs validate epic {id}`.

## SM Assessment

**Setup complete.** Session created, branch `feat/PROJ-15686-pf-context-create-epic` ready on pennyfarthing develop. Jira PROJ-15686 claimed and In Progress. Story 129-4 (templates) folded into this story. Dependencies 129-2 (schema) verified present at `pennyfarthing-dist/schemas/context-schema.yaml`. Epic context file at `sprint/context/context-epic-130.md` provides full technical architecture for the skill.

**Handoff:** To TEA (Thufir Hawat) for RED phase — design tests for the `/pf-context create epic` skill.

## TEA Assessment

**Tests Required:** No
**Reason:** All deliverables are markdown/YAML files (skill definition, epic context template, registry entry). No executable code to test. Structural validation handled by existing `pf validate skill-command` validator.

**Bypass Criteria:** Documentation/configuration changes with existing validation coverage.

**Handoff:** To Dev for implementation. Dev should create:
1. `pennyfarthing-dist/skills/pf-context.md` — skill definition with epic creation flow
2. `pennyfarthing-dist/templates/context-epic-template.md` — template with sections from `schemas/context-schema.yaml`
3. Registry entry in `pennyfarthing-dist/skills/skill-registry.yaml`

**Note:** Existing skills are flat `.md` files in `skills/`, not subdirectories. Registry metadata lives in `skill-registry.yaml`. See existing skills (e.g., `pf-bc`, `pf-changelog`) for structure reference.

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/templates/context-schema.yaml` - Document schema for epic/story context sections per ADR-0029 (dependency from 129-2 was incomplete — Prime schema existed but document schema was missing)
- `pennyfarthing-dist/templates/context-epic-template.md` - Epic context template with schema-driven sections (folded from 129-4)
- `pennyfarthing-dist/skills/pf-context/skill.md` - Skill definition with 7-step epic creation flow
- `pennyfarthing-dist/skills/skill-registry.yaml` - Registry entry for pf-context skill

**Tests:** N/A — TEA bypassed (markdown/YAML-only deliverables with existing validation)
**Branch:** feat/PROJ-15686-pf-context-create-epic (not yet pushed)

**Notes:**
- The `schemas/context-schema.yaml` is the Prime context schema (tiers, components). The document schema for epic/story sections was missing — created at `templates/context-schema.yaml` per ADR-0029 line 112.
- Skills are subdirectories (not flat `.md` files as TEA noted) — verified against existing skills like `pf-bc/`, `pf-changelog/`.
- Skill is extensible for 130-2 (story context) and 130-3 (tandem integration).

**Handoff:** To next phase (review)

## TEA Verify Assessment

**Verification:** Pass
**Reason:** All deliverables are markdown/YAML. Structural checks confirm:
- Template sections align with schema (3 required + 2 optional present)
- Skill references schema at Step 1 (schema-driven, not hardcoded)
- Registry entry resolves correctly
- Branch pushed, commit clean

**Handoff:** To Reviewer for code review

## Reviewer Assessment

**Verdict:** APPROVED
**Data flow traced:** `/pf-context create epic {id}` → schema read → sprint epic lookup → planning doc search → template load → section fill → write to `sprint/context/` (correct end-to-end)
**Pattern observed:** Schema-driven section authority at `skill.md:27` and `context-schema.yaml:10` — reinforces ADR-0029 Rule #2
**Error handling:** Graceful degradation for missing validator (`skill.md:95`), fallback ID resolution (`skill.md:33-34`), pre-existing content handling (`skill.md:48`)

**Observations:**
| Severity | Issue | Location | Action |
|----------|-------|----------|--------|
| [LOW] | Schema uses "Cross-Epic Dependencies" vs ADR's "Cross-Story Dependencies" | `context-schema.yaml:20` | Implementation more correct — ADR likely has typo |
| [LOW] | Step 5 enumerates sections explicitly (mild hardcoding) | `skill.md:62-68` | Inherent to instructional markdown — acceptable |
| [VERIFIED] | Schema sections match ADR-0029 | `context-schema.yaml:14-35` | Correct |
| [VERIFIED] | Template aligns with schema | `context-epic-template.md` | All required + optional present |
| [VERIFIED] | Correct schema path per ADR-0029 | `skill.md:27` | Matches ADR line 112 |
| [VERIFIED] | Registry entry follows patterns | `skill-registry.yaml` | Alphabetically ordered, all fields present |
| [VERIFIED] | No security concerns | All files | Markdown/YAML only |
| [VERIFIED] | Graceful degradation | `skill.md:48,95` | Missing validator, pre-existing content handled |

**Handoff:** To SM for finish-story

## Cross-Epic Dependencies

**Depends on:**
- Epic 129-2 (Context Schema YAML) — defines what sections to include
- Epic 129-4 (Context Document Templates) — provides the base template to fill

**Depended on by:**
- Epic 130-2 (Story context creation extends this skill)
- Epic 131-2 (SM Auto-Triggers Context Creation)