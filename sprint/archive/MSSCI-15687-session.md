# Session: 130-2

## Story

| Field | Value |
|-------|-------|
| **ID** | 130-2 |
| **Jira Key** | MSSCI-15687 |
| **Title** | /pf-context create story Skill (PM-Only Mode) |
| **Epic** | 130 (MSSCI-15685) — Automated Context Creation |
| **Points** | 3 |
| **Priority** | P1 |
| **Type** | feature |
| **Assigned** | keith.avery@1898andco.io |
| **Workflow** | tdd |

## Description

Extend the `/pf-context` skill to handle story context creation in PM-only mode. This story implements the core story context creation flow, reading parent epic context and story YAML, filling a story template with frontmatter. Tandem partner integration is added separately in 130-3.

**Key requirements:**
- PM reads parent epic context + story YAML
- Fills story template with frontmatter (`parent:` field linking to epic context)
- If parent epic context doesn't exist, fail with clear message
- Outputs to `sprint/context/context-story-{id}.md`
- Passes `pf context-docs validate story {id}` checks

**Implementation path:** Story context creation flow (per epic context, section 109-120)

## Workflow Tracking

| Field | Value |
|-------|-------|
| **Workflow** | tdd |
| **Phase** | setup |
| **Phase Started** | 2026-02-26T11:34:54Z |

## Phase History

| Phase | Agent | Status | Started | Completed |
|-------|-------|--------|---------|-----------|
| setup | sm | in_progress | 2026-02-26T11:34:54Z | — |
| red | tea | pending | — | — |
| green | dev | pending | — | — |
| verify | tea | pending | — | — |
| review | reviewer | pending | — | — |
| finish | sm | pending | — | — |

## Work Context

| Field | Value |
|-------|-------|
| **Repository** | pennyfarthing |
| **Branch** | feat/130-2-pf-context-create-story-skill |
| **Base Branch** | develop |

## SM Assessment

### Scope

Story 130-2 extends the `/pf-context` skill (created in 130-1) to create story context documents in PM-only mode. The skill must:

1. Accept invocation: `/pf-context create story {story_id}`
2. Read story metadata from sprint YAML (ACs, points, workflow, type)
3. Read parent epic context from `sprint/context/context-epic-{epic_id}.md`
4. Read context schema requirements from `context-schema.yaml`
5. Load story context template from `pennyfarthing-dist/templates/context-story-template.md`
6. Fill template sections with business context, scope boundaries, and AC context
7. Write output to `sprint/context/context-story-{story_id}.md` with frontmatter

This is the PM-primary path; tandem partner integration (backseat observation) is deferred to 130-3. The skill is PM-only for now — no tandem spawning.

### Key Files

**Consume (read, don't modify):**
- `/Users/keithavery/Projects/pf-2/sprint/context/context-epic-130.md` — Epic context and flow diagram
- `/Users/keithavery/Projects/pf-2/sprint/epic-MSSCI-15685.yaml` — Story metadata
- `/Users/keithavery/Projects/pf-2/pennyfarthing/pennyfarthing-dist/skills/pf-context/` — Skill from 130-1 (extend with story mode)
- `/Users/keithavery/Projects/pf-2/pennyfarthing/pennyfarthing-dist/templates/` — context-schema.yaml, context-story-template.md (from 129-4)

**Produce (create/modify):**
- `/Users/keithavery/Projects/pf-2/pennyfarthing/pennyfarthing-dist/skills/pf-context/skill.md` — Extended skill definition with story creation flow
- `/Users/keithavery/Projects/pf-2/pennyfarthing/pennyfarthing-dist/skills/pf-context/metadata.yaml` — Skill registration (updated if needed)

### Repos

| Repo | Branch | Role |
|------|--------|------|
| pennyfarthing | feat/130-2-pf-context-create-story-skill | primary |

### Routing

**Route:** TDD workflow
**Phase sequence:** setup → **red** → green → verify → review → finish

1. **Red Phase (TEA Igor)** — Write failing tests for story context creation
   - Test that `/pf-context create story {id}` validates parent epic context exists
   - Test that output file is created with correct frontmatter
   - Test that required template sections are populated
   - Test validation passes with `pf context-docs validate story {id}`

2. **Green Phase (DEV)** — Implement skill to pass tests
3. **Verify Phase (TEA)** — Validate context quality
4. **Review Phase (Reviewer)** — Code review and approval
5. **Finish Phase (SM)** — Merge and mark story complete

### Risk

**Dependencies:**
- Requires 130-1 (epic skill) — DONE (completed 2026-02-26)
- Requires 129-2 (context schema) and 129-4 (templates) — both from previous sprint

**Design clarity:** Flow is well-documented in epic context (section 109-120). Template schema is external dependency (from 129-4).

**Tandem future:** Story implements PM-only mode. Tandem integration deferred to 130-3; no design debt introduced here.

**Test scope:** Must validate frontmatter format and parent epic linkage. Schema compliance is validated by external tool `pf context-docs validate story`.

**No blocking risks identified.** Proceed to red phase.

---

**Session Created:** 2026-02-26T11:34:54Z
**SM:** Keith Avery

## TEA Assessment

**Tests Required:** Yes
**Reason:** Feature story — new skill functionality needs test coverage

**Test Files:**
- `tests/python/test_context_story_skill.py` — 11 tests across 5 ACs

**Tests Written:** 11 tests covering 5 ACs
| AC | Tests | What They Verify |
|----|-------|-----------------|
| AC1 (2 tests) | Skill section + quick ref | `## Create Story Context` heading exists, "create story" in content |
| AC2 (3 tests) | Template existence + structure | `context-story-template.md` exists, has schema-required section headings, has `parent` frontmatter placeholder |
| AC3 (1 test) | Skill args registration | Frontmatter `args` field includes "story" |
| AC4 (2 tests) | Parent epic validation | Story section mentions checking epic context exists, mentions failing on missing |
| AC5 (3 tests) | Output format | Mentions `parent` frontmatter, `context-story-` output path, reads `context-schema.yaml` |

**Status:** RED (11/11 failing — all for correct reasons: missing implementation)
**Commit:** `bca3cdef8` on `feat/130-2-pf-context-create-story-skill`

**Handoff:** To Dev (Ponder Stibbons) for implementation

## Dev Assessment

**Implementation Complete:** Yes
**Files Changed:**
- `pennyfarthing-dist/skills/pf-context/skill.md` — Added `## Create Story Context` section with 7-step flow (schema read, story lookup, parent epic validation, template load, section fill, frontmatter write, validation). Updated frontmatter args and Quick Reference table.
- `pennyfarthing-dist/templates/context-story-template.md` — New template with required sections (Business Context, Technical Guardrails, Scope Boundaries, AC Context) plus optional sections, with `parent:` frontmatter placeholder.

**Tests:** 11/11 passing (GREEN)
**Branch:** feat/130-2-pf-context-create-story-skill (pushed)

**Handoff:** To Igor (TEA) for verify phase

## TEA Verify Assessment

**Verification:** PASS
**Tests:** 11/11 passing (GREEN confirmed)

**Quality checks:**
- Skill structure mirrors epic section (7 steps, consistent pattern)
- Template includes all 4 required sections from `context-schema.yaml`
- Template includes all 3 optional sections from `context-schema.yaml`
- Frontmatter has `parent:` placeholder (required) + `workflow:` (bonus)
- Parent epic validation with clear error message (Step 3)
- Schema-driven approach (ADR-0029 Rule #2) enforced in instructions
- PM-only mode noted, 130-3 tandem deferred — no design debt
- No regressions in story test suite

**Handoff:** To Granny Weatherwax (Reviewer) for code review

## Reviewer Assessment

**Verdict:** APPROVED

| # | Severity | Finding | Location |
|---|----------|---------|----------|
| 1 | `[VERIFIED]` | Schema-template alignment correct. All 4 required + 3 optional sections present. Required `parent` frontmatter included. | `context-story-template.md:1-51` |
| 2 | `[VERIFIED]` | Structural consistency with epic section. Same 7-step pattern, parallel section/source tables. | `skill.md:106-198` |
| 3 | `[VERIFIED]` | Parent epic validation gate blocks on missing parent with actionable error message. | `skill.md:122-135` |
| 4 | `[VERIFIED]` | Args registration and Quick Reference both updated for `create story {id}`. | `skill.md:8,20` |
| 5 | `[MEDIUM]` | Test assertions are loose string matches. Acceptable per DEC-REV-003 for markdown skill definitions. | `test_context_story_skill.py` |
| 6 | `[VERIFIED]` | PM-only constraint explicitly stated, clean boundary for 130-3 tandem. | `skill.md:191-198` |
| 7 | `[VERIFIED]` | Output naming and location per ADR-0029 Rules #1 and #7. | `skill.md:175-179` |

**Data flow traced:** User → `/pf-context create story {id}` → schema → metadata → parent gate → template → fill → frontmatter write → validate. Linear, clean.
**Error handling:** Missing parent = explicit fail. Framework files = natural read failures. Invalid IDs caught by CLI.
**Preflight:** 11/11 tests pass, no forbidden patterns, 2 conventional commits.

**Handoff:** To Captain Carrot Ironfoundersson (SM) for finish-story